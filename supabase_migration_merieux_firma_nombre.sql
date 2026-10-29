-- =============================================================================
-- MIGRACIÓN: Merieux — nombre editable de firma
-- Contexto: la migración original (supabase_migration_merieux_module.sql) ya
-- se ejecutó en producción. El campo "Profesional" del encabezado pasó a ser
-- editable (varias personas usan la misma cuenta), y la firma ahora tiene su
-- propio campo de nombre (autocompletado desde "Profesional" pero editable
-- por separado, por si firma alguien distinto de quien completó el form).
--
-- Segura de ejecutar múltiples veces (idempotente).
-- =============================================================================

BEGIN;

ALTER TABLE public.merieux_visitas
  ADD COLUMN IF NOT EXISTS firma_nombre TEXT;

COMMIT;
