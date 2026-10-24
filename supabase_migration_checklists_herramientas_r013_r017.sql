-- =============================================================================
-- CHECK + MIGRACION + TESTS
-- Nuevas listas de chequeo R-013 a R-017
--
-- Ejecutar manualmente en Supabase SQL Editor. Los archivos .sql del repo no
-- se aplican automaticamente.
--
-- Permiso/restriccion en la app: VISITA_R003 (Registro de Visita).
-- Claves persistibles descriptivas (compatibles con la app ya instalada):
--   VISITA_CHEQUEO_HERRAMIENTAS_MANUALES
--   VISITA_CHEQUEO_SOLDADORA_AL_ARCO
--   VISITA_CHEQUEO_TALADRO_DESTORNILLADOR
--   VISITA_CHEQUEO_ESMERIL_ANGULAR
--   VISITA_CHEQUEO_EXTENSION_ELECTRICA
--
-- Esta migracion NO reemplaza, elimina ni desactiva checklists existentes.
--
-- COMO EJECUTAR ESTE ARCHIVO
-- Opcion simple recomendada:
--   1. Abre este archivo completo en Supabase SQL Editor.
--   2. Presiona Ctrl+A para seleccionar TODO.
--   3. Presiona Run UNA SOLA VEZ.
-- El check, la migracion, los tests y el resultado final se ejecutaran en orden.
--
-- Opcion por etapas:
--   PASO A: ejecuta por separado solo la seccion 0 (CHECK PREVIO).
--   PASO B: ejecuta TODO JUNTO desde BEGIN; hasta COMMIT; inclusive.
--   PASO C: ejecuta por separado solo la seccion 3 (RESULTADO FINAL).
-- Nunca ejecutes lineas internas aisladas del PASO B.
-- =============================================================================

-- =============================================================================
-- 0) CHECK PREVIO DE SOLO LECTURA
-- PASO A: ESTE BLOQUE SE PUEDE EJECUTAR POR SEPARADO.
--
-- Ejecuta primero solo esta seccion.
-- Resultado esperado antes de la primera aplicacion:
--   * formulario_items existe y muestra las 8 columnas requeridas.
--   * La segunda consulta devuelve 5 filas con total_filas = 0.
--   * R011 permanece visible como referencia; no sera modificada.
-- Si alguna clave nueva o R013-R017 ya tiene filas, revisa antes de continuar.
-- =============================================================================

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'formulario_items'
  AND column_name IN (
    'id', 'tipo_actividad', 'categoria', 'pregunta',
    'criticidad', 'orden', 'activo', 'peso'
  )
ORDER BY ordinal_position;

WITH codigos(tipo_actividad, nombre) AS (
  VALUES
    ('VISITA_CHEQUEO_HERRAMIENTAS_MANUALES', 'Chequeo de Herramientas Manuales'),
    ('VISITA_CHEQUEO_SOLDADORA_AL_ARCO', 'Chequeo de Soldadora al Arco'),
    ('VISITA_CHEQUEO_TALADRO_DESTORNILLADOR', 'Chequeo de Taladro Destornillador'),
    ('VISITA_CHEQUEO_ESMERIL_ANGULAR', 'Chequeo de Esmeril Angular'),
    ('VISITA_CHEQUEO_EXTENSION_ELECTRICA', 'Chequeo de Extensión Eléctrica')
)
SELECT
  c.tipo_actividad,
  c.nombre,
  COUNT(fi.id) AS total_filas,
  COUNT(fi.id) FILTER (WHERE COALESCE(fi.activo, true)) AS filas_activas
FROM codigos c
LEFT JOIN public.formulario_items fi
  ON fi.tipo_actividad = c.tipo_actividad
GROUP BY c.tipo_actividad, c.nombre
ORDER BY c.tipo_actividad;

SELECT tipo_actividad, COUNT(*) AS filas_legacy
FROM public.formulario_items
WHERE tipo_actividad IN (
  'VISITA_R013', 'VISITA_R014', 'VISITA_R015',
  'VISITA_R016', 'VISITA_R017'
)
GROUP BY tipo_actividad
ORDER BY tipo_actividad;

SELECT tipo_actividad, COUNT(*) AS filas, MIN(orden) AS primer_orden,
       MAX(orden) AS ultimo_orden
FROM public.formulario_items
WHERE tipo_actividad = 'VISITA_R011'
GROUP BY tipo_actividad;

