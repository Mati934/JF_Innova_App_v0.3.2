-- =============================================================================
-- MODULO REGISTRO DE INMERSIONES  ·  2026-11-18
-- Crea las tablas del registro de inmersiones de buceo (AquaChile): cabecera
-- vinculada a una inspeccion de buceo, una fila por buzo, una fila por
-- inmersion y fotos con tipo. Numero propio por empresa (RI-NNNN, contador
-- REGISTRO_INMERSIONES en numeradores_informe), rama en historial_unificado,
-- baja en cascada si se elimina la inspeccion, RLS y habilitacion para
-- AquaChile. Plan: docs/planificacion/02_en_progreso/PLAN_REGISTRO_INMERSIONES.md
-- Ejecutar MANUALMENTE, DESPUES de tener la app lista (orden de la plantilla).
-- Reejecutable: si (IF NOT EXISTS, CREATE OR REPLACE, DROP POLICY IF EXISTS,
-- ON CONFLICT). No borra datos.
-- Pasos: 0 (solo lectura) -> 1 (BEGIN..COMMIT) -> 2 (verificar).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. SOLO LECTURA
-- -----------------------------------------------------------------------------
-- Esperado antes de la primera ejecucion: las 4 tablas en NULL, bucket = true,
-- las 5 funciones presentes, numerador_existente = 0.
SELECT
  to_regclass('public.registros_inmersion')            AS registros,
  to_regclass('public.registro_inmersion_buzos')       AS buzos,
  to_regclass('public.registro_inmersion_inmersiones') AS inmersiones,
  to_regclass('public.registro_inmersion_fotos')       AS fotos,
  EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'evidencias') AS bucket,
  (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('next_numero_informe', 'is_admin_user', 'is_superadmin_user',
                        'user_has_empresa', 'resolver_empresa_usuario')) AS funciones_5,
  (SELECT count(*) FROM public.numeradores_informe
    WHERE modulo = 'REGISTRO_INMERSIONES') AS numerador_existente;

-- Esperado: 1 fila (Aquachile).
SELECT id, nombre FROM public.empresas WHERE nombre = 'Aquachile';

-- -----------------------------------------------------------------------------
-- 1. CAMBIO
-- -----------------------------------------------------------------------------
BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'evidencias') THEN
    RAISE EXCEPTION 'RI_BUCKET_FALTA: no existe el bucket evidencias';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.empresas WHERE nombre = 'Aquachile') THEN
    RAISE EXCEPTION 'RI_EMPRESA_FALTA: no existe la empresa Aquachile';
  END IF;
END $$;

