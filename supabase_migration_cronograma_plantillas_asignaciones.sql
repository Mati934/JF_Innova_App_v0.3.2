-- =============================================================================
-- MIGRACION: CRONOGRAMA PLANTILLAS - Asignaciones a empresas cliente
-- Objetivo:
--   1) Tabla de asignación de plantillas a empresas cliente (relación M2M)
--   2) Visibilidad controlada vía RLS
--   3) Trigger para generar planes automáticamente (placeholder por ahora)
--
-- Idempotente: seguro de ejecutar multiples veces.
-- Requiere: supabase_migration_cronograma_module.sql (tablas base)
-- =============================================================================

BEGIN;

-- Tabla de asignación: Plantilla <-> Empresa Cliente
CREATE TABLE IF NOT EXISTS public.cronograma_plantilla_asignaciones (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plantilla_id          UUID NOT NULL REFERENCES public.cronograma_plantillas(id) ON DELETE CASCADE,
  cliente_empresa_id    UUID NOT NULL REFERENCES public.cronograma_clientes_empresas(id) ON DELETE CASCADE,
  vigente_desde         DATE,
  vigente_hasta         DATE,
  auto_generar_plan     BOOLEAN NOT NULL DEFAULT true,
  activa                BOOLEAN NOT NULL DEFAULT true,
  created_by            UUID,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (plantilla_id, cliente_empresa_id)
);
COMMENT ON TABLE public.cronograma_plantilla_asignaciones IS
  'Asignación de plantillas de cronograma a empresas cliente. Cuando activa, genera automáticamente los planes según frecuencia.';

-- Indices
CREATE INDEX IF NOT EXISTS idx_cronograma_plantilla_asignaciones_plantilla
  ON public.cronograma_plantilla_asignaciones(plantilla_id);
CREATE INDEX IF NOT EXISTS idx_cronograma_plantilla_asignaciones_cliente
  ON public.cronograma_plantilla_asignaciones(cliente_empresa_id);
CREATE INDEX IF NOT EXISTS idx_cronograma_plantilla_asignaciones_activa
  ON public.cronograma_plantilla_asignaciones(activa);

-- Trigger para actualizar updated_at en asignaciones
CREATE OR REPLACE FUNCTION public.touch_cronograma_plantilla_asignaciones_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_touch_asignaciones_updated_at
  ON public.cronograma_plantilla_asignaciones;
CREATE TRIGGER trg_touch_asignaciones_updated_at
  BEFORE UPDATE ON public.cronograma_plantilla_asignaciones
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_cronograma_plantilla_asignaciones_updated_at();

-- RLS: Solo super admin puede ver/modificar (simplificado por ahora)
ALTER TABLE public.cronograma_plantilla_asignaciones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cronograma_plantilla_asignaciones_select
  ON public.cronograma_plantilla_asignaciones;
CREATE POLICY cronograma_plantilla_asignaciones_select ON public.cronograma_plantilla_asignaciones
  FOR SELECT USING (public.is_cronograma_admin());

DROP POLICY IF EXISTS cronograma_plantilla_asignaciones_insert
  ON public.cronograma_plantilla_asignaciones;
CREATE POLICY cronograma_plantilla_asignaciones_insert ON public.cronograma_plantilla_asignaciones
  FOR INSERT WITH CHECK (public.is_cronograma_admin());

DROP POLICY IF EXISTS cronograma_plantilla_asignaciones_update
  ON public.cronograma_plantilla_asignaciones;
CREATE POLICY cronograma_plantilla_asignaciones_update ON public.cronograma_plantilla_asignaciones
  FOR UPDATE USING (public.is_cronograma_admin());

DROP POLICY IF EXISTS cronograma_plantilla_asignaciones_delete
  ON public.cronograma_plantilla_asignaciones;
CREATE POLICY cronograma_plantilla_asignaciones_delete ON public.cronograma_plantilla_asignaciones
  FOR DELETE USING (public.is_cronograma_admin());

COMMIT;