-- =============================================================================
-- 1) MIGRACION
-- PASO B: EJECUTAR TODO JUNTO DESDE BEGIN HASTA COMMIT INCLUSIVE.
-- NO EJECUTAR LAS SENTENCIAS INTERNAS UNA POR UNA.
-- =============================================================================

BEGIN;

-- Esta sentencia es autocontenida: no depende de tablas temporales ni de que
-- Supabase reutilice la misma conexion entre ejecuciones.
WITH nuevos(tipo_legacy, categoria, orden, pregunta, criticidad) AS (
VALUES
  -- R-013: 20 items
  ('VISITA_R013', 'Herramientas Manuales', 1,
   'Caja de herramientas en buen estado', 'Medio'),
  ('VISITA_R013', 'Herramientas Manuales', 2,
  'Multímetro digital en buen estado', 'Intolerable'),
  ('VISITA_R013', 'Herramientas Manuales', 3,
   'Juego destornilladores de paleta disponibles y en buen estado', 'Alto'),
  ('VISITA_R013', 'Herramientas Manuales', 4,
   'Juego destornilladores de cruz disponibles y en buen estado', 'Alto'),
  ('VISITA_R013', 'Herramientas Manuales', 5,
   'Cuchillo cartonero disponible y en buen estado', 'Intolerable'),
  ('VISITA_R013', 'Herramientas Manuales', 6,
   'Huincha de medir en buen estado', 'Medio'),
  ('VISITA_R013', 'Herramientas Manuales', 7,
   'Llave francesa (ajustable) disponible y en buen estado', 'Alto'),
  ('VISITA_R013', 'Herramientas Manuales', 8,
   'Llave inglesa disponible y en buen estado', 'Alto'),
  ('VISITA_R013', 'Herramientas Manuales', 9,
   'Alicate corte diagonal disponible y en buen estado', 'Alto'),
  ('VISITA_R013', 'Herramientas Manuales', 10,
   'Alicate de punta disponible y en buen estado', 'Alto'),
  ('VISITA_R013', 'Herramientas Manuales', 11,
   'Alicate universal disponible y en buen estado', 'Alto'),
  ('VISITA_R013', 'Herramientas Manuales', 12,
   'Linterna en buen estado y operativa', 'Medio'),
  ('VISITA_R013', 'Herramientas Manuales', 13,
   'Juego de llaves Allen disponibles', 'Alto'),
  ('VISITA_R013', 'Herramientas Manuales', 14,
   'Juego de dados disponibles', 'Alto'),
  ('VISITA_R013', 'Herramientas Manuales', 15,
   'Tijeras en buen estado y operativas', 'Alto'),
  ('VISITA_R013', 'Herramientas Manuales', 16,
   'Juego de llaves punta corona disponibles', 'Alto'),
  ('VISITA_R013', 'Herramientas Manuales', 17,
   'Martillo en buen estado', 'Alto'),
  ('VISITA_R013', 'Herramientas Manuales', 18,
   'Lima plana en buen estado', 'Medio'),
  ('VISITA_R013', 'Herramientas Manuales', 19,
   'Prensa', 'Alto'),
  ('VISITA_R013', 'Herramientas Manuales', 20,
   'Sierra en buen estado y operativa', 'Intolerable'),

  -- R-014: 13 items
  ('VISITA_R014', 'Soldadora al Arco', 1,
   'Soldadora se encuentra en buen estado general', 'Alto'),
  ('VISITA_R014', 'Soldadora al Arco', 2,
   'Carcaza de soldadora se encuentra en buen estado', 'Alto'),
  ('VISITA_R014', 'Soldadora al Arco', 3,
  'Manilla de sujeción está en buen estado', 'Alto'),
  ('VISITA_R014', 'Soldadora al Arco', 4,
  'Luz indicadora de equipo encendido está operativa', 'Medio'),
  ('VISITA_R014', 'Soldadora al Arco', 5,
  'Porta electrodo está en buen estado y operativo', 'Intolerable'),
  ('VISITA_R014', 'Soldadora al Arco', 6,
   'Cableado de porta electrodo se encuentra en buen estado', 'Intolerable'),
  ('VISITA_R014', 'Soldadora al Arco', 7,
  'Pinzas a tierra están en buen estado y operativas', 'Intolerable'),
  ('VISITA_R014', 'Soldadora al Arco', 8,
   'Cableado de las pinzas a tierra se encuentra en buen estado', 'Intolerable'),
  ('VISITA_R014', 'Soldadora al Arco', 9,
  'El cable de alimentación se encuentra en buen estado a lo largo de su extensión',
   'Intolerable'),
  ('VISITA_R014', 'Soldadora al Arco', 10,
  'Enchufe se encuentra en buen estado, sin decoloración o quemado',
   'Intolerable'),
  ('VISITA_R014', 'Soldadora al Arco', 11,
  'Regulador de amperaje está en buen estado y operativo', 'Alto'),
  ('VISITA_R014', 'Soldadora al Arco', 12,
   'Sistema ventilador se encuentra en buen estado y operativo', 'Alto'),
  ('VISITA_R014', 'Soldadora al Arco', 13,
   'Interruptor de encendido y apagado se encuentra operativo y en buen estado',
   'Alto'),

  -- R-015: 13 items
  ('VISITA_R015', 'Taladro Destornillador', 1,
   'Se encuentra en buen estado general', 'Alto'),
  ('VISITA_R015', 'Taladro Destornillador', 2,
  'Mango y empuñaduras están en buen estado', 'Alto'),
  ('VISITA_R015', 'Taladro Destornillador', 3,
  'Sistema de apriete de brocas está operativo', 'Alto'),
  ('VISITA_R015', 'Taladro Destornillador', 4,
   'Gatillo se encuentra en buen estado y operativo', 'Alto'),
  ('VISITA_R015', 'Taladro Destornillador', 5,
  'Botón o rueda selectora de marcha o función en buen estado y operativa',
   'Medio'),
  ('VISITA_R015', 'Taladro Destornillador', 6,
  'El cable de alimentación se encuentra en buen estado a lo largo de su extensión',
   'Intolerable'),
  ('VISITA_R015', 'Taladro Destornillador', 7,
  'Entrada del cable de alimentación del taladro está en buen estado',
   'Intolerable'),
  ('VISITA_R015', 'Taladro Destornillador', 8,
  'En caso de ser inalámbrico, baterías de alimentación se encuentra en buen estado',
   'Alto'),
  ('VISITA_R015', 'Taladro Destornillador', 9,
  'En caso de ser inalámbrico, cargador de baterías se encuentra en buen estado',
   'Intolerable'),
  ('VISITA_R015', 'Taladro Destornillador', 10,
   'Sistema de bloqueo se encuentra operativo', 'Alto'),
  ('VISITA_R015', 'Taladro Destornillador', 11,
  'Brocas o puntas Phillips están en buen estado y son las adecuadas', 'Alto'),
  ('VISITA_R015', 'Taladro Destornillador', 12,
   'Es la herramienta indicada para la tarea que estoy desarrollando', 'Alto'),
  ('VISITA_R015', 'Taladro Destornillador', 13,
   'Al hacer funcionar el destornillador funciona de manera adecuada', 'Alto'),

  -- R-016: 16 items
  ('VISITA_R016', 'Esmeril Angular', 1,
   'Esmeril se encuentra en buen estado general', 'Alto'),
  ('VISITA_R016', 'Esmeril Angular', 2,
   'Se cuenta con mango en buen estado, incluido el mango auxiliar', 'Alto'),
  ('VISITA_R016', 'Esmeril Angular', 3,
  'Cuenta con carcasa protectora de disco y proyección de partículas',
   'Intolerable'),
  ('VISITA_R016', 'Esmeril Angular', 4,
  'El cable de alimentación se encuentra en buen estado a lo largo de su extensión',
   'Intolerable'),
  ('VISITA_R016', 'Esmeril Angular', 5,
  'Entrada del cable de alimentación del esmeril está en buen estado',
   'Intolerable'),
  ('VISITA_R016', 'Esmeril Angular', 6,
  'Enchufe se encuentra en buen estado, sin decoloración o quemado',
   'Intolerable'),
  ('VISITA_R016', 'Esmeril Angular', 7,
  'Sistema de regulación de la carcasa está en buenas condiciones',
   'Intolerable'),
  ('VISITA_R016', 'Esmeril Angular', 8,
   'Interruptor de encendido y apagado se encuentra operativo y en buen estado',
   'Alto'),
  ('VISITA_R016', 'Esmeril Angular', 9,
  'Botón de corte continuo se encuentra en buen estado y operativo (en caso de contar con él)',
   'Intolerable'),
  ('VISITA_R016', 'Esmeril Angular', 10,
  'Tuerca de fijación de los discos están en buenas condiciones', 'Intolerable'),
  ('VISITA_R016', 'Esmeril Angular', 11,
   'El o los discos a utilizar o que estoy utilizando son los adecuados para el esmeril angular',
   'Intolerable'),
  ('VISITA_R016', 'Esmeril Angular', 12,
   'El o los discos a utilizar o que estoy utilizando son los adecuados para la tarea',
   'Intolerable'),
  ('VISITA_R016', 'Esmeril Angular', 13,
  'El o los discos a utilizar o que estoy utilizando están en buenas condiciones',
   'Intolerable'),
  ('VISITA_R016', 'Esmeril Angular', 14,
  'En caso de usar batería como fuente de alimentación, se encuentra en buen estado',
   'Alto'),
  ('VISITA_R016', 'Esmeril Angular', 15,
  'El cableado del esmeril está en buen estado, no tiene piquetes u otros',
   'Intolerable'),
  ('VISITA_R016', 'Esmeril Angular', 16,
   'Es la herramienta indicada para la tarea que estoy desarrollando', 'Alto'),

  -- R-017: 10 items (la ultima fila vacia del Word se omite)
  ('VISITA_R017', 'Extensión Eléctrica', 1,
   'Cableado se encuentra en buen estado en toda su extensión', 'Intolerable'),
  ('VISITA_R017', 'Extensión Eléctrica', 2,
   'En general la cubierta exterior está en buen estado y sin restos de aceites, grasas o suciedad excesiva',
   'Alto'),
  ('VISITA_R017', 'Extensión Eléctrica', 3,
   'No se visualiza cableado interior suelto o expuesto', 'Intolerable'),
  ('VISITA_R017', 'Extensión Eléctrica', 4,
   'Enchufe no está quebrado o suelto', 'Intolerable'),
  ('VISITA_R017', 'Extensión Eléctrica', 5,
   'No hay signos de sobrecalentamiento (olor a quemado o decoloración)',
   'Intolerable'),
  ('VISITA_R017', 'Extensión Eléctrica', 6,
   'Clavijas del enchufe (enchufe macho) están rectas y sin deformación',
   'Intolerable'),
  ('VISITA_R017', 'Extensión Eléctrica', 7,
   'La extensión cuenta con conexión a tierra', 'Intolerable'),
  ('VISITA_R017', 'Extensión Eléctrica', 8,
   'No se observan empalmes o conexiones enhuinchadas', 'Intolerable'),
  ('VISITA_R017', 'Extensión Eléctrica', 9,
   'Es de un largo adecuado según lo que se requiere', 'Medio'),
  ('VISITA_R017', 'Extensión Eléctrica', 10,
   'Se almacena en un buen sector que no genere deterioro', 'Medio')
)
INSERT INTO public.formulario_items
  (id, tipo_actividad, categoria, pregunta, criticidad, orden, activo, peso)
