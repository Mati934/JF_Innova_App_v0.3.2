-- =============================================================================
-- REINICIAR el correlativo del modulo Tickets desde TCK-AAAA-0001
--
-- El codigo de ticket (TCK-AAAA-NNNN) lo asigna el trigger `trg_ticket_codigo`
-- tomando el siguiente valor de la secuencia `ticket_codigo_seq`.
-- Este script reinicia esa secuencia para que el proximo ticket sea 0001.
--
-- Los datos de prueba (tickets, ticket_items, ticket_historial_tomas,
-- ticket_notificaciones) ya fueron borrados via API (service_role_api_key) el
-- 2026-07-07. Solo falta reiniciar la secuencia, que es DDL y requiere
-- correrse manualmente aqui en el SQL Editor de Supabase.
--
-- ADVERTENCIA: si en el futuro quedan tickets con correlativos ya asignados,
-- reiniciar la secuencia hara que los proximos tickets repitan esos numeros.
-- Reinicia SOLO si la tabla tickets esta vacia (o asumes el riesgo).
-- =============================================================================

ALTER SEQUENCE public.ticket_codigo_seq RESTART WITH 1;

-- -----------------------------------------------------------------------------
-- OPCION B (por si necesitas volver a borrar datos + reiniciar en un solo paso
--           la proxima vez). Descomenta si hace falta.
-- -----------------------------------------------------------------------------
-- TRUNCATE TABLE public.tickets CASCADE;
-- ALTER SEQUENCE public.ticket_codigo_seq RESTART WITH 1;

-- -----------------------------------------------------------------------------
-- Verificacion: el proximo codigo que se asignaria.
-- (nextval AVANZA la secuencia; si la corres, vuelve a reiniciar con RESTART.)
-- -----------------------------------------------------------------------------
-- SELECT next_ticket_codigo();                        -- ej. 'TCK-2026-0001'
-- ALTER SEQUENCE public.ticket_codigo_seq RESTART WITH 1;  -- deshacer el nextval
