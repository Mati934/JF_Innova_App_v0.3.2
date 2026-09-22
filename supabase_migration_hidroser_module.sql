-- =============================================================================
-- MIGRACIÓN: Módulo Hidroser independiente
--
-- Crea un módulo Hidroser 100 % separado del Registro de Visita (R-003):
--   * Catálogo propio de listas de chequeo (`hidroser_listas`).
--   * Tabla de cabecera propia con `campos_extra` JSONB adaptable.
--   * Tabla de respuestas propia.
--   * Correlativo propio formato HIDROSER-<LISTA>-AAAA-NNNN.
--   * Vista `historial_unificado` extendida para incluir el módulo en el
--     historial general.
--
-- Las preguntas siguen viviendo en `formulario_items` (tipo `VISITA_R012`)
-- para no perder los seeds existentes; `hidroser_listas.tipo_formulario_items`
-- apunta a ese tipo. El R-012 ya está oculto del Registro de Visita en la app.
--
-- Pre-requisitos:
--   * supabase_migration_visitas_incluir_actividades.sql
--   * supabase_migration_campos_extra.sql
--   * supabase_migration_peso_preguntas.sql
--   * supabase_migration_checklist_gruas_horquillas_r012.sql  (preguntas R-012)
--   * supabase_migration_prosesso_history.sql  (vista historial_unificado base)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. CATÁLOGO de listas de chequeo Hidroser
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hidroser_listas (
  codigo                   TEXT PRIMARY KEY,
  nombre                   TEXT NOT NULL,
  subtitulo                TEXT,
  tipo_formulario_items    TEXT NOT NULL,
  icono                    TEXT,
  orden                    INTEGER NOT NULL DEFAULT 0,
  activo                   BOOLEAN NOT NULL DEFAULT TRUE,
  campos_extra_definicion  JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON COLUMN hidroser_listas.tipo_formulario_items IS
  'Apunta al tipo_actividad de formulario_items que define las preguntas.';
COMMENT ON COLUMN hidroser_listas.campos_extra_definicion IS
  'JSON array con campos de cabecera de la lista: [{clave,label,tipo,requerido,orden}]';

-- Seed inicial: Grúa Horquilla Patio Fiordo Austral.
INSERT INTO hidroser_listas (codigo, nombre, subtitulo, tipo_formulario_items, icono, orden, campos_extra_definicion)
VALUES (
  'GRUA_HORQUILLA_PFA',
  'Grúas Horquillas',
  'Lista de verificación',
  'VISITA_R012',
  'precision_manufacturing',
  10,
  '[
    {"clave":"conductor",       "label":"Conductor",        "tipo":"texto", "requerido":true,  "orden":1},
    {"clave":"numero_grua",     "label":"Número de grúa",   "tipo":"texto", "requerido":true,  "orden":2},
    {"clave":"horometro",       "label":"Horómetro",        "tipo":"texto", "requerido":false, "orden":3}
  ]'::jsonb
)
ON CONFLICT (codigo) DO UPDATE
   SET nombre                  = EXCLUDED.nombre,
       subtitulo               = EXCLUDED.subtitulo,
       tipo_formulario_items   = EXCLUDED.tipo_formulario_items,
       icono                   = EXCLUDED.icono,
       orden                   = EXCLUDED.orden,
       campos_extra_definicion = EXCLUDED.campos_extra_definicion,
       activo                  = TRUE;

