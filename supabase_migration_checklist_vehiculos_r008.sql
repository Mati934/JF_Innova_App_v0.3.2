-- =============================================================================
-- MIGRACIÓN: Checklist R-008 "Chequeo Vehículos Livianos"
-- Ejecutar en Supabase SQL Editor.
--
-- Reutiliza el módulo "Registro de Visita" (R-003). Para aparecer en el
-- dropdown "Tipo de Actividad" el `tipo_actividad` debe empezar con
-- "VISITA_" (ver LocalVisitRepository.getTiposChecklistVisita).
--
-- Convención del proyecto: VISITA_R0XX
--   - R-005 → VISITA_R005 (Condiciones Eléctricas)
--   - R-006 → VISITA_R006 (Pisos y Superficies)
--   - R-008 → VISITA_R008 (Chequeo Vehículos Livianos)  ← este archivo
--   - R-011 → VISITA_R011 (Chequeo Máquina Soldadora)
-- =============================================================================

-- 1. Limpieza idempotente del seed para este tipo
DELETE FROM formulario_items WHERE tipo_actividad = 'VISITA_R008';

-- 2. Seed de las 20 preguntas del formato R-008 (orden = N° de la planilla)
INSERT INTO formulario_items
  (id, tipo_actividad, categoria, pregunta, criticidad, orden, activo, peso)
VALUES
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Documentos del vehículo y del conductor vigentes y presentes en la inspección', 'Intolerable', 1,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'La carrocería en general está en buen estado',                                   'Medio',       2,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Se observa parabrisas sin fisuras o trizado',                                    'Alto',        3,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Se observan espejos retrovisores en buen estado',                                'Alto',        4,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Se observa limpieza del vehículo por dentro y por fuera',                        'Bajo',        5,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Placas patentes en buen estado y visibles',                                      'Alto',        6,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Luces altas y bajas operativas',                                                 'Alto',        7,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Luces de freno operativas',                                                      'Alto',        8,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Luces intermitentes operativas',                                                 'Alto',        9,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Luces de retroceso operativas',                                                  'Alto',        10, true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Luces de emergencia operativas',                                                 'Alto',        11, true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Se observan neumáticos con presión adecuada y buen estado',                      'Intolerable', 12, true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Se cuenta con rueda de repuesto en buen estado',                                 'Alto',        13, true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Se cuenta con llaves, gata hidráulica y herramientas disponibles para cambio de rueda', 'Alto', 14, true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Se observa botiquín, extintor, triángulo y chaleco reflectante operativos y en buen estado', 'Intolerable', 15, true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Están los niveles adecuados de aceite, líquido de freno, refrigerante, limpia parabrisas, otros', 'Alto', 16, true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Se observan todos los cinturones de seguridad operativos',                       'Intolerable', 17, true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Bocina y tablero del vehículo están operativos',                                 'Medio',       18, true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Tablero no marca alertas de advertencia',                                        'Alto',        19, true, 1.0),
  (gen_random_uuid(), 'VISITA_R008', 'Chequeo Vehículos Livianos',
   'Aire acondicionado disponible y operativo',                                      'Bajo',        20, true, 1.0);

-- =============================================================================
-- VERIFICACIÓN
-- =============================================================================
-- SELECT orden, pregunta, criticidad
--   FROM formulario_items
--  WHERE tipo_actividad = 'VISITA_R008'
--  ORDER BY orden;
--
-- En la app: "Registro de Visita" → dropdown "Tipo de Actividad" →
-- "Chequeo Vehículos Livianos". Mantener apagado el switch "Actividades
-- realizadas" para que no salga ese bloque en el PDF.
