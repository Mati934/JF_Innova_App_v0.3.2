-- =============================================================================
-- MIGRACIÓN: Checklist R-011 "Chequeo Máquina Soldadora"
-- Ejecutar en Supabase SQL Editor.
--
-- Este checklist se reutiliza dentro del módulo "Registro de Visita" (R-003).
-- Para que aparezca en el dropdown "Tipo de Actividad" del formulario de visita,
-- el `tipo_actividad` DEBE empezar con el prefijo "VISITA_" y no ser
-- "VISITA_R004" (ver LocalVisitRepository.getTiposChecklistVisita).
--
-- Convención usada en este proyecto: VISITA_R0XX
--   - R-005 → VISITA_R005 (Condiciones Eléctricas)
--   - R-006 → VISITA_R006 (Pisos y Superficies)
--   - R-011 → VISITA_R011 (Chequeo Máquina Soldadora)  ← este archivo
--
-- Recordatorio: junto con esto se asume que ya está aplicado
-- `supabase_migration_visitas_incluir_actividades.sql`, para que el bloque
-- "Actividades realizadas" del R-003 quede oculto por defecto al usar este
-- checklist (en la app solo se activa con el switch correspondiente).
-- =============================================================================

-- 1. Limpieza idempotente: si vuelves a correr el script, recreamos el seed.
--    (Se borra solo este tipo, no toca otros checklists).
DELETE FROM formulario_items WHERE tipo_actividad = 'VISITA_R011';

-- 2. Seed de las 16 preguntas del formato R-011 (orden = N° de la planilla)
INSERT INTO formulario_items
  (id, tipo_actividad, categoria, pregunta, criticidad, orden, activo, peso)
VALUES
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'En general soldadora está en buen estado',                              'Alto',        1,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'Porta electrodo en buen estado',                                        'Alto',        2,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'Pinzas a tierra en buen estado',                                        'Alto',        3,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'Carcaza de soldadora en buen estado',                                   'Medio',       4,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'Estado de enchufe en buen estado',                                      'Alto',        5,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'El cableado está en buen estado sin piquetes',                          'Alto',        6,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'Regulador de amperaje en buen estado',                                  'Medio',       7,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'Ventilador en buen estado',                                             'Medio',       8,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'Interruptor de encendido y apagado en buen estado',                     'Alto',        9,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'Se cuenta con los permisos de trabajo en caliente',                     'Intolerable', 10, true, 1.0),
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'Trabajador cuenta con capacitación en el uso de soldadora',             'Intolerable', 11, true, 1.0),
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'Áreas de trabajo sin presencia de elementos inflamables',               'Intolerable', 12, true, 1.0),
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'Se cuenta con extintor a mano y operativo',                             'Intolerable', 13, true, 1.0),
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'De ser necesario, se cuenta con biombos o similares',                   'Medio',       14, true, 1.0),
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'Equipamiento del soldador en buen estado',                              'Alto',        15, true, 1.0),
  (gen_random_uuid(), 'VISITA_R011', 'Chequeo Máquina Soldadora',
   'Operarios con todos sus elementos de protección personal',              'Intolerable', 16, true, 1.0);

-- =============================================================================
-- VERIFICACIÓN
-- =============================================================================
-- SELECT orden, pregunta, criticidad
--   FROM formulario_items
--  WHERE tipo_actividad = 'VISITA_R011'
--  ORDER BY orden;
--
-- Deberías ver las 16 preguntas en orden 1..16.
--
-- En la app: abre "Registro de Visita", elige en el dropdown
-- "Tipo de Actividad" la opción "Chequeo Máquina Soldadora" y deja el switch
-- "4. Actividades Realizadas" apagado para que el PDF NO incluya ese bloque.
