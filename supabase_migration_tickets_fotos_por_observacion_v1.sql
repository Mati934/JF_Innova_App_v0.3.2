-- =============================================================================
-- MIGRACION: un ticket por observacion fotografica
--
-- EJECUCION MANUAL OBLIGATORIA
-- Ejecutar primero los checks y luego este archivo manualmente en Supabase
-- SQL Editor. Los archivos .sql del repositorio no se aplican solos.
-- =============================================================================

-- CHECK DE SOLO LECTURA: revisar los indices actuales.
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'tickets'
  AND indexname IN (
    'uq_tickets_fotos_observacion_automatico',
    'uq_tickets_fotos_observacion_por_observacion'
  )
ORDER BY indexname;

-- CHECK DE SOLO LECTURA: detectar claves nuevas repetidas antes de crear el indice.
SELECT
  inspeccion_id,
  campos_extra_json ->> 'observacion_foto_key' AS observacion_foto_key,
  COUNT(*) AS cantidad
FROM public.tickets
WHERE eliminado = FALSE
  AND campos_extra_json ->> 'automatico_tipo' = 'FOTOS_OBSERVACION'
  AND campos_extra_json ->> 'observacion_foto_key' IS NOT NULL
GROUP BY inspeccion_id, campos_extra_json ->> 'observacion_foto_key'
HAVING COUNT(*) > 1;

BEGIN;

-- El indice anterior permitia solo un ticket de fotos por inspeccion.
DROP INDEX IF EXISTS public.uq_tickets_fotos_observacion_automatico;

-- Ahora la unidad unica es inspeccion + observacion normalizada.
CREATE UNIQUE INDEX IF NOT EXISTS uq_tickets_fotos_observacion_por_observacion
  ON public.tickets (
    inspeccion_id,
    (campos_extra_json ->> 'observacion_foto_key')
  )
  WHERE origen = 'INSPECCION'
    AND inspeccion_id IS NOT NULL
    AND eliminado = FALSE
    AND estado <> 'CERRADO'
    AND campos_extra_json ->> 'automatico_tipo' = 'FOTOS_OBSERVACION'
    AND campos_extra_json ->> 'observacion_foto_key' IS NOT NULL;

COMMIT;

-- VERIFICACION POSTERIOR DE SOLO LECTURA.
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'tickets'
  AND indexname IN (
    'uq_tickets_fotos_observacion_automatico',
    'uq_tickets_fotos_observacion_por_observacion'
  )
ORDER BY indexname;
