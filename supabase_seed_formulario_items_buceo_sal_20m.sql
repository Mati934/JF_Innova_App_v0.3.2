-- =============================================================================
-- SEED SOLO formulario_items: BUCEO_SAL_20M
-- Ejecuta este archivo si quieres poblar checklist directo en formulario_items.
-- =============================================================================

BEGIN;

DELETE FROM public.formulario_items
WHERE tipo_actividad = 'BUCEO_SAL_20M';

WITH base_items(tipo_actividad, categoria, pregunta, criticidad, orden, activo, peso) AS (
  VALUES
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Compresor de buceo profesional de baja presión, con entrega mínima de 115 lt/min y 8 bar para un buzo hasta 20 m.', 'Intolerable', 10, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Motor combustión en buen estado, sin filtración, piola de arranque en buen estado.', 'Alto', 20, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Nivel de aceite motor y cabezal en buen estado.', 'Alto', 30, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Estanque acumulador en buen estado, limpio y sin partículas en su interior.', 'Alto', 40, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Compresor con filtros de purificación de aire en buen estado y no saturados.', 'Intolerable', 50, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Partes móviles del compresor protegidas.', 'Alto', 60, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Correas de transmisión en buen estado sin desgaste.', 'Alto', 70, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Filtros de aspiración de aire en buen estado, no saturados ni húmedos, orientados a barlovento.', 'Intolerable', 80, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Manguera de toma de aire atóxica y en buen estado, sin desgaste ni rotura.', 'Intolerable', 90, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Válvula de alivio cabezal en buen estado sin filtración.', 'Alto', 100, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Válvula de seguridad en buen estado y regulada a 8 bar mínimo.', 'Intolerable', 110, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Válvula corte rápido en buen estado a la salida del acumulador.', 'Alto', 120, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Manguera de alta presión operativa, sin desgaste ni rotura.', 'Intolerable', 130, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Válvula de retención operativa y en buen estado.', 'Alto', 140, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Válvula de despiche acumulador operativa, sin filtración.', 'Alto', 150, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Manómetro operativo (números legibles, vidrio en buen estado, aguja funcional).', 'Alto', 160, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Niples y conectores de compresor general sin corrosión y en buen estado.', 'Alto', 170, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Mosquetón de acero inoxidable.', 'Medio', 180, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Manillas adecuadas para transporte.', 'Medio', 190, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Ruedas en buen estado.', 'Medio', 200, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Bandera alfa disponible.', 'Intolerable', 210, true, 1.0),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Otros elementos de apoyo verificados.', 'Bajo', 220, true, 1.0),

  ('BUCEO_SAL_20M', 'Manguera de buceo', 'Buen estado visual.', 'Intolerable', 300, true, 1.0),
  ('BUCEO_SAL_20M', 'Manguera de buceo', 'Cumple marcas reglamentarias cada 10 m.', 'Intolerable', 310, true, 1.0),
  ('BUCEO_SAL_20M', 'Manguera de buceo', 'Sin roturas ni rayas en sus tramos.', 'Intolerable', 320, true, 1.0),
  ('BUCEO_SAL_20M', 'Manguera de buceo', 'Válvula de retención en buen estado.', 'Alto', 330, true, 1.0),
  ('BUCEO_SAL_20M', 'Manguera de buceo', 'Apta para continuar su uso en faena.', 'Intolerable', 340, true, 1.0),

  ('BUCEO_SAL_20M', 'Emergencia', 'Botiquín de primeros auxilios básico.', 'Intolerable', 400, true, 1.0),
  ('BUCEO_SAL_20M', 'Emergencia', 'Procedimiento o Manual de Primeros Auxilios (plastificado).', 'Intolerable', 410, true, 1.0),
  ('BUCEO_SAL_20M', 'Emergencia', 'Unidad de O2 medicinal para emergencia.', 'Intolerable', 420, true, 1.0),
  ('BUCEO_SAL_20M', 'Emergencia', 'Tablas de Descompresión plastificadas (I a V).', 'Intolerable', 430, true, 1.0),

  ('BUCEO_SAL_20M', 'Documentos', 'Permiso de buceo autorizado por la AAMM.', 'Intolerable', 500, true, 1.0),
  ('BUCEO_SAL_20M', 'Documentos', 'Matrículas del personal de buzos vigentes.', 'Intolerable', 510, true, 1.0),
  ('BUCEO_SAL_20M', 'Documentos', 'Matrícula del compresor vigente.', 'Intolerable', 520, true, 1.0),
  ('BUCEO_SAL_20M', 'Documentos', 'Plan de contingencia en caso de accidentes de buceo.', 'Intolerable', 530, true, 1.0),
  ('BUCEO_SAL_20M', 'Documentos', 'Resolución de autorización del plan de contingencia o carta de entrega.', 'Intolerable', 540, true, 1.0),
  ('BUCEO_SAL_20M', 'Documentos', 'Bitácora de buceo y lista de chequeo diaria de faena.', 'Alto', 550, true, 1.0),
  ('BUCEO_SAL_20M', 'Documentos', 'Bitácora de mantención del compresor u otro respaldo de trazabilidad.', 'Alto', 560, true, 1.0),
  ('BUCEO_SAL_20M', 'Documentos', 'Exámenes pre/ocupacionales por buzo aptos.', 'Intolerable', 570, true, 1.0),
  ('BUCEO_SAL_20M', 'Documentos', 'Registro de entrega de EPP para buceo y trabajo en superficie.', 'Alto', 580, true, 1.0)
),
personal_items(tipo_actividad, categoria, pregunta, criticidad, orden, activo, peso) AS (
  SELECT
    'BUCEO_SAL_20M',
    'Personal por buzo',
    format('%s (BUZO %s)', p.pregunta_base, b.buzo_idx),
    'Medio',
    (600 + (p.orden_base * 10) + b.buzo_idx),
    true,
    1.0
  FROM (
    VALUES
      ('Traje de buceo en buen estado', 1),
      ('Botines de buceo', 2),
      ('Slip de buceo (Opcional)', 3),
      ('Polera de buceo (Opcional)', 4),
      ('Calcetas de buceo (Opcional)', 5),
      ('Guantes de protección', 6),
      ('Cuchillos de buceo, sin punta, con amarre y funda', 7),
      ('Computador de buceo o profundímetro digital operativo', 8),
      ('Regulador de buceo con chicote (buen estado)', 9),
      ('Arnés con hebilla de escape rápido en buen estado', 10),
      ('Caperuza', 11)
  ) AS p(pregunta_base, orden_base)
  CROSS JOIN (SELECT generate_series(1, 4) AS buzo_idx) b
),
all_items AS (
  SELECT * FROM base_items
  UNION ALL
  SELECT * FROM personal_items
)
INSERT INTO public.formulario_items
  (id, tipo_actividad, categoria, pregunta, criticidad, orden, activo, peso)
SELECT
  gen_random_uuid(),
  tipo_actividad,
  categoria,
  pregunta,
  CASE
    WHEN criticidad IN ('Bajo', 'Baja') THEN 'Bajo'::nivel_criticidad
    WHEN criticidad IN ('Medio', 'Media', 'Moderado') THEN 'Medio'::nivel_criticidad
    WHEN criticidad IN ('Alto', 'Alta') THEN 'Alto'::nivel_criticidad
    WHEN criticidad = 'Intolerable' THEN 'Intolerable'::nivel_criticidad
    ELSE 'Medio'::nivel_criticidad
  END,
  orden,
  activo,
  peso
FROM all_items;

COMMIT;

-- Verificación
-- SELECT tipo_actividad, categoria, orden, pregunta
-- FROM public.formulario_items
-- WHERE tipo_actividad = 'BUCEO_SAL_20M'
-- ORDER BY orden;