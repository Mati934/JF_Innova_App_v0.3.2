-- =============================================================================
-- FIX DE EMERGENCIA: RLS en visitas_tecnicas / visita_respuestas / visitas_checklists
-- =============================================================================
-- Contexto (2026-07-20): se activó RLS en `visitas_tecnicas` y `visita_respuestas`
-- sin crear policies. Como no quedó ninguna policy, TODOS los roles (incluido
-- `authenticated`) quedaron bloqueados para leer/escribir, y el upsert de
-- Visita Técnica en sync_service.dart (_sincronizarVisitas) empezó a fallar
-- silenciosamente (el catch solo hace debugPrint). Por eso el informe de un
-- usuario no llegó a la nube.
--
-- Este script:
--   1. Deja RLS activado (no lo desactiva, para no reabrir el hueco de seguridad).
--   2. Agrega policies "dueño" (igual patrón que ast_informes/ast_hallazgos) para
--      que cada usuario autenticado siga pudiendo crear/editar/leer SUS propias
--      visitas, exactamente como funcionaba antes de activar RLS.
--   3. También asegura `visitas_checklists`, que hoy está SIN RLS (visible para
--      cualquiera, ni siquiera logueado) y es hija directa de visitas_tecnicas.
--
-- Es seguro ejecutar este script aunque ya se haya corrido antes (usa
-- IF NOT EXISTS / DROP POLICY IF EXISTS en todos lados).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. visitas_tecnicas: el dueño (usuario_id) ve / inserta / actualiza sus visitas.
-- -----------------------------------------------------------------------------
ALTER TABLE public.visitas_tecnicas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS visitas_tecnicas_owner_all ON public.visitas_tecnicas;
CREATE POLICY visitas_tecnicas_owner_all
  ON public.visitas_tecnicas FOR ALL
  TO authenticated
  USING      (usuario_id = auth.uid() OR public.is_admin_user())
  WITH CHECK (usuario_id = auth.uid() OR public.is_admin_user());

