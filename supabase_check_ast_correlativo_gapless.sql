-- =============================================================================
-- CHECK (SOLO LECTURA): salud del correlativo AST
--
-- Objetivo:
-- 1) Ver huecos reales por anio.
-- 2) Detectar correlativos duplicados.
-- 3) Ver estado de trigger/funciones/counter table.
--
-- Este archivo NO modifica datos.
-- =============================================================================

-- 1) Huecos por anio (si hay filas AST-AAAA-NNNN)
WITH parsed AS (
  SELECT
    ((regexp_match(correlativo, '^AST-([0-9]{4})-([0-9]+)$'))[1])::int AS anio,
    ((regexp_match(correlativo, '^AST-([0-9]{4})-([0-9]+)$'))[2])::int AS numero
  FROM public.ast_informes
  WHERE correlativo ~ '^AST-[0-9]{4}-[0-9]+$'
),
bounds AS (
  SELECT anio, MIN(numero) AS min_num, MAX(numero) AS max_num
  FROM parsed
  GROUP BY anio
),
series AS (
  SELECT b.anio, generate_series(b.min_num, b.max_num) AS numero
  FROM bounds b
)
SELECT s.anio, s.numero AS numero_faltante
FROM series s
LEFT JOIN parsed p
  ON p.anio = s.anio
 AND p.numero = s.numero
WHERE p.numero IS NULL
ORDER BY s.anio DESC, s.numero;

-- 2) Resumen de huecos por anio
WITH parsed AS (
  SELECT
    ((regexp_match(correlativo, '^AST-([0-9]{4})-([0-9]+)$'))[1])::int AS anio,
    ((regexp_match(correlativo, '^AST-([0-9]{4})-([0-9]+)$'))[2])::int AS numero
  FROM public.ast_informes
  WHERE correlativo ~ '^AST-[0-9]{4}-[0-9]+$'
),
bounds AS (
  SELECT anio, MIN(numero) AS min_num, MAX(numero) AS max_num, COUNT(*) AS usados
  FROM parsed
  GROUP BY anio
)
SELECT
  b.anio,
  b.min_num,
  b.max_num,
  b.usados,
  (b.max_num - b.min_num + 1 - b.usados) AS huecos
FROM bounds b
ORDER BY b.anio DESC;

-- 3) Correlativos duplicados (debe devolver 0 filas)
SELECT correlativo, COUNT(*) AS repeticiones
FROM public.ast_informes
WHERE correlativo IS NOT NULL
  AND correlativo <> ''
GROUP BY correlativo
HAVING COUNT(*) > 1
ORDER BY repeticiones DESC, correlativo;

-- 4) Estado trigger AST correlativo
SELECT
  t.tgname AS trigger_name,
  t.tgenabled AS enabled,
  c.relname AS table_name,
  p.proname AS function_name
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_proc  p ON p.oid = t.tgfoid
WHERE NOT t.tgisinternal
  AND c.relname = 'ast_informes'
  AND t.tgname = 'trg_ast_correlativo';

-- 5) Fuente de funciones relacionadas
SELECT n.nspname AS schema_name, p.proname AS function_name
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('next_ast_correlativo', 'next_ast_correlativo_gapless', 'assign_ast_correlativo')
ORDER BY p.proname;

-- 6) Estado de la tabla de counters (si existe)
SELECT to_regclass('public.ast_correlativo_counters') AS counter_table;

-- 7) Estado de secuencia historica (si existe)
SELECT to_regclass('public.ast_correlativo_seq') AS legacy_sequence;

-- 8) Contador guardado vs. correlativos realmente usados (detecta "quemados")
-- Si ultimo_numero > usados, hay incrementos del contador que no quedaron
-- en ninguna fila final (numeros quemados por reintentos/insert fallido fuera
-- de la transaccion del trigger, o por llamadas directas a la funcion).
WITH parsed AS (
  SELECT
    ((regexp_match(correlativo, '^AST-([0-9]{4})-([0-9]+)$'))[1])::int AS anio,
    ((regexp_match(correlativo, '^AST-([0-9]{4})-([0-9]+)$'))[2])::bigint AS numero
  FROM public.ast_informes
  WHERE correlativo ~ '^AST-[0-9]{4}-[0-9]+$'
),
usados AS (
  SELECT anio, COUNT(*) AS usados, MAX(numero) AS max_usado
  FROM parsed
  GROUP BY anio
)
SELECT
  c.anio,
  c.ultimo_numero AS contador_guardado,
  u.usados,
  u.max_usado,
  (c.ultimo_numero - u.max_usado) AS numeros_quemados_no_reflejados_en_max,
  (c.ultimo_numero - u.usados) AS numeros_quemados_total
FROM public.ast_correlativo_counters c
LEFT JOIN usados u ON u.anio = c.anio
ORDER BY c.anio DESC;

-- 9) Codigo fuente real de las funciones (por si alguien las edito despues
-- de aplicar la migracion original)
SELECT p.proname AS function_name, pg_get_functiondef(p.oid) AS definicion
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('next_ast_correlativo', 'next_ast_correlativo_gapless', 'assign_ast_correlativo')
ORDER BY p.proname;
