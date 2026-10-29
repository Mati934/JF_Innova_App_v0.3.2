-- Correlativo exclusivo del Registro de Actividad, asignado al finalizar.
-- No reinicia secuencias ni renumera registros existentes.

CREATE SEQUENCE IF NOT EXISTS public.seq_inf_actividad_formativa
  AS INTEGER START WITH 1 INCREMENT BY 1 NO CYCLE;

GRANT USAGE, SELECT ON SEQUENCE public.seq_inf_actividad_formativa
  TO authenticated, service_role;

CREATE UNIQUE INDEX IF NOT EXISTS idx_actividades_formativas_numero_informe
  ON public.actividades (numero_informe)
  WHERE tipo_actividad = 'ACTIVIDAD_FORMATIVA' AND numero_informe > 0;

CREATE OR REPLACE FUNCTION public.asignar_numero_informe()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  IF NEW.tipo_actividad = 'ACTIVIDAD_FORMATIVA' THEN
    -- Permite recuperar finalizados sin numero en un reintento de sincronizacion.
    IF NEW.estado_final = 'En Seguimiento'
       AND (NEW.numero_informe IS NULL OR NEW.numero_informe = 0) THEN
      NEW.numero_informe := nextval('public.seq_inf_actividad_formativa');
    END IF;
  ELSIF NEW.estado_final = 'En Seguimiento'
     AND (TG_OP = 'INSERT' OR OLD.estado_final IS NULL OR OLD.estado_final != 'En Seguimiento')
     AND (NEW.numero_informe IS NULL OR NEW.numero_informe = 0) THEN
    IF NEW.tipo_actividad = 'INSPECCION_BUCEO' THEN
      NEW.numero_informe := nextval('public.seq_inf_buceo');
    ELSIF NEW.tipo_actividad = 'INSPECCION_EMBARCACION' THEN
      NEW.numero_informe := nextval('public.seq_inf_embarcacion');
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- Autoprueba aislada: copia la funcion a pg_temp y usa solo secuencias temporales.
-- No crea actividades reales ni consume numeros oficiales, incluso si falla.
DO $test$
DECLARE
  definition TEXT;
  assigned INTEGER;
  consumed BOOLEAN;
BEGIN
  CREATE TEMP SEQUENCE test_seq_formativa START WITH 1;
  CREATE TEMP SEQUENCE test_seq_buceo START WITH 1;
  CREATE TEMP SEQUENCE test_seq_embarcacion START WITH 1;
  CREATE TEMP TABLE test_actividad_correlativo (
    id INTEGER PRIMARY KEY,
    tipo_actividad TEXT NOT NULL,
    estado_final TEXT,
    numero_informe INTEGER
  ) ON COMMIT DROP;

  definition := pg_get_functiondef('public.asignar_numero_informe()'::regprocedure);
  definition := replace(definition, 'public.asignar_numero_informe()', 'pg_temp.test_asignar_numero_informe()');
  definition := replace(definition, 'public.seq_inf_actividad_formativa', 'pg_temp.test_seq_formativa');
  definition := replace(definition, 'public.seq_inf_buceo', 'pg_temp.test_seq_buceo');
  definition := replace(definition, 'public.seq_inf_embarcacion', 'pg_temp.test_seq_embarcacion');
  EXECUTE definition;

  CREATE TRIGGER test_asignar_numero
    BEFORE INSERT OR UPDATE ON test_actividad_correlativo
    FOR EACH ROW EXECUTE FUNCTION pg_temp.test_asignar_numero_informe();

  INSERT INTO test_actividad_correlativo VALUES (1, 'ACTIVIDAD_FORMATIVA', 'En Progreso', NULL);
  SELECT is_called INTO consumed FROM pg_temp.test_seq_formativa;
  ASSERT NOT consumed, 'Un borrador no debe consumir correlativo';

  UPDATE test_actividad_correlativo SET estado_final = 'En Seguimiento'
    WHERE id = 1 RETURNING numero_informe INTO assigned;
  ASSERT assigned = 1, 'La primera actividad debe recibir 1';
  UPDATE test_actividad_correlativo SET estado_final = 'En Seguimiento'
    WHERE id = 1 RETURNING numero_informe INTO assigned;
  ASSERT assigned = 1, 'Un reintento debe conservar el numero';

  INSERT INTO test_actividad_correlativo VALUES (2, 'ACTIVIDAD_FORMATIVA', 'En Seguimiento', NULL)
    RETURNING numero_informe INTO assigned;
  ASSERT assigned = 2, 'La siguiente actividad debe recibir 2';

  INSERT INTO test_actividad_correlativo VALUES (3, 'INSPECCION_BUCEO', 'En Seguimiento', NULL)
    RETURNING numero_informe INTO assigned;
  ASSERT assigned = 1, 'Buceo debe usar su propia secuencia';
  INSERT INTO test_actividad_correlativo VALUES (4, 'INSPECCION_EMBARCACION', 'En Seguimiento', NULL)
    RETURNING numero_informe INTO assigned;
  ASSERT assigned = 1, 'Embarcacion debe usar su propia secuencia';
  SELECT last_value INTO assigned FROM pg_temp.test_seq_formativa;
  ASSERT assigned = 2, 'Las inspecciones no deben consumir numeros formativos';

  ALTER TABLE test_actividad_correlativo DISABLE TRIGGER test_asignar_numero;
  INSERT INTO test_actividad_correlativo VALUES (5, 'ACTIVIDAD_FORMATIVA', 'En Seguimiento', NULL);
  ALTER TABLE test_actividad_correlativo ENABLE TRIGGER test_asignar_numero;
  UPDATE test_actividad_correlativo SET estado_final = 'En Seguimiento'
    WHERE id = 5 RETURNING numero_informe INTO assigned;
  ASSERT assigned = 3, 'Un finalizado sin numero debe poder recuperarse';

  DROP TABLE pg_temp.test_actividad_correlativo;
  DROP FUNCTION pg_temp.test_asignar_numero_informe();
  DROP SEQUENCE pg_temp.test_seq_formativa, pg_temp.test_seq_buceo, pg_temp.test_seq_embarcacion;
END;
$test$;
