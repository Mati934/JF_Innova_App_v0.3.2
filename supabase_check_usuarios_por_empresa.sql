-- =============================================================================
-- CHECK (SOLO LECTURA): usuarios por empresa
--
-- Incluye:
-- 1) Cantidad de usuarios por empresa.
-- 2) Listado de usuarios de una empresa seleccionada.
--
-- Nota:
-- - Este script NO modifica datos.
-- - Considera usuarios por relacion directa (`usuarios.empresa_id`) y tambien
--   por relacion multiempresa (`usuario_empresas`).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PARAMETROS (elige uno)
-- -----------------------------------------------------------------------------
-- Opcion A: buscar por empresa_id
-- Reemplaza el NULL por un UUID valido, por ejemplo:
-- '11111111-2222-3333-4444-555555555555'::uuid
WITH params AS (
  SELECT
    NULL::uuid AS p_empresa_id,
    NULL::text AS p_empresa_nombre -- Opcion B: texto parcial, ej: 'JF Innova'
),

-- -----------------------------------------------------------------------------
-- BASE: usuarios vinculados a empresas (directo + multiempresa)
-- -----------------------------------------------------------------------------
base_vinculos AS (
  -- Relacion directa en usuarios.empresa_id
  SELECT
    e.id AS empresa_id,
    e.nombre AS empresa_nombre,
    u.id AS usuario_id,
    u.nombre_completo,
    u.email,
    u.rut,
    u.telefono,
    'usuarios.empresa_id'::text AS origen_vinculo
  FROM public.empresas e
  LEFT JOIN public.usuarios u
    ON u.empresa_id = e.id

  UNION ALL

  -- Relacion multiempresa en usuario_empresas
  SELECT
    e.id AS empresa_id,
    e.nombre AS empresa_nombre,
    u.id AS usuario_id,
    u.nombre_completo,
    u.email,
    u.rut,
    u.telefono,
    'usuario_empresas'::text AS origen_vinculo
  FROM public.empresas e
  JOIN public.usuario_empresas ue
    ON ue.empresa_id = e.id
  JOIN public.usuarios u
    ON u.id = ue.usuario_id
),

-- Evitar duplicados del mismo usuario en la misma empresa
vinculos_dedup AS (
  SELECT DISTINCT
    empresa_id,
    empresa_nombre,
    usuario_id,
    nombre_completo,
    email,
    rut,
    telefono
  FROM base_vinculos
  WHERE usuario_id IS NOT NULL
),

-- Empresa objetivo para el detalle
empresa_objetivo AS (
  SELECT e.id, e.nombre
  FROM public.empresas e
  CROSS JOIN params p
  WHERE (p.p_empresa_id IS NOT NULL AND e.id = p.p_empresa_id)
     OR (p.p_empresa_id IS NULL AND p.p_empresa_nombre IS NOT NULL AND e.nombre ILIKE '%' || p.p_empresa_nombre || '%')
)

-- -----------------------------------------------------------------------------
-- 1) CANTIDAD DE USUARIOS POR EMPRESA
-- -----------------------------------------------------------------------------
SELECT
  e.id AS empresa_id,
  e.nombre AS empresa_nombre,
  COUNT(v.usuario_id) AS cantidad_usuarios
FROM public.empresas e
LEFT JOIN vinculos_dedup v
  ON v.empresa_id = e.id
GROUP BY e.id, e.nombre
ORDER BY cantidad_usuarios DESC, e.nombre;

-- -----------------------------------------------------------------------------
-- 2) USUARIOS DE EMPRESA SELECCIONADA
--
-- Si no seteas parametros, esta seccion devolvera 0 filas.
-- -----------------------------------------------------------------------------
SELECT
  eo.id AS empresa_id,
  eo.nombre AS empresa_nombre,
  v.usuario_id,
  v.nombre_completo,
  v.email,
  v.rut,
  v.telefono
FROM empresa_objetivo eo
JOIN vinculos_dedup v
  ON v.empresa_id = eo.id
ORDER BY v.nombre_completo, v.email;

-- -----------------------------------------------------------------------------
-- 3) AYUDA RAPIDA: empresas disponibles (para copiar id/nombre)
-- -----------------------------------------------------------------------------
SELECT id AS empresa_id, nombre AS empresa_nombre
FROM public.empresas
ORDER BY nombre;
