-- =====================================================
-- FIX: Borrar 4 actividades de prueba y resetear secuencias
-- Ejecutar en Supabase SQL Editor (Dashboard > SQL Editor)
-- Fecha: 2026-03-30
-- =====================================================
-- IMPORTANTE: Las secuencias son SEPARADAS por tipo:
--   seq_inf_buceo       → para INSPECCION_BUCEO (max legítimo: 92)
--   seq_inf_embarcacion → para INSPECCION_EMBARCACION (max: 26, no se toca)
--
-- Los 4 registros de prueba a borrar (todos INSPECCION_BUCEO):
-- #117 - Yashin Olivares  (23-ene-2026)
-- #335 - Yashin Olivares  (24-ene-2026)
-- #336 - Constanza Leyton (04-feb-2026)
-- #337 - Sebastian Chaparro (25-ene-2026)

-- IDs:
-- 66a09593-ea7d-4f46-884b-c9b21a5648f6  (#117)
-- 42bb477b-68f9-4c75-aa55-0cdfd4de7356  (#335)
-- f4e24314-db92-4f4b-8f6f-97cefdfb62ed  (#337)
-- 052d1f5f-4d21-4b7f-a4ed-f8436420efe0  (#336)


-- =========================================================
-- PASO 0: DRY-RUN — Ver qué se va a borrar (ejecutar solo)
-- =========================================================

SELECT 'actividades' AS tabla, id::text, numero_informe::text AS detalle
FROM actividades
WHERE id IN (
  '66a09593-ea7d-4f46-884b-c9b21a5648f6',
  '42bb477b-68f9-4c75-aa55-0cdfd4de7356',
  'f4e24314-db92-4f4b-8f6f-97cefdfb62ed',
  '052d1f5f-4d21-4b7f-a4ed-f8436420efe0'
)
UNION ALL
SELECT 'inspeccion_respuestas', id::text, actividad_id::text
FROM inspeccion_respuestas
WHERE actividad_id IN (
  '66a09593-ea7d-4f46-884b-c9b21a5648f6',
  '42bb477b-68f9-4c75-aa55-0cdfd4de7356',
  'f4e24314-db92-4f4b-8f6f-97cefdfb62ed',
  '052d1f5f-4d21-4b7f-a4ed-f8436420efe0'
)
UNION ALL
SELECT 'registro_fotografico', id::text, actividad_id::text
FROM registro_fotografico
WHERE actividad_id IN (
  '66a09593-ea7d-4f46-884b-c9b21a5648f6',
  '42bb477b-68f9-4c75-aa55-0cdfd4de7356',
  'f4e24314-db92-4f4b-8f6f-97cefdfb62ed',
  '052d1f5f-4d21-4b7f-a4ed-f8436420efe0'
)
UNION ALL
SELECT 'verificaciones_buceo', actividad_id::text, actividad_id::text
FROM verificaciones_buceo
WHERE actividad_id IN (
  '66a09593-ea7d-4f46-884b-c9b21a5648f6',
  '42bb477b-68f9-4c75-aa55-0cdfd4de7356',
  'f4e24314-db92-4f4b-8f6f-97cefdfb62ed',
  '052d1f5f-4d21-4b7f-a4ed-f8436420efe0'
)
UNION ALL
SELECT 'actividad_participantes', actividad_id::text, personal_id::text
FROM actividad_participantes
WHERE actividad_id IN (
  '66a09593-ea7d-4f46-884b-c9b21a5648f6',
  '42bb477b-68f9-4c75-aa55-0cdfd4de7356',
  'f4e24314-db92-4f4b-8f6f-97cefdfb62ed',
  '052d1f5f-4d21-4b7f-a4ed-f8436420efe0'
);


-- =========================================================
-- PASO 1: Borrar datos hijos (ejecutar en orden)
-- =========================================================

-- 1a. Respuestas de inspección
DELETE FROM inspeccion_respuestas
WHERE actividad_id IN (
  '66a09593-ea7d-4f46-884b-c9b21a5648f6',
  '42bb477b-68f9-4c75-aa55-0cdfd4de7356',
  'f4e24314-db92-4f4b-8f6f-97cefdfb62ed',
  '052d1f5f-4d21-4b7f-a4ed-f8436420efe0'
);

-- 1b. Fotos
DELETE FROM registro_fotografico
WHERE actividad_id IN (
  '66a09593-ea7d-4f46-884b-c9b21a5648f6',
  '42bb477b-68f9-4c75-aa55-0cdfd4de7356',
  'f4e24314-db92-4f4b-8f6f-97cefdfb62ed',
  '052d1f5f-4d21-4b7f-a4ed-f8436420efe0'
);

-- 1c. Verificaciones buceo (los 4 son INSPECCION_BUCEO)
DELETE FROM verificaciones_buceo
WHERE actividad_id IN (
  '66a09593-ea7d-4f46-884b-c9b21a5648f6',
  '42bb477b-68f9-4c75-aa55-0cdfd4de7356',
  'f4e24314-db92-4f4b-8f6f-97cefdfb62ed',
  '052d1f5f-4d21-4b7f-a4ed-f8436420efe0'
);

-- 1d. Participantes
DELETE FROM actividad_participantes
WHERE actividad_id IN (
  '66a09593-ea7d-4f46-884b-c9b21a5648f6',
  '42bb477b-68f9-4c75-aa55-0cdfd4de7356',
  'f4e24314-db92-4f4b-8f6f-97cefdfb62ed',
  '052d1f5f-4d21-4b7f-a4ed-f8436420efe0'
);


-- =========================================================
-- PASO 2: Borrar las 4 actividades de prueba
-- =========================================================

DELETE FROM actividades
WHERE id IN (
  '66a09593-ea7d-4f46-884b-c9b21a5648f6',
  '42bb477b-68f9-4c75-aa55-0cdfd4de7356',
  'f4e24314-db92-4f4b-8f6f-97cefdfb62ed',
  '052d1f5f-4d21-4b7f-a4ed-f8436420efe0'
);


-- =========================================================
-- PASO 3: Resetear AMBAS secuencias al MAX por tipo
-- =========================================================

DO $$
DECLARE
  max_buceo INTEGER;
  max_embarcacion INTEGER;
BEGIN
  -- Max de cada tipo
  SELECT COALESCE(MAX(numero_informe), 0) INTO max_buceo
  FROM actividades WHERE tipo_actividad = 'INSPECCION_BUCEO';

  SELECT COALESCE(MAX(numero_informe), 0) INTO max_embarcacion
  FROM actividades WHERE tipo_actividad = 'INSPECCION_EMBARCACION';

  -- Resetear seq_inf_buceo (debería quedar en 92)
  PERFORM setval('seq_inf_buceo', max_buceo);
  RAISE NOTICE 'seq_inf_buceo reseteada a % (próximo buceo será %)', max_buceo, max_buceo + 1;

  -- Resetear seq_inf_embarcacion (debería quedar en 26, sin cambios)
  PERFORM setval('seq_inf_embarcacion', max_embarcacion);
  RAISE NOTICE 'seq_inf_embarcacion reseteada a % (próximo embarcación será %)', max_embarcacion, max_embarcacion + 1;
END $$;


-- =========================================================
-- PASO 4: Verificación final
-- =========================================================

SELECT
  'Max BUCEO' AS check_name,
  MAX(numero_informe)::text AS valor
FROM actividades WHERE tipo_actividad = 'INSPECCION_BUCEO'
UNION ALL
SELECT
  'Max EMBARCACION',
  MAX(numero_informe)::text
FROM actividades WHERE tipo_actividad = 'INSPECCION_EMBARCACION'
UNION ALL
SELECT
  'seq_inf_buceo actual',
  currval('seq_inf_buceo')::text
UNION ALL
SELECT
  'seq_inf_embarcacion actual',
  currval('seq_inf_embarcacion')::text;


-- =========================================================
-- PASO 5 (RECOMENDADO): Trigger para auto-resetear secuencia al borrar
--
-- Si borras el informe buceo #93 (y es el último),
-- el próximo buceo será #93 de nuevo.
-- Si #94 existe y borras #93, el próximo será #95 (correcto).
-- Funciona independiente para buceo y embarcación.
--
-- Concurrencia: nextval() es atómico en PostgreSQL,
-- no hay riesgo de duplicados si 2 inspectores finalizan a la vez.
-- =========================================================

CREATE OR REPLACE FUNCTION resetear_secuencia_al_borrar()
RETURNS TRIGGER AS $$
DECLARE
  max_num INTEGER;
  seq_name TEXT;
BEGIN
  -- Solo actuar si el registro borrado tenía numero_informe
  IF OLD.numero_informe IS NOT NULL AND OLD.numero_informe > 0 THEN
    -- Elegir secuencia según tipo
    IF OLD.tipo_actividad = 'INSPECCION_BUCEO' THEN
      seq_name := 'seq_inf_buceo';
    ELSIF OLD.tipo_actividad = 'INSPECCION_EMBARCACION' THEN
      seq_name := 'seq_inf_embarcacion';
    ELSE
      RETURN OLD; -- Tipo desconocido, no tocar
    END IF;

    -- Resetear al max actual de ese tipo
    SELECT COALESCE(MAX(numero_informe), 0) INTO max_num
    FROM actividades
    WHERE tipo_actividad = OLD.tipo_actividad;

    PERFORM setval(seq_name, GREATEST(max_num, 1));
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_resetear_secuencia ON actividades;
CREATE TRIGGER trg_resetear_secuencia
  AFTER DELETE ON actividades
  FOR EACH ROW
  EXECUTE FUNCTION resetear_secuencia_al_borrar();
