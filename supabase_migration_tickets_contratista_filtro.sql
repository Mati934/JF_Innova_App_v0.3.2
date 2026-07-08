-- =============================================================================
-- MIGRACION: Módulo TICKETS — columna contratista_id + filtro
-- Contexto: el listado de Tickets ya soportaba filtrar por centro/embarcación/
-- área (columnas existentes desde supabase_migration_tickets_module.sql), pero
-- no había forma de filtrar por contratista porque `tickets` no guardaba ese
-- dato. Este archivo:
--   1) Agrega `tickets.contratista_id` (FK a contratistas).
--   2) Backfillea los tickets existentes que tengan embarcacion_id, tomando el
--      contratista dueño de esa embarcación (embarcaciones.contratista_id).
--   3) Agrega índice para filtrar rápido.
--
-- Seguro de ejecutar múltiples veces (idempotente).
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- A) Columna nueva
-- -----------------------------------------------------------------------------
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS contratista_id UUID REFERENCES public.contratistas(id);

CREATE INDEX IF NOT EXISTS idx_tickets_contratista ON public.tickets(contratista_id);

-- -----------------------------------------------------------------------------
-- B) Backfill: tickets ya creados con embarcación asociada heredan el
--    contratista dueño de esa embarcación.
-- -----------------------------------------------------------------------------
UPDATE public.tickets t
SET contratista_id = e.contratista_id
FROM public.embarcaciones e
WHERE t.embarcacion_id = e.id
  AND t.contratista_id IS NULL
  AND e.contratista_id IS NOT NULL;

COMMIT;