-- -----------------------------------------------------------------------------
-- 2. INSPECCIONES HIDROSER (cabecera)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hidroser_inspecciones (
  id                        UUID PRIMARY KEY,
  usuario_id                UUID,
  empresa_id                UUID REFERENCES empresas(id),
  lista_codigo              TEXT NOT NULL REFERENCES hidroser_listas(codigo),
  fecha_realizacion         TIMESTAMPTZ NOT NULL DEFAULT now(),
  correlativo               TEXT,
  quien_inspecciona         TEXT,
  observaciones             TEXT,
  campos_extra              JSONB NOT NULL DEFAULT '{}'::jsonb,
  firma_supervisor_nombre   TEXT,
  firma_operador_nombre     TEXT,
  estado_final              TEXT NOT NULL DEFAULT 'Borrador',
  pdf_url                   TEXT,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hidroser_inspecciones_usuario  ON hidroser_inspecciones(usuario_id);
CREATE INDEX IF NOT EXISTS idx_hidroser_inspecciones_empresa  ON hidroser_inspecciones(empresa_id);
CREATE INDEX IF NOT EXISTS idx_hidroser_inspecciones_estado   ON hidroser_inspecciones(estado_final);
CREATE INDEX IF NOT EXISTS idx_hidroser_inspecciones_lista    ON hidroser_inspecciones(lista_codigo);

-- -----------------------------------------------------------------------------
-- 3. RESPUESTAS HIDROSER
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hidroser_respuestas (
  id              UUID PRIMARY KEY,
  inspeccion_id   UUID NOT NULL REFERENCES hidroser_inspecciones(id) ON DELETE CASCADE,
  item_id         UUID NOT NULL REFERENCES formulario_items(id),
  estado          TEXT,
  observacion     TEXT,
  criticidad      TEXT,
  foto_path       TEXT
);
CREATE INDEX IF NOT EXISTS idx_hidroser_respuestas_inspeccion ON hidroser_respuestas(inspeccion_id);

-- -----------------------------------------------------------------------------
-- 4. CORRELATIVO PROPIO Hidroser (HIDROSER-<PREFIJO>-AAAA-NNNN)
-- -----------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS hidroser_correlativo_seq AS BIGINT START 1;

CREATE OR REPLACE FUNCTION next_hidroser_correlativo(p_lista TEXT)
RETURNS TEXT AS $$
DECLARE
  v_year   INT    := EXTRACT(YEAR FROM now())::int;
  v_num    BIGINT := nextval('hidroser_correlativo_seq');
  v_prefix TEXT;
BEGIN
  v_prefix := CASE p_lista
    WHEN 'GRUA_HORQUILLA_PFA' THEN 'HIDROSER-GH'
    ELSE 'HIDROSER-' || regexp_replace(p_lista, '[^A-Z0-9]+', '', 'g')
  END;
  RETURN format('%s-%s-%s', v_prefix, v_year, LPAD(v_num::text, 4, '0'));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION assign_hidroser_correlativo() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.estado_final = 'En Seguimiento'
     AND (NEW.correlativo IS NULL OR NEW.correlativo = '') THEN
    NEW.correlativo := next_hidroser_correlativo(NEW.lista_codigo);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_hidroser_correlativo ON hidroser_inspecciones;
CREATE TRIGGER trg_hidroser_correlativo
  BEFORE INSERT OR UPDATE ON hidroser_inspecciones
  FOR EACH ROW EXECUTE FUNCTION assign_hidroser_correlativo();

-- -----------------------------------------------------------------------------
-- 5. EXTENDER vista historial_unificado para incluir Hidroser
--    Conserva todas las ramas existentes y agrega una rama UNION para Hidroser.
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

-- VISITAS TÉCNICAS (R003, R005, R006, R004, MANTENCION_PROSESSO)
SELECT
  v.id::text                                  AS id,
  CASE
    WHEN v.tipo_actividad = 'VISITA_R004'        THEN 'Inspección Extintores'
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
  h.id::text                                                  AS id,
  'Hidroser'::text                                            AS modulo,
  h.lista_codigo::text                                        AS tipo_registro,
  h.estado_final::text                                        AS estado,
  COALESCE(NULLIF(hl.nombre, ''), 'Sin ubicación')            AS ubicacion,
  h.fecha_realizacion::timestamptz                            AS fecha_realizacion,
  h.correlativo::text                                         AS numero_reporte,
  h.pdf_url                                                   AS pdf_url,
  NULL::text                                                  AS pdf_certificado_url,
  COALESCE(NULLIF(h.quien_inspecciona, ''), u.nombre_completo) AS inspector_nombre,
  0::integer                                                  AS numero_seguimiento,
  h.usuario_id                                                AS usuario_id,
  NULL::uuid                                                  AS centro_id,
  NULL::uuid                                                  AS embarcacion_id
FROM hidroser_inspecciones h
LEFT JOIN hidroser_listas hl ON hl.codigo = h.lista_codigo
LEFT JOIN usuarios       u  ON u.id      = h.usuario_id
WHERE h.estado_final NOT IN ('Eliminada', 'En Progreso');

GRANT SELECT ON public.historial_unificado TO anon, authenticated;

-- -----------------------------------------------------------------------------
-- 6. RLS — sólo el usuario dueño ve sus inspecciones (los admins igual ven
--    todas vía las políticas existentes en el resto de tablas; ajusta a tu
--    setup si necesitas algo más fino).
-- -----------------------------------------------------------------------------
ALTER TABLE hidroser_inspecciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE hidroser_respuestas   ENABLE ROW LEVEL SECURITY;
ALTER TABLE hidroser_listas       ENABLE ROW LEVEL SECURITY;

-- Lectura de catálogo: todos los autenticados.
DROP POLICY IF EXISTS hidroser_listas_select_all ON hidroser_listas;
CREATE POLICY hidroser_listas_select_all
  ON hidroser_listas FOR SELECT
  TO authenticated
  USING (true);

-- Inspecciones: el dueño ve / inserta / actualiza las suyas.
DROP POLICY IF EXISTS hidroser_inspecciones_owner_all ON hidroser_inspecciones;
CREATE POLICY hidroser_inspecciones_owner_all
  ON hidroser_inspecciones FOR ALL
  TO authenticated
  USING      (usuario_id = auth.uid())
  WITH CHECK (usuario_id = auth.uid());

-- Respuestas: el dueño de la inspección.
DROP POLICY IF EXISTS hidroser_respuestas_owner_all ON hidroser_respuestas;
CREATE POLICY hidroser_respuestas_owner_all
  ON hidroser_respuestas FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM hidroser_inspecciones i
             WHERE i.id = inspeccion_id AND i.usuario_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM hidroser_inspecciones i
             WHERE i.id = inspeccion_id AND i.usuario_id = auth.uid())
  );

-- -----------------------------------------------------------------------------
-- 7. HABILITAR módulo HIDROSER para la(s) empresa(s) Hidroser
-- -----------------------------------------------------------------------------
INSERT INTO empresa_modulos (empresa_id, modulo_key, habilitado, orden)
SELECT e.id, 'HIDROSER', true, 50
FROM empresas e
WHERE e.nombre ILIKE 'Hidroser%'
   OR e.nombre ILIKE '%Hidroser Industrial%'
ON CONFLICT (empresa_id, modulo_key)
DO UPDATE SET habilitado = true;

-- =============================================================================
-- VERIFICACIÓN
-- =============================================================================
-- SELECT codigo, nombre, tipo_formulario_items FROM hidroser_listas;
-- SELECT id, lista_codigo, estado_final, correlativo FROM hidroser_inspecciones
--   ORDER BY created_at DESC LIMIT 5;
-- SELECT modulo, COUNT(*) FROM historial_unificado GROUP BY modulo;
