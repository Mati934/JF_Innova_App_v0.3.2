-- =============================================================================
-- MODULO TURNO (ingreso y egreso del auditor)  ·  2026-11-24
-- Crea la tabla turnos: un registro por turno del auditor (area, centro
-- opcional, ingreso, salida estimada = ingreso + 13 dias, salida confirmada).
-- Un solo turno ACTIVO por usuario. RLS: el auditor escribe lo suyo; el admin
-- lee lo de sus empresas (dashboard: "En turno ahora" e informe semanal).
-- Habilita el modulo TURNO para Aquachile y Servimaf.
-- Plan: docs/planificacion/02_en_progreso/PLAN_TURNO.md
-- Ejecutar MANUALMENTE, DESPUES de tener la app lista.
-- Reejecutable: si (IF NOT EXISTS, CREATE OR REPLACE, DROP POLICY IF EXISTS,
-- ON CONFLICT). No borra datos.
-- Pasos: 0 (solo lectura) -> 1 (BEGIN..COMMIT) -> 2 (verificar).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. SOLO LECTURA
-- -----------------------------------------------------------------------------
-- Esperado antes de la primera ejecucion: turnos = NULL, funciones_3 = 3,
-- empresas_2 = 2, modulo_turno = 0.
SELECT
  to_regclass('public.turnos') AS turnos,
  (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('is_admin_user', 'is_superadmin_user', 'user_has_empresa')) AS funciones_3,
  (SELECT count(*) FROM public.empresas WHERE nombre IN ('Aquachile', 'Servimaf')) AS empresas_2,
  (SELECT count(*) FROM public.empresa_modulos WHERE modulo_key = 'TURNO') AS modulo_turno;

-- -----------------------------------------------------------------------------
-- 1. CAMBIO
-- -----------------------------------------------------------------------------
BEGIN;

DO $$
BEGIN
  IF (SELECT count(*) FROM public.empresas WHERE nombre IN ('Aquachile', 'Servimaf')) <> 2 THEN
    RAISE EXCEPTION 'TURNO_EMPRESAS: faltan Aquachile o Servimaf en empresas';
  END IF;
END $$;

-- 1.1 Tabla. Mismas columnas que la tabla local turnos (SQLite) salvo
-- subido/eliminado, que son solo locales.
CREATE TABLE IF NOT EXISTS public.turnos (
  id UUID PRIMARY KEY,
  -- = auth.uid(). Sin FK, igual que registros_inmersion.
  usuario_id UUID NOT NULL,
  empresa_id UUID REFERENCES public.empresas(id),
  area_id UUID NOT NULL REFERENCES public.areas(id),
  -- Opcional: el auditor puede no saber o cubrir varios centros.
  centro_id UUID REFERENCES public.centros(id) ON DELETE SET NULL,
  estado TEXT NOT NULL DEFAULT 'ACTIVO'
    CHECK (estado IN ('ACTIVO', 'CERRADO')),
  ingreso_fecha DATE NOT NULL,
  -- Se guarda (no se calcula al leer) para que el dashboard no repita la regla.
  egreso_estimado DATE NOT NULL,
  egreso_fecha DATE,
  extraordinario BOOLEAN NOT NULL DEFAULT false,
  observacion_ingreso TEXT,
  observacion_egreso TEXT,
  -- Cuando se marco cada cosa (auditoria: si la fecha se corrigio o se cerro tarde).
  ingreso_registrado_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  egreso_registrado_at TIMESTAMPTZ,
  app_version TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT turnos_egreso_estimado_chk
    CHECK (egreso_estimado = ingreso_fecha + 13),
  CONSTRAINT turnos_egreso_fecha_chk
    CHECK (egreso_fecha IS NULL OR egreso_fecha >= ingreso_fecha),
  -- ACTIVO sin salida; CERRADO con salida.
  CONSTRAINT turnos_estado_egreso_chk
    CHECK ((estado = 'ACTIVO' AND egreso_fecha IS NULL)
        OR (estado = 'CERRADO' AND egreso_fecha IS NOT NULL))
);

-- Un solo turno activo por usuario (aunque use dos celulares).
CREATE UNIQUE INDEX IF NOT EXISTS uq_turnos_activo_por_usuario
  ON public.turnos(usuario_id) WHERE estado = 'ACTIVO';
-- Dashboard: "En turno ahora" e informes por fecha.
CREATE INDEX IF NOT EXISTS idx_turnos_empresa_estado
  ON public.turnos(empresa_id, estado);
CREATE INDEX IF NOT EXISTS idx_turnos_empresa_ingreso
  ON public.turnos(empresa_id, ingreso_fecha);

-- 1.2 updated_at y turno CERRADO de solo lectura: ningun UPDATE lo cambia
-- (ni un reintento del sync que lo traiga como ACTIVO, ni otra edicion). Una
-- correccion de administrador se hara aparte (PLAN_TURNO §8).
CREATE OR REPLACE FUNCTION public.turnos_before_write()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $$
BEGIN
  NEW.updated_at := now();
  IF TG_OP = 'UPDATE' AND OLD.estado = 'CERRADO' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_turnos_before_write ON public.turnos;
CREATE TRIGGER trg_turnos_before_write
  BEFORE INSERT OR UPDATE ON public.turnos
  FOR EACH ROW EXECUTE FUNCTION public.turnos_before_write();

-- 1.3 RLS: el auditor escribe lo suyo; el admin lee lo de sus empresas.
ALTER TABLE public.turnos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS turnos_owner_all ON public.turnos;
CREATE POLICY turnos_owner_all ON public.turnos
  FOR ALL TO authenticated
  USING (usuario_id = auth.uid())
  WITH CHECK (usuario_id = auth.uid()
              AND (empresa_id IS NULL OR public.user_has_empresa(empresa_id)));

DROP POLICY IF EXISTS turnos_admin_select ON public.turnos;
CREATE POLICY turnos_admin_select ON public.turnos
  FOR SELECT TO authenticated
  USING (public.is_superadmin_user()
         OR (public.is_admin_user() AND public.user_has_empresa(empresa_id)));

-- 1.4 Modulo habilitado para Aquachile y Servimaf.
INSERT INTO public.empresa_modulos (empresa_id, modulo_key, habilitado, orden)
SELECT e.id, 'TURNO', true, 80
FROM public.empresas e
WHERE e.nombre IN ('Aquachile', 'Servimaf')
ON CONFLICT (empresa_id, modulo_key) DO UPDATE SET habilitado = true;

COMMIT;

-- -----------------------------------------------------------------------------
-- 2. SOLO LECTURA: verificar
-- -----------------------------------------------------------------------------
-- Esperado: turnos con rls = true.
SELECT c.relname, c.relrowsecurity AS rls
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname = 'turnos';

-- Esperado: turnos_admin_select y turnos_owner_all.
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'turnos' ORDER BY 1;

-- Esperado: uq_turnos_activo_por_usuario, idx_turnos_empresa_estado,
-- idx_turnos_empresa_ingreso y turnos_pkey.
SELECT indexname FROM pg_indexes WHERE tablename = 'turnos' ORDER BY 1;

-- Esperado: TURNO habilitado = true para Aquachile y Servimaf.
SELECT e.nombre, em.modulo_key, em.habilitado, em.orden
FROM public.empresa_modulos em JOIN public.empresas e ON e.id = em.empresa_id
WHERE em.modulo_key = 'TURNO' ORDER BY 1;
