-- =============================================================================
-- FIX RLS: escritura en checklist_navigation_nodes (motor de checklists)
-- Archivo: supabase_fix_rls_checklist_navigation_nodes_write_v1.sql
-- Ejecutar MANUALMENTE en el SQL Editor de Supabase.
--
-- PROBLEMA
--   El admin de Checklists (pestana "Checklists" -> "Habilitar Herramientas y
--   Equipos") falla con:
--     PostgrestException(code: 42501,
--       "new row violates row-level security policy for
--        table \"checklist_navigation_nodes\"")
--   Causa: supabase_migration_motor_checklists_configurables_v1.sql habilito
--   RLS en checklist_navigation_nodes pero SOLO creo la policy de SELECT
--   (checklist_nodes_read). Sin policy de INSERT/UPDATE/DELETE, Postgres
--   bloquea todo INSERT (error 42501) y hace que los UPDATE afecten 0 filas
--   SIN error (el toggle de activar/desactivar nodos "guardaba" pero no
--   cambiaba nada).
--
-- SOLUCION
--   Policies de escritura separadas por comando, permitidas a:
--     - superadmin (admin de empresa administradora): cualquier empresa.
--     - admin normal: solo empresas a las que pertenece (user_has_empresa).
--   La policy de SELECT existente NO se toca.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) CHECK (solo lectura): ejecuta esto ANTES de migrar.
-- -----------------------------------------------------------------------------
-- 1.a Policies actuales de la tabla. Si solo aparece checklist_nodes_read
--     (cmd = SELECT), la migracion NO esta aplicada -> hay que aplicarla.
--     Si ya ves checklist_nodes_write_insert/update/delete, ya esta aplicada.
SELECT policyname, cmd, roles, qual AS using_expr, with_check AS check_expr
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'checklist_navigation_nodes'
ORDER BY cmd, policyname;

-- 1.b Confirma que RLS esta activo (rowsecurity debe ser true).
SELECT relname, relrowsecurity AS rls_activo
FROM pg_class
WHERE oid = 'public.checklist_navigation_nodes'::regclass;

-- 1.c Tu usuario actual: para saber si pasaras las policies.
--     es_admin debe ser true; es_superadmin true si quieres habilitar
--     catalogos a empresas de las que no eres miembro.
SELECT auth.uid() AS mi_usuario,
       public.is_admin_user() AS es_admin,
       public.is_superadmin_user() AS es_superadmin;

-- -----------------------------------------------------------------------------
-- 2) MIGRACION (idempotente)
-- -----------------------------------------------------------------------------
BEGIN;

DROP POLICY IF EXISTS checklist_nodes_write_insert ON public.checklist_navigation_nodes;
CREATE POLICY checklist_nodes_write_insert ON public.checklist_navigation_nodes
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_superadmin_user()
    OR (public.is_admin_user() AND public.user_has_empresa(empresa_id))
  );

DROP POLICY IF EXISTS checklist_nodes_write_update ON public.checklist_navigation_nodes;
CREATE POLICY checklist_nodes_write_update ON public.checklist_navigation_nodes
  FOR UPDATE TO authenticated
  USING (
    public.is_superadmin_user()
    OR (public.is_admin_user() AND public.user_has_empresa(empresa_id))
  )
  WITH CHECK (
    public.is_superadmin_user()
    OR (public.is_admin_user() AND public.user_has_empresa(empresa_id))
  );

DROP POLICY IF EXISTS checklist_nodes_write_delete ON public.checklist_navigation_nodes;
CREATE POLICY checklist_nodes_write_delete ON public.checklist_navigation_nodes
  FOR DELETE TO authenticated
  USING (
    public.is_superadmin_user()
    OR (public.is_admin_user() AND public.user_has_empresa(empresa_id))
  );

-- El admin necesita VER los nodos deshabilitados y los de otras empresas para
-- poder alternarlos. La policy original ya contempla is_admin_user(), pero se
-- recrea aqui por si una migracion parcial la dejo mas restrictiva.
DROP POLICY IF EXISTS checklist_nodes_read ON public.checklist_navigation_nodes;
CREATE POLICY checklist_nodes_read ON public.checklist_navigation_nodes
  FOR SELECT TO authenticated
  USING (public.is_admin_user() OR (
    habilitado AND public.user_has_empresa(empresa_id)
    AND (checklist_key IS NULL OR public.checklist_user_can(checklist_key, empresa_id, 'ver'))
  ));

-- checklist_permission_grants: el onboarding tambien inserta permisos. La
-- policy existente (checklist_grants_admin) exige superadmin; se amplia para
-- que un admin pueda otorgar permisos dentro de SUS propias empresas.
DROP POLICY IF EXISTS checklist_grants_admin ON public.checklist_permission_grants;
CREATE POLICY checklist_grants_admin ON public.checklist_permission_grants
  FOR ALL TO authenticated
  USING (
    public.is_superadmin_user()
    OR (public.is_admin_user() AND public.user_has_empresa(empresa_id))
  )
  WITH CHECK (
    public.is_superadmin_user()
    OR (public.is_admin_user() AND public.user_has_empresa(empresa_id))
  );

COMMIT;

-- -----------------------------------------------------------------------------
-- 3) TESTS (solo lectura): ejecuta esto DESPUES de migrar.
-- -----------------------------------------------------------------------------
-- 3.a Deben existir 4 policies: read (SELECT) + write_insert/update/delete.
SELECT policyname, cmd
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'checklist_navigation_nodes'
ORDER BY cmd, policyname;

-- 3.b checklist_permission_grants debe tener checklist_grants_admin (ALL) y
--     checklist_grants_read_own (SELECT).
SELECT policyname, cmd
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'checklist_permission_grants'
ORDER BY cmd, policyname;

-- 3.c Nodos por empresa (para verificar el resultado del boton del admin).
--     Tras habilitar Herramientas y Equipos en una empresa deberian aparecer
--     11 filas: 1 GROUP + 5 CHECKLIST agrupados + 5 CHECKLIST sueltos.
SELECT e.nombre AS empresa,
       count(*) FILTER (WHERE n.node_type = 'GROUP') AS grupos,
       count(*) FILTER (WHERE n.node_type = 'CHECKLIST') AS checklists,
       count(*) FILTER (WHERE n.habilitado) AS habilitados
FROM public.checklist_navigation_nodes n
JOIN public.empresas e ON e.id = n.empresa_id
GROUP BY e.nombre
ORDER BY e.nombre;