SELECT
  md5(n.tipo_legacy || ':' || n.orden::text)::uuid,
  CASE n.tipo_legacy
    WHEN 'VISITA_R013' THEN 'VISITA_CHEQUEO_HERRAMIENTAS_MANUALES'
    WHEN 'VISITA_R014' THEN 'VISITA_CHEQUEO_SOLDADORA_AL_ARCO'
    WHEN 'VISITA_R015' THEN 'VISITA_CHEQUEO_TALADRO_DESTORNILLADOR'
    WHEN 'VISITA_R016' THEN 'VISITA_CHEQUEO_ESMERIL_ANGULAR'
    WHEN 'VISITA_R017' THEN 'VISITA_CHEQUEO_EXTENSION_ELECTRICA'
  END,
  n.categoria,
  n.pregunta,
  n.criticidad::public.nivel_criticidad,
  n.orden,
  true,
  1.0
FROM nuevos n
ON CONFLICT (id) DO UPDATE SET
  tipo_actividad = EXCLUDED.tipo_actividad,
  categoria = EXCLUDED.categoria,
  pregunta = EXCLUDED.pregunta,
  criticidad = EXCLUDED.criticidad,
  orden = EXCLUDED.orden,
  activo = EXCLUDED.activo,
  peso = EXCLUDED.peso;

