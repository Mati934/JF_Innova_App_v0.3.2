-- =============================================================================
-- MIGRACION: Modulo CRONOGRAMA (ver docs/planificacion/02_en_progreso/PLAN_CRONOGRAMA_EMPRESAS_MVP.md)
-- Objetivo:
--   1) Crear tablas propias del modulo (no reutiliza `empresas`/`contratistas`).
--   2) Modulo 100% online: sin tablas `_pendientes` en SQLite (igual que Tickets).
--   3) RLS: visibilidad por grupo/usuario asignado a cada plan; administracion
--      reservada a super admin o usuarios con permiso CRONOGRAMA_ADMIN.
--   4) Vinculo opcional Ticket <-> Tarea de cronograma.
--
-- Idempotente: seguro de ejecutar multiples veces.
-- Requiere que ya exista la migracion de Tickets (usa public.is_admin_user()).
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- A) TABLAS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.cronograma_clientes_empresas (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      TEXT NOT NULL,
  rut         TEXT,
  activo      BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.cronograma_clientes_empresas IS
  'Empresa cliente objetivo del modulo Cronograma, independiente de public.empresas.';

CREATE TABLE IF NOT EXISTS public.cronograma_grupos_usuarios (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      TEXT NOT NULL,
  descripcion TEXT,
  activo      BOOLEAN NOT NULL DEFAULT true,
  created_by  UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cronograma_grupo_usuarios (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  grupo_id    UUID NOT NULL REFERENCES public.cronograma_grupos_usuarios(id) ON DELETE CASCADE,
  usuario_id  UUID NOT NULL,
  activo      BOOLEAN NOT NULL DEFAULT true,
  created_by  UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (grupo_id, usuario_id)
);

CREATE TABLE IF NOT EXISTS public.cronograma_tipos_tarea (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo                TEXT NOT NULL UNIQUE,
  nombre                TEXT NOT NULL,
  target_module_key     TEXT,
  usa_pantalla_generica BOOLEAN NOT NULL DEFAULT false,
  evidencia_config_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  activo                BOOLEAN NOT NULL DEFAULT true,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cronograma_plantillas (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      TEXT NOT NULL,
  descripcion TEXT,
  activo      BOOLEAN NOT NULL DEFAULT true,
  created_by  UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cronograma_plantilla_tareas (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plantilla_id        UUID NOT NULL REFERENCES public.cronograma_plantillas(id) ON DELETE CASCADE,
  tipo_tarea_id       UUID NOT NULL REFERENCES public.cronograma_tipos_tarea(id),
  nombre              TEXT NOT NULL,
  frecuencia          TEXT NOT NULL CHECK (frecuencia IN
                        ('DIARIA','SEMANAL','QUINCENAL','MENSUAL','TRIMESTRAL','SEMESTRAL','ANUAL','PERSONALIZADA')),
  config_periodo_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  parametros_json     JSONB NOT NULL DEFAULT '{}'::jsonb,
  orden               INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.cronograma_permisos (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id  UUID NOT NULL,
  permiso_key TEXT NOT NULL CHECK (permiso_key IN ('CRONOGRAMA_ADMIN')),
  activo      BOOLEAN NOT NULL DEFAULT true,
  created_by  UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (usuario_id, permiso_key)
);

CREATE TABLE IF NOT EXISTS public.cronograma_planes (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_empresa_id  UUID NOT NULL REFERENCES public.cronograma_clientes_empresas(id),
  nombre              TEXT NOT NULL,
  desde               DATE,
  hasta               DATE,
  activo              BOOLEAN NOT NULL DEFAULT true,
  created_by          UUID,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cronograma_grupo_planes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id     UUID NOT NULL REFERENCES public.cronograma_planes(id) ON DELETE CASCADE,
  grupo_id    UUID NOT NULL REFERENCES public.cronograma_grupos_usuarios(id) ON DELETE CASCADE,
  activo      BOOLEAN NOT NULL DEFAULT true,
  created_by  UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (plan_id, grupo_id)
);

CREATE TABLE IF NOT EXISTS public.cronograma_usuario_planes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id     UUID NOT NULL REFERENCES public.cronograma_planes(id) ON DELETE CASCADE,
  usuario_id  UUID NOT NULL,
  activo      BOOLEAN NOT NULL DEFAULT true,
  created_by  UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (plan_id, usuario_id)
);

CREATE TABLE IF NOT EXISTS public.cronograma_plan_tareas (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id             UUID NOT NULL REFERENCES public.cronograma_planes(id) ON DELETE CASCADE,
  tipo_tarea_id       UUID NOT NULL REFERENCES public.cronograma_tipos_tarea(id),
  nombre              TEXT NOT NULL,
  frecuencia          TEXT NOT NULL CHECK (frecuencia IN
                        ('DIARIA','SEMANAL','QUINCENAL','MENSUAL','TRIMESTRAL','SEMESTRAL','ANUAL','PERSONALIZADA')),
  desde               DATE,
  hasta               DATE,
  config_periodo_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  parametros_json     JSONB NOT NULL DEFAULT '{}'::jsonb,
  activo              BOOLEAN NOT NULL DEFAULT true,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cronograma_tareas_programadas (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_tarea_id               UUID NOT NULL REFERENCES public.cronograma_plan_tareas(id) ON DELETE CASCADE,
  cliente_empresa_id          UUID NOT NULL REFERENCES public.cronograma_clientes_empresas(id),
  fecha_programada            DATE NOT NULL,
  estado                      TEXT NOT NULL DEFAULT 'PROGRAMADA'
                                CHECK (estado IN ('PROGRAMADA','TOMADA','EN_PROGRESO','COMPLETADA','VENCIDA')),
  tomada_por_id               UUID,
  tomada_at                   TIMESTAMPTZ,
  completada_por_id           UUID,
  completada_at               TIMESTAMPTZ,
  completada_fuera_de_plazo   BOOLEAN NOT NULL DEFAULT false,
  motivo_regularizacion       TEXT,
  resultado_json              JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (plan_tarea_id, fecha_programada)
);

CREATE TABLE IF NOT EXISTS public.cronograma_tareas_historial (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tarea_programada_id   UUID NOT NULL REFERENCES public.cronograma_tareas_programadas(id) ON DELETE CASCADE,
  accion                TEXT NOT NULL CHECK (accion IN
                          ('CREADA','TOMADA','SOLTADA','INICIADA','COMPLETADA','REABIERTA','VENCIDA')),
  usuario_id            UUID NOT NULL,
  comentario            TEXT,
  payload_json          JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cronograma_tareas_evidencias (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tarea_programada_id   UUID NOT NULL REFERENCES public.cronograma_tareas_programadas(id) ON DELETE CASCADE,
  tipo                  TEXT,
  url                   TEXT,
  comentario            TEXT,
  created_by            UUID,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cronograma_tarea_inspecciones (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tarea_programada_id   UUID NOT NULL REFERENCES public.cronograma_tareas_programadas(id) ON DELETE CASCADE,
  inspeccion_id         UUID NOT NULL REFERENCES public.actividades(id),
  created_by            UUID,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tarea_programada_id, inspeccion_id)
);

-- Vinculo opcional Ticket <-> Tarea de cronograma (ver seccion 6 del plan).
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS cronograma_tarea_id UUID REFERENCES public.cronograma_tareas_programadas(id);

-- -----------------------------------------------------------------------------
-- B) INDICES
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_cronograma_grupo_usuarios_usuario   ON public.cronograma_grupo_usuarios(usuario_id);
CREATE INDEX IF NOT EXISTS idx_cronograma_planes_cliente           ON public.cronograma_planes(cliente_empresa_id);
CREATE INDEX IF NOT EXISTS idx_cronograma_usuario_planes_usuario   ON public.cronograma_usuario_planes(usuario_id);
CREATE INDEX IF NOT EXISTS idx_cronograma_plan_tareas_plan         ON public.cronograma_plan_tareas(plan_id);
CREATE INDEX IF NOT EXISTS idx_cronograma_tareas_prog_plan_tarea   ON public.cronograma_tareas_programadas(plan_tarea_id);
CREATE INDEX IF NOT EXISTS idx_cronograma_tareas_prog_estado       ON public.cronograma_tareas_programadas(estado);
CREATE INDEX IF NOT EXISTS idx_cronograma_tareas_hist_tarea        ON public.cronograma_tareas_historial(tarea_programada_id);
CREATE INDEX IF NOT EXISTS idx_cronograma_tareas_evid_tarea        ON public.cronograma_tareas_evidencias(tarea_programada_id);
CREATE INDEX IF NOT EXISTS idx_tickets_cronograma_tarea            ON public.tickets(cronograma_tarea_id);

-- -----------------------------------------------------------------------------
-- C) updated_at automatico
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.touch_cronograma_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'cronograma_clientes_empresas', 'cronograma_grupos_usuarios', 'cronograma_tipos_tarea',
    'cronograma_plantillas', 'cronograma_planes', 'cronograma_plan_tareas',
    'cronograma_tareas_programadas'
  ]
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_touch_updated_at ON public.%I; '
      'CREATE TRIGGER trg_touch_updated_at BEFORE UPDATE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.touch_cronograma_updated_at();',
      t, t
    );
  END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- D) HELPERS DE RLS
-- -----------------------------------------------------------------------------

-- true si el usuario es super admin (admin + empresa administradora) o tiene
-- el permiso persistible CRONOGRAMA_ADMIN (ver cronograma_permisos).
CREATE OR REPLACE FUNCTION public.is_cronograma_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    (
      public.is_admin_user() AND (
        EXISTS (
          SELECT 1 FROM public.usuario_empresas ue
          JOIN public.empresas e ON e.id = ue.empresa_id
          WHERE ue.usuario_id = auth.uid() AND e.es_administradora = true
        )
        OR EXISTS (
          SELECT 1 FROM public.usuarios u
          JOIN public.empresas e ON e.id = u.empresa_id
          WHERE u.id = auth.uid() AND e.es_administradora = true
        )
      )
    )
    OR EXISTS (
      SELECT 1 FROM public.cronograma_permisos cp
      WHERE cp.usuario_id = auth.uid() AND cp.permiso_key = 'CRONOGRAMA_ADMIN' AND cp.activo = true
    );
$$;

-- true si el usuario tiene un cronograma (plan) asignado por grupo o directo.
CREATE OR REPLACE FUNCTION public.cronograma_plan_visible(p_plan_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.is_cronograma_admin()
    OR EXISTS (
      SELECT 1 FROM public.cronograma_usuario_planes up
      WHERE up.plan_id = p_plan_id AND up.usuario_id = auth.uid() AND up.activo = true
    )
    OR EXISTS (
      SELECT 1 FROM public.cronograma_grupo_planes gp
      JOIN public.cronograma_grupo_usuarios gu ON gu.grupo_id = gp.grupo_id AND gu.activo = true
      WHERE gp.plan_id = p_plan_id AND gp.activo = true AND gu.usuario_id = auth.uid()
    );
$$;

-- -----------------------------------------------------------------------------
-- E) ROW LEVEL SECURITY
-- -----------------------------------------------------------------------------
ALTER TABLE public.cronograma_clientes_empresas   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma_grupos_usuarios      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma_grupo_usuarios       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma_tipos_tarea          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma_plantillas           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma_plantilla_tareas     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma_permisos             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma_planes               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma_grupo_planes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma_usuario_planes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma_plan_tareas          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma_tareas_programadas   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma_tareas_historial     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma_tareas_evidencias    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma_tarea_inspecciones   ENABLE ROW LEVEL SECURITY;

-- Configuracion de back-office (empresas cliente, grupos, tipos, plantillas,
-- permisos): solo administra quien tiene is_cronograma_admin(); el resto de
-- usuarios no necesita leer estas tablas directamente (se resuelven via
-- funciones SECURITY DEFINER en las tablas operativas).
DROP POLICY IF EXISTS cronograma_clientes_empresas_all ON public.cronograma_clientes_empresas;
CREATE POLICY cronograma_clientes_empresas_all ON public.cronograma_clientes_empresas
  FOR ALL TO authenticated
  USING (public.is_cronograma_admin())
  WITH CHECK (public.is_cronograma_admin());

DROP POLICY IF EXISTS cronograma_grupos_usuarios_all ON public.cronograma_grupos_usuarios;
CREATE POLICY cronograma_grupos_usuarios_all ON public.cronograma_grupos_usuarios
  FOR ALL TO authenticated
  USING (public.is_cronograma_admin())
  WITH CHECK (public.is_cronograma_admin());

DROP POLICY IF EXISTS cronograma_grupo_usuarios_all ON public.cronograma_grupo_usuarios;
CREATE POLICY cronograma_grupo_usuarios_all ON public.cronograma_grupo_usuarios
  FOR ALL TO authenticated
  USING (public.is_cronograma_admin())
  WITH CHECK (public.is_cronograma_admin());

DROP POLICY IF EXISTS cronograma_tipos_tarea_all ON public.cronograma_tipos_tarea;
CREATE POLICY cronograma_tipos_tarea_all ON public.cronograma_tipos_tarea
  FOR ALL TO authenticated
  USING (public.is_cronograma_admin())
  WITH CHECK (public.is_cronograma_admin());

DROP POLICY IF EXISTS cronograma_plantillas_all ON public.cronograma_plantillas;
CREATE POLICY cronograma_plantillas_all ON public.cronograma_plantillas
  FOR ALL TO authenticated
  USING (public.is_cronograma_admin())
  WITH CHECK (public.is_cronograma_admin());

DROP POLICY IF EXISTS cronograma_plantilla_tareas_all ON public.cronograma_plantilla_tareas;
CREATE POLICY cronograma_plantilla_tareas_all ON public.cronograma_plantilla_tareas
  FOR ALL TO authenticated
  USING (public.is_cronograma_admin())
  WITH CHECK (public.is_cronograma_admin());

-- cronograma_permisos: solo un super admin "real" (empresa administradora)
-- puede otorgar/quitar el permiso CRONOGRAMA_ADMIN, para evitar que alguien
-- con ese mismo permiso se auto-otorgue mas accesos.
DROP POLICY IF EXISTS cronograma_permisos_all ON public.cronograma_permisos;
CREATE POLICY cronograma_permisos_all ON public.cronograma_permisos
  FOR ALL TO authenticated
  USING (
    public.is_admin_user() AND (
      EXISTS (SELECT 1 FROM public.usuario_empresas ue JOIN public.empresas e ON e.id = ue.empresa_id
              WHERE ue.usuario_id = auth.uid() AND e.es_administradora = true)
      OR EXISTS (SELECT 1 FROM public.usuarios u JOIN public.empresas e ON e.id = u.empresa_id
                 WHERE u.id = auth.uid() AND e.es_administradora = true)
    )
  )
  WITH CHECK (
    public.is_admin_user() AND (
      EXISTS (SELECT 1 FROM public.usuario_empresas ue JOIN public.empresas e ON e.id = ue.empresa_id
              WHERE ue.usuario_id = auth.uid() AND e.es_administradora = true)
      OR EXISTS (SELECT 1 FROM public.usuarios u JOIN public.empresas e ON e.id = u.empresa_id
                 WHERE u.id = auth.uid() AND e.es_administradora = true)
    )
  );

-- Planes: admin gestiona todo; usuarios ven solo los planes que tengan asignados.
DROP POLICY IF EXISTS cronograma_planes_select ON public.cronograma_planes;
CREATE POLICY cronograma_planes_select ON public.cronograma_planes FOR SELECT TO authenticated
  USING (public.cronograma_plan_visible(id));

DROP POLICY IF EXISTS cronograma_planes_write ON public.cronograma_planes;
CREATE POLICY cronograma_planes_write ON public.cronograma_planes FOR ALL TO authenticated
  USING (public.is_cronograma_admin())
  WITH CHECK (public.is_cronograma_admin());

DROP POLICY IF EXISTS cronograma_grupo_planes_all ON public.cronograma_grupo_planes;
CREATE POLICY cronograma_grupo_planes_all ON public.cronograma_grupo_planes
  FOR ALL TO authenticated
  USING (public.is_cronograma_admin())
  WITH CHECK (public.is_cronograma_admin());

DROP POLICY IF EXISTS cronograma_usuario_planes_select ON public.cronograma_usuario_planes;
CREATE POLICY cronograma_usuario_planes_select ON public.cronograma_usuario_planes FOR SELECT TO authenticated
  USING (public.is_cronograma_admin() OR usuario_id = auth.uid());

DROP POLICY IF EXISTS cronograma_usuario_planes_write ON public.cronograma_usuario_planes;
CREATE POLICY cronograma_usuario_planes_write ON public.cronograma_usuario_planes FOR ALL TO authenticated
  USING (public.is_cronograma_admin())
  WITH CHECK (public.is_cronograma_admin());

-- Tareas de plan: visibles/editables si el plan padre es visible.
DROP POLICY IF EXISTS cronograma_plan_tareas_select ON public.cronograma_plan_tareas;
CREATE POLICY cronograma_plan_tareas_select ON public.cronograma_plan_tareas FOR SELECT TO authenticated
  USING (public.cronograma_plan_visible(plan_id));

DROP POLICY IF EXISTS cronograma_plan_tareas_write ON public.cronograma_plan_tareas;
CREATE POLICY cronograma_plan_tareas_write ON public.cronograma_plan_tareas FOR ALL TO authenticated
  USING (public.is_cronograma_admin())
  WITH CHECK (public.is_cronograma_admin());

-- Tareas programadas: visibles si el plan es visible; cualquier usuario con
-- acceso puede tomar/soltar/completar (UPDATE); la generacion masiva (INSERT)
-- queda para el admin o una funcion RPC.
DROP POLICY IF EXISTS cronograma_tareas_prog_select ON public.cronograma_tareas_programadas;
CREATE POLICY cronograma_tareas_prog_select ON public.cronograma_tareas_programadas FOR SELECT TO authenticated
  USING (
    public.cronograma_plan_visible(
      (SELECT pt.plan_id FROM public.cronograma_plan_tareas pt WHERE pt.id = plan_tarea_id)
    )
  );

DROP POLICY IF EXISTS cronograma_tareas_prog_update ON public.cronograma_tareas_programadas;
CREATE POLICY cronograma_tareas_prog_update ON public.cronograma_tareas_programadas FOR UPDATE TO authenticated
  USING (
    public.cronograma_plan_visible(
      (SELECT pt.plan_id FROM public.cronograma_plan_tareas pt WHERE pt.id = plan_tarea_id)
    )
  )
  WITH CHECK (
    public.cronograma_plan_visible(
      (SELECT pt.plan_id FROM public.cronograma_plan_tareas pt WHERE pt.id = plan_tarea_id)
    )
  );

DROP POLICY IF EXISTS cronograma_tareas_prog_insert ON public.cronograma_tareas_programadas;
CREATE POLICY cronograma_tareas_prog_insert ON public.cronograma_tareas_programadas FOR INSERT TO authenticated
  WITH CHECK (public.is_cronograma_admin());

-- Historial y evidencias: append-only, visibles/insertables si la tarea es visible.
DROP POLICY IF EXISTS cronograma_tareas_hist_select ON public.cronograma_tareas_historial;
CREATE POLICY cronograma_tareas_hist_select ON public.cronograma_tareas_historial FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.cronograma_tareas_programadas tp
      JOIN public.cronograma_plan_tareas pt ON pt.id = tp.plan_tarea_id
      WHERE tp.id = tarea_programada_id AND public.cronograma_plan_visible(pt.plan_id)
    )
  );

