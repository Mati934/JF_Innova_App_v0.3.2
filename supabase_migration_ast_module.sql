-- =============================================================================
-- MIGRACIÓN: Módulo AST (Análisis Seguro de Trabajo) independiente
--
-- Crea un módulo AST 100 % separado del resto:
--   * Limpia el diseño AST anterior no usado (ast_registros/detalles/plantillas).
--   * Tabla de cabecera propia `ast_informes`.
--   * Tabla de hallazgos propia `ast_hallazgos`.
--   * Correlativo propio formato AST-AAAA-NNNN (se asigna al finalizar,
--     estado_final = 'En Seguimiento').
--   * RLS por dueño.
--   * Habilitación del módulo 'AST' en `empresa_modulos`.
--
-- El espejo local en SQLite vive en `ast_informes_pendientes` /
-- `ast_hallazgos_pendientes` (DatabaseHelper v49). La sincronización limpia los
-- campos local-only (subido, eliminado, pdf_path_local, fotos_generales) antes
-- del upsert; el correlativo lo asigna ESTE trigger, no la app.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. LIMPIEZA del diseño AST anterior (NO usado por la app actual)
--
--    El proyecto tenía un modelo AST distinto (análisis paso a paso / JSA):
--      * ast_registros   (atado a actividad_id, supervisores, fecha_ast…)
--      * ast_detalles    (paso_nro, peligro, medida_control, responsable…)
--      * ast_plantillas  (plantillas de pasos en jsonb)
--    Ninguna de esas tablas es referenciada por el código Flutter y estaban
--    vacías. Se eliminan para dejar AST limpio y alineado con este módulo.
--
--    ⚠️ Si en el futuro vuelves a necesitar el modelo de pasos/JSA, recupéralo
--    desde el control de versiones; aquí se borran de forma definitiva.
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS ast_detalles   CASCADE;
DROP TABLE IF EXISTS ast_registros  CASCADE;
DROP TABLE IF EXISTS ast_plantillas CASCADE;

-- -----------------------------------------------------------------------------
-- 1. CABECERA: ast_informes
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ast_informes (
  id                    UUID PRIMARY KEY,
  usuario_id            UUID,
  empresa_id            UUID REFERENCES empresas(id),
  area_id               UUID,
  centro_id             UUID,
  contratista_id        UUID,
  embarcacion_id        UUID,
  area_nombre           TEXT,
  centro_nombre         TEXT,
  contratista_nombre    TEXT,
  embarcacion_nombre    TEXT,
  profesional           TEXT,
  fecha_realizacion     TIMESTAMPTZ NOT NULL DEFAULT now(),
  descripcion_actividad TEXT,
  observaciones         TEXT,
  correlativo           TEXT,
  estado_final          TEXT NOT NULL DEFAULT 'En Progreso',
  pdf_url               TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ast_informes_usuario ON ast_informes(usuario_id);
CREATE INDEX IF NOT EXISTS idx_ast_informes_empresa ON ast_informes(empresa_id);
CREATE INDEX IF NOT EXISTS idx_ast_informes_estado  ON ast_informes(estado_final);

-- -----------------------------------------------------------------------------
-- 2. HALLAZGOS: ast_hallazgos
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ast_hallazgos (
  id           UUID PRIMARY KEY,
  informe_id   UUID NOT NULL REFERENCES ast_informes(id) ON DELETE CASCADE,
  numero       INTEGER NOT NULL DEFAULT 0,
  titulo       TEXT,
  detalle      TEXT,
  foto_path    TEXT
);
CREATE INDEX IF NOT EXISTS idx_ast_hallazgos_informe ON ast_hallazgos(informe_id);

-- -----------------------------------------------------------------------------
-- 3. CORRELATIVO PROPIO AST (AST-AAAA-NNNN)
-- -----------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS ast_correlativo_seq AS BIGINT START 1;

CREATE OR REPLACE FUNCTION next_ast_correlativo()
RETURNS TEXT AS $$
DECLARE
  v_year INT    := EXTRACT(YEAR FROM now())::int;
  v_num  BIGINT := nextval('ast_correlativo_seq');
BEGIN
  RETURN format('AST-%s-%s', v_year, LPAD(v_num::text, 4, '0'));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION assign_ast_correlativo() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.estado_final = 'En Seguimiento'
     AND (NEW.correlativo IS NULL OR NEW.correlativo = '') THEN
    NEW.correlativo := next_ast_correlativo();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ast_correlativo ON ast_informes;
CREATE TRIGGER trg_ast_correlativo
  BEFORE INSERT OR UPDATE ON ast_informes
  FOR EACH ROW EXECUTE FUNCTION assign_ast_correlativo();

-- -----------------------------------------------------------------------------
-- 4. RLS — el dueño ve / inserta / actualiza sus AST.
-- -----------------------------------------------------------------------------
ALTER TABLE ast_informes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE ast_hallazgos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ast_informes_owner_all ON ast_informes;
CREATE POLICY ast_informes_owner_all
  ON ast_informes FOR ALL
  TO authenticated
  USING      (usuario_id = auth.uid())
  WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS ast_hallazgos_owner_all ON ast_hallazgos;
CREATE POLICY ast_hallazgos_owner_all
  ON ast_hallazgos FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM ast_informes i
             WHERE i.id = informe_id AND i.usuario_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM ast_informes i
             WHERE i.id = informe_id AND i.usuario_id = auth.uid())
  );

