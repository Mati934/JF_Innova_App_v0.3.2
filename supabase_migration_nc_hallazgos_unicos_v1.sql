-- =============================================================================
-- MIGRACION: Hallazgos unicos NC V1
-- Fecha: 2026-08-03
-- Objetivo:
--   1) Separar hallazgo real (deduplicado) de ocurrencias diarias.
--   2) Permitir un ticket activo por hallazgo (no por inspeccion).
--   3) Mantener historico para reapariciones despues de cierre.
--
-- NOTA:
-- - Revisar y ajustar nombres de estados/tipos si difieren en produccion.
-- - Ejecutar en SQL Editor de Supabase manualmente.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1) TABLA MAESTRA DE HALLAZGOS DEDUPLICADOS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.nc_hallazgos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id),
  tipo_actividad TEXT NOT NULL,
  item_id UUID NOT NULL REFERENCES public.formulario_items(id),

  -- EMBARCACION: clave principal v1. Si falta, usar CENTRO_FALLBACK.
  dedupe_mode TEXT NOT NULL CHECK (dedupe_mode IN ('EMBARCACION', 'CENTRO_FALLBACK')),
  embarcacion_id UUID NULL REFERENCES public.embarcaciones(id),
  centro_id UUID NULL REFERENCES public.centros(id),

  estado_hallazgo TEXT NOT NULL DEFAULT 'ABIERTO'
    CHECK (estado_hallazgo IN ('ABIERTO', 'EN_SEGUIMIENTO', 'CERRADO')),

  criticidad_inicial TEXT,
  criticidad_actual TEXT,

  fecha_primera_deteccion TIMESTAMPTZ NOT NULL DEFAULT now(),
  fecha_ultima_deteccion TIMESTAMPTZ NOT NULL DEFAULT now(),

  informe_inicial_id UUID REFERENCES public.actividades(id),
  informe_ultima_ocurrencia_id UUID REFERENCES public.actividades(id),

  creado_por UUID REFERENCES public.usuarios(id),

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_nc_hallazgos_empresa_estado
  ON public.nc_hallazgos(empresa_id, estado_hallazgo);

CREATE INDEX IF NOT EXISTS idx_nc_hallazgos_item
  ON public.nc_hallazgos(item_id);

CREATE INDEX IF NOT EXISTS idx_nc_hallazgos_contexto
  ON public.nc_hallazgos(empresa_id, tipo_actividad, dedupe_mode, embarcacion_id, centro_id);

