-- =============================================================================
-- MIGRACIÓN: Checklist R-012 "Listado Verificación Grúas Horquillas" (Hidroser)
-- Ejecutar en Supabase SQL Editor.
--
-- Reutiliza el módulo "Registro de Visita" (R-003): la app lo descubre solo
-- porque el `tipo_actividad` empieza con "VISITA_" (ver
-- LocalVisitRepository.getTiposChecklistVisita). NO requiere actualizar la app.
--
-- Convención del proyecto: VISITA_R0XX
--   - R-005 → VISITA_R005 (Condiciones Eléctricas)
--   - R-006 → VISITA_R006 (Pisos y Superficies)
--   - R-008 → VISITA_R008 (Chequeo Vehículos Livianos)
--   - R-011 → VISITA_R011 (Chequeo Máquina Soldadora)
--   - R-012 → VISITA_R012 (Listado Verificación Grúas Horquillas)  ← este archivo
--
-- PRE-REQUISITOS:
--   * supabase_migration_visitas_incluir_actividades.sql
--   * supabase_migration_campos_extra.sql  (para campos de cabecera propios)
--   * supabase_migration_peso_preguntas.sql (columna peso)
--
-- En la app: "Registro de Visita" → dropdown "Tipo de Actividad" →
--   "Listado Verificación Grúas Horquillas". Dejar apagado el switch
--   "Actividades realizadas" si Hidroser no necesita ese bloque en el PDF.
-- =============================================================================

-- 1. Limpieza idempotente del seed para este tipo
DELETE FROM formulario_items WHERE tipo_actividad = 'VISITA_R012';

-- 2. Seed de las 22 preguntas del formato R-012 (orden = N° de la planilla)
INSERT INTO formulario_items
  (id, tipo_actividad, categoria, pregunta, criticidad, orden, activo, peso)
VALUES
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Cilindro de gas en buenas condiciones',                                      'Intolerable', 1,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Afianzada a la estructura',                                                  'Intolerable', 2,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Alarma de retroceso en buen estado',                                         'Alto',        3,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Baliza en buen estado',                                                      'Alto',        4,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Luces delanteras en buen estado',                                            'Alto',        5,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Luces traseras en buen estado y funcionando',                                'Alto',        6,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Luces de retroceso funcionando',                                             'Alto',        7,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Espejos retrovisor en buen estado',                                          'Alto',        8,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Neumáticos en buen estado',                                                  'Intolerable', 9,  true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Extintor de 1 kg en buen estado',                                            'Intolerable', 10, true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Frenos de servicio funcionando y en buen estado',                            'Intolerable', 11, true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Dirección en buen estado',                                                   'Intolerable', 12, true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Orden y limpieza de grúas',                                                  'Bajo',        13, true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Torre de elevación sin daños',                                               'Intolerable', 14, true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Evidencia fugas de mangueras hidráulicas',                                   'Alto',        15, true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Freno de estacionamiento funcionando (freno de mano)',                       'Intolerable', 16, true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Vidrios en buen estado',                                                     'Medio',       17, true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Joystick en buen estado y operativo',                                        'Alto',        18, true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Espejos laterales en buen estado',                                           'Alto',        19, true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Rotador en buen estado y operativo',                                         'Alto',        20, true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Uñas en buen estado',                                                        'Intolerable', 21, true, 1.0),
  (gen_random_uuid(), 'VISITA_R012', 'Verificación Grúas Horquillas',
   'Plumillas en buen estado y operativas',                                      'Medio',       22, true, 1.0);

-- =============================================================================
-- 3. Campos extra propios del R-012 (cabecera Hidroser que no existe en R-003)
--    El R-003 ya aporta: Empresa, Profesional, Región, Centro, Jefatura,
--    Origen, Fecha, Hora inicio/término y correos. El R-012 además requiere
--    identificar la grúa y su horómetro.
-- =============================================================================

DELETE FROM formulario_campos_extra WHERE tipo_actividad = 'VISITA_R012';

INSERT INTO formulario_campos_extra
  (tipo_actividad, clave, label, tipo, orden, requerido, activo)
VALUES
  ('VISITA_R012', 'numero_grua',             'N° de Grúa',                'texto', 1, true,  true),
  ('VISITA_R012', 'hora_inicio_horometro',   'Hora inicio / Horómetro',   'texto', 2, false, true),
  ('VISITA_R012', 'hora_termino_horometro',  'Hora término / Horómetro',  'texto', 3, false, true);

-- =============================================================================
-- 4. Habilitar el módulo HIDROSER en `empresa_modulos` SOLO para la empresa
--    Hidroser (acepta variantes razonables del nombre). Si tu empresa se
--    llama distinto, ajusta el WHERE.
-- =============================================================================

INSERT INTO empresa_modulos (empresa_id, modulo_key, habilitado, orden)
SELECT e.id, 'HIDROSER', true, 50
FROM empresas e
WHERE e.nombre ILIKE 'Hidroser%'
   OR e.nombre ILIKE '%Hidroser Industrial%'
ON CONFLICT (empresa_id, modulo_key)
DO UPDATE SET habilitado = true;

-- =============================================================================
-- VERIFICACIÓN
-- =============================================================================
-- SELECT orden, pregunta, criticidad
--   FROM formulario_items
--  WHERE tipo_actividad = 'VISITA_R012'
--  ORDER BY orden;
--
-- SELECT orden, clave, label, tipo, requerido
--   FROM formulario_campos_extra
--  WHERE tipo_actividad = 'VISITA_R012' AND activo = true
--  ORDER BY orden;
--
-- SELECT e.nombre, em.modulo_key, em.habilitado
--   FROM empresa_modulos em
--   JOIN empresas e ON e.id = em.empresa_id
--  WHERE em.modulo_key = 'HIDROSER';
--
-- Deberías ver 22 preguntas, 3 campos extra y el módulo HIDROSER habilitado
-- para la(s) empresa(s) Hidroser.
