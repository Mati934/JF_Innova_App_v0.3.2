-- =============================================================================
-- RLS para las 4 tablas que quedaban abiertas al rol anon (2026-10-22)
-- =============================================================================
-- Objetivo: cerrar el acceso anónimo (anon key, que va dentro del APK) SIN
-- cambiar nada para usuarios logueados. No requiere actualizar la app.
--
-- Análisis previo (solo lectura):
--   - formulario_campos_extra: la app solo hace GET en el sync, siempre como
--     authenticated (logs 24h: 70 GET, todos authenticated, 0 anon).
--   - ast_correlativo_counters: la escribe next_ast_correlativo_gapless(),
--     llamada por el trigger trg_ast_correlativo. NO es SECURITY DEFINER, corre
--     como el usuario logueado -> necesita INSERT/UPDATE/SELECT para
--     authenticated o los AST no podrían finalizar.
--   - dashboard_permisos_catalogo / usuario_dashboard_permisos: no se usan en
--     esta app; las usa el panel de control aparte. Sin tráfico REST en 24h.
--   - Ninguna vista depende de estas tablas.
--
-- Por eso: authenticated conserva exactamente el acceso que tiene hoy
-- (policy amplia). Solo se pierde el acceso anon. service_role ignora RLS.
-- Pendiente (no se hace aquí): restringir la escritura de authenticated en
-- usuario_dashboard_permisos y ast_correlativo_counters cuando se conozca
-- cómo las usa el panel.
-- =============================================================================

BEGIN;

ALTER TABLE public.formulario_campos_extra     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ast_correlativo_counters    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dashboard_permisos_catalogo ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuario_dashboard_permisos  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS formulario_campos_extra_authenticated_all ON public.formulario_campos_extra;
CREATE POLICY formulario_campos_extra_authenticated_all
  ON public.formulario_campos_extra FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS ast_correlativo_counters_authenticated_all ON public.ast_correlativo_counters;
CREATE POLICY ast_correlativo_counters_authenticated_all
  ON public.ast_correlativo_counters FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS dashboard_permisos_catalogo_authenticated_all ON public.dashboard_permisos_catalogo;
CREATE POLICY dashboard_permisos_catalogo_authenticated_all
  ON public.dashboard_permisos_catalogo FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS usuario_dashboard_permisos_authenticated_all ON public.usuario_dashboard_permisos;
CREATE POLICY usuario_dashboard_permisos_authenticated_all
  ON public.usuario_dashboard_permisos FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

COMMIT;

-- Verificación: las 4 con rls = true y 1 policy cada una.
-- SELECT relname, relrowsecurity rls,
--        (SELECT count(*) FROM pg_policy WHERE polrelid = c.oid) policies
-- FROM pg_class c
-- WHERE relnamespace = 'public'::regnamespace
--   AND relname IN ('formulario_campos_extra','ast_correlativo_counters',
--                   'dashboard_permisos_catalogo','usuario_dashboard_permisos');

-- Rollback (vuelve exactamente al estado anterior):
-- ALTER TABLE public.formulario_campos_extra     DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.ast_correlativo_counters    DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.dashboard_permisos_catalogo DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.usuario_dashboard_permisos  DISABLE ROW LEVEL SECURITY;
-- DROP POLICY IF EXISTS formulario_campos_extra_authenticated_all ON public.formulario_campos_extra;
-- DROP POLICY IF EXISTS ast_correlativo_counters_authenticated_all ON public.ast_correlativo_counters;
-- DROP POLICY IF EXISTS dashboard_permisos_catalogo_authenticated_all ON public.dashboard_permisos_catalogo;
-- DROP POLICY IF EXISTS usuario_dashboard_permisos_authenticated_all ON public.usuario_dashboard_permisos;