-- -----------------------------------------------------------------------------
-- 2. visita_respuestas: acceso según la visita padre (igual patrón ast_hallazgos).
-- -----------------------------------------------------------------------------
ALTER TABLE public.visita_respuestas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS visita_respuestas_owner_all ON public.visita_respuestas;
CREATE POLICY visita_respuestas_owner_all
  ON public.visita_respuestas FOR ALL
  TO authenticated
  USING (
    public.is_admin_user() OR EXISTS (
      SELECT 1 FROM public.visitas_tecnicas v
      WHERE v.id = visita_id AND v.usuario_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_admin_user() OR EXISTS (
      SELECT 1 FROM public.visitas_tecnicas v
      WHERE v.id = visita_id AND v.usuario_id = auth.uid()
    )
  );

-- -----------------------------------------------------------------------------
-- 3. visitas_checklists: hoy sin RLS (dato expuesto públicamente). La dejamos
--    protegida con el mismo criterio: acceso según la visita padre.
-- -----------------------------------------------------------------------------
ALTER TABLE public.visitas_checklists ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS visitas_checklists_owner_all ON public.visitas_checklists;
CREATE POLICY visitas_checklists_owner_all
  ON public.visitas_checklists FOR ALL
  TO authenticated
  USING (
    public.is_admin_user() OR EXISTS (
      SELECT 1 FROM public.visitas_tecnicas v
      WHERE v.id = visita_id AND v.usuario_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_admin_user() OR EXISTS (
      SELECT 1 FROM public.visitas_tecnicas v
      WHERE v.id = visita_id AND v.usuario_id = auth.uid()
    )
  );

-- -----------------------------------------------------------------------------
-- 4. Storage: asegurar que el bucket "pdfs_visitas" permite subir/leer al dueño
--    autenticado (la app sube el PDF y el certificado ahí desde sync_service.dart).
--    Si esta policy ya existe (creada desde el dashboard) el DO evita duplicarla.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'pdfs_visitas_authenticated_all'
  ) THEN
    CREATE POLICY pdfs_visitas_authenticated_all
      ON storage.objects FOR ALL
      TO authenticated
      USING      (bucket_id = 'pdfs_visitas')
      WITH CHECK (bucket_id = 'pdfs_visitas');
  END IF;
END $$;

-- =============================================================================
-- PARTE 2 (2026-07-20, mismo incidente): módulo Inspección (actividades)
-- =============================================================================
-- Confirmado con `SELECT * FROM pg_policies` en el dashboard: `actividades` e
-- `inspeccion_respuestas` YA tienen RLS activado, pero solo con policies de
-- SELECT (`select_readonly` para {anon,authenticated}, más "Admins ven todas
-- las actividades" con `is_admin()`). NO existe ninguna policy de INSERT/UPDATE,
-- y `registro_fotografico` no tiene ninguna policy. Resultado: el upsert a
-- `actividades` / `registro_fotografico` / `inspeccion_respuestas` en
-- sync_service.dart falla para cualquier usuario autenticado (igual que pasó
-- con visitas_tecnicas) — esto es lo que le pasó a Sebastián Chaparro.
--
-- No tocamos las policies de SELECT existentes (eso es un tema de seguridad
-- aparte, no de esta emergencia). Solo agregamos la policy que falta para que
-- el dueño (usuario_id / actividad.usuario_id) pueda insertar y actualizar,
-- reusando `public.is_admin()` (la misma función que ya usa la policy de
-- SELECT de `actividades`, confirmada existente en producción).
-- -----------------------------------------------------------------------------

-- 5. actividades: el dueño puede insertar/actualizar sus propias actividades.
DROP POLICY IF EXISTS actividades_owner_write ON public.actividades;
CREATE POLICY actividades_owner_write
  ON public.actividades FOR ALL
  TO authenticated
  USING      (usuario_id = auth.uid() OR public.is_admin())
  WITH CHECK (usuario_id = auth.uid() OR public.is_admin());

-- 6. registro_fotografico: sin ninguna policy hoy. Acceso según la actividad padre.
ALTER TABLE public.registro_fotografico ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS registro_fotografico_owner_all ON public.registro_fotografico;
CREATE POLICY registro_fotografico_owner_all
  ON public.registro_fotografico FOR ALL
  TO authenticated
  USING (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.actividades a
      WHERE a.id = actividad_id AND a.usuario_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.actividades a
      WHERE a.id = actividad_id AND a.usuario_id = auth.uid()
    )
  );

-- 7. inspeccion_respuestas: el dueño puede insertar/actualizar según la actividad padre.
DROP POLICY IF EXISTS inspeccion_respuestas_owner_write ON public.inspeccion_respuestas;
CREATE POLICY inspeccion_respuestas_owner_write
  ON public.inspeccion_respuestas FOR ALL
  TO authenticated
  USING (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.actividades a
      WHERE a.id = actividad_id AND a.usuario_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.actividades a
      WHERE a.id = actividad_id AND a.usuario_id = auth.uid()
    )
  );

-- 8. Storage: buckets que usa el módulo Inspección ("evidencias" para fotos,
--    "reportes" para el PDF del informe).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'evidencias_authenticated_all'
  ) THEN
    CREATE POLICY evidencias_authenticated_all
      ON storage.objects FOR ALL
      TO authenticated
      USING      (bucket_id = 'evidencias')
      WITH CHECK (bucket_id = 'evidencias');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'reportes_authenticated_all'
  ) THEN
    CREATE POLICY reportes_authenticated_all
      ON storage.objects FOR ALL
      TO authenticated
      USING      (bucket_id = 'reportes')
      WITH CHECK (bucket_id = 'reportes');
  END IF;
END $$;

