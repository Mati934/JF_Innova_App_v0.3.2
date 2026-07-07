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

COMMIT;

-- =============================================================================
-- NOTA: no fue necesario agregar una columna nueva de "activo": la columna
-- `eliminado` ya existía desde supabase_migration_tickets_module.sql y ya la
-- usa la app para filtrar el listado (`TicketRepository.getTickets` hace
-- `.eq('eliminado', false)`). Este archivo solo agrega la restricción de
-- permisos que faltaba a nivel de base de datos.
-- =============================================================================
