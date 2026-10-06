-- =============================================================================
-- REINICIAR el correlativo del modulo Tickets desde TCK-AAAA-0001
--
-- El codigo de ticket (TCK-AAAA-NNNN) lo asigna el trigger `trg_ticket_codigo`
-- tomando el siguiente valor de la secuencia `ticket_codigo_seq`.
-- Este script reinicia esa secuencia para que el proximo ticket sea 0001.
--
-- IMPORTANTE:
-- - Si todavia existen tickets con codigo_ticket asignado, reiniciar la
--   secuencia por si sola puede provocar codigos repetidos.
-- - Desde que se agrego hallazgo unico, ahora tambien existen relaciones a
--   `nc_hallazgos`, `nc_hallazgo_ocurrencias` y opcionalmente
--   `ticket_item_subsanaciones`.
--
-- Usa UNA de estas opciones:
--   OPCION A: reinicio protegido (solo si tickets esta vacia)
--   OPCION B: borrado total + reinicio real desde 1
-- =============================================================================

-- -----------------------------------------------------------------------------
-- OPCION A (RECOMENDADA): reinicia solo si la tabla tickets esta vacia.
-- Si no esta vacia, lanza error y NO toca la secuencia.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
	IF EXISTS (SELECT 1 FROM public.tickets LIMIT 1) THEN
		RAISE EXCEPTION
			'No se puede reiniciar ticket_codigo_seq: la tabla public.tickets no esta vacia.';
	END IF;

	ALTER SEQUENCE public.ticket_codigo_seq RESTART WITH 1;
END $$;

-- -----------------------------------------------------------------------------
-- OPCION B (REINICIO REAL DESDE 1): borrar TODO el modulo tickets y reiniciar.
-- Descomenta este bloque SOLO si quieres partir limpio.
-- -----------------------------------------------------------------------------
-- TRUNCATE TABLE public.tickets CASCADE;
-- -- Si quieres partir limpio tambien en el modelo de hallazgos, descomenta:
-- -- TRUNCATE TABLE public.nc_hallazgo_ocurrencias CASCADE;
-- -- TRUNCATE TABLE public.nc_hallazgos CASCADE;
-- -- TRUNCATE TABLE public.ticket_item_subsanaciones CASCADE;
-- ALTER SEQUENCE public.ticket_codigo_seq RESTART WITH 1;

-- -----------------------------------------------------------------------------
-- Verificacion: el proximo codigo que se asignaria.
-- (nextval AVANZA la secuencia; si la corres, vuelve a reiniciar con RESTART.)
-- -----------------------------------------------------------------------------
-- SELECT next_ticket_codigo();                        -- ej. 'TCK-2026-0001'
-- ALTER SEQUENCE public.ticket_codigo_seq RESTART WITH 1;  -- deshacer el nextval
