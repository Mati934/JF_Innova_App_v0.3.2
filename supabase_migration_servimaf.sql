-- ============================================================
-- MIGRACIÓN: Empresa Servimaf + flag es_administradora
--            + todos los usuarios solo en AquaChile
-- Fecha: 2026-04-08
-- ============================================================

-- 1. Agregar columna es_administradora a empresas
ALTER TABLE empresas
ADD COLUMN es_administradora BOOLEAN NOT NULL DEFAULT false;

-- 2. Crear empresa Servimaf (única super-admin)
INSERT INTO empresas (id, nombre, rut, es_administradora)
VALUES (
  gen_random_uuid(),
  'Servimaf',
  NULL,
  true
);

-- 3. Borrar TODAS las relaciones usuario_empresas con JF Innova
DELETE FROM usuario_empresas
WHERE empresa_id = 'c45b61b1-f54a-4ce2-a1f0-17e2bd03302b';

-- 4. Asegurar que todos los usuarios estén en AquaChile
--    (ON CONFLICT para no duplicar los que ya están)
INSERT INTO usuario_empresas (id, usuario_id, empresa_id)
SELECT gen_random_uuid(), u.id, '88f539a7-8312-41e9-93ac-6b4470a274c3'
FROM usuarios u
WHERE NOT EXISTS (
  SELECT 1 FROM usuario_empresas ue
  WHERE ue.usuario_id = u.id
    AND ue.empresa_id = '88f539a7-8312-41e9-93ac-6b4470a274c3'
);

-- 5. Actualizar empresa_id legacy en usuarios → AquaChile
UPDATE usuarios
SET empresa_id = '88f539a7-8312-41e9-93ac-6b4470a274c3';

-- 6. Verificación
SELECT u.nombre_completo, e.nombre AS empresa
FROM usuario_empresas ue
JOIN usuarios u ON u.id = ue.usuario_id
JOIN empresas e ON e.id = ue.empresa_id
ORDER BY u.nombre_completo, e.nombre;