DROP POLICY IF EXISTS cronograma_tareas_hist_insert ON public.cronograma_tareas_historial;
CREATE POLICY cronograma_tareas_hist_insert ON public.cronograma_tareas_historial FOR INSERT TO authenticated
  WITH CHECK (
    usuario_id = auth.uid() AND EXISTS (
      SELECT 1 FROM public.cronograma_tareas_programadas tp
      JOIN public.cronograma_plan_tareas pt ON pt.id = tp.plan_tarea_id
      WHERE tp.id = tarea_programada_id AND public.cronograma_plan_visible(pt.plan_id)
    )
  );

DROP POLICY IF EXISTS cronograma_tareas_evid_select ON public.cronograma_tareas_evidencias;
CREATE POLICY cronograma_tareas_evid_select ON public.cronograma_tareas_evidencias FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.cronograma_tareas_programadas tp
      JOIN public.cronograma_plan_tareas pt ON pt.id = tp.plan_tarea_id
      WHERE tp.id = tarea_programada_id AND public.cronograma_plan_visible(pt.plan_id)
    )
  );

DROP POLICY IF EXISTS cronograma_tareas_evid_insert ON public.cronograma_tareas_evidencias;
CREATE POLICY cronograma_tareas_evid_insert ON public.cronograma_tareas_evidencias FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.cronograma_tareas_programadas tp
      JOIN public.cronograma_plan_tareas pt ON pt.id = tp.plan_tarea_id
      WHERE tp.id = tarea_programada_id AND public.cronograma_plan_visible(pt.plan_id)
    )
  );

DROP POLICY IF EXISTS cronograma_tarea_inspecciones_select ON public.cronograma_tarea_inspecciones;
CREATE POLICY cronograma_tarea_inspecciones_select ON public.cronograma_tarea_inspecciones FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.cronograma_tareas_programadas tp
      JOIN public.cronograma_plan_tareas pt ON pt.id = tp.plan_tarea_id
      WHERE tp.id = tarea_programada_id AND public.cronograma_plan_visible(pt.plan_id)
    )
  );

DROP POLICY IF EXISTS cronograma_tarea_inspecciones_insert ON public.cronograma_tarea_inspecciones;
CREATE POLICY cronograma_tarea_inspecciones_insert ON public.cronograma_tarea_inspecciones FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.cronograma_tareas_programadas tp
      JOIN public.cronograma_plan_tareas pt ON pt.id = tp.plan_tarea_id
      WHERE tp.id = tarea_programada_id AND public.cronograma_plan_visible(pt.plan_id)
    )
  );

-- -----------------------------------------------------------------------------
-- F) REALTIME (opcional, para reflejar tomas/cierres en vivo)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'cronograma_tareas_programadas'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.cronograma_tareas_programadas;
  END IF;
END $$;

COMMIT;
