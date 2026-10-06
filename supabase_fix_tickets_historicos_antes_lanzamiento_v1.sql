-- =============================================================================
-- FIX: desactivar tickets de inspecciones anteriores al lanzamiento
-- Fecha de corte: 2026-08-31 00:00:00 UTC
--
-- EJECUCION MANUAL OBLIGATORIA
-- Este archivo NO se aplica solo. Ejecutarlo manualmente en Supabase SQL Editor.
-- No borra fisicamente tickets: los desactiva con eliminado = TRUE.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PASO 1 (SOLO LECTURA): revisar exactamente que tickets serian desactivados.
-- Debe ejecutarse y revisarse antes del UPDATE.
-- -----------------------------------------------------------------------------
SELECT
  t.id AS ticket_id,
  t.codigo_ticket,
  t.estado,
  t.eliminado,
  t.numero_informe,
  t.inspeccion_id,
  a.created_at AS inspeccion_creada,
  a.fecha_realizacion,
  a.tickets_generados_at,
  COUNT(ti.id) AS total_items
FROM public.tickets t
JOIN public.actividades a ON a.id = t.inspeccion_id
LEFT JOIN public.ticket_items ti ON ti.ticket_id = t.id
WHERE t.eliminado = FALSE
  AND a.created_at < TIMESTAMPTZ '2026-08-31 00:00:00+00'
  AND t.origen = 'INSPECCION'
GROUP BY
  t.id,
  t.codigo_ticket,
  t.estado,
  t.eliminado,
  t.numero_informe,
  t.inspeccion_id,
  a.created_at,
  a.fecha_realizacion,
  a.tickets_generados_at
ORDER BY a.created_at, t.codigo_ticket;

-- Como interpretar:
-- - Estas son las inspecciones antiguas que ya generaron tickets.
-- - Si el resultado incluye un ticket que debe conservarse como historico
--   visible, detenerse y revisarlo antes del UPDATE.
-- - El UPDATE afecta solo tickets activos ligados a inspecciones antiguas.

-- -----------------------------------------------------------------------------
-- PASO 2 (SOLO LECTURA): resumen de impacto.
-- -----------------------------------------------------------------------------
SELECT
  COUNT(*) AS tickets_a_desactivar,
  COUNT(DISTINCT t.inspeccion_id) AS inspecciones_afectadas,
  MIN(a.created_at) AS inspeccion_mas_antigua,
  MAX(a.created_at) AS inspeccion_mas_reciente
FROM public.tickets t
JOIN public.actividades a ON a.id = t.inspeccion_id
WHERE t.eliminado = FALSE
  AND a.created_at < TIMESTAMPTZ '2026-08-31 00:00:00+00'
  AND t.origen = 'INSPECCION';

-- -----------------------------------------------------------------------------
-- PASO 3 (CAMBIO DE DATOS): desactivar los tickets antiguos.
-- Ejecutar solo despues de revisar PASO 1 y PASO 2.
-- -----------------------------------------------------------------------------
BEGIN;

UPDATE public.tickets t
SET eliminado = TRUE,
    updated_at = now()
FROM public.actividades a
WHERE t.inspeccion_id = a.id
  AND t.eliminado = FALSE
  AND a.created_at < TIMESTAMPTZ '2026-08-31 00:00:00+00'
  AND t.origen = 'INSPECCION';

-- Verificacion dentro de la transaccion antes de confirmar.
SELECT
  COUNT(*) AS tickets_antiguos_aun_activos
FROM public.tickets t
JOIN public.actividades a ON a.id = t.inspeccion_id
WHERE t.eliminado = FALSE
  AND a.created_at < TIMESTAMPTZ '2026-08-31 00:00:00+00'
  AND t.origen = 'INSPECCION';

-- Si el resultado anterior es 0 y el Paso 1 fue revisado, confirmar:
COMMIT;

-- Para deshacer funcionalmente un caso puntual, revisar primero y luego:
-- UPDATE public.tickets
-- SET eliminado = FALSE, updated_at = now()
-- WHERE codigo_ticket = 'TCK-AAAA-NNNN';
