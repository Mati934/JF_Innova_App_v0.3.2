-- =============================================================================
-- FIX: desactivar tickets automaticos vacios
--
-- EJECUCION MANUAL OBLIGATORIA
-- Este archivo NO se aplica solo. Ejecutarlo manualmente en Supabase SQL Editor.
-- No borra fisicamente registros: usa borrado logico (eliminado = TRUE).
-- =============================================================================

-- PASO 1 (SOLO LECTURA): revisar los tickets exactos que seran desactivados.
SELECT
  t.id AS ticket_id,
  t.codigo_ticket,
  t.estado,
  t.created_at,
  t.inspeccion_id,
  a.numero_informe,
  a.fecha_realizacion,
  a.usuario_id,
  a.embarcacion_id
FROM public.tickets t
JOIN public.actividades a ON a.id = t.inspeccion_id
WHERE t.eliminado = FALSE
  AND t.origen = 'INSPECCION'
  AND NOT EXISTS (
    SELECT 1
    FROM public.ticket_items ti
    WHERE ti.ticket_id = t.id
  )
ORDER BY t.created_at, t.codigo_ticket;

-- Como interpretar:
-- Deben aparecer solo cabeceras automaticas sin items. Si aparece un ticket
-- que deba conservarse, detenerse antes del UPDATE.

-- PASO 2 (SOLO LECTURA): resumen de impacto.
SELECT
  COUNT(*) AS tickets_a_desactivar,
  COUNT(DISTINCT t.inspeccion_id) AS inspecciones_afectadas
FROM public.tickets t
JOIN public.actividades a ON a.id = t.inspeccion_id
WHERE t.eliminado = FALSE
  AND t.origen = 'INSPECCION'
  AND NOT EXISTS (
    SELECT 1
    FROM public.ticket_items ti
    WHERE ti.ticket_id = t.id
  );

-- PASO 3: ejecutar solo despues de revisar PASO 1 y PASO 2.
BEGIN;

UPDATE public.tickets t
SET eliminado = TRUE,
    updated_at = now()
WHERE t.eliminado = FALSE
  AND t.origen = 'INSPECCION'
  AND NOT EXISTS (
    SELECT 1
    FROM public.ticket_items ti
    WHERE ti.ticket_id = t.id
  );

-- Verificacion antes de confirmar.
SELECT COUNT(*) AS tickets_vacios_activos
FROM public.tickets t
WHERE t.eliminado = FALSE
  AND t.origen = 'INSPECCION'
  AND NOT EXISTS (
    SELECT 1
    FROM public.ticket_items ti
    WHERE ti.ticket_id = t.id
  );

-- Si el resultado es 0, confirmar la transaccion.
COMMIT;
