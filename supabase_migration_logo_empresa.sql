-- =============================================================================
-- MIGRACIÓN: Logo personalizado por empresa (para PDFs)
-- Ejecutar en Supabase SQL Editor
-- =============================================================================

-- 1. Agregar columna logo_url a empresas (URL pública del logo en Storage)
ALTER TABLE empresas ADD COLUMN IF NOT EXISTS logo_url TEXT;

-- 2. (Opcional) Crear bucket público para logos si no existe.
--    Hazlo manualmente desde el panel de Supabase si prefieres:
--    Storage → New bucket → name: "empresa-logos" → Public bucket: ON
--
-- INSERT INTO storage.buckets (id, name, public)
-- VALUES ('empresa-logos', 'empresa-logos', true)
-- ON CONFLICT (id) DO NOTHING;

-- 3. Ejemplos de cómo setear los logos (reemplaza los UUID y URL):
--
-- UPDATE empresas
-- SET logo_url = 'https://<TU-PROYECTO>.supabase.co/storage/v1/object/public/empresa-logos/aquachile.png'
-- WHERE nombre = 'Aquachile';
--
-- UPDATE empresas
-- SET logo_url = 'https://<TU-PROYECTO>.supabase.co/storage/v1/object/public/empresa-logos/jfinnova.png'
-- WHERE nombre = 'JF Innova';

-- 4. Verificación
-- SELECT id, nombre, logo_url FROM empresas;
