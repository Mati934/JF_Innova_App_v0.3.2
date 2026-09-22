-- supabase_migration_email_metrics_v1.sql
-- Metricas durables de correo para dashboard.
-- Ejecutar manualmente en Supabase SQL Editor.
-- Idempotente.

BEGIN;

ALTER TABLE public.correo_eventos
  ADD COLUMN IF NOT EXISTS modulo_key text,
  ADD COLUMN IF NOT EXISTS lista_nombre text,
  ADD COLUMN IF NOT EXISTS template_nombre text,
  ADD COLUMN IF NOT EXISTS regla_envio_nombre text,
  ADD COLUMN IF NOT EXISTS destinatarios_json jsonb,
  ADD COLUMN IF NOT EXISTS destinatarios_count integer,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_correo_eventos_metricas_fecha
  ON public.correo_eventos(event_timestamp, modulo_key, usuario_id);

CREATE INDEX IF NOT EXISTS idx_correo_eventos_metricas_empresa
  ON public.correo_eventos(empresa_id, event_timestamp);

COMMIT;
