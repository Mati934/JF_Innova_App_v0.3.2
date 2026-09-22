-- ============================================================
-- MIGRACIÓN: empresa_areas (N:N entre empresas y areas)
-- Ejecutar en Supabase ANTES de actualizar la app Flutter
-- ============================================================

-- 1. Crear tabla junction
CREATE TABLE IF NOT EXISTS empresa_areas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  area_id UUID NOT NULL REFERENCES areas(id) ON DELETE CASCADE,
  UNIQUE(empresa_id, area_id)
);

-- 2. Índices de performance
CREATE INDEX IF NOT EXISTS idx_empresa_areas_empresa
  ON empresa_areas(empresa_id);
CREATE INDEX IF NOT EXISTS idx_empresa_areas_area
  ON empresa_areas(area_id);

-- 3. Seed desde relación 1:N existente (areas.empresa_id)
INSERT INTO empresa_areas (empresa_id, area_id)
SELECT empresa_id, id FROM areas
WHERE empresa_id IS NOT NULL
ON CONFLICT (empresa_id, area_id) DO NOTHING;

-- 4. Todas las áreas visibles para TODAS las empresas (CROSS JOIN)
INSERT INTO empresa_areas (empresa_id, area_id)
SELECT e.id, a.id
FROM empresas e
CROSS JOIN areas a
ON CONFLICT (empresa_id, area_id) DO NOTHING;

-- 5. RLS (permitir lectura a usuarios autenticados)
ALTER TABLE empresa_areas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read empresa_areas"
  ON empresa_areas FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can insert empresa_areas"
  ON empresa_areas FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update empresa_areas"
  ON empresa_areas FOR UPDATE TO authenticated USING (true);

-- 6. Verificación
SELECT ea.empresa_id, e.nombre AS empresa, COUNT(*) AS area_count
FROM empresa_areas ea
JOIN empresas e ON e.id = ea.empresa_id
GROUP BY ea.empresa_id, e.nombre;