-- =============================================================================
-- 2) TESTS TRANSACCIONALES
-- Cualquier incumplimiento genera error y revierte toda la migracion.
-- =============================================================================

DO $$
DECLARE
  total_insertado INTEGER;
  tipos_validos INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO total_insertado
  FROM public.formulario_items
  WHERE tipo_actividad IN (
    'VISITA_CHEQUEO_HERRAMIENTAS_MANUALES',
    'VISITA_CHEQUEO_SOLDADORA_AL_ARCO',
    'VISITA_CHEQUEO_TALADRO_DESTORNILLADOR',
    'VISITA_CHEQUEO_ESMERIL_ANGULAR',
    'VISITA_CHEQUEO_EXTENSION_ELECTRICA'
  );

  IF total_insertado <> 72 THEN
    RAISE EXCEPTION 'Se esperaban 72 items y se encontraron %.', total_insertado;
  END IF;

  SELECT COUNT(*)
  INTO tipos_validos
  FROM (
    SELECT tipo_actividad, COUNT(*) AS total, MIN(orden) AS minimo,
           MAX(orden) AS maximo, COUNT(DISTINCT orden) AS ordenes_unicos,
           BOOL_AND(activo) AS todos_activos,
           BOOL_AND(pregunta <> '') AS preguntas_validas,
           BOOL_AND(criticidad IN ('Medio', 'Alto', 'Intolerable'))
             AS criticidades_validas
    FROM public.formulario_items
    WHERE tipo_actividad IN (
      'VISITA_CHEQUEO_HERRAMIENTAS_MANUALES',
      'VISITA_CHEQUEO_SOLDADORA_AL_ARCO',
      'VISITA_CHEQUEO_TALADRO_DESTORNILLADOR',
      'VISITA_CHEQUEO_ESMERIL_ANGULAR',
      'VISITA_CHEQUEO_EXTENSION_ELECTRICA'
    )
    GROUP BY tipo_actividad
  ) resumen
    WHERE (tipo_actividad = 'VISITA_CHEQUEO_HERRAMIENTAS_MANUALES' AND total = 20 AND maximo = 20)
      OR (tipo_actividad = 'VISITA_CHEQUEO_SOLDADORA_AL_ARCO' AND total = 13 AND maximo = 13)
      OR (tipo_actividad = 'VISITA_CHEQUEO_TALADRO_DESTORNILLADOR' AND total = 13 AND maximo = 13)
      OR (tipo_actividad = 'VISITA_CHEQUEO_ESMERIL_ANGULAR' AND total = 16 AND maximo = 16)
      OR (tipo_actividad = 'VISITA_CHEQUEO_EXTENSION_ELECTRICA' AND total = 10 AND maximo = 10);

  IF tipos_validos <> 5 THEN
    RAISE EXCEPTION 'Fallaron los conteos esperados de R013-R017.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM (
      SELECT tipo_actividad, COUNT(*) AS total, MIN(orden) AS minimo,
             MAX(orden) AS maximo, COUNT(DISTINCT orden) AS ordenes_unicos,
             BOOL_AND(activo) AS todos_activos,
             BOOL_AND(pregunta <> '') AS preguntas_validas,
             BOOL_AND(criticidad IN ('Medio', 'Alto', 'Intolerable'))
               AS criticidades_validas
      FROM public.formulario_items
      WHERE tipo_actividad IN (
        'VISITA_CHEQUEO_HERRAMIENTAS_MANUALES',
        'VISITA_CHEQUEO_SOLDADORA_AL_ARCO',
        'VISITA_CHEQUEO_TALADRO_DESTORNILLADOR',
        'VISITA_CHEQUEO_ESMERIL_ANGULAR',
        'VISITA_CHEQUEO_EXTENSION_ELECTRICA'
      )
      GROUP BY tipo_actividad
    ) resumen
    WHERE minimo <> 1
       OR total <> maximo
       OR total <> ordenes_unicos
       OR NOT todos_activos
       OR NOT preguntas_validas
       OR NOT criticidades_validas
  ) THEN
    RAISE EXCEPTION 'Hay ordenes, estados, preguntas o criticidades invalidas.';
  END IF;
END $$;

COMMIT;

-- =============================================================================
-- 3) RESULTADO FINAL
-- PASO C: ESTE SELECT SE PUEDE EJECUTAR POR SEPARADO DESPUES DEL COMMIT.
-- Esperado: 20, 13, 13, 16 y 10 filas; todas activas.
-- =============================================================================

SELECT tipo_actividad, categoria, COUNT(*) AS items,
       COUNT(*) FILTER (WHERE activo) AS activos,
       MIN(orden) AS primer_orden, MAX(orden) AS ultimo_orden
FROM public.formulario_items
WHERE tipo_actividad IN (
  'VISITA_CHEQUEO_HERRAMIENTAS_MANUALES',
  'VISITA_CHEQUEO_SOLDADORA_AL_ARCO',
  'VISITA_CHEQUEO_TALADRO_DESTORNILLADOR',
  'VISITA_CHEQUEO_ESMERIL_ANGULAR',
  'VISITA_CHEQUEO_EXTENSION_ELECTRICA'
)
GROUP BY tipo_actividad, categoria
ORDER BY tipo_actividad;