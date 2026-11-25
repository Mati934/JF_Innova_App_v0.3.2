-- =============================================================================
-- INSPECCION: QUIEN REALIZA Y QUIEN RECIBE  ·  2026-10-29
-- Agrega a actividades el nombre de quien realiza y de quien recibe la
-- inspeccion. Lo usa el formato Searov (usuario general por empresa: el
-- usuario de la app no identifica al inspector). Columnas nulas, sin default:
-- no cambian filas existentes. Las firmas quedan solo en el dispositivo.
-- Reejecutable: si (ADD COLUMN IF NOT EXISTS).
-- Pasos: 0 (solo lectura) -> 1 (BEGIN..COMMIT) -> 2 (verificar).
-- =============================================================================

-- 0. SOLO LECTURA. Esperado antes de aplicar: 0 filas.
select column_name
from information_schema.columns
where table_schema = 'public' and table_name = 'actividades'
  and column_name in ('inspector_nombre', 'recibe_nombre');

-- 1. CAMBIO
BEGIN;
ALTER TABLE public.actividades ADD COLUMN IF NOT EXISTS inspector_nombre text;
ALTER TABLE public.actividades ADD COLUMN IF NOT EXISTS recibe_nombre text;
COMMENT ON COLUMN public.actividades.inspector_nombre IS
  'Nombre (y cargo) de quien realiza la inspeccion, escrito en el formulario.';
COMMENT ON COLUMN public.actividades.recibe_nombre IS
  'Nombre de quien recibe la inspeccion (jefe de centro, supervisor o rep. contratista).';
COMMIT;

-- 2. SOLO LECTURA. Esperado: 2 filas, data_type = text, is_nullable = YES.
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'actividades'
  and column_name in ('inspector_nombre', 'recibe_nombre');
