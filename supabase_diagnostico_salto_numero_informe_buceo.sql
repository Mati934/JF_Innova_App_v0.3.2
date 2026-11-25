-- ============================================================================
-- FIX: renumerar informes de buceo 477-483 → 398-404 y alinear secuencia
-- Proyecto: JF Innova App  |  Ejecutar en Supabase SQL Editor
-- Fecha: 2026-07-22
--
-- Situacion confirmada en produccion:
--   El ultimo correlativo continuo es 397 (2026-07-20).
--   Los siguientes 7 informes saltaron a 477..483 por secuencia adelantada.
--   No existe ninguna fila con numero_informe entre 398 y 476.
--
-- Resultado esperado tras ejecutar este script:
--   477 → 398  |  478 → 399  |  479 → 400  |  480 → 401
--   481 → 402  |  482 → 403  |  483 → 404
--   seq_inf_buceo queda en 404  →  el proximo informe sera 405
-- ============================================================================

-- =========================================================
-- PASO 0: DRY-RUN — verificar estado antes de tocar nada
-- =========================================================
SELECT
  id,
  numero_informe              AS num_actual,
  397 + ROW_NUMBER() OVER (ORDER BY numero_informe ASC) AS num_nuevo,
  created_at
FROM public.actividades
WHERE tipo_actividad = 'INSPECCION_BUCEO'
  AND numero_informe >= 477
ORDER BY numero_informe;

-- Confirmar que 398..476 estan vacios (debe devolver 0 filas)
SELECT COUNT(*) AS fila_colisionantes
FROM public.actividades
WHERE numero_informe BETWEEN 398 AND 476;

-- =========================================================
-- PASO 1: Renumeracion en transaccion segura
-- =========================================================
BEGIN;

-- Pausar triggers para que no interfieran con el UPDATE interno
ALTER TABLE public.actividades DISABLE TRIGGER trg_asignar_numero_informe;
ALTER TABLE public.actividades DISABLE TRIGGER trg_resetear_secuencia;

-- Asignar numeros intermedios negativos primero para evitar conflictos
-- de constraint UNIQUE durante el UPDATE si existiese
UPDATE public.actividades
SET numero_informe = -numero_informe
WHERE tipo_actividad = 'INSPECCION_BUCEO'
  AND numero_informe >= 477;

-- Asignar los numeros definitivos 398..404 en orden ascendente
WITH ranked AS (
  SELECT
    id,
    397 + ROW_NUMBER() OVER (ORDER BY -numero_informe ASC) AS new_num
  FROM public.actividades
  WHERE tipo_actividad = 'INSPECCION_BUCEO'
    AND numero_informe <= -477
)
UPDATE public.actividades a
SET numero_informe = r.new_num
FROM ranked r
WHERE a.id = r.id;

-- Re-habilitar triggers
ALTER TABLE public.actividades ENABLE TRIGGER trg_asignar_numero_informe;
ALTER TABLE public.actividades ENABLE TRIGGER trg_resetear_secuencia;

COMMIT;

-- =========================================================
-- PASO 2: Realinear la secuencia
-- =========================================================
DO $$
DECLARE
  max_buceo INTEGER;
BEGIN
  SELECT COALESCE(MAX(numero_informe), 0)
  INTO max_buceo
  FROM public.actividades
  WHERE tipo_actividad = 'INSPECCION_BUCEO';

  PERFORM setval('public.seq_inf_buceo', max_buceo, true);
  RAISE NOTICE 'seq_inf_buceo alineada a %. Proximo informe: %', max_buceo, max_buceo + 1;
END $$;

-- =========================================================
-- PASO 3: Verificacion final (debe mostrar continuidad 395..404)
-- =========================================================
SELECT
  id,
  numero_informe,
  estado_final,
  fecha_realizacion,
  created_at
FROM public.actividades
WHERE tipo_actividad = 'INSPECCION_BUCEO'
  AND numero_informe >= 395
ORDER BY numero_informe;

SELECT
  (SELECT MAX(numero_informe) FROM public.actividades WHERE tipo_actividad = 'INSPECCION_BUCEO') AS max_en_tabla,
  (SELECT last_value FROM public.seq_inf_buceo) AS seq_last_value;

-- =========================================================
-- PASO 4 (IMPORTANTE): investigar causa raiz
-- =========================================================
-- Ejecuta esto para encontrar por que la secuencia se adelanto.

-- 4a) Ver estado de la secuencia (si last_value >> max en tabla, la causa esta aqui)
SELECT last_value, is_called FROM public.seq_inf_buceo;

-- 4b) Ver si la columna tiene DEFAULT que consuma la secuencia en inserts
SELECT column_name, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'actividades'
  AND column_name  = 'numero_informe';

-- 4c) Ver triggers activos en actividades
SELECT
  t.tgname        AS trigger_name,
  p.proname       AS function_name,
  t.tgenabled     AS enabled
FROM pg_trigger t
JOIN pg_proc p   ON p.oid = t.tgfoid
JOIN pg_class c  ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'actividades'
  AND NOT t.tgisinternal
ORDER BY t.tgname;