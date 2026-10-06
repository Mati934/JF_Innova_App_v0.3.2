-- =============================================================================
-- RESET TOTAL DEL MODULO TICKETS PARA PRODUCCION
-- Fecha: 2026-08-21
--
-- EJECUTAR MANUALMENTE en el SQL Editor de Supabase (Dashboard > SQL Editor).
-- Los .sql de este repo NO se aplican solos.
--
-- ORDEN OBLIGATORIO antes de correr este archivo:
--   1) supabase_verificacion_tickets_indices.sql (solo lectura) — ya corrido.
--   2) supabase_migration_tickets_hallazgo_index_fix.sql (el fix de indices)
--      — segun indicaste, lo vas a correr.
--   3) ESTE archivo.
--
-- ADVERTENCIA: DELETE real (no borrado logico) e IRREVERSIBLE.
-- Se pierden los hallazgos reales detectados hoy (TCK-2026-0001 informe 496
-- de Hector Leal, TCK-2026-0005 informe 498 de Paola Villarroel, ambos por
-- "falta de escalera de rescate de buzo"). Si esos NC vuelven a detectarse
-- en una inspeccion futura, se creara ticket nuevo desde cero.
--
-- Que hace, en orden:
--   1) Muestra conteos ANTES (para constancia).
--   2) Borra TODOS los tickets (incluidos eliminado=true) -> CASCADE arrastra
--      ticket_items, ticket_historial_tomas, ticket_notificaciones,
--      ticket_item_subsanaciones.
--   3) Borra TODOS los nc_hallazgos -> CASCADE arrastra nc_hallazgo_ocurrencias.
--   4) Reinicia el correlativo TCK-AAAA-NNNN en 1.
--   5) Marca tickets_generados_at = now() en TODAS las inspecciones
--      finalizadas sin marcar. CRITICO: sin esto, las inspecciones 496 y 498
--      (y cualquier otra En Seguimiento sin marca) VOLVERIAN a generar
--      tickets en el proximo sync de su autor, apenas lances produccion.
--      Con la marca, la automatizacion parte de cero: solo generara tickets
--      de inspecciones finalizadas DESPUES de este reset.
--   6) Muestra conteos DESPUES (todo debe quedar en 0).
-- =============================================================================

-- (1) CONTEOS ANTES
SELECT 'ANTES' AS momento, 'tickets' AS tabla, count(*) AS total FROM public.tickets
UNION ALL SELECT 'ANTES', 'ticket_items', count(*) FROM public.ticket_items
UNION ALL SELECT 'ANTES', 'ticket_historial_tomas', count(*) FROM public.ticket_historial_tomas
UNION ALL SELECT 'ANTES', 'ticket_notificaciones', count(*) FROM public.ticket_notificaciones
UNION ALL SELECT 'ANTES', 'ticket_item_subsanaciones', count(*) FROM public.ticket_item_subsanaciones
UNION ALL SELECT 'ANTES', 'nc_hallazgos', count(*) FROM public.nc_hallazgos
UNION ALL SELECT 'ANTES', 'nc_hallazgo_ocurrencias', count(*) FROM public.nc_hallazgo_ocurrencias
UNION ALL SELECT 'ANTES', 'actividades_sin_marcar', count(*) FROM public.actividades
  WHERE estado_final = 'En Seguimiento'
    AND tipo_actividad IN ('INSPECCION_BUCEO', 'INSPECCION_EMBARCACION')
    AND tickets_generados_at IS NULL;

BEGIN;

-- (2) Tickets (arrastra hijas por ON DELETE CASCADE)
DELETE FROM public.tickets;

-- (3) Hallazgos (arrastra ocurrencias por ON DELETE CASCADE)
DELETE FROM public.nc_hallazgos;

-- (4) Correlativo desde 0001
ALTER SEQUENCE IF EXISTS public.ticket_codigo_seq RESTART WITH 1;

-- (5) Marcar como ya procesadas TODAS las inspecciones finalizadas, para que
--     la automatizacion no regenere tickets de informes anteriores al reset.
UPDATE public.actividades
SET tickets_generados_at = now()
WHERE tickets_generados_at IS NULL
  AND estado_final = 'En Seguimiento'
  AND tipo_actividad IN ('INSPECCION_BUCEO', 'INSPECCION_EMBARCACION');

COMMIT;

-- (6) CONTEOS DESPUES — esperado: 0 en las 7 tablas y 0 sin marcar
SELECT 'DESPUES' AS momento, 'tickets' AS tabla, count(*) AS total FROM public.tickets
UNION ALL SELECT 'DESPUES', 'ticket_items', count(*) FROM public.ticket_items
UNION ALL SELECT 'DESPUES', 'ticket_historial_tomas', count(*) FROM public.ticket_historial_tomas
UNION ALL SELECT 'DESPUES', 'ticket_notificaciones', count(*) FROM public.ticket_notificaciones
UNION ALL SELECT 'DESPUES', 'ticket_item_subsanaciones', count(*) FROM public.ticket_item_subsanaciones
UNION ALL SELECT 'DESPUES', 'nc_hallazgos', count(*) FROM public.nc_hallazgos
UNION ALL SELECT 'DESPUES', 'nc_hallazgo_ocurrencias', count(*) FROM public.nc_hallazgo_ocurrencias
UNION ALL SELECT 'DESPUES', 'actividades_sin_marcar', count(*) FROM public.actividades
  WHERE estado_final = 'En Seguimiento'
    AND tipo_actividad IN ('INSPECCION_BUCEO', 'INSPECCION_EMBARCACION')
    AND tickets_generados_at IS NULL;

-- =============================================================================
-- OPCIONAL (NO ejecutar si quieres partir totalmente en blanco):
-- Si en vez de borrar prefieres CONSERVAR los 2 hallazgos reales con la
-- atribucion corregida, NO corras este archivo y usa solo:
--
--   UPDATE public.tickets SET generado_por_id = '650b93e2-0a46-4554-aead-6c0fdd61af5c'
--   WHERE codigo_ticket = 'TCK-2026-0001';  -- Hector Leal (informe 496)
--   UPDATE public.tickets SET generado_por_id = '4e095cf2-51aa-40bd-80a9-78d8b5b4ed48'
--   WHERE codigo_ticket = 'TCK-2026-0005';  -- Paola Villarroel (informe 498)
--   UPDATE public.actividades SET tickets_generados_at = now()
--   WHERE id IN ('19f6d179-5572-475e-b326-99affdf90325',
--                '58045215-44ca-4dda-b82a-590d92efa5e1');
-- =============================================================================