-- Unico parcial para evitar dos hallazgos activos de la misma clave dura.
-- Se considera "activo" ABIERTO y EN_SEGUIMIENTO.
CREATE UNIQUE INDEX IF NOT EXISTS uq_nc_hallazgos_activo_dedupe
  ON public.nc_hallazgos (
    empresa_id,
    tipo_actividad,
    item_id,
    dedupe_mode,
    COALESCE(embarcacion_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(centro_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  WHERE estado_hallazgo IN ('ABIERTO', 'EN_SEGUIMIENTO');

-- Trigger updated_at
CREATE OR REPLACE FUNCTION public.touch_nc_hallazgos_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_touch_nc_hallazgos_updated_at ON public.nc_hallazgos;
CREATE TRIGGER trg_touch_nc_hallazgos_updated_at
BEFORE UPDATE ON public.nc_hallazgos
FOR EACH ROW EXECUTE FUNCTION public.touch_nc_hallazgos_updated_at();

-- -----------------------------------------------------------------------------
-- 2) TABLA DE OCURRENCIAS (TRAZABILIDAD DIARIA)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.nc_hallazgo_ocurrencias (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hallazgo_id UUID NOT NULL REFERENCES public.nc_hallazgos(id) ON DELETE CASCADE,

  inspeccion_respuesta_id UUID NOT NULL UNIQUE REFERENCES public.inspeccion_respuestas(id) ON DELETE CASCADE,
  informe_id UUID NOT NULL REFERENCES public.actividades(id) ON DELETE CASCADE,

  empresa_id UUID NOT NULL REFERENCES public.empresas(id),
  contratista_id UUID NULL REFERENCES public.contratistas(id),
  centro_id UUID NULL REFERENCES public.centros(id),
  embarcacion_id UUID NULL REFERENCES public.embarcaciones(id),

  fecha_ocurrencia TIMESTAMPTZ NOT NULL DEFAULT now(),
  observacion TEXT,
  criticidad_registrada TEXT,
  evidencia_foto_count INTEGER NOT NULL DEFAULT 0,

  creado_por UUID REFERENCES public.usuarios(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_nc_ocurrencias_hallazgo
  ON public.nc_hallazgo_ocurrencias(hallazgo_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_nc_ocurrencias_empresa_fecha
  ON public.nc_hallazgo_ocurrencias(empresa_id, fecha_ocurrencia DESC);

-- -----------------------------------------------------------------------------
-- 3) EXTENSION A TICKETS PARA RELACION CON HALLAZGO
-- -----------------------------------------------------------------------------
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS hallazgo_id UUID REFERENCES public.nc_hallazgos(id),
  ADD COLUMN IF NOT EXISTS hallazgo_ocurrencia_id UUID REFERENCES public.nc_hallazgo_ocurrencias(id);

CREATE INDEX IF NOT EXISTS idx_tickets_hallazgo
  ON public.tickets(hallazgo_id)
  WHERE hallazgo_id IS NOT NULL;

-- Solo un ticket ACTIVO por hallazgo (permite historico de cerrados).
CREATE UNIQUE INDEX IF NOT EXISTS uq_tickets_hallazgo_activo
  ON public.tickets(hallazgo_id)
  WHERE hallazgo_id IS NOT NULL
    AND eliminado = false
    AND estado <> 'CERRADO';

-- Importante: remover la unicidad legacy de 1 ticket por inspección,
-- ya que el nuevo modelo es 1 ticket por hallazgo.
DROP INDEX IF EXISTS public.uq_tickets_inspeccion_automatico;

CREATE INDEX IF NOT EXISTS idx_tickets_inspeccion_origen
  ON public.tickets(inspeccion_id, origen)
  WHERE origen = 'INSPECCION' AND inspeccion_id IS NOT NULL AND eliminado = false;

-- -----------------------------------------------------------------------------
-- 4) RLS (patron empresa/admin similar a tickets)
-- -----------------------------------------------------------------------------
ALTER TABLE public.nc_hallazgos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nc_hallazgo_ocurrencias ENABLE ROW LEVEL SECURITY;

-- Lectura por empresa del usuario o admin
DROP POLICY IF EXISTS nc_hallazgos_select ON public.nc_hallazgos;
CREATE POLICY nc_hallazgos_select
ON public.nc_hallazgos FOR SELECT TO authenticated
USING (
  public.is_admin_user()
  OR public.user_has_empresa(empresa_id)
);

DROP POLICY IF EXISTS nc_hallazgos_insert ON public.nc_hallazgos;
CREATE POLICY nc_hallazgos_insert
ON public.nc_hallazgos FOR INSERT TO authenticated
WITH CHECK (
  public.is_admin_user()
  OR public.user_has_empresa(empresa_id)
);

DROP POLICY IF EXISTS nc_hallazgos_update ON public.nc_hallazgos;
CREATE POLICY nc_hallazgos_update
ON public.nc_hallazgos FOR UPDATE TO authenticated
USING (
  public.is_admin_user()
  OR public.user_has_empresa(empresa_id)
)
WITH CHECK (
  public.is_admin_user()
  OR public.user_has_empresa(empresa_id)
);

DROP POLICY IF EXISTS nc_ocurrencias_select ON public.nc_hallazgo_ocurrencias;
CREATE POLICY nc_ocurrencias_select
ON public.nc_hallazgo_ocurrencias FOR SELECT TO authenticated
USING (
  public.is_admin_user()
  OR public.user_has_empresa(empresa_id)
);

DROP POLICY IF EXISTS nc_ocurrencias_insert ON public.nc_hallazgo_ocurrencias;
CREATE POLICY nc_ocurrencias_insert
ON public.nc_hallazgo_ocurrencias FOR INSERT TO authenticated
WITH CHECK (
  public.is_admin_user()
  OR public.user_has_empresa(empresa_id)
);

COMMIT;
