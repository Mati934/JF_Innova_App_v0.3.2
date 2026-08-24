-- =============================================================================
-- VERIFICACION INTEGRAL AST CORRELATIVO (SOLO LECTURA)
--
-- Objetivo:
-- - Corroborar que todo el esquema/flujo de correlativo AST quedo en orden
--   despues de migracion + fix de duplicados.
--
-- Alcance:
-- - NO modifica datos.
-- - Ejecutar completo en SQL Editor de Supabase.
--
-- Criterio de "todo OK":
-- 1) Estructura: tabla ast_correlativo_counters existe.
-- 2) Funciones: existen assign_ast_correlativo, next_ast_correlativo,
--    next_ast_correlativo_gapless.
-- 3) Trigger: trg_ast_correlativo habilitado sobre ast_informes.
-- 4) Duplicados: 0 filas en consulta de duplicados.
-- 5) Formato invalido: 0 filas en consulta de formato.
-- 6) Correlativo en estado En Seguimiento vacio: 0 filas.
-- 7) Consistencia counter vs max usado por anio: 0 filas en desalineacion.
--
-- Nota:
-- - Los huecos historicos pueden existir por historia previa con secuencias.
--   Lo importante es que ya no se sigan generando por rollback/reintentos.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0) Contexto general
-- -----------------------------------------------------------------------------
SELECT
  now() AS executed_at,
  current_database() AS db_name,
  current_user AS db_user,
  EXTRACT(YEAR FROM now())::int AS anio_actual;

-- -----------------------------------------------------------------------------
-- 1) Existencia de objetos clave
-- -----------------------------------------------------------------------------
SELECT
  to_regclass('public.ast_informes') AS ast_informes,
  to_regclass('public.ast_correlativo_counters') AS ast_correlativo_counters,
  to_regclass('public.ast_correlativo_seq') AS legacy_sequence;

-- -----------------------------------------------------------------------------
-- 2) Trigger AST correlativo (debe existir y estar enabled = O)
-- -----------------------------------------------------------------------------
SELECT
  t.tgname AS trigger_name,
  t.tgenabled AS enabled,
  c.relname AS table_name,
  p.proname AS function_name,
  pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_proc p  ON p.oid = t.tgfoid
WHERE NOT t.tgisinternal
  AND c.relname = 'ast_informes'
  AND t.tgname = 'trg_ast_correlativo';

-- -----------------------------------------------------------------------------
-- 3) Funciones requeridas (deben existir las 3)
-- -----------------------------------------------------------------------------
SELECT
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS args,
  pg_get_function_result(p.oid) AS returns
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'assign_ast_correlativo',
    'next_ast_correlativo',
    'next_ast_correlativo_gapless'
  )
ORDER BY p.proname, args;

-- -----------------------------------------------------------------------------
-- 4) Integridad de correlativos: duplicados (debe devolver 0 filas)
-- -----------------------------------------------------------------------------
SELECT
  correlativo,
  COUNT(*) AS repeticiones
FROM public.ast_informes
WHERE correlativo IS NOT NULL
  AND correlativo <> ''
GROUP BY correlativo
HAVING COUNT(*) > 1
ORDER BY repeticiones DESC, correlativo;

-- -----------------------------------------------------------------------------
-- 5) Formato de correlativo invalido (debe devolver 0 filas)
--    Formato esperado: AST-AAAA-NNNN(+) 
-- -----------------------------------------------------------------------------
SELECT
  id,
  correlativo,
  estado_final,
  created_at
FROM public.ast_informes
WHERE correlativo IS NOT NULL
  AND correlativo <> ''
  AND correlativo !~ '^AST-[0-9]{4}-[0-9]{4,}$'
ORDER BY created_at DESC, id;

-- -----------------------------------------------------------------------------
-- 6) En Seguimiento sin correlativo (debe devolver 0 filas)
-- -----------------------------------------------------------------------------
SELECT
  id,
  estado_final,
  correlativo,
  fecha_realizacion,
  created_at
FROM public.ast_informes
WHERE estado_final = 'En Seguimiento'
  AND COALESCE(correlativo, '') = ''
ORDER BY created_at DESC, id;

-- -----------------------------------------------------------------------------
-- 7) Resumen por anio: min/max/usados/huecos
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- 8) Huecos detallados del anio actual (informativo)
-- -----------------------------------------------------------------------------
WITH parsed AS (
  SELECT
    ((regexp_match(correlativo, '^AST-([0-9]{4})-([0-9]+)$'))[1])::int AS anio,
    ((regexp_match(correlativo, '^AST-([0-9]{4})-([0-9]+)$'))[2])::int AS numero
  FROM public.ast_informes
  WHERE correlativo ~ '^AST-[0-9]{4}-[0-9]+$'
),
actual AS (
  SELECT numero
  FROM parsed
  WHERE anio = EXTRACT(YEAR FROM now())::int
),
bounds AS (
  SELECT MIN(numero) AS min_num, MAX(numero) AS max_num
  FROM actual
),
series AS (
  SELECT generate_series((SELECT min_num FROM bounds), (SELECT max_num FROM bounds)) AS numero
)
SELECT s.numero AS numero_faltante
FROM series s
LEFT JOIN actual a ON a.numero = s.numero
WHERE a.numero IS NULL
ORDER BY s.numero;

-- -----------------------------------------------------------------------------
-- 9) Consistencia counters vs max usado por anio
--    Debe devolver 0 filas en estado != OK
-- -----------------------------------------------------------------------------
WITH max_por_anio AS (
  SELECT
    ((regexp_match(correlativo, '^AST-([0-9]{4})-([0-9]+)$'))[1])::int AS anio,
    MAX(((regexp_match(correlativo, '^AST-([0-9]{4})-([0-9]+)$'))[2])::bigint) AS max_usado
  FROM public.ast_informes
  WHERE correlativo ~ '^AST-[0-9]{4}-[0-9]+$'
  GROUP BY 1
)
SELECT
  m.anio,
  m.max_usado,
  c.ultimo_numero,
  CASE
    WHEN c.anio IS NULL THEN 'FALTA_COUNTER'
    WHEN c.ultimo_numero < m.max_usado THEN 'COUNTER_ATRASADO'
    ELSE 'OK'
  END AS estado
FROM max_por_anio m
LEFT JOIN public.ast_correlativo_counters c
  ON c.anio = m.anio
WHERE c.anio IS NULL
   OR c.ultimo_numero < m.max_usado
ORDER BY m.anio DESC;

-- -----------------------------------------------------------------------------
-- 10) Snapshot actual de counters (informativo)
-- -----------------------------------------------------------------------------
SELECT anio, ultimo_numero, updated_at
FROM public.ast_correlativo_counters
ORDER BY anio DESC;

-- -----------------------------------------------------------------------------
-- 11) Conteo rapido de AST por estado (informativo)
-- -----------------------------------------------------------------------------
SELECT estado_final, COUNT(*) AS cantidad
FROM public.ast_informes
GROUP BY estado_final
ORDER BY estado_final;
