-- =============================================================================
-- FIX: corregir correlativos AST duplicados
--
-- Uso recomendado:
-- 1) Ejecutar primero la seccion A (solo lectura) y revisar filas afectadas.
-- 2) Si todo se ve bien, ejecutar seccion B (fix transaccional).
-- 3) Ejecutar seccion C (verificacion final).
--
-- Requiere que ya exista la migracion gapless aplicada:
-- - public.next_ast_correlativo_gapless(...)
-- - public.ast_correlativo_counters
-- =============================================================================

-- -----------------------------------------------------------------------------
-- A) SOLO LECTURA: ver grupos duplicados y filas concretas
-- -----------------------------------------------------------------------------

-- A1) Grupos duplicados
SELECT correlativo, COUNT(*) AS repeticiones
FROM public.ast_informes
WHERE correlativo IS NOT NULL
  AND correlativo <> ''
GROUP BY correlativo
HAVING COUNT(*) > 1
ORDER BY repeticiones DESC, correlativo;

-- A2) Filas detalladas por correlativo duplicado
WITH dupes AS (
  SELECT correlativo
  FROM public.ast_informes
  WHERE correlativo IS NOT NULL
    AND correlativo <> ''
  GROUP BY correlativo
  HAVING COUNT(*) > 1
)
SELECT
  a.id,
  a.correlativo,
  a.estado_final,
  a.fecha_realizacion,
  a.created_at,
  a.usuario_id
FROM public.ast_informes a
JOIN dupes d
  ON d.correlativo = a.correlativo
ORDER BY a.correlativo, a.created_at NULLS LAST, a.id;

-- -----------------------------------------------------------------------------
-- B) FIX TRANSACCIONAL
-- Mantiene 1 fila por correlativo original y reasigna las demas con numero nuevo
-- usando el generador gapless (sin huecos por rollback).
-- -----------------------------------------------------------------------------

BEGIN;

-- Guardia: exige que la migracion gapless exista antes de corregir datos.
DO $$
BEGIN
  IF to_regclass('public.ast_correlativo_counters') IS NULL THEN
    RAISE EXCEPTION 'FALTA ast_correlativo_counters. Ejecuta primero supabase_migration_ast_correlativo_gapless_v1.sql';
  END IF;

  PERFORM 1
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'next_ast_correlativo_gapless';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'FALTA funcion next_ast_correlativo_gapless. Ejecuta primero supabase_migration_ast_correlativo_gapless_v1.sql';
  END IF;
END;
$$;

-- Bloquea la tabla durante el fix para evitar carreras con nuevas inserciones.
LOCK TABLE public.ast_informes IN SHARE ROW EXCLUSIVE MODE;

WITH dupes AS (
  SELECT correlativo
  FROM public.ast_informes
  WHERE correlativo IS NOT NULL
    AND correlativo <> ''
  GROUP BY correlativo
  HAVING COUNT(*) > 1
),
ranked AS (
  SELECT
    a.id,
    a.correlativo,
    a.fecha_realizacion,
    ROW_NUMBER() OVER (
      PARTITION BY a.correlativo
      ORDER BY a.created_at NULLS LAST, a.id
    ) AS rn
  FROM public.ast_informes a
  JOIN dupes d
    ON d.correlativo = a.correlativo
),
updated AS (
  UPDATE public.ast_informes a
  SET correlativo = public.next_ast_correlativo_gapless(COALESCE(a.fecha_realizacion, now()))
  FROM ranked r
  WHERE a.id = r.id
    AND r.rn > 1
  RETURNING
    a.id,
    r.correlativo AS correlativo_anterior,
    a.correlativo AS correlativo_nuevo
)
SELECT *
FROM updated
ORDER BY correlativo_anterior, id;

COMMIT;

-- -----------------------------------------------------------------------------
-- C) VERIFICACION FINAL (solo lectura)
-- -----------------------------------------------------------------------------

-- C1) Debe devolver 0 filas
SELECT correlativo, COUNT(*) AS repeticiones
FROM public.ast_informes
WHERE correlativo IS NOT NULL
  AND correlativo <> ''
GROUP BY correlativo
HAVING COUNT(*) > 1
ORDER BY repeticiones DESC, correlativo;

-- C2) Resumen del anio actual despues del fix
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
WHERE b.anio = EXTRACT(YEAR FROM now())::int
ORDER BY b.anio DESC;
