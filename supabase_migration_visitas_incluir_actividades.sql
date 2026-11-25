-- =============================================================================
-- MIGRACIÓN: Bloque "Actividades realizadas" opcional en Registro de Visita (R-003)
-- Ejecutar en Supabase SQL Editor.
--
-- Motivo:
--   El formulario R-003 (Registro de Visita) trae 9 checkboxes de
--   "Actividades realizadas" (reunión, capacitación, charla, etc.). Esa
--   sección NO aplica para las nuevas listas de chequeo reutilizables
--   (ej: R-011 Chequeo Máquina Soldadora). Para que el módulo se pueda
--   reutilizar sin contaminar el PDF, agregamos un flag explícito que
--   indica si el usuario decidió incluir el bloque.
--
--   - false / NULL → No se renderiza el bloque en el PDF y los checks
--                    quedan ignorados.
--   - true         → Se renderiza tal cual el formato R-003 original.
-- =============================================================================

-- 1. Agregar la columna (idempotente)
ALTER TABLE visitas_tecnicas
  ADD COLUMN IF NOT EXISTS incluir_actividades BOOLEAN NOT NULL DEFAULT false;

-- 2. Backfill: cualquier visita histórica que YA tenga al menos un check
--    marcado se considera "con bloque de actividades incluido" para no
--    cambiar la apariencia de PDFs ya emitidos al re-generarlos.
UPDATE visitas_tecnicas
   SET incluir_actividades = true
 WHERE incluir_actividades = false
   AND (
        COALESCE(check_reunion, false)
     OR COALESCE(check_instalacion_senaletica, false)
     OR COALESCE(check_capacitacion, false)
     OR COALESCE(check_visita_sso, false)
     OR COALESCE(check_charla, false)
     OR COALESCE(check_investigacion_incidente, false)
     OR COALESCE(check_inspeccion_sso, false)
     OR COALESCE(check_obs_conductual, false)
     OR COALESCE(check_otro, false)
   );

-- 3. Verificación rápida
-- SELECT id, empresa, incluir_actividades,
--        check_reunion, check_capacitacion, check_otro
--   FROM visitas_tecnicas
--  ORDER BY fecha_realizacion DESC
--  LIMIT 20;
