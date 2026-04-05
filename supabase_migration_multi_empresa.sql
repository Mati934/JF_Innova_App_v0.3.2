-- =============================================================================
-- MIGRACIÓN: Multi-Empresa + Módulos Configurables
-- Ejecutar en Supabase SQL Editor - EN ORDEN, paso por paso
-- =============================================================================

-- =============================================================================
-- PASO 1: Crear tabla empresa_modulos
-- =============================================================================
CREATE TABLE IF NOT EXISTS empresa_modulos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  modulo_key TEXT NOT NULL,
  habilitado BOOLEAN NOT NULL DEFAULT true,
  orden INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(empresa_id, modulo_key)
);

-- =============================================================================
-- PASO 2: Crear tabla usuario_empresas
-- =============================================================================
CREATE TABLE IF NOT EXISTS usuario_empresas (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(usuario_id, empresa_id)
);

-- =============================================================================
-- PASO 3: Migrar datos legacy (usuarios que ya tienen empresa_id = Aquachile)
-- =============================================================================
INSERT INTO usuario_empresas (usuario_id, empresa_id)
SELECT id, empresa_id
FROM usuarios
WHERE empresa_id IS NOT NULL
ON CONFLICT (usuario_id, empresa_id) DO NOTHING;

-- =============================================================================
-- PASO 4: Crear empresa "JF Innova"
-- =============================================================================
INSERT INTO empresas (id, nombre)
VALUES (gen_random_uuid(), 'JF Innova')
ON CONFLICT DO NOTHING;

-- =============================================================================
-- PASO 5: Asignar TODOS los usuarios actuales a "JF Innova"
-- (además de Aquachile donde ya están por paso 3)
-- =============================================================================
INSERT INTO usuario_empresas (usuario_id, empresa_id)
SELECT u.id, e.id
FROM usuarios u
CROSS JOIN empresas e
WHERE e.nombre = 'JF Innova'
ON CONFLICT (usuario_id, empresa_id) DO NOTHING;

-- =============================================================================
-- PASO 6: Seed módulos default para TODAS las empresas
-- =============================================================================
INSERT INTO empresa_modulos (empresa_id, modulo_key, habilitado, orden)
SELECT e.id, m.key, true, m.ord
FROM empresas e
CROSS JOIN (VALUES
  ('INSPECCION', 0),
  ('VISITA_R003', 1),
  ('VISITA_R004', 2),
  ('RENDICIONES', 3)
) AS m(key, ord)
ON CONFLICT (empresa_id, modulo_key) DO NOTHING;

-- =============================================================================
-- VERIFICACIÓN: ejecuta estas queries para confirmar que todo quedó bien
-- =============================================================================

-- Ver empresas:
-- SELECT id, nombre FROM empresas;

-- Ver asignaciones usuario-empresa:
-- SELECT ue.id, u.nombre_completo, e.nombre as empresa
-- FROM usuario_empresas ue
-- JOIN usuarios u ON u.id = ue.usuario_id
-- JOIN empresas e ON e.id = ue.empresa_id
-- ORDER BY u.nombre_completo, e.nombre;

-- Ver módulos por empresa:
-- SELECT e.nombre as empresa, em.modulo_key, em.habilitado, em.orden
-- FROM empresa_modulos em
-- JOIN empresas e ON e.id = em.empresa_id
-- ORDER BY e.nombre, em.orden;
