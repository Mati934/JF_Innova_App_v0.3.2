-- =============================================================================
-- REGISTRO DE INMERSIONES v2: REGISTRO SIN INSPECCION  ·  2026-11-18
-- Permite registros de inmersiones sin inspeccion de buceo vinculada
-- (actividad_id NULL). El auditor puede vincularlo despues, mientras es
-- borrador. Requiere v1 (supabase_migration_registro_inmersiones_v1.sql).
-- Sin cambios en triggers, RLS ni vista:
--   - el indice unico parcial (actividad_id) admite varios NULL;
--   - el trigger de numero solo mira la inspeccion si existe;
--   - la cascada de baja filtra por actividad_id = inspeccion.
-- Reejecutable. No borra datos.
-- Pasos: 0 (solo lectura) -> 1 (BEGIN..COMMIT) -> 2 (verificar).
-- =============================================================================

-- 0. SOLO LECTURA. Esperado antes: is_nullable = 'NO'.
SELECT column_name, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'registros_inmersion'
  AND column_name = 'actividad_id';

-- 1. CAMBIO
BEGIN;
ALTER TABLE public.registros_inmersion ALTER COLUMN actividad_id DROP NOT NULL;
COMMENT ON COLUMN public.registros_inmersion.actividad_id IS
  'Inspeccion de buceo vinculada. NULL = registro sin inspeccion.';
COMMIT;

-- 2. VERIFICAR. Esperado: is_nullable = 'YES'.
SELECT column_name, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'registros_inmersion'
  AND column_name = 'actividad_id';
