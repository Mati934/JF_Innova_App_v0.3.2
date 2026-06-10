-- =============================================================================
-- REINICIAR el correlativo del módulo AST desde AST-AAAA-0001
--
-- El número de AST (AST-AAAA-NNNN) lo asigna el trigger `trg_ast_correlativo`
-- tomando el siguiente valor de la secuencia `ast_correlativo_seq`.
-- Este script reinicia esa secuencia para que el próximo AST sea 0001.
--
-- ⚠️ ADVERTENCIA: si quedan informes con correlativos ya asignados
-- (AST-2026-0001, ...), reiniciar la secuencia hará que los próximos AST
-- repitan esos números. Reinicia SOLO si vas a partir de cero (datos de prueba).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- OPCIÓN A — Solo reiniciar la secuencia (NO borra datos)
--   Úsala si la tabla ast_informes ya NO tiene correlativos asignados
--   (o asumes el riesgo de duplicados).
-- -----------------------------------------------------------------------------
ALTER SEQUENCE ast_correlativo_seq RESTART WITH 1;

-- -----------------------------------------------------------------------------
-- OPCIÓN B — Borrar los AST de prueba y reiniciar (recomendado para empezar
--            limpio). Descomenta este bloque y comenta la OPCIÓN A de arriba.
--
--   Elimina hallazgos + informes AST y deja la secuencia en 1, de modo que
--   el primer AST nuevo sea AST-AAAA-0001 sin riesgo de colisión.
-- -----------------------------------------------------------------------------
-- TRUNCATE TABLE ast_hallazgos CASCADE;
-- TRUNCATE TABLE ast_informes  CASCADE;
-- ALTER SEQUENCE ast_correlativo_seq RESTART WITH 1;

-- -----------------------------------------------------------------------------
-- Verificación: el próximo correlativo que se asignaría.
-- (nextval AVANZA la secuencia; si la corres, vuelve a reiniciar con RESTART.)
-- -----------------------------------------------------------------------------
-- SELECT next_ast_correlativo();          -- ej. 'AST-2026-0001'
-- ALTER SEQUENCE ast_correlativo_seq RESTART WITH 1;  -- deshacer el nextval
