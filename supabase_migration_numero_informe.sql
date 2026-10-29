-- =====================================================
-- MIGRACIÓN: numero_informe solo se asigna al finalizar
-- Ejecutar en Supabase SQL Editor (Dashboard > SQL Editor)
-- =====================================================

-- PASO 1: Encontrar el nombre real de la secuencia
-- (Ejecuta esto primero si quieres ver el nombre)
-- SELECT pg_get_serial_sequence('actividades', 'numero_informe');

-- PASO 2: Crear la función que asigna número solo al finalizar
-- Usa pg_get_serial_sequence para encontrar la secuencia automáticamente
CREATE OR REPLACE FUNCTION asignar_numero_informe()
RETURNS TRIGGER AS $$
DECLARE
  seq_name TEXT;
BEGIN
  -- Solo asignar número cuando se cambia a "En Seguimiento" (finalizado)
  -- y aún no tiene número asignado
  IF NEW.estado_final = 'En Seguimiento'
     AND (TG_OP = 'INSERT' OR OLD.estado_final IS NULL OR OLD.estado_final != 'En Seguimiento')
     AND (NEW.numero_informe IS NULL OR NEW.numero_informe = 0) THEN

    -- Buscar la secuencia asociada a la columna
    seq_name := pg_get_serial_sequence('actividades', 'numero_informe');

    IF seq_name IS NOT NULL THEN
      NEW.numero_informe := nextval(seq_name);
    ELSE
      -- Fallback: calcular MAX + 1 si no hay secuencia
      SELECT COALESCE(MAX(numero_informe), 0) + 1
      INTO NEW.numero_informe
      FROM actividades;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- PASO 3: Quitar el DEFAULT de la columna (para que INSERT no consuma secuencia)
ALTER TABLE actividades ALTER COLUMN numero_informe DROP DEFAULT;

-- PASO 4: Permitir NULL en numero_informe (borradores no tendrán número)
ALTER TABLE actividades ALTER COLUMN numero_informe DROP NOT NULL;

-- PASO 5: Crear el trigger BEFORE INSERT OR UPDATE
DROP TRIGGER IF EXISTS trg_asignar_numero_informe ON actividades;
CREATE TRIGGER trg_asignar_numero_informe
  BEFORE INSERT OR UPDATE ON actividades
  FOR EACH ROW
  EXECUTE FUNCTION asignar_numero_informe();

-- PASO 6: Resetear la secuencia al máximo actual
DO $$
DECLARE
  seq_name TEXT;
  max_num INTEGER;
BEGIN
  seq_name := pg_get_serial_sequence('actividades', 'numero_informe');
  IF seq_name IS NOT NULL THEN
    SELECT COALESCE(MAX(numero_informe), 0) INTO max_num FROM actividades;
    PERFORM setval(seq_name, max_num);
    RAISE NOTICE 'Secuencia % reseteada a %', seq_name, max_num;
  ELSE
    RAISE NOTICE 'No se encontró secuencia, el trigger usará MAX+1';
  END IF;
END $$;

-- PASO 7: Limpiar numero_informe de borradores existentes
UPDATE actividades
SET numero_informe = NULL
WHERE estado_final IN ('En Progreso', 'Eliminada');

-- VERIFICACIÓN: Ver el estado final
SELECT estado_final, COUNT(*) as total,
       MIN(numero_informe) as min_num,
       MAX(numero_informe) as max_num,
       COUNT(numero_informe) as con_numero
FROM actividades
GROUP BY estado_final;
