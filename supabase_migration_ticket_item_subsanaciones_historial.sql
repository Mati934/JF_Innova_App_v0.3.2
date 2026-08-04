-- =============================================================================
-- MIGRACION: Historial de subsanaciones por item de ticket
-- Fecha: 2026-08-03
-- Objetivo:
--   - Registrar cada acción de subsanar / deshacer en ticket_items
--   - Habilitar trazabilidad histórica para dashboard (ultima subsanacion,
--     tiempos de ciclo, re-trabajos)
-- =============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.ticket_item_subsanaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  ticket_item_id UUID NOT NULL REFERENCES public.ticket_items(id) ON DELETE CASCADE,
  hallazgo_id UUID NULL REFERENCES public.nc_hallazgos(id),

  accion TEXT NOT NULL CHECK (accion IN ('SUBSANADO', 'DESHECHO')),
  usuario_id UUID NOT NULL,

  foto_subsanacion_url TEXT,
  comentario TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ticket_item_subsanaciones_item_fecha
  ON public.ticket_item_subsanaciones(ticket_item_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ticket_item_subsanaciones_ticket_fecha
  ON public.ticket_item_subsanaciones(ticket_id, created_at DESC);

ALTER TABLE public.ticket_item_subsanaciones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ticket_item_subsanaciones_select ON public.ticket_item_subsanaciones;
CREATE POLICY ticket_item_subsanaciones_select
ON public.ticket_item_subsanaciones FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.tickets t
    WHERE t.id = ticket_id
      AND (public.is_admin_user() OR public.user_has_empresa(t.empresa_id))
  )
);

DROP POLICY IF EXISTS ticket_item_subsanaciones_insert ON public.ticket_item_subsanaciones;
CREATE POLICY ticket_item_subsanaciones_insert
ON public.ticket_item_subsanaciones FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.tickets t
    WHERE t.id = ticket_id
      AND (public.is_admin_user() OR public.user_has_empresa(t.empresa_id))
  )
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'ticket_item_subsanaciones'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.ticket_item_subsanaciones;
  END IF;
END $$;

COMMIT;
