-- =============================================================================
-- FIX CRITICO: quitar unicidad legacy por inspeccion en tickets automaticos
-- Fecha: 2026-08-03
--
-- Problema:
--   El índice `uq_tickets_inspeccion_automatico` deja max 1 ticket por
--   inspeccion (aunque ahora queremos 1 ticket por hallazgo).
--
-- Solucion:
--   1) Eliminar índice único legacy por inspección.
--   2) Mantener índice no-único de soporte para búsquedas por inspección.
--   3) Asegurar índice único activo por hallazgo.
-- =============================================================================

BEGIN;

DROP INDEX IF EXISTS public.uq_tickets_inspeccion_automatico;

CREATE INDEX IF NOT EXISTS idx_tickets_inspeccion_origen
  ON public.tickets(inspeccion_id, origen)
  WHERE origen = 'INSPECCION' AND inspeccion_id IS NOT NULL AND eliminado = false;

CREATE UNIQUE INDEX IF NOT EXISTS uq_tickets_hallazgo_activo
  ON public.tickets(hallazgo_id)
  WHERE hallazgo_id IS NOT NULL
    AND eliminado = false
    AND estado <> 'CERRADO';

COMMIT;
