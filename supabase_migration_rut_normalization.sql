-- =====================================================
-- MIGRACIÓN: Normalización de RUTs en personal_externo
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- PASO 0: Verificar estado actual (DRY RUN)
SELECT rut, nombre_completo, id, contratista_id
FROM personal_externo
WHERE rut IS NOT NULL AND rut != ''
ORDER BY rut;

-- Ver duplicados ANTES de normalizar
SELECT LOWER(REPLACE(REPLACE(REPLACE(rut, '.', ''), '-', ''), ' ', '')) as rut_norm,
       array_agg(id) as ids,
       array_agg(nombre_completo) as nombres,
       COUNT(*) as cnt
FROM personal_externo
WHERE rut IS NOT NULL AND rut != ''
GROUP BY rut_norm
HAVING COUNT(*) > 1;

-- =====================================================
-- PASO 1: Normalizar todos los RUTs
-- =====================================================
BEGIN;

UPDATE personal_externo
SET rut = LOWER(REPLACE(REPLACE(REPLACE(TRIM(BOTH FROM rut), '.', ''), '-', ''), ' ', ''))
WHERE rut IS NOT NULL AND rut != '';

-- =====================================================
-- PASO 2: Resolver duplicados
-- Para cada grupo de duplicados, mantener el que tenga
-- contratista_id (o el primero si ninguno lo tiene)
-- y reasignar actividad_participantes
-- =====================================================
DO $$
DECLARE
  dup RECORD;
  winner_id TEXT;
  loser_id TEXT;
  ids_arr TEXT[];
BEGIN
  FOR dup IN
    SELECT rut, array_agg(id ORDER BY
      CASE WHEN contratista_id IS NOT NULL THEN 0 ELSE 1 END,
      id
    ) as ids
    FROM personal_externo
    WHERE rut IS NOT NULL AND rut != ''
    GROUP BY rut
    HAVING COUNT(*) > 1
  LOOP
    ids_arr := dup.ids;
    winner_id := ids_arr[1]; -- El primero (preferencia contratista_id)

    -- Reasignar participaciones de los perdedores al ganador
    FOR i IN 2..array_length(ids_arr, 1) LOOP
      loser_id := ids_arr[i];

      -- Actualizar referencias (ignorar conflictos de PK compuesta)
      UPDATE actividad_participantes
      SET personal_id = winner_id
      WHERE personal_id = loser_id
      AND NOT EXISTS (
        SELECT 1 FROM actividad_participantes ap2
        WHERE ap2.actividad_id = actividad_participantes.actividad_id
        AND ap2.personal_id = winner_id
      );

      -- Eliminar relaciones huérfanas (donde ya existía el ganador)
      DELETE FROM actividad_participantes
      WHERE personal_id = loser_id;

      -- Eliminar el registro perdedor
      DELETE FROM personal_externo WHERE id = loser_id;

      RAISE NOTICE 'Merged % into %', loser_id, winner_id;
    END LOOP;
  END LOOP;
END $$;

-- =====================================================
-- PASO 3: Crear constraint UNIQUE parcial
-- =====================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_personal_externo_rut_unique
ON personal_externo(rut) WHERE rut IS NOT NULL AND rut != '';

COMMIT;

-- =====================================================
-- PASO 4: Verificar resultado
-- =====================================================
SELECT rut, COUNT(*) as cnt
FROM personal_externo
WHERE rut IS NOT NULL AND rut != ''
GROUP BY rut
HAVING COUNT(*) > 1;
-- Debería retornar 0 filas

SELECT COUNT(*) as total_personal FROM personal_externo;
