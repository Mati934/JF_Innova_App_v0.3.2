-- =============================================================================
-- FIX RLS: Modulo Datos Maestros (centros, contratistas, embarcaciones, areas)
-- Fecha: 2026-07-26
--
-- Objetivo:
-- 1) Mantener RLS habilitado (no abrir tablas al rol anon).
-- 2) Permitir lectura a usuarios autenticados para carga de catalogos.
-- 3) Permitir escritura solo a usuarios admin en el panel de Datos Maestros.
--
-- Nota:
-- - Esta migracion es idempotente (DROP POLICY IF EXISTS + CREATE POLICY).
-- - Reutiliza helper de admin por rol en tablas usuarios/roles.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- A) HELPERS DE RLS (compatibles con migraciones previas)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.usuarios u
    JOIN public.roles r ON r.id = u.rol_id
    WHERE u.id = auth.uid()
      AND lower(r.nombre) IN ('admin', 'administrador')
  );
$$;

CREATE OR REPLACE FUNCTION public.user_has_empresa(p_empresa_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.usuario_empresas ue
    WHERE ue.usuario_id = auth.uid() AND ue.empresa_id = p_empresa_id
  )
  OR EXISTS (
    SELECT 1
    FROM public.usuarios u
    WHERE u.id = auth.uid() AND u.empresa_id = p_empresa_id
  );
$$;

-- -----------------------------------------------------------------------------
-- B) TABLAS MAESTRAS: RLS ON + SELECT autenticado + WRITE admin
-- -----------------------------------------------------------------------------
ALTER TABLE public.areas          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.centros        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contratistas   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.embarcaciones  ENABLE ROW LEVEL SECURITY;

-- areas
DROP POLICY IF EXISTS areas_select_authenticated ON public.areas;
CREATE POLICY areas_select_authenticated
  ON public.areas FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS areas_admin_write ON public.areas;
CREATE POLICY areas_admin_write
  ON public.areas FOR ALL
  TO authenticated
  USING      (public.is_admin_user())
  WITH CHECK (public.is_admin_user());

-- centros
DROP POLICY IF EXISTS centros_select_authenticated ON public.centros;
CREATE POLICY centros_select_authenticated
  ON public.centros FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS centros_admin_write ON public.centros;
CREATE POLICY centros_admin_write
  ON public.centros FOR ALL
  TO authenticated
  USING      (public.is_admin_user())
  WITH CHECK (public.is_admin_user());

-- contratistas
DROP POLICY IF EXISTS contratistas_select_authenticated ON public.contratistas;
CREATE POLICY contratistas_select_authenticated
  ON public.contratistas FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS contratistas_admin_write ON public.contratistas;
CREATE POLICY contratistas_admin_write
  ON public.contratistas FOR ALL
  TO authenticated
  USING      (public.is_admin_user())
  WITH CHECK (public.is_admin_user());

-- embarcaciones
DROP POLICY IF EXISTS embarcaciones_select_authenticated ON public.embarcaciones;
CREATE POLICY embarcaciones_select_authenticated
  ON public.embarcaciones FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS embarcaciones_admin_write ON public.embarcaciones;
CREATE POLICY embarcaciones_admin_write
  ON public.embarcaciones FOR ALL
  TO authenticated
  USING      (public.is_admin_user())
  WITH CHECK (public.is_admin_user());

COMMIT;
