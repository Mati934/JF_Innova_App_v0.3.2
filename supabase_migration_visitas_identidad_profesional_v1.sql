-- =============================================================================
-- MIGRACION: identidad manual del profesional en registros de visita
--
-- EJECUCION MANUAL OBLIGATORIA
-- Ejecutar primero el CHECK y luego esta migracion manualmente en Supabase
-- SQL Editor. Los archivos .sql del repositorio no se aplican solos.
-- =============================================================================

-- CHECK DE SOLO LECTURA: confirmar si las columnas ya existen.
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'visitas_tecnicas'
  AND column_name IN ('profesional', 'fono_profesional', 'correo_profesional')
ORDER BY column_name;

BEGIN;

ALTER TABLE public.visitas_tecnicas
  ADD COLUMN IF NOT EXISTS profesional TEXT,
  ADD COLUMN IF NOT EXISTS fono_profesional TEXT,
  ADD COLUMN IF NOT EXISTS correo_profesional TEXT;

COMMENT ON COLUMN public.visitas_tecnicas.profesional IS
  'Nombre de la persona que realizo el registro; puede diferir del usuario de la cuenta.';
COMMENT ON COLUMN public.visitas_tecnicas.fono_profesional IS
  'Telefono informado por la persona que realizo el registro.';
COMMENT ON COLUMN public.visitas_tecnicas.correo_profesional IS
  'Correo informado por la persona que realizo el registro.';

COMMIT;

-- VERIFICACION POSTERIOR DE SOLO LECTURA.
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'visitas_tecnicas'
  AND column_name IN ('profesional', 'fono_profesional', 'correo_profesional')
ORDER BY column_name;