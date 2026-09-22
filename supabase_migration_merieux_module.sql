-- =============================================================================
-- MIGRACIÓN: Módulo Merieux (independiente, 2 submódulos)
--
-- Empresa nueva "Merieux" (demo). Dos submódulos, ambos comparten el MISMO
-- encabezado (10 campos: profesional/fono/correo de sesión + región + área +
-- jefatura a cargo + hora inicio/término + origen de la actividad + correos):
--   * MERIEUX_VISITAS    -> Registro de visita reducido a 2 checklists:
--                           "Sin checklist" y "Vehículos Livianos" (reusa el
--                           mismo banco de preguntas de formulario_items,
--                           tipo_actividad = 'VISITA_R008').
--   * MERIEUX_EXTINTORES -> Igual encabezado + checklist de mantención de
--                           extintores (grilla de N extintores, 9 preguntas
--                           c/u), tal como Prosesso, pero con tablas propias.
--
-- Arquitectura: módulo 100% independiente (como Hidroser v2 / AST / Buceo
-- Equipamiento), NO reutiliza visitas_tecnicas ni las tablas de Prosesso.
-- Un único header (`merieux_visitas`) sirve a ambos submódulos, distinguidos
-- por `tipo_actividad`; cada uno tiene su propia tabla hija:
--   * merieux_visita_respuestas  (checklist de 1 sola pregunta por fila, como
--     hidroser_respuestas) — solo aplica a MERIEUX_VISITAS.
--   * merieux_extintores         (1 fila por extintor con su propio checklist
--     embebido en JSON, como mantenciones_prosesso_pendientes) — solo aplica
--     a MERIEUX_EXTINTORES.
--
-- Espejo local en SQLite: merieux_visitas_pendientes / _respuestas_pendientes /
-- extintores_pendientes (ver bump de DatabaseHelper correspondiente).
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. CABECERA COMPARTIDA: merieux_visitas
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.merieux_visitas (
  id                 UUID PRIMARY KEY,
  usuario_id         UUID,
  empresa_id         UUID REFERENCES public.empresas(id),
  tipo_actividad     TEXT NOT NULL CHECK (tipo_actividad IN ('MERIEUX_VISITAS', 'MERIEUX_EXTINTORES')),
  checklist_tipo     TEXT, -- solo MERIEUX_VISITAS: NULL = sin checklist, 'VISITA_R008' = Vehículos Livianos
  profesional        TEXT,
  fono_profesional   TEXT,
  correo_profesional TEXT,
  region             TEXT,
  area               TEXT,
  jefatura_a_cargo   TEXT,
  origen_actividad   TEXT,
  fecha_realizacion  TIMESTAMPTZ NOT NULL DEFAULT now(),
  hora_inicio        TEXT,
  hora_termino       TEXT,
  correo_1           TEXT,
  correo_2           TEXT,
  campos_extra       JSONB NOT NULL DEFAULT '{}'::jsonb,
  observaciones      TEXT,
  correlativo        TEXT,
  estado_final       TEXT NOT NULL DEFAULT 'En Progreso',
  pdf_url            TEXT,
  eliminado          BOOLEAN NOT NULL DEFAULT false,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_merieux_visitas_usuario ON public.merieux_visitas(usuario_id);
CREATE INDEX IF NOT EXISTS idx_merieux_visitas_empresa ON public.merieux_visitas(empresa_id);
CREATE INDEX IF NOT EXISTS idx_merieux_visitas_estado   ON public.merieux_visitas(estado_final);
CREATE INDEX IF NOT EXISTS idx_merieux_visitas_tipo     ON public.merieux_visitas(tipo_actividad);

-- -----------------------------------------------------------------------------
-- 2. CHECKLIST SUBMÓDULO "MERIEUX_VISITAS" (1 fila por pregunta respondida)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.merieux_visita_respuestas (
  id           UUID PRIMARY KEY,
  visita_id    UUID NOT NULL REFERENCES public.merieux_visitas(id) ON DELETE CASCADE,
  item_id      UUID NOT NULL REFERENCES public.formulario_items(id),
  estado       TEXT,
  observacion  TEXT,
  criticidad   TEXT,
  foto_path    TEXT
);
CREATE INDEX IF NOT EXISTS idx_merieux_visita_respuestas_visita ON public.merieux_visita_respuestas(visita_id);

-- -----------------------------------------------------------------------------
-- 3. CHECKLIST SUBMÓDULO "MERIEUX_EXTINTORES" (1 fila por extintor)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.merieux_extintores (
  id                 UUID PRIMARY KEY,
  visita_id          UUID NOT NULL REFERENCES public.merieux_visitas(id) ON DELETE CASCADE,
  numero             INTEGER NOT NULL DEFAULT 0,
  planta             TEXT,
  ubicacion          TEXT,
  ubicacion_sector   TEXT,
  ubicacion_2        TEXT,
  certificado        TEXT,
  anio               INTEGER,
  tipo               TEXT,
  peso               TEXT,
  kg                 TEXT,
  fecha_vencimiento  TEXT,
  observaciones      TEXT,
  respuestas_json    JSONB NOT NULL DEFAULT '{}'::jsonb, -- 9 preguntas (igual formato que Prosesso)
  fotos_json         JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_merieux_extintores_visita ON public.merieux_extintores(visita_id);

-- -----------------------------------------------------------------------------
-- 4. CORRELATIVO PROPIO (MERIEUX-VIS-AAAA-NNNN / MERIEUX-EXT-AAAA-NNNN)
-- -----------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS merieux_correlativo_seq AS BIGINT START 1;

CREATE OR REPLACE FUNCTION next_merieux_correlativo(p_tipo TEXT)
RETURNS TEXT AS $$
DECLARE
  v_year   INT    := EXTRACT(YEAR FROM now())::int;
  v_num    BIGINT := nextval('merieux_correlativo_seq');
  v_prefix TEXT;
BEGIN
  v_prefix := CASE p_tipo
    WHEN 'MERIEUX_EXTINTORES' THEN 'MERIEUX-EXT'
    ELSE 'MERIEUX-VIS'
  END;
  RETURN format('%s-%s-%s', v_prefix, v_year, LPAD(v_num::text, 4, '0'));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION assign_merieux_correlativo() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.estado_final = 'En Seguimiento'
     AND (NEW.correlativo IS NULL OR NEW.correlativo = '') THEN
    NEW.correlativo := next_merieux_correlativo(NEW.tipo_actividad);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_merieux_correlativo ON public.merieux_visitas;
CREATE TRIGGER trg_merieux_correlativo
  BEFORE INSERT OR UPDATE ON public.merieux_visitas
  FOR EACH ROW EXECUTE FUNCTION assign_merieux_correlativo();

-- -----------------------------------------------------------------------------
-- 5. RLS — el dueño ve / inserta / actualiza sus registros (mismo patrón AST/Hidroser).
-- -----------------------------------------------------------------------------
ALTER TABLE public.merieux_visitas            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merieux_visita_respuestas   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merieux_extintores          ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS merieux_visitas_owner_all ON public.merieux_visitas;
CREATE POLICY merieux_visitas_owner_all
  ON public.merieux_visitas FOR ALL
  TO authenticated
  USING      (usuario_id = auth.uid())
  WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS merieux_visita_respuestas_owner_all ON public.merieux_visita_respuestas;
CREATE POLICY merieux_visita_respuestas_owner_all
  ON public.merieux_visita_respuestas FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.merieux_visitas v
             WHERE v.id = visita_id AND v.usuario_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.merieux_visitas v
             WHERE v.id = visita_id AND v.usuario_id = auth.uid())
  );

