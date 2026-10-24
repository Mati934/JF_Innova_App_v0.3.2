-- =====================================================
-- LIMPIEZA: Eliminar borradores y registros eliminados
-- de Supabase (actividades + visitas_tecnicas)
-- Ejecutar en Supabase SQL Editor
-- NOTA: actividades.estado_final es tipo enum (estado_actividad),
--       visitas_tecnicas.estado_final es tipo text
-- =====================================================

-- =====================================================
-- PASO 0: DRY RUN - Ver qué se va a borrar
-- =====================================================
SELECT 'actividades' as tabla, estado_final::text, COUNT(*) as total
FROM actividades
WHERE estado_final::text IN ('En Progreso', 'Eliminada')
GROUP BY estado_final

UNION ALL

SELECT 'visitas_tecnicas' as tabla, estado_final, COUNT(*) as total
FROM visitas_tecnicas
WHERE estado_final IN ('En Progreso', 'Eliminada')
GROUP BY estado_final;

-- Detalle de lo que se eliminará
SELECT id, estado_final::text, tipo_actividad, fecha_realizacion, numero_informe
FROM actividades
WHERE estado_final::text IN ('En Progreso', 'Eliminada')
ORDER BY fecha_realizacion DESC;

SELECT id, estado_final, tipo_actividad, fecha_realizacion
FROM visitas_tecnicas
WHERE estado_final IN ('En Progreso', 'Eliminada')
ORDER BY fecha_realizacion DESC;

-- =====================================================
-- PASO 1: EJECUTAR LIMPIEZA (dentro de transacción)
-- =====================================================
BEGIN;

-- 2a. registro_fotografico de actividades
DELETE FROM registro_fotografico
WHERE actividad_id IN (
  SELECT id FROM actividades
  WHERE estado_final::text IN ('En Progreso', 'Eliminada')
);

-- 2b. inspeccion_respuestas
DELETE FROM inspeccion_respuestas
WHERE actividad_id IN (
  SELECT id FROM actividades
  WHERE estado_final::text IN ('En Progreso', 'Eliminada')
);

-- 2c. verificaciones_buceo
DELETE FROM verificaciones_buceo
WHERE actividad_id IN (
  SELECT id FROM actividades
  WHERE estado_final::text IN ('En Progreso', 'Eliminada')
);

-- 2d. verificaciones_embarcacion
DELETE FROM verificaciones_embarcacion
WHERE actividad_id IN (
  SELECT id FROM actividades
  WHERE estado_final::text IN ('En Progreso', 'Eliminada')
);

-- 2e. actividad_participantes de actividades
DELETE FROM actividad_participantes
WHERE actividad_id IN (
  SELECT id FROM actividades
  WHERE estado_final::text IN ('En Progreso', 'Eliminada')
);

-- 3a. visitas_checklists
DELETE FROM visitas_checklists
WHERE visita_id IN (
  SELECT id FROM visitas_tecnicas
  WHERE estado_final IN ('En Progreso', 'Eliminada')
);

-- 3b. extintores
DELETE FROM extintores
WHERE visita_id IN (
  SELECT id FROM visitas_tecnicas
  WHERE estado_final IN ('En Progreso', 'Eliminada')
);

-- 3c. registro_fotografico de visitas
DELETE FROM registro_fotografico
WHERE actividad_id IN (
  SELECT id FROM visitas_tecnicas
  WHERE estado_final IN ('En Progreso', 'Eliminada')
);

-- 4a. Eliminar actividades borradores
DELETE FROM actividades
WHERE estado_final::text IN ('En Progreso', 'Eliminada');

-- 4b. Eliminar visitas_tecnicas borradores
DELETE FROM visitas_tecnicas
WHERE estado_final IN ('En Progreso', 'Eliminada');

COMMIT;

-- =====================================================
-- PASO 2: Verificar limpieza
-- =====================================================
SELECT 'actividades' as tabla, estado_final::text, COUNT(*) as total
FROM actividades
GROUP BY estado_final

UNION ALL

SELECT 'visitas_tecnicas' as tabla, estado_final, COUNT(*) as total
FROM visitas_tecnicas
GROUP BY estado_final;

-- NOTA: Las fotos en Supabase Storage (buckets 'evidencias' y 'pdfs_visitas')
-- quedarán huérfanas. No causan problemas funcionales pero ocupan espacio.
-- Para limpiarlas, usar la API de Storage o el Dashboard de Supabase.
