-- =============================================================================
-- MIGRACION: tickets automaticos al finalizar inspecciones
-- Ejecutar manualmente en Supabase SQL Editor (Dashboard > SQL Editor).
-- =============================================================================

BEGIN;

-- Los tickets de inspeccion se explican por sus item(s): pregunta, resultado
-- NC, observacion y/o foto. Solo las SOLICITUDES requieren descripcion libre.
ALTER TABLE public.tickets
  ALTER COLUMN motivo DROP NOT NULL;

ALTER TABLE public.tickets
  DROP CONSTRAINT IF EXISTS chk_solicitud_motivo;

ALTER TABLE public.tickets
  ADD CONSTRAINT chk_solicitud_motivo
  CHECK (
    origen = 'INSPECCION'
    OR NULLIF(BTRIM(motivo), '') IS NOT NULL
  ) NOT VALID;

-- El ticket es un expediente vivo del hallazgo: se conserva cuando el NC se
-- detecta otra vez y se registra la reapertura o la evidencia nueva.
ALTER TABLE public.ticket_historial_tomas
  DROP CONSTRAINT IF EXISTS ticket_historial_tomas_accion_check;

ALTER TABLE public.ticket_historial_tomas
  ADD CONSTRAINT ticket_historial_tomas_accion_check
  CHECK (accion IN (
    'TOMADO', 'SOLTADO', 'FINALIZADO', 'REVISADO_APROBADO',
    'REVISADO_RECHAZADO', 'REABIERTO', 'NUEVA_OCURRENCIA'
  ));

-- Una respuesta de inspección debe quedar una sola vez en el expediente.
CREATE UNIQUE INDEX IF NOT EXISTS uq_ticket_items_respuesta_ocurrencia
  ON public.ticket_items(referencia_id)
  WHERE origen_item = 'RESPUESTA_INSPECCION'
    AND referencia_id IS NOT NULL;

-- Marca que una inspeccion finalizada ya proceso sus NC y fotos con
-- observacion. Los registros historicos se marcan para que la automatizacion
-- aplique solo a finalizaciones posteriores a esta migracion.
ALTER TABLE public.actividades
  ADD COLUMN IF NOT EXISTS tickets_generados_at TIMESTAMPTZ;

COMMENT ON COLUMN public.actividades.tickets_generados_at IS
  'Momento en que se procesaron los tickets automaticos de NC y fotos con observacion.';

UPDATE public.actividades
SET tickets_generados_at = now()
WHERE tickets_generados_at IS NULL
  AND estado_final = 'En Seguimiento';

-- La migracion antigua del modulo tenia una unicidad por inspeccion. El flujo
-- actual requiere varios tickets por informe (uno por hallazgo y uno de fotos).
DROP INDEX IF EXISTS public.uq_tickets_inspeccion_automatico;

-- Solo existe un ticket activo de fotos libres con observacion por inspeccion.
CREATE UNIQUE INDEX IF NOT EXISTS uq_tickets_fotos_observacion_automatico
  ON public.tickets(inspeccion_id)
  WHERE origen = 'INSPECCION'
    AND inspeccion_id IS NOT NULL
    AND eliminado = false
    AND estado <> 'CERRADO'
    AND campos_extra_json ->> 'automatico_tipo' = 'FOTOS_OBSERVACION';

COMMIT;