DROP POLICY IF EXISTS merieux_extintores_owner_all ON public.merieux_extintores;
CREATE POLICY merieux_extintores_owner_all
  ON public.merieux_extintores FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.merieux_visitas v
             WHERE v.id = visita_id AND v.usuario_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.merieux_visitas v
             WHERE v.id = visita_id AND v.usuario_id = auth.uid())
  );

-- -----------------------------------------------------------------------------
-- 6. HABILITAR módulos para la empresa Merieux.
--    Ajusta el ILIKE si el nombre real en `empresas` difiere.
-- -----------------------------------------------------------------------------
-- INSERT INTO empresa_modulos (empresa_id, modulo_key, habilitado, orden)
-- SELECT e.id, 'MERIEUX_VISITAS', true, 60
-- FROM empresas e
-- WHERE e.nombre ILIKE '%Merieux%'
-- ON CONFLICT (empresa_id, modulo_key) DO UPDATE SET habilitado = true;
--
-- INSERT INTO empresa_modulos (empresa_id, modulo_key, habilitado, orden)
-- SELECT e.id, 'MERIEUX_EXTINTORES', true, 61
-- FROM empresas e
-- WHERE e.nombre ILIKE '%Merieux%'
-- ON CONFLICT (empresa_id, modulo_key) DO UPDATE SET habilitado = true;

-- -----------------------------------------------------------------------------
-- 7. EXTENDER historial_unificado para incluir Merieux (2 ramas).
--    Conserva todas las ramas existentes (Inspección, Visita Técnica, Hidroser,
--    AST) y agrega Merieux Visitas + Merieux Extintores.
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
WHERE a.estado_final NOT IN ('Eliminada', 'En Progreso')

UNION ALL

-- MERIEUX (Visitas + Extintores, mismo header, distinguidos por tipo_actividad)
SELECT
  m.id::text                                                   AS id,
  CASE
    WHEN m.tipo_actividad = 'MERIEUX_EXTINTORES' THEN 'Merieux - Mantención de Extintores'
    ELSE 'Merieux - Registro de Visita'
  END::text                                                    AS modulo,
  COALESCE(m.checklist_tipo, m.tipo_actividad)::text            AS tipo_registro,
  m.estado_final::text                                         AS estado,
  COALESCE(NULLIF(m.area, ''), NULLIF(m.region, ''), 'Sin ubicación') AS ubicacion,
  m.fecha_realizacion::timestamptz                             AS fecha_realizacion,
  m.correlativo::text                                          AS numero_reporte,
  m.pdf_url                                                    AS pdf_url,
  NULL::text                                                   AS pdf_certificado_url,
  COALESCE(NULLIF(m.profesional, ''), u.nombre_completo)       AS inspector_nombre,
  0::integer                                                   AS numero_seguimiento,
  m.usuario_id                                                 AS usuario_id,
  NULL::uuid                                                   AS centro_id,
  NULL::uuid                                                   AS embarcacion_id
FROM merieux_visitas m
LEFT JOIN usuarios u ON u.id = m.usuario_id
WHERE m.estado_final NOT IN ('Eliminada', 'En Progreso') AND m.eliminado = false;

GRANT SELECT ON public.historial_unificado TO anon, authenticated;

COMMIT;

-- =============================================================================
-- VERIFICACIÓN
-- =============================================================================
-- SELECT id, tipo_actividad, checklist_tipo, estado_final, correlativo FROM merieux_visitas ORDER BY created_at DESC LIMIT 5;
-- SELECT visita_id, item_id, estado FROM merieux_visita_respuestas ORDER BY visita_id LIMIT 10;
-- SELECT visita_id, numero, tipo FROM merieux_extintores ORDER BY visita_id, numero LIMIT 10;
