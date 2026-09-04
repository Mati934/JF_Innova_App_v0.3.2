-- =============================================================================
-- MIGRACION CONSOLIDADA: Motor de Checklists Configurables v1
--
-- EJECUCION MANUAL OBLIGATORIA
-- 1) Ejecutar primero supabase_check_motor_checklists_configurables_v1.sql.
-- 2) Revisar sus resultados, especialmente tablas checklist_* existentes,
--    contrato de historial_unificado y cantidad de historicos sin empresa_id.
-- 3) Ejecutar este archivo manualmente en Supabase SQL Editor.
--
-- Esta migracion no corrige los historicos sin empresa_id, no migra modulos
-- existentes y no crea un checklist de negocio. Solo instala el contrato del
-- motor y deja listo el primer form_type tecnico.
--
-- DECISIONES v1
-- * form_type_key es el nombre canonico del motor (no se duplica con family_key).
-- * checklist_key y permission_key son claves de datos estables.
-- * las versiones guardan snapshot JSONB inmutable de preguntas y campos.
-- * el correlativo es por checklist, no se reinicia por ano: VL-0001.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0) CHECK PREVIO DE SOLO LECTURA (repetir antes de continuar)
-- -----------------------------------------------------------------------------
SELECT
  to_regclass('public.empresas') AS empresas,
  to_regclass('public.usuarios') AS usuarios,
  to_regclass('public.roles') AS roles,
  to_regclass('public.usuario_empresas') AS usuario_empresas,
  to_regclass('public.formulario_items') AS formulario_items,
  to_regclass('public.formulario_campos_extra') AS formulario_campos_extra,
  to_regclass('public.historial_unificado') AS historial_unificado,
  to_regclass('public.checklist_form_types') AS checklist_form_types,
  to_regclass('public.checklists') AS checklists,
  to_regclass('public.checklist_versions') AS checklist_versions,
  to_regclass('public.checklist_navigation_nodes') AS checklist_navigation_nodes,
  to_regclass('public.checklist_permission_grants') AS checklist_permission_grants,
  to_regclass('public.checklist_correlativo_counters') AS checklist_correlativo_counters,
  to_regclass('public.checklist_inspecciones') AS checklist_inspecciones,
  to_regclass('public.checklist_respuestas') AS checklist_respuestas,
  to_regclass('public.checklist_evidencias') AS checklist_evidencias;

SELECT modulo, count(*) AS informes_sin_empresa
FROM public.historial_unificado
WHERE empresa_id IS NULL
GROUP BY modulo
ORDER BY modulo;

SELECT column_name, data_type, ordinal_position
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'historial_unificado'
ORDER BY ordinal_position;

BEGIN;

