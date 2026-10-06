-- =============================================================================
-- MIGRACION V2: Normalizacion de checklist SAL/SAM (sin tocar migraciones previas)
-- Objetivo:
--   1) Eliminar preguntas legacy/no deseadas.
--   2) Dejar SAL y SAM con sus catálogos correctos.
--   3) Sincronizar espejo en formulario_items (compatibilidad).
--
-- Idempotente: se puede ejecutar multiples veces.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 0) Limpieza explicita de preguntas legacy conocidas
-- -----------------------------------------------------------------------------
    
WITH legacy_questions(pregunta) AS (
  VALUES
    ('Traje en buen estado'),
    ('Casco y comunicaciones operativas'),
    ('Compresor con mantencion vigente'),
    ('Filtros y purgas en condiciones'),
    ('Plan de contingencia disponible'),
    ('Bitacora y registros al dia'),
    ('Completar checklist específico SAM 36 m según procedimiento vigente.')
)
DELETE FROM public.buceo_equipamiento_items i
USING legacy_questions l
WHERE i.lista_codigo IN ('BUCEO_SAL_20M', 'BUCEO_SAM_36M')
  AND i.pregunta = l.pregunta;

WITH legacy_questions(pregunta) AS (
  VALUES
    ('Traje en buen estado'),
    ('Casco y comunicaciones operativas'),
    ('Compresor con mantencion vigente'),
    ('Filtros y purgas en condiciones'),
    ('Plan de contingencia disponible'),
    ('Bitacora y registros al dia'),
    ('Completar checklist específico SAM 36 m según procedimiento vigente.')
)
DELETE FROM public.formulario_items f
USING legacy_questions l
WHERE f.tipo_actividad IN ('BUCEO_SAL_20M', 'BUCEO_SAM_36M')
  AND f.pregunta = l.pregunta;

