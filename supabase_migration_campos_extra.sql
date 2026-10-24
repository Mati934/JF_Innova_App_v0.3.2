-- =============================================================================
-- MIGRACIÓN: Campos extra por checklist en Registro de Visita (R-003)
-- =============================================================================
-- Objetivo:
--   Cada checklist puede tener campos adicionales propios que no caben en el
--   formulario base R-003 (por ej. el R-008 Vehículos Livianos necesita
--   Patente, Kilometraje y Conductor).
--
--   Se modela como:
--     1. Tabla maestra `formulario_campos_extra` (qué campos pide cada tipo).
--     2. Columna jsonb `campos_extra` en `visitas_tecnicas` con los valores
--        ingresados (clave -> valor).
--
--   El JSON se sincroniza desde la app como string TEXT en SQLite y se sube
--   como jsonb a Supabase.
-- =============================================================================

-- 1. Tabla maestra de definiciones (master data, igual que formulario_items)
CREATE TABLE IF NOT EXISTS formulario_campos_extra (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_actividad  text    NOT NULL,
  clave           text    NOT NULL,        -- snake_case, se usa como key en el JSON
  label           text    NOT NULL,        -- texto que se muestra en UI/PDF
  tipo            text    NOT NULL DEFAULT 'texto',
                                            -- 'texto' | 'numero' | 'hora' | 'email'
  orden           integer NOT NULL DEFAULT 0,
  requerido       boolean NOT NULL DEFAULT false,
  activo          boolean NOT NULL DEFAULT true,
  UNIQUE (tipo_actividad, clave)
);

CREATE INDEX IF NOT EXISTS idx_formulario_campos_extra_tipo
  ON formulario_campos_extra (tipo_actividad)
  WHERE activo = true;

-- 2. Columna jsonb en la tabla de visitas
ALTER TABLE visitas_tecnicas
  ADD COLUMN IF NOT EXISTS campos_extra jsonb;

COMMENT ON COLUMN visitas_tecnicas.campos_extra IS
  'Valores de los campos específicos del checklist seleccionado (clave -> valor). '
  'Las definiciones viven en formulario_campos_extra.';

-- =============================================================================
-- 3. SEED: R-008 "Chequeo Vehículos Livianos"
--    Estos son los datos del encabezado del formato R-008 que NO existen en
--    el R-003 base (R-003 ya tiene Empresa, Profesional, Región, Centro,
--    Jefatura, Origen, Hora inicio/término y 2 correos de empresa).
-- =============================================================================

DELETE FROM formulario_campos_extra WHERE tipo_actividad = 'VISITA_R008';

INSERT INTO formulario_campos_extra
  (tipo_actividad, clave, label, tipo, orden, requerido, activo)
VALUES
  ('VISITA_R008', 'patente',     'Patente del vehículo', 'texto',  1, true,  true),
  ('VISITA_R008', 'kilometraje', 'Kilometraje',          'numero', 2, false, true),
  ('VISITA_R008', 'conductor',   'Conductor',            'texto',  3, true,  true);

-- =============================================================================
-- VERIFICACIÓN
-- =============================================================================
-- SELECT tipo_actividad, orden, clave, label, tipo, requerido
--   FROM formulario_campos_extra
--  WHERE activo = true
--  ORDER BY tipo_actividad, orden;
--
-- Para agregar campos a otro checklist solo inserta filas nuevas con su
-- tipo_actividad (ej. 'VISITA_R011') sin tocar la app.
