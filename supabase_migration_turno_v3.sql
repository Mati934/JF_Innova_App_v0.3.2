-- =============================================================================
-- TURNO v3: cierre de turno + directorio de contactos por empresa  ·  2026-11-25
-- 1) turno_cierres: un cierre por turno (borrador o generado) con indicadores y
--    resumen de tickets en columnas; las secciones con filas en JSONB mientras
--    se pule el PDF (decision del usuario 2026-11-25: hibrido; pasar a tablas
--    hijas cuando el PDF quede fijo).
-- 2) contratista_contactos: supervisor/correo/fono por contratista, compartido
--    entre los usuarios de una empresa (se llena solo en el proximo cierre).
-- Ejecutar MANUALMENTE. Reejecutable: si (IF NOT EXISTS / DROP POLICY IF EXISTS).
-- Pasos: 0 (solo lectura) -> 1 (BEGIN..COMMIT) -> 2 (verificar).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. SOLO LECTURA
-- -----------------------------------------------------------------------------
-- Esperado: 0 filas (las tablas no existen aun) o las dos si se reejecuta.
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('turno_cierres', 'contratista_contactos');

-- Esperado: existen las tres funciones usadas por las politicas.
SELECT proname FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN ('user_has_empresa', 'is_admin_user', 'is_superadmin_user');

-- -----------------------------------------------------------------------------
-- 1. CAMBIO
-- -----------------------------------------------------------------------------
BEGIN;

-- 1.1 Cierre de turno. Mismas columnas que la tabla local turno_cierres
-- (SQLite) salvo subido/eliminado/pdf_path_local, que son solo locales.
CREATE TABLE IF NOT EXISTS public.turno_cierres (
  id UUID PRIMARY KEY,
  turno_id UUID NOT NULL UNIQUE REFERENCES public.turnos(id) ON DELETE CASCADE,
  usuario_id UUID NOT NULL,
  empresa_id UUID REFERENCES public.empresas(id),
  area_id UUID REFERENCES public.areas(id),
  -- Periodo que cubre el cierre (por defecto ingreso y salida del turno).
  desde DATE NOT NULL,
  hasta DATE NOT NULL,
  estado TEXT NOT NULL DEFAULT 'BORRADOR'
    CHECK (estado IN ('BORRADOR', 'GENERADO')),
  -- Resumen de indicadores (automatico, editable por el auditor).
  n_centros INTEGER,
  n_insp_buceo INTEGER,
  n_ast INTEGER,
  n_insp_emb INTEGER,
  n_reg_act INTEGER,
  n_obs_buceo INTEGER,
  n_obs_emb INTEGER,
  n_faenas_suspendidas INTEGER,
  -- Tickets del profesional en el periodo (mismo calculo que "historicos por
  -- profesional" del dashboard, acotado al turno).
  tk_creados INTEGER,
  tk_cerrados INTEGER,
  tk_solo_creo INTEGER,
  tk_creo_y_cerro INTEGER,
  tk_solo_cerro INTEGER,
  tk_abiertos INTEGER,
  tk_tomados INTEGER,
  tk_parciales INTEGER,
  tk_por_revisar INTEGER,
  tk_estado_cerrados INTEGER,
  tk_a_cargo INTEGER,
  -- Secciones con filas (arreglos JSON de objetos), ver docs/modulos/turno.md.
  folios JSONB NOT NULL DEFAULT '[]'::jsonb,
  centros JSONB NOT NULL DEFAULT '[]'::jsonb,
  suspensiones JSONB NOT NULL DEFAULT '[]'::jsonb,
  informes_pendientes JSONB NOT NULL DEFAULT '[]'::jsonb,
  hallazgos JSONB NOT NULL DEFAULT '[]'::jsonb,
  servicios JSONB NOT NULL DEFAULT '[]'::jsonb,
  puertos_cerrados JSONB NOT NULL DEFAULT '[]'::jsonb,
  bitacora TEXT,
  pdf_url TEXT,
  pdf_version TEXT,
  pdf_generado_at TIMESTAMPTZ,
  app_version TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT turno_cierres_periodo_chk CHECK (hasta >= desde)
);

CREATE INDEX IF NOT EXISTS idx_turno_cierres_empresa_desde
  ON public.turno_cierres(empresa_id, desde);

CREATE OR REPLACE FUNCTION public.turno_cierres_before_write()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_turno_cierres_before_write ON public.turno_cierres;
CREATE TRIGGER trg_turno_cierres_before_write
  BEFORE INSERT OR UPDATE ON public.turno_cierres
  FOR EACH ROW EXECUTE FUNCTION public.turno_cierres_before_write();

ALTER TABLE public.turno_cierres ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS turno_cierres_owner_all ON public.turno_cierres;
CREATE POLICY turno_cierres_owner_all ON public.turno_cierres
  FOR ALL TO authenticated
  USING (usuario_id = auth.uid())
  WITH CHECK (usuario_id = auth.uid()
              AND (empresa_id IS NULL OR public.user_has_empresa(empresa_id)));

DROP POLICY IF EXISTS turno_cierres_admin_select ON public.turno_cierres;
CREATE POLICY turno_cierres_admin_select ON public.turno_cierres
  FOR SELECT TO authenticated
  USING (public.is_superadmin_user()
         OR (public.is_admin_user() AND public.user_has_empresa(empresa_id)));

-- 1.2 Directorio de contactos por contratista, compartido en la empresa.
CREATE TABLE IF NOT EXISTS public.contratista_contactos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES public.empresas(id),
  contratista_id UUID REFERENCES public.contratistas(id) ON DELETE SET NULL,
  -- Nombre tal como se ve (el AST guarda el contratista como texto).
  contratista_nombre TEXT NOT NULL,
  -- Clave para no duplicar: nombre sin espacios extra y en minusculas.
  contratista_clave TEXT GENERATED ALWAYS AS (lower(btrim(contratista_nombre))) STORED,
  actividad TEXT,
  supervisor TEXT,
  correo TEXT,
  fono TEXT,
  actualizado_por UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_contratista_contactos_empresa_clave
    UNIQUE (empresa_id, contratista_clave)
);

DROP TRIGGER IF EXISTS trg_contratista_contactos_before_write ON public.contratista_contactos;
CREATE TRIGGER trg_contratista_contactos_before_write
  BEFORE INSERT OR UPDATE ON public.contratista_contactos
  FOR EACH ROW EXECUTE FUNCTION public.turno_cierres_before_write();

ALTER TABLE public.contratista_contactos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS contratista_contactos_empresa_all ON public.contratista_contactos;
CREATE POLICY contratista_contactos_empresa_all ON public.contratista_contactos
  FOR ALL TO authenticated
  USING (public.is_superadmin_user() OR public.user_has_empresa(empresa_id))
  WITH CHECK (public.is_superadmin_user() OR public.user_has_empresa(empresa_id));

COMMIT;

-- -----------------------------------------------------------------------------
-- 2. SOLO LECTURA: verificar
-- -----------------------------------------------------------------------------
-- Esperado: las dos tablas con rls = true.
SELECT c.relname, c.relrowsecurity AS rls
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('turno_cierres', 'contratista_contactos');

-- Esperado: contratista_contactos_empresa_all, turno_cierres_admin_select,
-- turno_cierres_owner_all.
SELECT tablename, policyname, cmd FROM pg_policies
WHERE tablename IN ('turno_cierres', 'contratista_contactos')
ORDER BY 1, 2;
