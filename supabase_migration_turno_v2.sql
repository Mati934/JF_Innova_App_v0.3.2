-- =============================================================================
-- TURNO v2: salida estimada ajustable  ·  2026-11-25
-- La salida estimada deja de ser fija (ingreso + 13): el auditor puede acortarla
-- (ej. turno extra mas corto), nunca mas de 14 dias ni antes del ingreso.
-- Reemplaza "Ingreso extraordinario" (la columna queda, siempre false).
-- Ejecutar MANUALMENTE. Reejecutable: si (DROP IF EXISTS + ADD).
-- Pasos: 0 (solo lectura) -> 1 (BEGIN..COMMIT) -> 2 (verificar).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. SOLO LECTURA: estado actual
-- -----------------------------------------------------------------------------
-- Esperado (antes): CHECK ((egreso_estimado = (ingreso_fecha + 13)))
SELECT conname, pg_get_constraintdef(oid) AS def
FROM pg_constraint
WHERE conrelid = 'public.turnos'::regclass
  AND conname = 'turnos_egreso_estimado_chk';

-- Esperado: 0 (ninguna fila incumple la regla nueva).
SELECT count(*) AS fuera_de_rango
FROM public.turnos
WHERE egreso_estimado NOT BETWEEN ingreso_fecha AND ingreso_fecha + 13;

-- -----------------------------------------------------------------------------
-- 1. CAMBIO
-- -----------------------------------------------------------------------------
BEGIN;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.turnos
    WHERE egreso_estimado NOT BETWEEN ingreso_fecha AND ingreso_fecha + 13
  ) THEN
    RAISE EXCEPTION 'TURNO_V2: hay turnos con salida estimada fuera de rango';
  END IF;
END;
$$;

ALTER TABLE public.turnos
  DROP CONSTRAINT IF EXISTS turnos_egreso_estimado_chk;
ALTER TABLE public.turnos
  ADD CONSTRAINT turnos_egreso_estimado_chk
  CHECK (egreso_estimado BETWEEN ingreso_fecha AND ingreso_fecha + 13);

COMMENT ON COLUMN public.turnos.egreso_estimado IS
  'Salida planificada. Por defecto ingreso + 13 (14 dias); el auditor puede acortarla.';
COMMENT ON COLUMN public.turnos.extraordinario IS
  'Sin uso desde 2026-11-25 (siempre false). Un turno extra es un turno mas corto.';

COMMIT;

-- -----------------------------------------------------------------------------
-- 2. SOLO LECTURA: verificar
-- -----------------------------------------------------------------------------
-- Esperado: CHECK (((egreso_estimado >= ingreso_fecha) AND (egreso_estimado <= (ingreso_fecha + 13))))
SELECT conname, pg_get_constraintdef(oid) AS def
FROM pg_constraint
WHERE conrelid = 'public.turnos'::regclass
  AND conname = 'turnos_egreso_estimado_chk';
