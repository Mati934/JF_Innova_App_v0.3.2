-- =============================================================================
-- CHECK SOLO LECTURA: Motor de Checklists Configurables v1
--
-- OBJETIVO
-- Verificar el estado real de Supabase ANTES de crear las tablas del motor,
-- catalogos, permisos, correlativos e integracion de historial.
--
-- ESTE ARCHIVO NO MODIFICA DATOS NI ESTRUCTURA.
-- Ejecutar manualmente en Supabase SQL Editor y guardar los resultados.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) EXISTENCIA DE TABLAS BASE Y TABLAS NUEVAS
--
-- Esperado antes de la migracion:
-- * tablas_base = presentes.
-- * tablas_motor = NULL (aun no creadas).
-- Si alguna tabla_motor ya existe, no ejecutar una migracion sin revisar antes
-- su estructura y si contiene datos.   
-- -----------------------------------------------------------------------------
SELECT
  to_regclass('public.empresas') AS empresas,
  to_regclass('public.usuarios') AS usuarios,
  to_regclass('public.roles') AS roles,
  to_regclass('public.usuario_empresas') AS usuario_empresas,
  to_regclass('public.empresa_modulos') AS empresa_modulos,
  to_regclass('public.formulario_items') AS formulario_items,
  to_regclass('public.formulario_campos_extra') AS formulario_campos_extra,
  to_regclass('public.historial_unificado') AS historial_unificado,
  to_regclass('public.checklist_form_types') AS checklist_form_types,
  to_regclass('public.checklists') AS checklists,
  to_regclass('public.checklist_versions') AS checklist_versions,
  to_regclass('public.checklist_navigation_nodes') AS checklist_navigation_nodes,
  to_regclass('public.checklist_inspecciones') AS checklist_inspecciones,
  to_regclass('public.checklist_respuestas') AS checklist_respuestas,
  to_regclass('public.checklist_evidencias') AS checklist_evidencias,
  to_regclass('public.checklist_correlativo_counters') AS checklist_correlativo_counters,
  to_regclass('public.checklist_permission_grants') AS checklist_permission_grants;

-- -----------------------------------------------------------------------------
-- 2) COLUMNAS DEL CATALOGO ACTUAL QUE SE REUTILIZARAN
--
-- Esperado: formulario_items tiene tipo_actividad/pregunta/categoria/criticidad
-- y formulario_campos_extra tiene tipo_actividad/clave/label/tipo/requerido.
-- Esto determina como se hara la migracion compatible a checklist_key.
-- -----------------------------------------------------------------------------
SELECT
  table_name,
  ordinal_position,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('formulario_items', 'formulario_campos_extra', 'empresa_modulos')
ORDER BY table_name, ordinal_position;

-- -----------------------------------------------------------------------------
-- 3) CONFIGURACION Y DATOS QUE NO SE DEBEN ROMPER
-- -----------------------------------------------------------------------------

-- Modulos configurados por empresa. Permite planear coexistencia con la nueva
-- navegacion sin sustituir empresa_modulos de una vez.
SELECT
  em.empresa_id,
  e.nombre AS empresa_nombre,
  em.modulo_key,
  em.habilitado,
  em.orden
FROM public.empresa_modulos em
LEFT JOIN public.empresas e ON e.id = em.empresa_id
ORDER BY e.nombre NULLS LAST, em.orden, em.modulo_key;

-- Preguntas actuales por tipo: se usan para mapear o duplicar catalogos sin
-- cambiar preguntas historicas.
SELECT
  tipo_actividad,
  COUNT(*) AS preguntas_activas,
  COUNT(*) FILTER (WHERE criticidad IS NOT NULL)
    AS preguntas_con_criticidad
FROM public.formulario_items
WHERE COALESCE(activo, true) = true
GROUP BY tipo_actividad
ORDER BY tipo_actividad;

-- Campos de encabezado actuales y su regla de obligatoriedad.
SELECT
  tipo_actividad,
  orden,
  clave,
  label,
  tipo,
  requerido,
  activo
FROM public.formulario_campos_extra
ORDER BY tipo_actividad, orden, clave;

-- -----------------------------------------------------------------------------
-- 4) AUTORIZACION Y HISTORIAL
--
-- Esperado: las funciones is_admin_user, is_superadmin_user,
-- user_has_empresa e historial_autorizado existen y authenticated tiene EXECUTE
-- en historial_autorizado.
-- -----------------------------------------------------------------------------
SELECT
  p.proname AS funcion,
  pg_get_function_identity_arguments(p.oid) AS argumentos,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_ejecuta
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'is_admin_user',
    'is_superadmin_user',
    'user_has_empresa',
    'historial_autorizado'
  )
ORDER BY p.proname, argumentos;

-- Politicas y RLS de los objetos existentes que el motor debe respetar.
SELECT
  c.relname AS tabla,
  c.relrowsecurity AS rls_habilitado,
  c.relforcerowsecurity AS rls_forzado
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'empresa_modulos',
    'formulario_items',
    'formulario_campos_extra',
    'hidroser_inspecciones',
    'hidroser_respuestas',
    'buceo_equipamiento_inspecciones',
    'buceo_equipamiento_respuestas'
  )
ORDER BY c.relname;

SELECT
  tablename,
  policyname,
  cmd,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'empresa_modulos',
    'formulario_items',
    'formulario_campos_extra',
    'hidroser_inspecciones',
    'hidroser_respuestas',
    'buceo_equipamiento_inspecciones',
    'buceo_equipamiento_respuestas'
  )
ORDER BY tablename, policyname;

-- -----------------------------------------------------------------------------
-- 5) HISTORIAL Y STORAGE
--
-- La migracion debe ampliar la fuente de historial autorizada, no agregar otra
-- consulta directa desde la app.
-- -----------------------------------------------------------------------------
SELECT
  modulo,
  COUNT(*) AS informes_visibles,
  COUNT(*) FILTER (WHERE empresa_id IS NULL) AS informes_sin_empresa
FROM public.historial_unificado
GROUP BY modulo
ORDER BY modulo;

SELECT id, name, public
FROM storage.buckets
WHERE id IN ('evidencias', 'reportes', 'pdfs_visitas')
ORDER BY id;

-- -----------------------------------------------------------------------------
-- 6) RESULTADO ESPERADO PARA SEGUIR
--
-- Se puede preparar la migracion solo si:
-- * las tablas base requeridas existen;
-- * las tablas checklist_* aun no existen o fueron revisadas;
-- * historial_autorizado y los helpers de autorizacion existen;
-- * se entiende el resultado RLS de empresa_modulos/catalogos;
-- * la vista historial_unificado expone las 15 columnas que consume la RPC;
--   la RPC agrega empresa_nombre y devuelve 16 columnas.
--
-- IMPORTANTE: los informes historicos sin empresa_id NO bloquean la creacion
-- del motor nuevo. Se reportan como deuda de datos separada y no se corrigen
-- en esta migracion.
-- =============================================================================