-- -----------------------------------------------------------------------------
-- 5. HABILITAR módulo AST para una empresa.
--    Ajusta el filtro WHERE a tu empresa (o quita el WHERE para todas).
-- -----------------------------------------------------------------------------
-- Ejemplo: habilitar AST para TODAS las empresas:
-- INSERT INTO empresa_modulos (empresa_id, modulo_key, habilitado, orden)
-- SELECT e.id, 'AST', true, 55
-- FROM empresas e
-- ON CONFLICT (empresa_id, modulo_key) DO UPDATE SET habilitado = true;

-- Ejemplo: habilitar AST sólo para una empresa concreta por nombre:
-- INSERT INTO empresa_modulos (empresa_id, modulo_key, habilitado, orden)
-- SELECT e.id, 'AST', true, 55
-- FROM empresas e
-- WHERE e.nombre ILIKE '%NOMBRE_EMPRESA%'
-- ON CONFLICT (empresa_id, modulo_key) DO UPDATE SET habilitado = true;

-- -----------------------------------------------------------------------------
-- 6. EXTENDER historial_unificado para incluir AST
--
--    Admins ven todos los registros; usuarios normales solo ven los suyos
--    (el filtro usuario_id lo aplica SupabaseHistoryRepository en la app).
--    Se recrea la vista completa conservando las 3 ramas existentes.
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS public.historial_unificado;

CREATE VIEW public.historial_unificado AS

-- INSPECCIONES (actividades)
SELECT
  a.id::text                                  AS id,
  'Inspección'::text                          AS modulo,
  a.tipo_actividad::text                      AS tipo_registro,
  a.estado_final::text                        AS estado,
  COALESCE(c.nombre, 'Sin ubicación')         AS ubicacion,
  a.fecha_realizacion::timestamptz            AS fecha_realizacion,
  a.numero_informe::text                      AS numero_reporte,
  a.pdf_url                                   AS pdf_url,
  NULL::text                                  AS pdf_certificado_url,
  u.nombre_completo                           AS inspector_nombre,
  COALESCE(a.numero_seguimiento, 0)::integer  AS numero_seguimiento,
  a.usuario_id                                AS usuario_id,
  a.centro_id                                 AS centro_id,
  a.embarcacion_id                            AS embarcacion_id
FROM actividades a
LEFT JOIN centros  c ON c.id = a.centro_id
LEFT JOIN usuarios u ON u.id = a.usuario_id
WHERE a.estado_final NOT IN ('Eliminada', 'En Progreso')

UNION ALL