-- -----------------------------------------------------------------------------
-- 1) Catalogo canonico para SAL y SAM
--    Nota: Se replica estructura completa en ambas listas para evitar vacios.
-- -----------------------------------------------------------------------------
WITH lista_cfg(lista_codigo, categoria_apoyo) AS (
  VALUES
    ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros')
),
base_questions(categoria_key, pregunta, criticidad, peso, orden) AS (
  VALUES
    ('APOYO', 'Compresor de buceo profesional de baja presión, con entrega mínima de 115 lt/min y 8 bar para un buzo hasta 20 m.', 'Intolerable', 1, 10),
    ('APOYO', 'Motor combustión en buen estado, sin filtración, piola de arranque en buen estado.', 'Alto', 1, 20),
    ('APOYO', 'Nivel de aceite motor y cabezal en buen estado.', 'Alto', 1, 30),
    ('APOYO', 'Estanque acumulador en buen estado, limpio y sin partículas en su interior.', 'Alto', 1, 40),
    ('APOYO', 'Compresor con filtros de purificación de aire en buen estado y no saturados.', 'Intolerable', 1, 50),
    ('APOYO', 'Partes móviles del compresor protegidas.', 'Alto', 1, 60),
    ('APOYO', 'Correas de transmisión en buen estado sin desgaste.', 'Alto', 1, 70),
    ('APOYO', 'Filtros de aspiración de aire en buen estado, no saturados ni húmedos, orientados a barlovento.', 'Intolerable', 1, 80),
    ('APOYO', 'Manguera de toma de aire atóxica y en buen estado, sin desgaste ni rotura.', 'Intolerable', 1, 90),
    ('APOYO', 'Válvula de alivio cabezal en buen estado sin filtración.', 'Alto', 1, 100),
    ('APOYO', 'Válvula de seguridad en buen estado y regulada a 8 bar mínimo.', 'Intolerable', 1, 110),
    ('APOYO', 'Válvula corte rápido en buen estado a la salida del acumulador.', 'Alto', 1, 120),
    ('APOYO', 'Manguera de alta presión operativa, sin desgaste ni rotura.', 'Intolerable', 1, 130),
    ('APOYO', 'Válvula de retención operativa y en buen estado.', 'Alto', 1, 140),
    ('APOYO', 'Válvula de despiche acumulador operativa, sin filtración.', 'Alto', 1, 150),
    ('APOYO', 'Manómetro operativo (números legibles, vidrio en buen estado, aguja funcional).', 'Alto', 1, 160),
    ('APOYO', 'Niples y conectores de compresor general sin corrosión y en buen estado.', 'Alto', 1, 170),
    ('APOYO', 'Mosquetón de acero inoxidable.', 'Medio', 1, 180),
    ('APOYO', 'Manillas adecuadas para transporte.', 'Medio', 1, 190),
    ('APOYO', 'Ruedas en buen estado.', 'Medio', 1, 200),
    ('APOYO', 'Bandera alfa disponible.', 'Intolerable', 1, 210),
    ('APOYO', 'Otros elementos de apoyo verificados.', 'Bajo', 1, 220),

    ('MANGUERA', 'Buen estado visual.', 'Intolerable', 1, 300),
    ('MANGUERA', 'Cumple marcas reglamentarias cada 10 m.', 'Intolerable', 1, 310),
    ('MANGUERA', 'Sin roturas ni rayas en sus tramos.', 'Intolerable', 1, 320),
    ('MANGUERA', 'Válvula de retención en buen estado.', 'Alto', 1, 330),
    ('MANGUERA', 'Apta para continuar su uso en faena.', 'Intolerable', 1, 340),

    ('EMERGENCIA', 'Botiquín de primeros auxilios básico.', 'Intolerable', 1, 400),
    ('EMERGENCIA', 'Procedimiento o Manual de Primeros Auxilios (plastificado).', 'Intolerable', 1, 410),
    ('EMERGENCIA', 'Unidad de O2 medicinal para emergencia.', 'Intolerable', 1, 420),
    ('EMERGENCIA', 'Tablas de Descompresión plastificadas (I a V).', 'Intolerable', 1, 430),

    ('DOCUMENTOS', 'Permiso de buceo autorizado por la AAMM.', 'Intolerable', 1, 500),
    ('DOCUMENTOS', 'Matrículas del personal de buzos vigentes.', 'Intolerable', 1, 510),
    ('DOCUMENTOS', 'Matrícula del compresor vigente.', 'Intolerable', 1, 520),
    ('DOCUMENTOS', 'Plan de contingencia en caso de accidentes de buceo.', 'Intolerable', 1, 530),
    ('DOCUMENTOS', 'Resolución de autorización del plan de contingencia o carta de entrega.', 'Intolerable', 1, 540),
    ('DOCUMENTOS', 'Bitácora de buceo y lista de chequeo diaria de faena.', 'Alto', 1, 550),
    ('DOCUMENTOS', 'Bitácora de mantención del compresor u otro respaldo de trazabilidad.', 'Alto', 1, 560),
    ('DOCUMENTOS', 'Exámenes pre/ocupacionales por buzo aptos.', 'Intolerable', 1, 570),
    ('DOCUMENTOS', 'Registro de entrega de EPP para buceo y trabajo en superficie.', 'Alto', 1, 580)
),
personal_questions(pregunta_base, orden_base) AS (
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
),
base_expandido AS (
  SELECT
    l.lista_codigo,
    CASE b.categoria_key
      WHEN 'APOYO' THEN l.categoria_apoyo
      WHEN 'MANGUERA' THEN 'Manguera de buceo'
      WHEN 'EMERGENCIA' THEN 'Emergencia'
      WHEN 'DOCUMENTOS' THEN 'Documentos'
      ELSE 'General'
    END AS categoria,
    b.pregunta,
    false AS aplica_por_buzo,
    b.criticidad,
    b.peso,
    b.orden,
    true AS activo
  FROM lista_cfg l
  CROSS JOIN base_questions b
),
sam_direct_items(lista_codigo, categoria, pregunta, aplica_por_buzo, criticidad, peso, orden, activo) AS (
  VALUES
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Compresor de buceo profesional de baja presion, con entrega de volumen y presion, minima de 350 lt./min. y 13 bar respectivamente considerando la operacion de dos buzos, hasta una profundidad maxima de 36 metros', false, 'Intolerable', 1, 10, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Motor combustion en buen estado, sin filtracion, piola de arranque en buen estado.', false, 'Alto', 1, 20, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Nivel de aceite motor y cabezal en buen estado', false, 'Alto', 1, 30, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Estanque acumulador visualmente en buen estado sin golpes ni desgaste, limpio y sin particulas en su interior.', false, 'Alto', 1, 40, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Compresor cuenta con sistemas de filtros de purificacion de aire en buen estado y no saturados', false, 'Intolerable', 1, 50, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Partes moviles compresor protegidas', false, 'Alto', 1, 60, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Correas de transmision en buen estado sin desgaste.', false, 'Alto', 1, 70, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Filtros de aspiracion de aire en buen estado (no saturado/sin humedad o mojado) orientado a barlovento', false, 'Intolerable', 1, 80, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Manguera de toma de aire atoxica y en buen estado, sin desgaste o rotura.', false, 'Intolerable', 1, 90, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Valvula de alivio cabezal en buen estado sin filtracion', false, 'Alto', 1, 100, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Valvula de seguridad en buen estado y regulada a presion de trabajo de 13 bar como minimo.', false, 'Intolerable', 1, 110, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Valvula corte rapido en buen estado, salida del acumulador.', false, 'Alto', 1, 120, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Manguera de alta presion operativa, sin desgaste o rotura', false, 'Intolerable', 1, 130, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Valvula de retencion operativa y en buen estado', false, 'Alto', 1, 140, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Valvula de despiche acumulador operativo sin filtracion', false, 'Alto', 1, 150, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Manometro operativo (Numeros legibles, Buen estado esfera de vidrio, Aguja funciona)', false, 'Alto', 1, 160, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Niples y conectores de compresor general sin corrosion y en buen estado', false, 'Alto', 1, 170, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Banco auxiliar (botellas cargadas a alta presion) volumen minimo de 48 lt. y 204 bar. (sin corrosion ni filtracion)', false, 'Intolerable', 1, 180, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Panel de control de gases de superficie (consola) en buen estado sin corrosion ni filtracion', false, 'Alto', 1, 190, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Indicadores panel control de gases (manometros) Numeros legibles, Buen estado esfera de vidrio, Aguja funciona.', false, 'Alto', 1, 200, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Sistema de comunicaciones operativa, en buen estado y bateria cargada.', false, 'Intolerable', 1, 210, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Conectores bananas y hi-use 4 pin, en buen estado y operativos.', false, 'Alto', 1, 220, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Mascara facial con comunicaciones en buen estado, sin filtracion, purga operativa y con membrana, broches sin desgaste ni trizados.', false, 'Intolerable', 1, 230, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Umbilical en buen estado', false, 'Intolerable', 1, 240, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Latiguillo compresor 5M en buen estado niples sin corrosion ni filtracion', false, 'Alto', 1, 250, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Manifold Block Kirby Morgan en buen estado, sin corrosion, valvula de retencion operativa y sin filtracion', false, 'Alto', 1, 260, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Botellas de emergencia de 5ltrs con manometro y regulador 1 y 2 estado, operativos sin filtracion y cargadas.', false, 'Intolerable', 1, 270, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Arnes de buceo antienredo con hebilla de escape rapido en buen estado', false, 'Intolerable', 1, 280, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Mosqueton de acero inoxidable', false, 'Medio', 1, 290, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Manillas adecuadas para transporte', false, 'Medio', 1, 300, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Ruedas en buen estado', false, 'Medio', 1, 310, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Bandera alfa', false, 'Intolerable', 1, 320, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Otros', false, 'Bajo', 1, 330, true),
  ('BUCEO_SAM_36M', 'Manguera de buceo', 'Buen estado visual', false, 'Intolerable', 1, 400, true),
  ('BUCEO_SAM_36M', 'Manguera de buceo', 'Cumple con las marcas reglamentarias cada 10 m.', false, 'Intolerable', 1, 410, true),
  ('BUCEO_SAM_36M', 'Manguera de buceo', 'Cumple con no tener roturas y/o rayas en sus tramos', false, 'Intolerable', 1, 420, true),
  ('BUCEO_SAM_36M', 'Manguera de buceo', 'Valvula de retencion en buen estado', false, 'Alto', 1, 430, true),
  ('BUCEO_SAM_36M', 'Manguera de buceo', 'Apta para continuar su uso en faena', false, 'Intolerable', 1, 440, true),
  ('BUCEO_SAM_36M', 'Union compresora / manguera de buceo', 'Buen estado Niple de union', false, 'Alto', 1, 500, true),
  ('BUCEO_SAM_36M', 'Emergencia', 'Botiquin de primeros auxilios basico', false, 'Intolerable', 1, 600, true),
  ('BUCEO_SAM_36M', 'Emergencia', 'Procedimiento o Manual de 1 Auxilios (plastificado)', false, 'Intolerable', 1, 610, true),
  ('BUCEO_SAM_36M', 'Emergencia', 'Unidad de O2 medicinal para emergencia', false, 'Intolerable', 1, 620, true),
  ('BUCEO_SAM_36M', 'Emergencia', 'Tablas de Descompresion Plastificadas (I a V)', false, 'Intolerable', 1, 630, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Permiso de buceo autorizado por la AAMM', false, 'Intolerable', 1, 700, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Matriculas del personal de buzos vigentes', false, 'Intolerable', 1, 710, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Matricula del compresor vigente', false, 'Intolerable', 1, 720, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Plan de contingencia en caso de accidentes de buceo', false, 'Intolerable', 1, 730, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Resolucion de autorizacion del plan de contingencia o carta de entrega', false, 'Intolerable', 1, 740, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Bitacora de buceo y lista de chequeo diaria de faena', false, 'Alto', 1, 750, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Bitacora de mantencion del compresor u otro respaldo de trazabilidad', false, 'Alto', 1, 760, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Examenes pre/ocupacionales por buzo aptos', false, 'Intolerable', 1, 770, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Registro de entrega de EPP para buceo y trabajo en superficie', false, 'Alto', 1, 780, true)
),
personal_expandido AS (
  SELECT
    l.lista_codigo,
    'Checklist por buzo' AS categoria,
    format('%s (BUZO %s)', p.pregunta_base, b.buzo_idx)::TEXT AS pregunta,
    true AS aplica_por_buzo,
    'Medio' AS criticidad,
    1 AS peso,
    (600 + (p.orden_base * 10) + b.buzo_idx)::INTEGER AS orden,
    true AS activo
  FROM lista_cfg l
  CROSS JOIN personal_questions p
  CROSS JOIN (SELECT generate_series(1, 4) AS buzo_idx) b
),
canonical AS (
  SELECT * FROM base_expandido
  UNION ALL
  SELECT * FROM personal_expandido
  UNION ALL
  SELECT * FROM sam_direct_items
),
upsert_items AS (
  INSERT INTO public.buceo_equipamiento_items (
    lista_codigo,
    categoria,
    pregunta,
    aplica_por_buzo,
    criticidad,
    peso,
    orden,
    activo
  )
  SELECT
    c.lista_codigo,
    c.categoria,
    c.pregunta,
    c.aplica_por_buzo,
    c.criticidad,
    c.peso,
    c.orden,
    c.activo
  FROM canonical c
  ON CONFLICT (lista_codigo, pregunta)
  DO UPDATE SET
    categoria = EXCLUDED.categoria,
    aplica_por_buzo = EXCLUDED.aplica_por_buzo,
    criticidad = EXCLUDED.criticidad,
    peso = EXCLUDED.peso,
    orden = EXCLUDED.orden,
    activo = EXCLUDED.activo,
    updated_at = now()
  RETURNING 1
),
deactivate_extra AS (
  UPDATE public.buceo_equipamiento_items i
  SET activo = false,
      updated_at = now()
  WHERE i.lista_codigo IN ('BUCEO_SAL_20M', 'BUCEO_SAM_36M')
    AND NOT EXISTS (
      SELECT 1
      FROM canonical c
      WHERE c.lista_codigo = i.lista_codigo
        AND c.pregunta = i.pregunta
    )
  RETURNING 1
),
clear_formulario AS (
  DELETE FROM public.formulario_items
  WHERE tipo_actividad IN ('BUCEO_SAL_20M', 'BUCEO_SAM_36M')
  RETURNING 1
),
insert_formulario AS (
  INSERT INTO public.formulario_items
    (id, tipo_actividad, categoria, pregunta, criticidad, orden, activo, peso)
  SELECT
    gen_random_uuid(),
    c.lista_codigo,
    c.categoria,
    c.pregunta,
    CASE
      WHEN c.criticidad IN ('Bajo', 'Baja') THEN 'Bajo'::nivel_criticidad
      WHEN c.criticidad IN ('Medio', 'Media', 'Moderado') THEN 'Medio'::nivel_criticidad
      WHEN c.criticidad IN ('Alto', 'Alta') THEN 'Alto'::nivel_criticidad
      WHEN c.criticidad = 'Intolerable' THEN 'Intolerable'::nivel_criticidad
      ELSE 'Medio'::nivel_criticidad
    END,
    c.orden,
    c.activo,
    c.peso::numeric
  FROM canonical c
  RETURNING 1
)
SELECT 1;

COMMIT;

-- Verificacion sugerida:
-- SELECT lista_codigo, categoria, orden, pregunta, activo
-- FROM public.buceo_equipamiento_items
-- WHERE lista_codigo IN ('BUCEO_SAL_20M','BUCEO_SAM_36M')
-- ORDER BY lista_codigo, orden;
