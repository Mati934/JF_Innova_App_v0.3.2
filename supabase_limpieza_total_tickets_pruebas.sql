-- =============================================================================
-- LIMPIEZA TOTAL DE DATOS DE PRUEBA: Modulo Tickets
-- Ejecutar manualmente en el SQL Editor de Supabase.
-- ADVERTENCIA: esto es un DELETE real (no borrado logico) e IRREVERSIBLE.
-- Solo correr si toda la data actual de tickets es de prueba y se puede perder.
--
-- Borra, en este orden (los CASCADE de las FK se encargan del resto):
--   1) tickets            -> arrastra ticket_items, ticket_historial_tomas,
--                            ticket_notificaciones, ticket_item_subsanaciones
--   2) nc_hallazgos        -> arrastra nc_hallazgo_ocurrencias
--   3) reinicia el correlativo TCK-AAAA-NNNN para que el proximo ticket
--      real que se genere en produccion vuelva a arrancar en 0001.
-- =============================================================================

BEGIN;

DELETE FROM public.tickets;
DELETE FROM public.nc_hallazgos;

ALTER SEQUENCE IF EXISTS public.ticket_codigo_seq RESTART WITH 1;

COMMIT;

-- Verificacion post-limpieza (debe devolver 0 filas en todas):
SELECT 'tickets' AS tabla, count(*) FROM public.tickets
UNION ALL SELECT 'ticket_items', count(*) FROM public.ticket_items
UNION ALL SELECT 'ticket_historial_tomas', count(*) FROM public.ticket_historial_tomas
UNION ALL SELECT 'ticket_notificaciones', count(*) FROM public.ticket_notificaciones
UNION ALL SELECT 'ticket_item_subsanaciones', count(*) FROM public.ticket_item_subsanaciones
UNION ALL SELECT 'nc_hallazgos', count(*) FROM public.nc_hallazgos
UNION ALL SELECT 'nc_hallazgo_ocurrencias', count(*) FROM public.nc_hallazgo_ocurrencias;