-- VISITAS TÉCNICAS (R003, R004, MANTENCION_PROSESSO, etc.)
SELECT
  v.id::text                                  AS id,
  CASE
    WHEN v.tipo_actividad = 'VISITA_R004'         THEN 'Inspección Extintores'
    WHEN v.tipo_actividad = 'MANTENCION_PROSESSO' THEN 'Mantención de Extintores'
    ELSE 'Visita Técnica'
  END::text                                   AS modulo,
  v.tipo_actividad::text                      AS tipo_registro,
  v.estado_final::text                        AS estado,
  COALESCE(NULLIF(v.cliente_nombre, ''),
           NULLIF(v.lugar_visita,   ''),
           'Sin ubicación')                   AS ubicacion,
  v.fecha_realizacion::timestamptz            AS fecha_realizacion,
  v.cert_numero::text                         AS numero_reporte,
  v.pdf_url                                   AS pdf_url,
  v.pdf_certificado_url                       AS pdf_certificado_url,
  u.nombre_completo                           AS inspector_nombre,
  0::integer                                  AS numero_seguimiento,
  v.usuario_id                                AS usuario_id,
  NULL::uuid                                  AS centro_id,
  NULL::uuid                                  AS embarcacion_id
FROM visitas_tecnicas v
LEFT JOIN usuarios u ON u.id = v.usuario_id
WHERE v.estado_final NOT IN ('Eliminada', 'En Progreso')

UNION ALL

-- HIDROSER (módulo independiente)
SELECT
  h.id::text                                                   AS id,
  'Hidroser'::text                                             AS modulo,
  h.lista_codigo::text                                         AS tipo_registro,
  h.estado_final::text                                         AS estado,
  COALESCE(NULLIF(hl.nombre, ''), 'Sin ubicación')             AS ubicacion,
  h.fecha_realizacion::timestamptz                             AS fecha_realizacion,
  h.correlativo::text                                          AS numero_reporte,
  h.pdf_url                                                    AS pdf_url,
  NULL::text                                                   AS pdf_certificado_url,
  COALESCE(NULLIF(h.quien_inspecciona, ''), u.nombre_completo) AS inspector_nombre,
  0::integer                                                   AS numero_seguimiento,
  h.usuario_id                                                 AS usuario_id,
  NULL::uuid                                                   AS centro_id,
  NULL::uuid                                                   AS embarcacion_id
FROM hidroser_inspecciones h
LEFT JOIN hidroser_listas hl ON hl.codigo = h.lista_codigo
LEFT JOIN usuarios        u  ON u.id      = h.usuario_id
WHERE h.estado_final NOT IN ('Eliminada', 'En Progreso')

UNION ALL

-- AST (Análisis Seguro de Trabajo)
SELECT
  a.id::text                                                   AS id,
  'AST'::text                                                  AS modulo,
  'AST'::text                                                  AS tipo_registro,
  a.estado_final::text                                         AS estado,
  COALESCE(NULLIF(a.centro_nombre, ''),
           NULLIF(a.contratista_nombre, ''),
           'Sin ubicación')                                    AS ubicacion,
  a.fecha_realizacion::timestamptz                             AS fecha_realizacion,
  a.correlativo::text                                          AS numero_reporte,
  a.pdf_url                                                    AS pdf_url,
  NULL::text                                                   AS pdf_certificado_url,
  COALESCE(NULLIF(a.profesional, ''), u.nombre_completo)       AS inspector_nombre,
  0::integer                                                   AS numero_seguimiento,
  a.usuario_id                                                 AS usuario_id,
  a.centro_id                                                  AS centro_id,
  a.embarcacion_id                                             AS embarcacion_id
FROM ast_informes a
LEFT JOIN usuarios u ON u.id = a.usuario_id
WHERE a.estado_final NOT IN ('Eliminada', 'En Progreso');

GRANT SELECT ON public.historial_unificado TO anon, authenticated;

-- =============================================================================
-- VERIFICACIÓN
-- =============================================================================
-- SELECT id, estado_final, correlativo FROM ast_informes ORDER BY created_at DESC LIMIT 5;
-- SELECT informe_id, numero, titulo FROM ast_hallazgos ORDER BY numero LIMIT 10;
