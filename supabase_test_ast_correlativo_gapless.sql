-- =============================================================================
-- TESTS SQL: AST correlativo (funcion + trigger)
--
-- Ejecuta en SQL Editor. Si algo falla, levanta EXCEPTION con mensaje claro.
-- Se ejecuta dentro de transaccion y termina con ROLLBACK para no ensuciar.
-- =============================================================================

BEGIN;

-- Test 1: la funcion gapless NO deja avance si la operacion falla (subtransaccion).
DO $$
DECLARE
  v_anio INT := EXTRACT(YEAR FROM now())::int;
  v_before BIGINT;
  v_after BIGINT;
BEGIN
  INSERT INTO public.ast_correlativo_counters (anio, ultimo_numero)
  VALUES (v_anio, 0)
  ON CONFLICT (anio) DO NOTHING;

  SELECT ultimo_numero
  INTO v_before
  FROM public.ast_correlativo_counters
  WHERE anio = v_anio;

  BEGIN
    PERFORM public.next_ast_correlativo_gapless(now());
    RAISE EXCEPTION 'force rollback subtx';
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  SELECT ultimo_numero
  INTO v_after
  FROM public.ast_correlativo_counters
  WHERE anio = v_anio;

  IF v_after <> v_before THEN
    RAISE EXCEPTION 'TEST1 FAIL: counter avanzo en rollback (before %, after %)', v_before, v_after;
  END IF;
END;
$$;

-- Test 2: al pasar a En Seguimiento, trigger asigna correlativo.
DO $$
DECLARE
  v_id UUID := gen_random_uuid();
  v_corr TEXT;
BEGIN
  INSERT INTO public.ast_informes (
    id,
    usuario_id,
    empresa_id,
    area_id,
    centro_id,
    contratista_id,
    embarcacion_id,
    area_nombre,
    centro_nombre,
    contratista_nombre,
    embarcacion_nombre,
    profesional,
    fecha_realizacion,
    descripcion_actividad,
    observaciones,
    correlativo,
    estado_final,
    pdf_url,
    created_at
  ) VALUES (
    v_id,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    'TEST',
    'TEST',
    'TEST',
    NULL,
    'SQL TEST',
    now(),
    'test',
    'test',
    NULL,
    'En Progreso',
    NULL,
    now()
  );

  UPDATE public.ast_informes
  SET estado_final = 'En Seguimiento'
  WHERE id = v_id;

  SELECT correlativo INTO v_corr
  FROM public.ast_informes
  WHERE id = v_id;

  IF COALESCE(v_corr, '') = '' THEN
    RAISE EXCEPTION 'TEST2 FAIL: trigger no asigno correlativo al finalizar';
  END IF;

  IF v_corr !~ '^AST-[0-9]{4}-[0-9]{4,}$' THEN
    RAISE EXCEPTION 'TEST2 FAIL: formato correlativo invalido: %', v_corr;
  END IF;
END;
$$;

-- Test 3: una vez asignado, un UPDATE posterior no debe cambiarlo.
DO $$
DECLARE
  v_id UUID := gen_random_uuid();
  v_corr_1 TEXT;
  v_corr_2 TEXT;
BEGIN
  INSERT INTO public.ast_informes (
    id,
    usuario_id,
    empresa_id,
    area_id,
    centro_id,
    contratista_id,
    embarcacion_id,
    area_nombre,
    centro_nombre,
    contratista_nombre,
    embarcacion_nombre,
    profesional,
    fecha_realizacion,
    descripcion_actividad,
    observaciones,
    correlativo,
    estado_final,
    pdf_url,
    created_at
  ) VALUES (
    v_id,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    'TEST',
    'TEST',
    'TEST',
    NULL,
    'SQL TEST',
    now(),
    'test',
    'obs1',
    NULL,
    'En Seguimiento',
    NULL,
    now()
  );

  SELECT correlativo INTO v_corr_1
  FROM public.ast_informes
  WHERE id = v_id;

  UPDATE public.ast_informes
  SET observaciones = 'obs2'
  WHERE id = v_id;

  SELECT correlativo INTO v_corr_2
  FROM public.ast_informes
  WHERE id = v_id;

  IF COALESCE(v_corr_1, '') = '' THEN
    RAISE EXCEPTION 'TEST3 FAIL: correlativo inicial vacio';
  END IF;

  IF v_corr_1 IS DISTINCT FROM v_corr_2 THEN
    RAISE EXCEPTION 'TEST3 FAIL: correlativo cambio en update posterior (% -> %)', v_corr_1, v_corr_2;
  END IF;
END;
$$;

-- Test 4: no debe haber duplicados en la tabla real.
DO $$
DECLARE
  v_dup_count BIGINT;
BEGIN
  SELECT COUNT(*) INTO v_dup_count
  FROM (
    SELECT correlativo
    FROM public.ast_informes
    WHERE correlativo IS NOT NULL
      AND correlativo <> ''
    GROUP BY correlativo
    HAVING COUNT(*) > 1
  ) d;

  IF v_dup_count > 0 THEN
    RAISE EXCEPTION 'TEST4 FAIL: existen correlativos duplicados (% grupos)', v_dup_count;
  END IF;
END;
$$;

-- Importante: este script es de prueba, NO persiste cambios.
ROLLBACK;
