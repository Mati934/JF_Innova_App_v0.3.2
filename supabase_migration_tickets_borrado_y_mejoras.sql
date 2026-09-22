-- =============================================================================
-- MIGRACION: Módulo TICKETS — borrado propio + ajustes menores
-- Contexto: supabase_migration_tickets_module.sql ya crea la columna
-- `tickets.eliminado BOOLEAN DEFAULT false` (borrado lógico), pero la
-- política `tickets_update` permite que CUALQUIER usuario de la misma
-- empresa actualice cualquier ticket (necesario para tomar/soltar/subsanar
-- entre compañeros). Este archivo agrega un trigger que restringe
-- específicamente el cambio de `eliminado` para que solo pueda hacerlo:
--   - el usuario que generó el ticket (generado_por_id), o
--   - un usuario admin (is_admin_user()).
--
-- Seguro de ejecutar múltiples veces (idempotente).
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- A) TRIGGER: solo el autor del ticket o un admin pueden eliminarlo/restaurarlo
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_ticket_borrado_permiso()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.eliminado IS DISTINCT FROM OLD.eliminado THEN
    IF NOT (
      auth.uid() = OLD.generado_por_id OR public.is_admin_user()
    ) THEN
      RAISE EXCEPTION 'No tienes permiso para eliminar este ticket.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_ticket_borrado_permiso ON public.tickets;
CREATE TRIGGER trg_ticket_borrado_permiso
  BEFORE UPDATE ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.check_ticket_borrado_permiso();

-- -----------------------------------------------------------------------------
-- B) Índice para filtrar rápido por `eliminado` en el listado (además del
--    índice compuesto ya usado por empresa/estado).
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_tickets_eliminado ON public.tickets(eliminado);

-- -----------------------------------------------------------------------------
-- C) `ticket_items`: guardar categoría/número/pregunta por separado (para el
--    rediseño de la tarjeta de ítem a subsanar, en vez de tenerlos
--    concatenados dentro de `descripcion`). Solo aplican a ítems de origen
--    RESPUESTA_INSPECCION; para FOTO_OBSERVACION quedan en NULL.
-- -----------------------------------------------------------------------------
ALTER TABLE public.ticket_items
  ADD COLUMN IF NOT EXISTS categoria       TEXT,
  ADD COLUMN IF NOT EXISTS numero_pregunta INTEGER,
  ADD COLUMN IF NOT EXISTS pregunta        TEXT;

-- Backfill best-effort de ítems ya existentes (creados antes de este cambio)
-- a partir de la respuesta de inspección original referenciada.
UPDATE public.ticket_items ti
SET
  pregunta        = fi.pregunta,
  categoria       = fi.categoria,
  numero_pregunta = fi.orden
FROM public.inspeccion_respuestas ir
JOIN public.formulario_items fi ON fi.id = ir.item_id
WHERE ti.origen_item = 'RESPUESTA_INSPECCION'
  AND ti.referencia_id = ir.id
  AND ti.pregunta IS NULL;

-- -----------------------------------------------------------------------------
-- D) BUG: el índice único "1 ticket automático por inspección" no consideraba
--    el borrado lógico. Si el ticket automático de una inspección se
--    eliminaba (`eliminado = true`), la BD seguía bloqueando la creación de
--    uno nuevo para la misma inspección porque el índice viejo no excluía
--    los eliminados. Se recrea el índice agregando `AND eliminado = false`
--    para que un ticket eliminado ya no cuente como "el automático vigente".
-- -----------------------------------------------------------------------------
DROP INDEX IF EXISTS public.uq_tickets_inspeccion_automatico;

CREATE UNIQUE INDEX IF NOT EXISTS uq_tickets_inspeccion_automatico
  ON public.tickets(inspeccion_id)
  WHERE origen = 'INSPECCION' AND inspeccion_id IS NOT NULL AND eliminado = false;

COMMIT;

-- =============================================================================
-- NOTA: no fue necesario agregar una columna nueva de "activo": la columna
-- `eliminado` ya existía desde supabase_migration_tickets_module.sql y ya la
-- usa la app para filtrar el listado (`TicketRepository.getTickets` hace
-- `.eq('eliminado', false)`). Este archivo solo agrega la restricción de
-- permisos que faltaba a nivel de base de datos.
-- =============================================================================
