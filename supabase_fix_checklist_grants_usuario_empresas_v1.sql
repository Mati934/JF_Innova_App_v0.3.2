-- =============================================================================
-- FIX: permisos del motor de checklists para usuarios multiempresa
--
-- Causa: el onboarding consultaba solo usuarios.empresa_id (legacy), pero las
-- asignaciones actuales viven en usuario_empresas. Los nodos quedaban activos
-- sin grants y RLS ocultaba los checklists a los usuarios normales.
--
-- Este script es idempotente. Otorga las capacidades operativas a los usuarios
-- vinculados con cada empresa para los checklists que esa empresa ya tiene en
-- checklist_navigation_nodes. La visibilidad sigue controlada por habilitado.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) CHECK PREVIO DE SOLO LECTURA
-- -----------------------------------------------------------------------------
WITH usuarios_por_empresa AS (
  SELECT ue.empresa_id, ue.usuario_id
  FROM public.usuario_empresas ue
  UNION
  SELECT u.empresa_id, u.id
  FROM public.usuarios u
  WHERE u.empresa_id IS NOT NULL
), checklists_por_empresa AS (
  SELECT DISTINCT n.empresa_id, n.checklist_key
  FROM public.checklist_navigation_nodes n
  WHERE n.checklist_key IS NOT NULL
), capacidades(capacidad) AS (
  VALUES ('ver'), ('crear'), ('editar_borrador'), ('finalizar')
), faltantes AS (
  SELECT cpe.empresa_id, cpe.checklist_key, upe.usuario_id, c.capacidad
  FROM checklists_por_empresa cpe
  JOIN usuarios_por_empresa upe ON upe.empresa_id = cpe.empresa_id
  CROSS JOIN capacidades c
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.checklist_permission_grants g
    WHERE g.empresa_id = cpe.empresa_id
      AND g.checklist_key = cpe.checklist_key
      AND g.usuario_id = upe.usuario_id
      AND g.capacidad = c.capacidad
  )
)
SELECT e.nombre AS empresa, COUNT(*) AS grants_faltantes
FROM faltantes f
JOIN public.empresas e ON e.id = f.empresa_id
GROUP BY e.id, e.nombre
ORDER BY e.nombre;
-- Interpretacion:
-- - Una empresa con un numero mayor que 0 necesita la reparacion.
-- - Si no retorna filas, los permisos ya estan completos y no hace falta migrar.
-- - Para M&S se esperan 40 grants por usuario si tiene los 5 checklists
--   (5 checklists x 4 capacidades).

-- -----------------------------------------------------------------------------
-- 2) MIGRACION IDEMPOTENTE
-- -----------------------------------------------------------------------------
BEGIN;

WITH usuarios_por_empresa AS (
  SELECT ue.empresa_id, ue.usuario_id
  FROM public.usuario_empresas ue
  UNION
  SELECT u.empresa_id, u.id
  FROM public.usuarios u
  WHERE u.empresa_id IS NOT NULL
), checklists_por_empresa AS (
  SELECT DISTINCT n.empresa_id, n.checklist_key
  FROM public.checklist_navigation_nodes n
  WHERE n.checklist_key IS NOT NULL
), capacidades(capacidad) AS (
  VALUES ('ver'), ('crear'), ('editar_borrador'), ('finalizar')
)
INSERT INTO public.checklist_permission_grants
  (empresa_id, checklist_key, usuario_id, capacidad)
SELECT cpe.empresa_id, cpe.checklist_key, upe.usuario_id, c.capacidad
FROM checklists_por_empresa cpe
JOIN usuarios_por_empresa upe ON upe.empresa_id = cpe.empresa_id
CROSS JOIN capacidades c
WHERE NOT EXISTS (
  SELECT 1
  FROM public.checklist_permission_grants g
  WHERE g.empresa_id = cpe.empresa_id
    AND g.checklist_key = cpe.checklist_key
    AND g.usuario_id = upe.usuario_id
    AND g.capacidad = c.capacidad
);

COMMIT;

-- -----------------------------------------------------------------------------
-- 3) TESTS DE SOLO LECTURA DESPUES DE MIGRAR
-- -----------------------------------------------------------------------------
WITH usuarios_por_empresa AS (
  SELECT ue.empresa_id, ue.usuario_id
  FROM public.usuario_empresas ue
  UNION
  SELECT u.empresa_id, u.id
  FROM public.usuarios u
  WHERE u.empresa_id IS NOT NULL
), checklists_por_empresa AS (
  SELECT DISTINCT n.empresa_id, n.checklist_key
  FROM public.checklist_navigation_nodes n
  WHERE n.checklist_key IS NOT NULL
), capacidades(capacidad) AS (
  VALUES ('ver'), ('crear'), ('editar_borrador'), ('finalizar')
)
SELECT COUNT(*) AS grants_faltantes
FROM checklists_por_empresa cpe
JOIN usuarios_por_empresa upe ON upe.empresa_id = cpe.empresa_id
CROSS JOIN capacidades c
WHERE NOT EXISTS (
  SELECT 1
  FROM public.checklist_permission_grants g
  WHERE g.empresa_id = cpe.empresa_id
    AND g.checklist_key = cpe.checklist_key
    AND g.usuario_id = upe.usuario_id
    AND g.capacidad = c.capacidad
  );
-- Esperado: grants_faltantes = 0.

SELECT empresa_id, checklist_key, usuario_id, capacidad, COUNT(*) AS duplicados
FROM public.checklist_permission_grants
WHERE usuario_id IS NOT NULL
GROUP BY empresa_id, checklist_key, usuario_id, capacidad
HAVING COUNT(*) > 1;
-- Esperado: 0 filas.

SELECT e.nombre AS empresa, u.nombre_completo AS usuario,
       g.checklist_key, COUNT(*) AS capacidades,
       BOOL_OR(g.capacidad = 'ver') AS puede_ver
FROM public.checklist_permission_grants g
JOIN public.empresas e ON e.id = g.empresa_id
JOIN public.usuarios u ON u.id = g.usuario_id
WHERE e.nombre ILIKE '%M&S%'
   OR e.nombre ILIKE '%M & S%'
   OR e.nombre ILIKE '%MyS%'
GROUP BY e.nombre, u.nombre_completo, g.checklist_key
ORDER BY u.nombre_completo, g.checklist_key;
-- Esperado para M&S: una fila por usuario/checklist, capacidades = 4 y
-- puede_ver = true.