-- =============================================================================
-- PARTE 3 (2026-07-20, mismo incidente): resto de tablas detectadas con
-- `SELECT * FROM pg_policies` (screenshot completo del dashboard).
-- =============================================================================
-- Se revisó TODA la lista de tablas públicas. Se agrupan así:
--
-- (A) ROTAS AHORA MISMO (RLS ON, sin policy de escritura) — mismo bug de hoy:
--     - verificaciones_buceo / verificaciones_embarcacion: solo select_readonly,
--       sin INSERT/UPDATE. Se escriben desde sync_service.dart
--       (_sincronizarVerificaciones / _sincronizarVerificacionesEmbarcacion)
--       para INSPECCION_BUCEO / INSPECCION_EMBARCACION (el módulo de Sebastián).
--     - buceo_equipamiento_numeradores: RLS ON y CERO policies. La usa el
--       trigger fn_buceo_equipamiento_set_correlativo() (NO es SECURITY DEFINER,
--       corre como el usuario autenticado) para asignar el correlativo al
--       finalizar un informe de Buceo Equipamiento -> sin policy, esos informes
--       no pueden finalizar.
--
-- (B) SIN RLS HOY (hueco de seguridad, abiertas a cualquiera) que SÍ se
--     escriben desde la app -> les damos el mismo patrón "dueño"/authenticated
--     que ya usa el resto del proyecto:
--     - actividad_participantes (via actividad padre)
--     - extintores / mantenciones_prosesso (via visita padre)
--     - personal_externo (ya tiene su policy correcta, solo faltaba activar RLS)
--     - empresa_areas / empresa_modulos (lectura para cualquier autenticado,
--       escritura solo admin — se gestionan desde el panel admin de la app)
--
-- (C) SIN RLS y SIN uso actual en el código de esta app (formulario_campos_extra
--     ya tenía RLS+SELECT, pero capacitaciones_asistentes/capacitaciones_registros/
--     ticket_historial/roles no se tocan desde este repo). Se activa RLS con una
--     policy amplia para authenticated (no se conoce su dueño/esquema de uso real
--     y podrían ser usadas por el panel de control aparte) para cerrar el acceso
--     anónimo sin arriesgar romper ese otro sistema.
-- -----------------------------------------------------------------------------

-- (A.1) verificaciones_buceo / verificaciones_embarcacion: dueño via actividad padre.
DROP POLICY IF EXISTS verificaciones_buceo_owner_write ON public.verificaciones_buceo;
CREATE POLICY verificaciones_buceo_owner_write
  ON public.verificaciones_buceo FOR ALL
  TO authenticated
  USING (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.actividades a
      WHERE a.id = actividad_id AND a.usuario_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.actividades a
      WHERE a.id = actividad_id AND a.usuario_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS verificaciones_embarcacion_owner_write ON public.verificaciones_embarcacion;
CREATE POLICY verificaciones_embarcacion_owner_write
  ON public.verificaciones_embarcacion FOR ALL
  TO authenticated
  USING (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.actividades a
      WHERE a.id = actividad_id AND a.usuario_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.actividades a
      WHERE a.id = actividad_id AND a.usuario_id = auth.uid()
    )
  );

-- (A.2) buceo_equipamiento_numeradores: contador interno compartido, sin dueño.
DROP POLICY IF EXISTS buceo_equipamiento_numeradores_authenticated_all ON public.buceo_equipamiento_numeradores;
CREATE POLICY buceo_equipamiento_numeradores_authenticated_all
  ON public.buceo_equipamiento_numeradores FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- (B.1) actividad_participantes: dueño via actividad padre.
ALTER TABLE public.actividad_participantes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS actividad_participantes_owner_write ON public.actividad_participantes;
CREATE POLICY actividad_participantes_owner_write
  ON public.actividad_participantes FOR ALL
  TO authenticated
  USING (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.actividades a
      WHERE a.id = actividad_id AND a.usuario_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.actividades a
      WHERE a.id = actividad_id AND a.usuario_id = auth.uid()
    )
  );

