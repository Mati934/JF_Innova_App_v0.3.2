-- =============================================================================
-- MIGRACIÓN: Habilitar HISTORIAL para PROSESSO + actualizar historial_unificado
--           para incluir mantenciones PROSESSO y exponer pdf_certificado_url
-- Ejecutar en Supabase SQL Editor (paso por paso).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PASO 1: Habilitar el módulo HISTORY (Historial) para la empresa Prosesso.
--         Acepta el nombre actualizado 'Prosesso' o el legado 'PROSESSO SpA'.
-- -----------------------------------------------------------------------------
INSERT INTO empresa_modulos (empresa_id, modulo_key, habilitado, orden)
SELECT e.id, 'HISTORY', true, 90
FROM empresas e
WHERE e.nombre IN ('Prosesso', 'PROSESSO SpA')
ON CONFLICT (empresa_id, modulo_key)
DO UPDATE SET habilitado = true;

-- (Opcional, normalización) renombrar la empresa al nuevo formato.
-- UPDATE empresas SET nombre = 'Prosesso' WHERE nombre = 'PROSESSO SpA';

-- -----------------------------------------------------------------------------
-- PASO 2: Recrear la vista historial_unificado para que:
--         - Incluya MANTENCION_PROSESSO (estaban excluidas).
--         - Exponga `pdf_certificado_url` (segundo PDF del módulo Prosesso).
--         - Mantenga compatibilidad con inspecciones y visitas existentes.
--
-- ⚠️  La definición de la vista DEPENDE de tu schema actual. Si ya tenías una
-- versión personalizada, conserva tus columnas y solo agrega:
--   1) `pdf_certificado_url`  →  `null::text` para módulos sin certificado.
--   2) Una rama UNION para los registros de PROSESSO si no estaban incluidos.
-- =============================================================================

DROP VIEW IF EXISTS public.historial_unificado;

CREATE VIEW public.historial_unificado AS
-- INSPECCIONES (actividades_pendientes finalizadas)
SELECT
  a.id::text                                    AS id,
  'Inspección'::text                            AS modulo,
  a.tipo_actividad::text                        AS tipo_registro,
  a.estado_final::text                          AS estado,
  COALESCE(c.nombre, 'Sin ubicación')           AS ubicacion,
  a.fecha_realizacion::timestamptz              AS fecha_realizacion,
  a.numero_informe::text                        AS numero_reporte,
  a.pdf_url                                     AS pdf_url,
  null::text                                    AS pdf_certificado_url,
  u.nombre_completo                             AS inspector_nombre,
  COALESCE(a.numero_seguimiento, 0)::integer    AS numero_seguimiento,
  a.usuario_id                                  AS usuario_id,
  a.centro_id                                   AS centro_id,
  a.embarcacion_id                              AS embarcacion_id
FROM actividades a
LEFT JOIN centros  c ON c.id = a.centro_id
LEFT JOIN usuarios u ON u.id = a.usuario_id
WHERE a.estado_final NOT IN ('Eliminada', 'En Progreso')

UNION ALL

-- VISITAS TÉCNICAS estándar (incluye R003/R005/R006/R004)
SELECT
  v.id::text                                    AS id,
  CASE
    WHEN v.tipo_actividad = 'VISITA_R004'
      THEN 'Inspección Extintores'
    WHEN v.tipo_actividad = 'MANTENCION_PROSESSO'
      THEN 'Mantención de Extintores'
    ELSE 'Visita Técnica'
  END::text                                     AS modulo,
  v.tipo_actividad::text                        AS tipo_registro,
  v.estado_final::text                          AS estado,
  COALESCE(
    NULLIF(v.cliente_nombre, ''),
    NULLIF(v.lugar_visita, ''),
    'Sin ubicación'
  )                                             AS ubicacion,
  v.fecha_realizacion::timestamptz              AS fecha_realizacion,
  v.cert_numero::text                           AS numero_reporte,
  v.pdf_url                                     AS pdf_url,
  v.pdf_certificado_url                         AS pdf_certificado_url,
  u.nombre_completo                             AS inspector_nombre,
  0::integer                                    AS numero_seguimiento,
  v.usuario_id                                  AS usuario_id,
  null::uuid                                    AS centro_id,
  null::uuid                                    AS embarcacion_id
FROM visitas_tecnicas v
LEFT JOIN usuarios u ON u.id = v.usuario_id
WHERE v.estado_final NOT IN ('Eliminada', 'En Progreso');

-- -----------------------------------------------------------------------------
-- PASO 3: Permisos (ajusta según tu RLS existente).
-- -----------------------------------------------------------------------------
GRANT SELECT ON public.historial_unificado TO anon, authenticated;

-- -----------------------------------------------------------------------------
-- VERIFICACIÓN
-- -----------------------------------------------------------------------------
-- SELECT modulo, COUNT(*) FROM historial_unificado GROUP BY modulo;
-- SELECT modulo_key, habilitado FROM empresa_modulos
--   WHERE empresa_id IN (SELECT id FROM empresas WHERE nombre IN ('Prosesso','PROSESSO SpA'));