-- 1.1 Cabecera: un registro por inspeccion de buceo.
CREATE TABLE IF NOT EXISTS public.registros_inmersion (
  id UUID PRIMARY KEY,
  actividad_id UUID NOT NULL
    REFERENCES public.actividades(id) ON DELETE CASCADE,
  empresa_id UUID REFERENCES public.empresas(id),
  usuario_id UUID,
  centro_id UUID,
  contratista_id UUID,
  -- Copias del dia (el informe no cambia si despues se edita el maestro).
  centro_nombre TEXT,
  contratista_nombre TEXT,
  numero_inspeccion TEXT,
  fecha_realizacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  profundidad_autorizada_m NUMERIC(6,2),
  observacion_general TEXT,
  origen TEXT NOT NULL DEFAULT 'TARJETA_INICIO'
    CHECK (origen IN ('AVISO_FINALIZAR', 'TARJETA_INICIO')),
  estado_final TEXT NOT NULL DEFAULT 'Borrador'
    CHECK (estado_final IN ('Borrador', 'Finalizado', 'Eliminada')),
  -- Los asigna el trigger al pasar a Finalizado.
  numero INTEGER,
  correlativo TEXT,
  pdf_url TEXT,
  pdf_version TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Un registro vigente por inspeccion (los eliminados no bloquean uno nuevo).
CREATE UNIQUE INDEX IF NOT EXISTS uq_registros_inmersion_actividad_vigente
  ON public.registros_inmersion(actividad_id)
  WHERE estado_final <> 'Eliminada';
CREATE INDEX IF NOT EXISTS idx_registros_inmersion_empresa
  ON public.registros_inmersion(empresa_id);
CREATE INDEX IF NOT EXISTS idx_registros_inmersion_usuario
  ON public.registros_inmersion(usuario_id);

-- 1.2 Buzos: una fila por buzo, con el resumen de sus inmersiones.
CREATE TABLE IF NOT EXISTS public.registro_inmersion_buzos (
  id UUID PRIMARY KEY,
  registro_id UUID NOT NULL
    REFERENCES public.registros_inmersion(id) ON DELETE CASCADE,
  personal_id UUID REFERENCES public.personal_externo(id) ON DELETE SET NULL,
  nombre TEXT NOT NULL,
  rut TEXT,
  cargo TEXT,
  realizo_inmersion BOOLEAN NOT NULL DEFAULT true,
  profundidad_maxima_m NUMERIC(6,2) CHECK (profundidad_maxima_m >= 0),
  excede_autorizada BOOLEAN NOT NULL DEFAULT false,
  marcado_rojo BOOLEAN NOT NULL DEFAULT false,
  tiempo_total_min INTEGER CHECK (tiempo_total_min >= 0),
  cantidad_inmersiones INTEGER NOT NULL DEFAULT 0
    CHECK (cantidad_inmersiones >= 0),
  profundimetro_marca TEXT,
  profundimetro_serie TEXT,
  dispositivo_tipo TEXT,
  dispositivo_serie TEXT,
  nota TEXT,
  orden INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_registro_inmersion_buzos_registro
  ON public.registro_inmersion_buzos(registro_id);
CREATE INDEX IF NOT EXISTS idx_registro_inmersion_buzos_personal
  ON public.registro_inmersion_buzos(personal_id);
CREATE INDEX IF NOT EXISTS idx_registro_inmersion_buzos_rut
  ON public.registro_inmersion_buzos(rut);

-- 1.3 Inmersiones: una fila por bajada (lo normal es una por buzo).
CREATE TABLE IF NOT EXISTS public.registro_inmersion_inmersiones (
  id UUID PRIMARY KEY,
  buzo_id UUID NOT NULL
    REFERENCES public.registro_inmersion_buzos(id) ON DELETE CASCADE,
  registro_id UUID NOT NULL
    REFERENCES public.registros_inmersion(id) ON DELETE CASCADE,
  orden INTEGER NOT NULL DEFAULT 1 CHECK (orden >= 1),
  profundidad_maxima_m NUMERIC(6,2) CHECK (profundidad_maxima_m >= 0),
  excede_autorizada BOOLEAN NOT NULL DEFAULT false,
  hora_inicio TEXT CHECK (hora_inicio IS NULL OR hora_inicio ~ '^[0-2][0-9]:[0-5][0-9]$'),
  hora_inicio_editada BOOLEAN NOT NULL DEFAULT false,
  hora_termino TEXT CHECK (hora_termino IS NULL OR hora_termino ~ '^[0-2][0-9]:[0-5][0-9]$'),
  tiempo_min INTEGER CHECK (tiempo_min >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_registro_inmersion_inm_buzo
  ON public.registro_inmersion_inmersiones(buzo_id);
CREATE INDEX IF NOT EXISTS idx_registro_inmersion_inm_registro
  ON public.registro_inmersion_inmersiones(registro_id);

-- 1.4 Fotos: GENERAL = galeria del informe (sin buzo); las demas, de un buzo.
CREATE TABLE IF NOT EXISTS public.registro_inmersion_fotos (
  id UUID PRIMARY KEY,
  registro_id UUID NOT NULL
    REFERENCES public.registros_inmersion(id) ON DELETE CASCADE,
  buzo_id UUID
    REFERENCES public.registro_inmersion_buzos(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL
    CHECK (tipo IN ('PROFUNDIMETRO', 'DISPOSITIVO', 'BUZO_GENERAL', 'GENERAL')),
  posicion INTEGER NOT NULL DEFAULT 0 CHECK (posicion >= 0),
  storage_path TEXT NOT NULL UNIQUE,
  foto_url TEXT NOT NULL,
  descripcion TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT registro_inmersion_fotos_tipo_buzo_check CHECK (
    (tipo = 'GENERAL' AND buzo_id IS NULL)
    OR (tipo <> 'GENERAL' AND buzo_id IS NOT NULL)
  )
);
CREATE INDEX IF NOT EXISTS idx_registro_inmersion_fotos_registro
  ON public.registro_inmersion_fotos(registro_id);

-- 1.5 Numero propio por empresa al finalizar (no se reutiliza).
CREATE OR REPLACE FUNCTION public.assign_registro_inmersion_numero()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  NEW.updated_at := now();
  IF NEW.empresa_id IS NULL THEN
    NEW.empresa_id := public.resolver_empresa_usuario(NEW.usuario_id);
  END IF;

  -- El sync sube con upsert: Postgres dispara BEFORE INSERT aunque la fila ya
  -- exista. Si existe, numera el BEFORE UPDATE (no gasta numeros en reintentos).
  IF TG_OP = 'INSERT'
     AND EXISTS (SELECT 1 FROM public.registros_inmersion WHERE id = NEW.id) THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- Un numero asignado no se pisa desde la app.
    NEW.numero := COALESCE(OLD.numero, NEW.numero);
    NEW.correlativo := COALESCE(OLD.correlativo, NEW.correlativo);
    -- Una baja no se revierte con un reintento del sync.
    IF OLD.estado_final = 'Eliminada' THEN
      NEW.estado_final := 'Eliminada';
    END IF;
  END IF;

  -- Si la inspeccion ya esta eliminada, el registro nace/queda de baja y no
  -- consume numero.
  IF EXISTS (SELECT 1 FROM public.actividades a
              WHERE a.id = NEW.actividad_id
                AND a.estado_final::text = 'Eliminada') THEN
    NEW.estado_final := 'Eliminada';
  END IF;

  IF NEW.estado_final = 'Finalizado' AND NEW.numero IS NULL THEN
    IF NEW.empresa_id IS NULL THEN
      RAISE EXCEPTION 'RI_SIN_EMPRESA: registro % sin empresa', NEW.id;
    END IF;
    NEW.numero := public.next_numero_informe(NEW.empresa_id, 'REGISTRO_INMERSIONES', 0);
    NEW.correlativo := 'RI-' || LPAD(NEW.numero::text, 4, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_registro_inmersion_numero ON public.registros_inmersion;
CREATE TRIGGER trg_registro_inmersion_numero
  BEFORE INSERT OR UPDATE ON public.registros_inmersion
  FOR EACH ROW EXECUTE FUNCTION public.assign_registro_inmersion_numero();

-- 1.6 Si la inspeccion de buceo se elimina (soft delete), su registro tambien.
CREATE OR REPLACE FUNCTION public.cascade_baja_registro_inmersion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  IF NEW.estado_final::text = 'Eliminada'
     AND OLD.estado_final::text IS DISTINCT FROM 'Eliminada' THEN
    UPDATE public.registros_inmersion
       SET estado_final = 'Eliminada'
     WHERE actividad_id = NEW.id
       AND estado_final <> 'Eliminada';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_actividades_baja_registro_inmersion ON public.actividades;
CREATE TRIGGER trg_actividades_baja_registro_inmersion
  AFTER UPDATE OF estado_final ON public.actividades
  FOR EACH ROW EXECUTE FUNCTION public.cascade_baja_registro_inmersion();

-- 1.7 RLS: el auditor escribe lo suyo; el admin lee lo de sus empresas.
ALTER TABLE public.registros_inmersion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registro_inmersion_buzos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registro_inmersion_inmersiones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registro_inmersion_fotos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS registros_inmersion_owner_all ON public.registros_inmersion;
CREATE POLICY registros_inmersion_owner_all ON public.registros_inmersion
  FOR ALL TO authenticated
  USING (usuario_id = auth.uid())
  WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS registros_inmersion_admin_select ON public.registros_inmersion;
CREATE POLICY registros_inmersion_admin_select ON public.registros_inmersion
  FOR SELECT TO authenticated
  USING (public.is_superadmin_user()
         OR (public.is_admin_user() AND public.user_has_empresa(empresa_id)));

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['registro_inmersion_buzos',
                           'registro_inmersion_inmersiones',
                           'registro_inmersion_fotos'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_owner_all', t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR ALL TO authenticated
         USING (EXISTS (SELECT 1 FROM public.registros_inmersion r
                         WHERE r.id = %I.registro_id AND r.usuario_id = auth.uid()))
         WITH CHECK (EXISTS (SELECT 1 FROM public.registros_inmersion r
                         WHERE r.id = %I.registro_id AND r.usuario_id = auth.uid()))',
      t || '_owner_all', t, t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_admin_select', t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated
         USING (EXISTS (SELECT 1 FROM public.registros_inmersion r
                         WHERE r.id = %I.registro_id
                           AND (public.is_superadmin_user()
                                OR (public.is_admin_user()
                                    AND public.user_has_empresa(r.empresa_id)))))',
      t || '_admin_select', t, t);
  END LOOP;
END $$;

-- 1.8 Historial: misma vista de hoy + rama del registro de inmersiones.
CREATE OR REPLACE VIEW public.historial_unificado AS
 SELECT a.id::text AS id,
    'Inspección'::text AS modulo,
    a.tipo_actividad::text AS tipo_registro,
    a.estado_final::text AS estado,
    COALESCE(c.nombre, 'Sin ubicación'::character varying) AS ubicacion,
    a.fecha_realizacion::timestamp with time zone AS fecha_realizacion,
    a.numero_informe::text AS numero_reporte,
    a.pdf_url,
    NULL::text AS pdf_certificado_url,
    u.nombre_completo AS inspector_nombre,
    COALESCE(a.numero_seguimiento, 0) AS numero_seguimiento,
    a.usuario_id,
    a.centro_id,
    a.embarcacion_id,
    a.empresa_id
   FROM public.actividades a
     LEFT JOIN public.centros c ON c.id = a.centro_id
     LEFT JOIN public.usuarios u ON u.id = a.usuario_id
  WHERE a.estado_final <> ALL (ARRAY['Eliminada'::public.estado_actividad, 'En Progreso'::public.estado_actividad])
UNION ALL
 SELECT v.id::text AS id,
        CASE
            WHEN v.tipo_actividad = 'VISITA_R004'::text THEN 'Inspección Extintores'::text
            WHEN v.tipo_actividad = 'MANTENCION_PROSESSO'::text THEN 'Mantención de Extintores'::text
            ELSE 'Visita Técnica'::text
        END AS modulo,
    v.tipo_actividad AS tipo_registro,
    v.estado_final AS estado,
    COALESCE(NULLIF(v.cliente_nombre, ''::text), NULLIF(v.lugar_visita, ''::text), 'Sin ubicación'::text) AS ubicacion,
    v.fecha_realizacion,
    v.cert_numero AS numero_reporte,
    v.pdf_url,
    v.pdf_certificado_url,
    u.nombre_completo AS inspector_nombre,
    0 AS numero_seguimiento,
    v.usuario_id,
    NULL::uuid AS centro_id,
    NULL::uuid AS embarcacion_id,
    v.empresa_id
   FROM public.visitas_tecnicas v
     LEFT JOIN public.usuarios u ON u.id = v.usuario_id
  WHERE v.estado_final <> ALL (ARRAY['Eliminada'::text, 'En Progreso'::text])
UNION ALL
 SELECT h.id::text AS id,
    'Hidroser'::text AS modulo,
    h.lista_codigo AS tipo_registro,
    h.estado_final AS estado,
    COALESCE(NULLIF(hl.nombre, ''::text), 'Sin ubicación'::text) AS ubicacion,
    h.fecha_realizacion,
    h.correlativo AS numero_reporte,
    h.pdf_url,
    NULL::text AS pdf_certificado_url,
    COALESCE(NULLIF(h.quien_inspecciona, ''::text), u.nombre_completo::text) AS inspector_nombre,
    0 AS numero_seguimiento,
    h.usuario_id,
    NULL::uuid AS centro_id,
    NULL::uuid AS embarcacion_id,
    h.empresa_id
   FROM public.hidroser_inspecciones h
     LEFT JOIN public.hidroser_listas hl ON hl.codigo = h.lista_codigo
     LEFT JOIN public.usuarios u ON u.id = h.usuario_id
  WHERE (h.estado_final <> ALL (ARRAY['Eliminada'::text, 'En Progreso'::text])) AND (h.lista_codigo <> ALL (ARRAY['BUCEO_SAL_20M'::text, 'BUCEO_SAM_36M'::text]))
UNION ALL
 SELECT a.id::text AS id,
    'AST'::text AS modulo,
    'AST'::text AS tipo_registro,
    a.estado_final AS estado,
    COALESCE(NULLIF(a.centro_nombre, ''::text), NULLIF(a.contratista_nombre, ''::text), 'Sin ubicación'::text) AS ubicacion,
    a.fecha_realizacion,
    a.correlativo AS numero_reporte,
    a.pdf_url,
    NULL::text AS pdf_certificado_url,
    COALESCE(NULLIF(a.profesional, ''::text), u.nombre_completo::text) AS inspector_nombre,
    0 AS numero_seguimiento,
    a.usuario_id,
    a.centro_id,
    a.embarcacion_id,
    a.empresa_id
   FROM public.ast_informes a
     LEFT JOIN public.usuarios u ON u.id = a.usuario_id
  WHERE a.estado_final <> ALL (ARRAY['Eliminada'::text, 'En Progreso'::text])
UNION ALL
 SELECT b.id::text AS id,
    'Equipamiento de Buceo'::text AS modulo,
    b.lista_codigo AS tipo_registro,
    b.estado_final AS estado,
    COALESCE(NULLIF(bl.nombre, ''::text), 'Sin ubicación'::text) AS ubicacion,
    b.fecha_realizacion,
    b.correlativo AS numero_reporte,
    b.pdf_url,
    NULL::text AS pdf_certificado_url,
    COALESCE(NULLIF(b.quien_inspecciona, ''::text), u.nombre_completo::text) AS inspector_nombre,
    0 AS numero_seguimiento,
    b.usuario_id,
    NULL::uuid AS centro_id,
    NULL::uuid AS embarcacion_id,
    b.empresa_id
   FROM public.buceo_equipamiento_inspecciones b
     LEFT JOIN public.buceo_equipamiento_listas bl ON bl.codigo = b.lista_codigo
     LEFT JOIN public.usuarios u ON u.id = b.usuario_id
  WHERE b.estado_final <> ALL (ARRAY['Eliminada'::text, 'En Progreso'::text])
UNION ALL
 SELECT m.id::text AS id,
        CASE
            WHEN m.tipo_actividad = 'MERIEUX_EXTINTORES'::text THEN 'Merieux - Mantención de Extintores'::text
            ELSE 'Merieux - Registro de Visita'::text
        END AS modulo,
    COALESCE(m.checklist_tipo, m.tipo_actividad) AS tipo_registro,
    m.estado_final AS estado,
    COALESCE(NULLIF(m.area, ''::text), NULLIF(m.region, ''::text), 'Sin ubicación'::text) AS ubicacion,
    m.fecha_realizacion,
    m.correlativo AS numero_reporte,
    m.pdf_url,
    NULL::text AS pdf_certificado_url,
    COALESCE(NULLIF(m.profesional, ''::text), u.nombre_completo::text) AS inspector_nombre,
    0 AS numero_seguimiento,
    m.usuario_id,
    NULL::uuid AS centro_id,
    NULL::uuid AS embarcacion_id,
    m.empresa_id
   FROM public.merieux_visitas m
     LEFT JOIN public.usuarios u ON u.id = m.usuario_id
  WHERE (m.estado_final <> ALL (ARRAY['Eliminada'::text, 'En Progreso'::text])) AND m.eliminado = false
UNION ALL
 SELECT i.id::text AS id,
    c.nombre AS modulo,
    c.checklist_key AS tipo_registro,
    i.estado_final AS estado,
    COALESCE(NULLIF(i.campos_extra ->> 'obra_faena'::text, ''::text), 'Sin ubicación'::text) AS ubicacion,
    i.fecha_realizacion,
    i.correlativo AS numero_reporte,
    i.pdf_url,
    NULL::text AS pdf_certificado_url,
    COALESCE(NULLIF(i.quien_inspecciona, ''::text), u.nombre_completo::text) AS inspector_nombre,
    0 AS numero_seguimiento,
    i.usuario_id,
    NULL::uuid AS centro_id,
    NULL::uuid AS embarcacion_id,
    i.empresa_id
   FROM public.checklist_inspecciones i
     JOIN public.checklists c ON c.checklist_key = i.checklist_key
     LEFT JOIN public.usuarios u ON u.id = i.usuario_id
  WHERE (i.estado_final <> ALL (ARRAY['Eliminada'::text, 'En Progreso'::text, 'Borrador'::text])) AND i.eliminado = false
UNION ALL
 SELECT r.id::text AS id,
    'Registro de inmersiones'::text AS modulo,
    'REGISTRO_INMERSIONES'::text AS tipo_registro,
    r.estado_final AS estado,
    COALESCE(NULLIF(r.centro_nombre, ''::text), 'Sin ubicación'::text) AS ubicacion,
    r.fecha_realizacion,
    r.correlativo AS numero_reporte,
    r.pdf_url,
    NULL::text AS pdf_certificado_url,
    u.nombre_completo::text AS inspector_nombre,
    0 AS numero_seguimiento,
    r.usuario_id,
    r.centro_id,
    NULL::uuid AS embarcacion_id,
    r.empresa_id
   FROM public.registros_inmersion r
     LEFT JOIN public.usuarios u ON u.id = r.usuario_id
  WHERE r.estado_final <> ALL (ARRAY['Eliminada'::text, 'Borrador'::text]);

-- Igual que hoy: la vista solo se lee mediante historial_autorizado().
REVOKE ALL ON public.historial_unificado FROM anon, authenticated;

-- 1.9 Habilitar el modulo para AquaChile (todos sus auditores).
INSERT INTO public.empresa_modulos (empresa_id, modulo_key, habilitado, orden)
SELECT e.id, 'REGISTRO_INMERSIONES', true, 75
FROM public.empresas e
WHERE e.nombre = 'Aquachile'
ON CONFLICT (empresa_id, modulo_key) DO UPDATE SET habilitado = true;

COMMIT;

-- -----------------------------------------------------------------------------
-- 2. SOLO LECTURA: verificar
-- -----------------------------------------------------------------------------
-- Esperado: 4 tablas, rls = true en las 4.
SELECT c.relname, c.relrowsecurity AS rls
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('registros_inmersion', 'registro_inmersion_buzos',
                    'registro_inmersion_inmersiones', 'registro_inmersion_fotos')
ORDER BY 1;

-- Esperado: 2 politicas por tabla (owner_all + admin_select).
SELECT tablename, count(*) AS politicas
FROM pg_policies
WHERE tablename IN ('registros_inmersion', 'registro_inmersion_buzos',
                    'registro_inmersion_inmersiones', 'registro_inmersion_fotos')
GROUP BY 1 ORDER BY 1;

-- Esperado: trg_registro_inmersion_numero y trg_actividades_baja_registro_inmersion.
SELECT c.relname, t.tgname
FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
WHERE NOT t.tgisinternal
  AND t.tgname IN ('trg_registro_inmersion_numero',
                   'trg_actividades_baja_registro_inmersion');

-- Esperado: la vista sigue entregando las mismas filas que antes (0 del modulo nuevo).
SELECT modulo, count(*) FROM public.historial_unificado GROUP BY 1 ORDER BY 1;

-- Esperado: REGISTRO_INMERSIONES habilitado = true para Aquachile.
SELECT e.nombre, em.modulo_key, em.habilitado, em.orden
FROM public.empresa_modulos em JOIN public.empresas e ON e.id = em.empresa_id
WHERE em.modulo_key = 'REGISTRO_INMERSIONES';