-- (B.2) extintores / mantenciones_prosesso: dueño via visita padre.
ALTER TABLE public.extintores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS extintores_owner_write ON public.extintores;
CREATE POLICY extintores_owner_write
  ON public.extintores FOR ALL
  TO authenticated
  USING (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.visitas_tecnicas v
      WHERE v.id = visita_id AND v.usuario_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.visitas_tecnicas v
      WHERE v.id = visita_id AND v.usuario_id = auth.uid()
    )
  );

ALTER TABLE public.mantenciones_prosesso ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mantenciones_prosesso_owner_write ON public.mantenciones_prosesso;
CREATE POLICY mantenciones_prosesso_owner_write
  ON public.mantenciones_prosesso FOR ALL
  TO authenticated
  USING (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.visitas_tecnicas v
      WHERE v.id = visita_id AND v.usuario_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.visitas_tecnicas v
      WHERE v.id = visita_id AND v.usuario_id = auth.uid()
    )
  );

-- (B.3) personal_externo: la policy "Permitir gestion total a usuarios
--       autenticados" ya existe y es correcta, solo faltaba activar RLS.
ALTER TABLE public.personal_externo ENABLE ROW LEVEL SECURITY;

-- (B.4) empresa_areas / empresa_modulos: lectura para cualquier autenticado
--       (necesaria para mostrar/ocultar módulos y áreas por empresa),
--       escritura solo admin (se gestiona desde el panel admin de la app).
ALTER TABLE public.empresa_areas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS empresa_areas_select ON public.empresa_areas;
CREATE POLICY empresa_areas_select
  ON public.empresa_areas FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS empresa_areas_admin_write ON public.empresa_areas;
CREATE POLICY empresa_areas_admin_write
  ON public.empresa_areas FOR ALL
  TO authenticated
  USING      (public.is_admin())
  WITH CHECK (public.is_admin());

ALTER TABLE public.empresa_modulos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS empresa_modulos_select ON public.empresa_modulos;
CREATE POLICY empresa_modulos_select
  ON public.empresa_modulos FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS empresa_modulos_admin_write ON public.empresa_modulos;
CREATE POLICY empresa_modulos_admin_write
  ON public.empresa_modulos FOR ALL
  TO authenticated
  USING      (public.is_admin())
  WITH CHECK (public.is_admin());

-- (C) Tablas sin RLS y sin uso detectado en este repo (posible uso del panel
--     de control aparte). Se activa RLS con acceso amplio para `authenticated`
--     para no romper ese otro sistema, y se cierra el acceso a `anon`.
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
-- (la policy "Todos leen roles" ya existe con rol {public}; queda activa)

ALTER TABLE public.capacitaciones_registros ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS capacitaciones_registros_authenticated_all ON public.capacitaciones_registros;
CREATE POLICY capacitaciones_registros_authenticated_all
  ON public.capacitaciones_registros FOR ALL
  TO authenticated USING (true) WITH CHECK (true);

ALTER TABLE public.capacitaciones_asistentes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS capacitaciones_asistentes_authenticated_all ON public.capacitaciones_asistentes;
CREATE POLICY capacitaciones_asistentes_authenticated_all
  ON public.capacitaciones_asistentes FOR ALL
  TO authenticated USING (true) WITH CHECK (true);

ALTER TABLE public.ticket_historial ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ticket_historial_authenticated_all ON public.ticket_historial;
CREATE POLICY ticket_historial_authenticated_all
  ON public.ticket_historial FOR ALL
  TO authenticated USING (true) WITH CHECK (true);

-- -----------------------------------------------------------------------------
-- 10. Verificación rápida (ejecutar aparte, no bloquea el script):
--    SELECT c.relname AS tabla, c.relrowsecurity AS rls_activado,
--           COALESCE(p.policyname,'(sin policies)') AS policy, p.cmd, p.roles
--    FROM pg_class c
--    JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
--    LEFT JOIN pg_policies p ON p.schemaname = 'public' AND p.tablename = c.relname
--    WHERE c.relkind = 'r'
--    ORDER BY c.relname, p.cmd;
-- -----------------------------------------------------------------------------