-- -----------------------------------------------------------------------------
-- 1) CATALOGOS Y VERSIONES
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.checklist_form_types (
  form_type_key TEXT PRIMARY KEY
    CHECK (form_type_key ~ '^[a-z][a-z0-9_]*$'),
  nombre TEXT NOT NULL,
  descripcion TEXT,
  pdf_template_key TEXT NOT NULL
    CHECK (pdf_template_key ~ '^[a-z][a-z0-9_]*$'),
  permite_respuestas BOOLEAN NOT NULL DEFAULT TRUE,
  permite_fotos BOOLEAN NOT NULL DEFAULT TRUE,
  permite_firma BOOLEAN NOT NULL DEFAULT TRUE,
  requiere_observacion_nc BOOLEAN NOT NULL DEFAULT FALSE,
  requiere_foto_nc BOOLEAN NOT NULL DEFAULT FALSE,
  usa_criticidad BOOLEAN NOT NULL DEFAULT FALSE,
  requiere_criticidad_nc BOOLEAN NOT NULL DEFAULT FALSE,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.checklists (
  checklist_key TEXT PRIMARY KEY
    CHECK (checklist_key ~ '^[a-z][a-z0-9_]*$'),
  form_type_key TEXT NOT NULL REFERENCES public.checklist_form_types(form_type_key),
  permission_key TEXT NOT NULL
    CHECK (permission_key ~ '^[a-z][a-z0-9_.:-]*$'),
  report_prefix TEXT NOT NULL
    CHECK (report_prefix ~ '^[A-Z0-9-]+$'),
  nombre TEXT NOT NULL,
  subtitulo TEXT,
  icono TEXT,
  color TEXT,
  published_version INTEGER NOT NULL DEFAULT 0 CHECK (published_version >= 0),
  activo BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.checklists
  DROP CONSTRAINT IF EXISTS checklists_report_prefix_key;
CREATE UNIQUE INDEX IF NOT EXISTS uq_checklists_active_report_prefix
  ON public.checklists(report_prefix) WHERE activo = TRUE;

CREATE TABLE IF NOT EXISTS public.checklist_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  checklist_key TEXT NOT NULL REFERENCES public.checklists(checklist_key),
  version INTEGER NOT NULL CHECK (version > 0),
  estado TEXT NOT NULL DEFAULT 'BORRADOR'
    CHECK (estado IN ('BORRADOR', 'PUBLICADA', 'RETIRADA')),
  snapshot_preguntas JSONB NOT NULL DEFAULT '[]'::jsonb,
  snapshot_campos_extra JSONB NOT NULL DEFAULT '[]'::jsonb,
  snapshot_reglas JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by UUID,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (checklist_key, version)
);
CREATE INDEX IF NOT EXISTS idx_checklist_versions_lookup
  ON public.checklist_versions(checklist_key, estado, version DESC);

-- Seed tecnico: solo declara el contrato aprobado, no habilita usuarios.
INSERT INTO public.checklist_form_types (
  form_type_key, nombre, descripcion, pdf_template_key,
  permite_respuestas, permite_fotos, permite_firma,
  requiere_observacion_nc, requiere_foto_nc, usa_criticidad,
  requiere_criticidad_nc
) VALUES (
  'generic_standard_form',
  'Formulario estandar generico',
  'Contrato inicial para listas configurables de inspeccion.',
  'standard_checklist_pdf',
  TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE
)
ON CONFLICT (form_type_key) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 2) NAVEGACION Y PERMISOS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.checklist_navigation_nodes (
  node_key TEXT PRIMARY KEY CHECK (node_key ~ '^[a-z][a-z0-9_]*$'),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  parent_node_key TEXT REFERENCES public.checklist_navigation_nodes(node_key),
  node_type TEXT NOT NULL CHECK (node_type IN ('GROUP', 'CHECKLIST')),
  checklist_key TEXT REFERENCES public.checklists(checklist_key),
  permission_key TEXT NOT NULL
    CHECK (permission_key ~ '^[a-z][a-z0-9_.:-]*$'),
  titulo TEXT NOT NULL,
  icono TEXT,
  color TEXT,
  orden INTEGER NOT NULL DEFAULT 0 CHECK (orden >= 0),
  habilitado BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (
    (node_type = 'GROUP' AND checklist_key IS NULL)
    OR (node_type = 'CHECKLIST' AND checklist_key IS NOT NULL)
  )
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_checklist_nodes_empresa_parent_orden
  ON public.checklist_navigation_nodes
  (empresa_id, COALESCE(parent_node_key, ''), orden);
CREATE INDEX IF NOT EXISTS idx_checklist_nodes_empresa
  ON public.checklist_navigation_nodes(empresa_id, habilitado, orden);

CREATE TABLE IF NOT EXISTS public.checklist_permission_grants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  checklist_key TEXT NOT NULL REFERENCES public.checklists(checklist_key) ON DELETE CASCADE,
  usuario_id UUID REFERENCES public.usuarios(id) ON DELETE CASCADE,
  rol_id UUID REFERENCES public.roles(id) ON DELETE CASCADE,
  capacidad TEXT NOT NULL
    CHECK (capacidad IN ('ver', 'crear', 'editar_borrador', 'finalizar', 'administrar')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((usuario_id IS NOT NULL) <> (rol_id IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_checklist_grant_usuario
  ON public.checklist_permission_grants(empresa_id, checklist_key, usuario_id, capacidad)
  WHERE usuario_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_checklist_grant_rol
  ON public.checklist_permission_grants(empresa_id, checklist_key, rol_id, capacidad)
  WHERE rol_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.checklist_user_can(
  p_checklist_key TEXT,
  p_empresa_id UUID,
  p_capacidad TEXT
) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.is_superadmin_user()
    OR (
      public.user_has_empresa(p_empresa_id)
      AND EXISTS (
        SELECT 1
        FROM public.checklist_permission_grants g
        LEFT JOIN public.usuarios u ON u.id = auth.uid()
        WHERE g.empresa_id = p_empresa_id
          AND g.checklist_key = p_checklist_key
          AND g.capacidad = p_capacidad
          AND (g.usuario_id = auth.uid() OR g.rol_id = u.rol_id)
      )
    );
$$;

-- -----------------------------------------------------------------------------
-- 3) CONTADOR TRANSACCIONAL POR CHECKLIST
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.checklist_correlativo_counters (
  checklist_key TEXT PRIMARY KEY REFERENCES public.checklists(checklist_key),
  ultimo_numero BIGINT NOT NULL DEFAULT 0 CHECK (ultimo_numero >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.next_checklist_correlativo(p_checklist_key TEXT)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_prefix TEXT;
  v_numero BIGINT;
BEGIN
  SELECT report_prefix INTO v_prefix
  FROM public.checklists
  WHERE checklist_key = p_checklist_key AND activo = TRUE;
  IF v_prefix IS NULL THEN
    RAISE EXCEPTION 'CHECKLIST_CORRELATIVO_INVALIDO';
  END IF;

  INSERT INTO public.checklist_correlativo_counters(checklist_key, ultimo_numero)
  VALUES (p_checklist_key, 0)
  ON CONFLICT (checklist_key) DO NOTHING;

  UPDATE public.checklist_correlativo_counters
  SET ultimo_numero = ultimo_numero + 1, updated_at = now()
  WHERE checklist_key = p_checklist_key
  RETURNING ultimo_numero INTO v_numero;

  RETURN format('%s-%s', v_prefix, lpad(v_numero::text, 4, '0'));
END;
$$;

CREATE OR REPLACE FUNCTION public.assign_checklist_correlativo()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.estado_final NOT IN ('Borrador', 'En Progreso', 'Eliminada')
     AND COALESCE(NEW.correlativo, '') = ''
     AND (TG_OP = 'INSERT' OR OLD.estado_final IN ('Borrador', 'En Progreso')) THEN
    NEW.correlativo := public.next_checklist_correlativo(NEW.checklist_key);
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.freeze_checklist_snapshot()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_snapshot JSONB;
BEGIN
  IF NEW.estado_final NOT IN ('Borrador', 'En Progreso', 'Eliminada')
     AND NEW.snapshot = '{}'::jsonb THEN
    SELECT jsonb_build_object(
      'preguntas', snapshot_preguntas,
      'campos_extra', snapshot_campos_extra,
      'reglas', snapshot_reglas
    ) INTO v_snapshot
    FROM public.checklist_versions
    WHERE id = NEW.version_id
      AND checklist_key = NEW.checklist_key
      AND version = NEW.version;
    IF v_snapshot IS NULL THEN
      RAISE EXCEPTION 'CHECKLIST_SNAPSHOT_REQUERIDO';
    END IF;
    NEW.snapshot := v_snapshot;
  END IF;

  IF TG_OP = 'UPDATE'
     AND OLD.estado_final NOT IN ('Borrador', 'En Progreso')
     AND (NEW.checklist_key IS DISTINCT FROM OLD.checklist_key
       OR NEW.version_id IS DISTINCT FROM OLD.version_id
       OR NEW.version IS DISTINCT FROM OLD.version
       OR NEW.snapshot IS DISTINCT FROM OLD.snapshot) THEN
    RAISE EXCEPTION 'CHECKLIST_SNAPSHOT_INMUTABLE';
  END IF;
  RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------------
-- 4) INSPECCIONES, RESPUESTAS Y EVIDENCIAS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.checklist_inspecciones (
  id UUID PRIMARY KEY,
  usuario_id UUID NOT NULL REFERENCES public.usuarios(id),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id),
  checklist_key TEXT NOT NULL REFERENCES public.checklists(checklist_key),
  form_type_key TEXT NOT NULL REFERENCES public.checklist_form_types(form_type_key),
  version_id UUID REFERENCES public.checklist_versions(id),
  version INTEGER NOT NULL CHECK (version > 0),
  snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  fecha_realizacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  correlativo TEXT,
  quien_inspecciona TEXT,
  supervisor_correo TEXT,
  observaciones TEXT,
  campos_extra JSONB NOT NULL DEFAULT '{}'::jsonb,
  firma_nombre TEXT,
  firma_storage_path TEXT,
  estado_final TEXT NOT NULL DEFAULT 'Borrador',
  pdf_url TEXT,
  pdf_storage_path TEXT,
  subido BOOLEAN NOT NULL DEFAULT FALSE,
  eliminado BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (checklist_key, correlativo)
);
CREATE INDEX IF NOT EXISTS idx_checklist_insp_empresa_estado
  ON public.checklist_inspecciones(empresa_id, estado_final, eliminado);
CREATE INDEX IF NOT EXISTS idx_checklist_insp_usuario
  ON public.checklist_inspecciones(usuario_id, estado_final);
CREATE INDEX IF NOT EXISTS idx_checklist_insp_checklist
  ON public.checklist_inspecciones(checklist_key, created_at DESC);

CREATE TABLE IF NOT EXISTS public.checklist_respuestas (
  id UUID PRIMARY KEY,
  inspeccion_id UUID NOT NULL REFERENCES public.checklist_inspecciones(id) ON DELETE CASCADE,
  item_key TEXT NOT NULL,
  categoria TEXT,
  pregunta TEXT NOT NULL,
  orden INTEGER NOT NULL DEFAULT 0,
  estado TEXT CHECK (estado IN ('C', 'NC', 'N/A')),
  observacion TEXT,
  criticidad TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (inspeccion_id, item_key)
);
CREATE INDEX IF NOT EXISTS idx_checklist_resp_inspeccion
  ON public.checklist_respuestas(inspeccion_id, orden);

CREATE TABLE IF NOT EXISTS public.checklist_evidencias (
  id UUID PRIMARY KEY,
  inspeccion_id UUID NOT NULL REFERENCES public.checklist_inspecciones(id) ON DELETE CASCADE,
  respuesta_id UUID REFERENCES public.checklist_respuestas(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL CHECK (tipo IN ('GENERAL', 'RESPUESTA')),
  storage_path TEXT NOT NULL,
  orden INTEGER NOT NULL DEFAULT 0 CHECK (orden >= 0),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((tipo = 'GENERAL' AND respuesta_id IS NULL) OR
         (tipo = 'RESPUESTA' AND respuesta_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS idx_checklist_evidencias_inspeccion
  ON public.checklist_evidencias(inspeccion_id, tipo, orden);

DROP TRIGGER IF EXISTS trg_checklist_correlativo ON public.checklist_inspecciones;
CREATE TRIGGER trg_checklist_correlativo
  BEFORE INSERT OR UPDATE ON public.checklist_inspecciones
  FOR EACH ROW EXECUTE FUNCTION public.assign_checklist_correlativo();
DROP TRIGGER IF EXISTS trg_checklist_snapshot ON public.checklist_inspecciones;
CREATE TRIGGER trg_checklist_snapshot
  BEFORE INSERT OR UPDATE ON public.checklist_inspecciones
  FOR EACH ROW EXECUTE FUNCTION public.freeze_checklist_snapshot();

-- -----------------------------------------------------------------------------
-- 5) RLS
-- -----------------------------------------------------------------------------
ALTER TABLE public.checklist_form_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_navigation_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_permission_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_inspecciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_respuestas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_evidencias ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS checklist_form_types_read ON public.checklist_form_types;
CREATE POLICY checklist_form_types_read ON public.checklist_form_types
  FOR SELECT TO authenticated USING (activo OR public.is_admin_user());
DROP POLICY IF EXISTS checklists_read ON public.checklists;
CREATE POLICY checklists_read ON public.checklists
  FOR SELECT TO authenticated
  USING (public.is_admin_user() OR EXISTS (
    SELECT 1 FROM public.checklist_permission_grants g
    WHERE g.checklist_key = checklists.checklist_key
      AND g.capacidad IN ('ver', 'crear', 'editar_borrador', 'finalizar')
      AND (g.usuario_id = auth.uid() OR g.rol_id = (SELECT rol_id FROM public.usuarios WHERE id = auth.uid()))
  ));
DROP POLICY IF EXISTS checklist_versions_read ON public.checklist_versions;
CREATE POLICY checklist_versions_read ON public.checklist_versions
  FOR SELECT TO authenticated
  USING (public.is_admin_user() OR EXISTS (
    SELECT 1 FROM public.checklists c
    WHERE c.checklist_key = checklist_versions.checklist_key
      AND (c.activo OR public.is_admin_user())
  ));
DROP POLICY IF EXISTS checklist_nodes_read ON public.checklist_navigation_nodes;
CREATE POLICY checklist_nodes_read ON public.checklist_navigation_nodes
  FOR SELECT TO authenticated
  USING (public.is_admin_user() OR (
    habilitado AND public.user_has_empresa(empresa_id)
    AND (checklist_key IS NULL OR public.checklist_user_can(checklist_key, empresa_id, 'ver'))
  ));
DROP POLICY IF EXISTS checklist_grants_admin ON public.checklist_permission_grants;
CREATE POLICY checklist_grants_admin ON public.checklist_permission_grants
  FOR ALL TO authenticated
  USING (public.is_superadmin_user())
  WITH CHECK (public.is_superadmin_user());
DROP POLICY IF EXISTS checklist_grants_read_own ON public.checklist_permission_grants;
CREATE POLICY checklist_grants_read_own ON public.checklist_permission_grants
  FOR SELECT TO authenticated
  USING (public.is_superadmin_user()
      OR usuario_id = auth.uid()
      OR rol_id = (SELECT rol_id FROM public.usuarios WHERE id = auth.uid()));
DROP POLICY IF EXISTS checklist_insp_owner ON public.checklist_inspecciones;
CREATE POLICY checklist_insp_owner ON public.checklist_inspecciones
  FOR ALL TO authenticated
  USING (usuario_id = auth.uid() OR public.is_admin_user())
  WITH CHECK (public.is_admin_user()
      OR (usuario_id = auth.uid()
          AND (public.checklist_user_can(checklist_key, empresa_id, 'crear')
            OR public.checklist_user_can(checklist_key, empresa_id, 'editar_borrador')
            OR public.checklist_user_can(checklist_key, empresa_id, 'finalizar'))));
DROP POLICY IF EXISTS checklist_resp_owner ON public.checklist_respuestas;
CREATE POLICY checklist_resp_owner ON public.checklist_respuestas
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.checklist_inspecciones i
                 WHERE i.id = inspeccion_id AND (i.usuario_id = auth.uid() OR public.is_admin_user())))
  WITH CHECK (EXISTS (SELECT 1 FROM public.checklist_inspecciones i
                      WHERE i.id = inspeccion_id AND (i.usuario_id = auth.uid() OR public.is_admin_user())));
DROP POLICY IF EXISTS checklist_evidence_owner ON public.checklist_evidencias;
CREATE POLICY checklist_evidence_owner ON public.checklist_evidencias
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.checklist_inspecciones i
                 WHERE i.id = inspeccion_id AND (i.usuario_id = auth.uid() OR public.is_admin_user())))
  WITH CHECK (EXISTS (SELECT 1 FROM public.checklist_inspecciones i
                      WHERE i.id = inspeccion_id AND (i.usuario_id = auth.uid() OR public.is_admin_user())));

REVOKE ALL ON public.checklist_correlativo_counters FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.next_checklist_correlativo(TEXT) FROM anon, authenticated;

-- -----------------------------------------------------------------------------
-- 6) HISTORIAL CENTRALIZADO
-- -----------------------------------------------------------------------------
-- La vista conserva el contrato actual de 15 columnas de historial_autorizado.
-- Los modulos existentes se mantienen; solo se agrega la rama generica.
DROP VIEW IF EXISTS public.historial_unificado;
CREATE VIEW public.historial_unificado AS
SELECT a.id::text, 'Inspeccion'::text AS modulo, a.tipo_actividad::text AS tipo_registro,
  a.estado_final::text AS estado, COALESCE(c.nombre, 'Sin ubicacion') AS ubicacion,
  a.fecha_realizacion::timestamptz AS fecha_realizacion,
  a.numero_informe::text AS numero_reporte, a.pdf_url AS pdf_url,
  NULL::text AS pdf_certificado_url, u.nombre_completo AS inspector_nombre,
  COALESCE(a.numero_seguimiento, 0)::integer AS numero_seguimiento,
       a.usuario_id, a.centro_id, a.embarcacion_id, a.empresa_id
FROM public.actividades a LEFT JOIN public.centros c ON c.id = a.centro_id
LEFT JOIN public.usuarios u ON u.id = a.usuario_id
WHERE a.estado_final NOT IN ('Eliminada', 'En Progreso')
UNION ALL
SELECT v.id::text,
       CASE WHEN v.tipo_actividad = 'VISITA_R004' THEN 'Inspeccion Extintores'
            WHEN v.tipo_actividad = 'MANTENCION_PROSESSO' THEN 'Mantencion de Extintores'
            ELSE 'Visita Tecnica' END::text,
       v.tipo_actividad::text, v.estado_final::text,
       COALESCE(NULLIF(v.cliente_nombre, ''), NULLIF(v.lugar_visita, ''), 'Sin ubicacion'),
       v.fecha_realizacion::timestamptz, v.cert_numero::text, v.pdf_url,
       v.pdf_certificado_url, u.nombre_completo, 0::integer, v.usuario_id,
       NULL::uuid, NULL::uuid, v.empresa_id
FROM public.visitas_tecnicas v LEFT JOIN public.usuarios u ON u.id = v.usuario_id
WHERE v.estado_final NOT IN ('Eliminada', 'En Progreso')
UNION ALL
SELECT h.id::text, 'Hidroser'::text, h.lista_codigo::text, h.estado_final::text,
       COALESCE(NULLIF(hl.nombre, ''), 'Sin ubicacion'), h.fecha_realizacion::timestamptz,
       h.correlativo::text, h.pdf_url, NULL::text,
       COALESCE(NULLIF(h.quien_inspecciona, ''), u.nombre_completo), 0::integer,
       h.usuario_id, NULL::uuid, NULL::uuid, h.empresa_id
FROM public.hidroser_inspecciones h
LEFT JOIN public.hidroser_listas hl ON hl.codigo = h.lista_codigo
LEFT JOIN public.usuarios u ON u.id = h.usuario_id
WHERE h.estado_final NOT IN ('Eliminada', 'En Progreso')
  AND h.lista_codigo NOT IN ('BUCEO_SAL_20M', 'BUCEO_SAM_36M')
UNION ALL
SELECT a.id::text, 'AST'::text, 'AST'::text, a.estado_final::text,
       COALESCE(NULLIF(a.centro_nombre, ''), NULLIF(a.contratista_nombre, ''), 'Sin ubicacion'),
       a.fecha_realizacion::timestamptz, a.correlativo::text, a.pdf_url, NULL::text,
       COALESCE(NULLIF(a.profesional, ''), u.nombre_completo), 0::integer,
       a.usuario_id, a.centro_id, a.embarcacion_id, a.empresa_id
FROM public.ast_informes a LEFT JOIN public.usuarios u ON u.id = a.usuario_id
WHERE a.estado_final NOT IN ('Eliminada', 'En Progreso')
UNION ALL
SELECT b.id::text, 'Equipamiento de Buceo'::text, b.lista_codigo::text,
       b.estado_final::text, COALESCE(NULLIF(bl.nombre, ''), 'Sin ubicacion'),
       b.fecha_realizacion::timestamptz, b.correlativo::text, b.pdf_url, NULL::text,
       COALESCE(NULLIF(b.quien_inspecciona, ''), u.nombre_completo), 0::integer,
       b.usuario_id, NULL::uuid, NULL::uuid, b.empresa_id
FROM public.buceo_equipamiento_inspecciones b
LEFT JOIN public.buceo_equipamiento_listas bl ON bl.codigo = b.lista_codigo
LEFT JOIN public.usuarios u ON u.id = b.usuario_id
WHERE b.estado_final NOT IN ('Eliminada', 'En Progreso')
UNION ALL
SELECT m.id::text,
       CASE WHEN m.tipo_actividad = 'MERIEUX_EXTINTORES' THEN 'Merieux - Mantencion de Extintores'
            ELSE 'Merieux - Registro de Visita' END::text,
       COALESCE(m.checklist_tipo, m.tipo_actividad)::text, m.estado_final::text,
       COALESCE(NULLIF(m.area, ''), NULLIF(m.region, ''), 'Sin ubicacion'),
       m.fecha_realizacion::timestamptz, m.correlativo::text, m.pdf_url, NULL::text,
       COALESCE(NULLIF(m.profesional, ''), u.nombre_completo), 0::integer,
       m.usuario_id, NULL::uuid, NULL::uuid, m.empresa_id
FROM public.merieux_visitas m LEFT JOIN public.usuarios u ON u.id = m.usuario_id
WHERE m.estado_final NOT IN ('Eliminada', 'En Progreso') AND m.eliminado = false
UNION ALL
SELECT i.id::text, c.nombre::text, c.checklist_key::text, i.estado_final::text,
       COALESCE(NULLIF(i.campos_extra->>'obra_faena', ''), 'Sin ubicacion'),
       i.fecha_realizacion, i.correlativo, i.pdf_url, NULL::text,
       COALESCE(NULLIF(i.quien_inspecciona, ''), u.nombre_completo), 0::integer,
       i.usuario_id, NULL::uuid, NULL::uuid, i.empresa_id
FROM public.checklist_inspecciones i
JOIN public.checklists c ON c.checklist_key = i.checklist_key
LEFT JOIN public.usuarios u ON u.id = i.usuario_id
WHERE i.estado_final NOT IN ('Eliminada', 'En Progreso', 'Borrador')
  AND i.eliminado = false;

CREATE OR REPLACE FUNCTION public.historial_autorizado(
  p_empresa_id uuid DEFAULT NULL, p_usuario_id uuid DEFAULT NULL,
  p_centro_id uuid DEFAULT NULL, p_modulo text DEFAULT NULL
) RETURNS TABLE (
  id text, modulo text, tipo_registro text, estado text, ubicacion text,
  fecha_realizacion timestamptz, numero_reporte text, pdf_url text,
  pdf_certificado_url text, inspector_nombre text, numero_seguimiento integer,
  usuario_id uuid, centro_id uuid, embarcacion_id uuid, empresa_id uuid,
  empresa_nombre text
) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT h.*, e.nombre
  FROM public.historial_unificado h
  LEFT JOIN public.empresas e ON e.id = h.empresa_id
  WHERE h.estado NOT IN ('Eliminada', 'En Progreso', 'Borrador')
    AND (p_centro_id IS NULL OR h.centro_id = p_centro_id)
    AND (p_modulo IS NULL OR h.modulo = p_modulo)
    AND (p_usuario_id IS NULL OR h.usuario_id = p_usuario_id)
    AND (public.is_superadmin_user()
      OR (public.is_admin_user() AND p_empresa_id IS NOT NULL
          AND public.user_has_empresa(p_empresa_id) AND h.empresa_id = p_empresa_id)
      OR (NOT public.is_admin_user() AND h.usuario_id = auth.uid()))
  ORDER BY h.fecha_realizacion DESC;
$$;
REVOKE ALL ON public.historial_unificado FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.historial_autorizado(uuid, uuid, uuid, text) TO authenticated;

COMMIT;

-- -----------------------------------------------------------------------------
-- 7) PRUEBAS POSTERIORES (ejecutar despues del COMMIT)
-- -----------------------------------------------------------------------------
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public' AND table_name LIKE 'checklist_%'
ORDER BY table_name;

SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public' AND tablename LIKE 'checklist_%'
ORDER BY tablename, policyname;

SELECT COUNT(*) AS columnas_historial
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'historial_unificado';
-- Esperado: 15 columnas en la vista y 16 en el retorno de la RPC.

SELECT proname, has_function_privilege('authenticated', p.oid, 'EXECUTE') AS puede_ejecutar
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND proname IN ('historial_autorizado', 'next_checklist_correlativo');

-- Prueba transaccional manual, solo cuando exista un checklist activo:
-- BEGIN;
-- SELECT public.next_checklist_correlativo('checklist_key_de_prueba');
-- ROLLBACK;
-- SELECT * FROM public.checklist_correlativo_counters
-- WHERE checklist_key = 'checklist_key_de_prueba';
-- El contador debe conservar su valor anterior despues del ROLLBACK.
