-- =============================================================================
-- ELIMINAR INSPECCION EMBARCACION #49 (SEGURO)
-- Archivo: supabase_delete_inspeccion_embarcacion_49_safe.sql
--
-- Que hace:
--   1) Valida que exista EXACTAMENTE 1 actividad objetivo.
--   2) Limpia referencias que bloquean por FK (tickets + hallazgos NC).
--   3) Borra hijos y luego la actividad.
--   4) Reajusta secuencia seq_inf_embarcacion al max actual.
--
-- Ajusta estas dos constantes dentro del DO si quieres reutilizar:
--   v_tipo_actividad := 'INSPECCION_EMBARCACION'
--   v_numero_informe := 49
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_tipo_actividad TEXT := 'INSPECCION_EMBARCACION';
  v_numero_informe INTEGER := 49;

  v_objetivo_id UUID;
  v_objetivo_count INTEGER;
  v_ids TEXT;

  v_max_embarcacion INTEGER;
  v_tiene_seq BOOLEAN;

  v_tickets_desvinc_ocurrencia INTEGER := 0;
  v_tickets_desvinc_inspeccion INTEGER := 0;
  v_hallazgos_null_inicial INTEGER := 0;
  v_hallazgos_null_ultima INTEGER := 0;

  v_del_respuestas INTEGER := 0;
  v_del_fotos INTEGER := 0;
  v_del_verif_emb INTEGER := 0;
  v_del_participantes INTEGER := 0;
  v_del_ocurrencias INTEGER := 0;
  v_del_actividad INTEGER := 0;
BEGIN
  -- ---------------------------------------------------------------------------
  -- 1) Validar objetivo unico
  -- ---------------------------------------------------------------------------
  SELECT COUNT(*), string_agg(id::text, ', ')
    INTO v_objetivo_count, v_ids
  FROM public.actividades
  WHERE tipo_actividad = v_tipo_actividad
    AND numero_informe = v_numero_informe;

  IF v_objetivo_count = 0 THEN
    RAISE EXCEPTION
      'No se encontro actividad con tipo=% y numero_informe=%',
      v_tipo_actividad, v_numero_informe;
  END IF;

  IF v_objetivo_count > 1 THEN
    RAISE EXCEPTION
      'Se encontraron % actividades para tipo=% y numero_informe=%. IDs: %',
      v_objetivo_count, v_tipo_actividad, v_numero_informe, v_ids;
  END IF;

  SELECT id
    INTO v_objetivo_id
  FROM public.actividades
  WHERE tipo_actividad = v_tipo_actividad
    AND numero_informe = v_numero_informe
  LIMIT 1;

  RAISE NOTICE 'Objetivo: actividad_id=%', v_objetivo_id;

  -- ---------------------------------------------------------------------------
  -- 2) Limpiar referencias FK que pueden bloquear borrado
  -- ---------------------------------------------------------------------------

  -- 2.1 tickets -> ocurrencias (evita error FK tickets_hallazgo_ocurrencia_id_fkey)
  UPDATE public.tickets t
     SET hallazgo_ocurrencia_id = NULL,
         updated_at = now()
   WHERE t.hallazgo_ocurrencia_id IN (
     SELECT o.id
     FROM public.nc_hallazgo_ocurrencias o
     WHERE o.informe_id = v_objetivo_id
   );
  GET DIAGNOSTICS v_tickets_desvinc_ocurrencia = ROW_COUNT;

  -- 2.2 tickets -> inspeccion (por si hay FK directa a actividades)
  UPDATE public.tickets
     SET inspeccion_id = NULL,
         updated_at = now()
   WHERE inspeccion_id = v_objetivo_id;
  GET DIAGNOSTICS v_tickets_desvinc_inspeccion = ROW_COUNT;

  -- 2.3 hallazgos -> informe_inicial / informe_ultima (evita error nc_hallazgos_*_fkey)
  UPDATE public.nc_hallazgos
     SET informe_inicial_id = NULL,
         updated_at = now()
   WHERE informe_inicial_id = v_objetivo_id;
  GET DIAGNOSTICS v_hallazgos_null_inicial = ROW_COUNT;

  UPDATE public.nc_hallazgos
     SET informe_ultima_ocurrencia_id = NULL,
         updated_at = now()
   WHERE informe_ultima_ocurrencia_id = v_objetivo_id;
  GET DIAGNOSTICS v_hallazgos_null_ultima = ROW_COUNT;

  -- ---------------------------------------------------------------------------
  -- 3) Borrar hijos directos de la actividad
  -- ---------------------------------------------------------------------------
  DELETE FROM public.inspeccion_respuestas
   WHERE actividad_id = v_objetivo_id;
  GET DIAGNOSTICS v_del_respuestas = ROW_COUNT;

  DELETE FROM public.registro_fotografico
   WHERE actividad_id = v_objetivo_id;
  GET DIAGNOSTICS v_del_fotos = ROW_COUNT;

  DELETE FROM public.verificaciones_embarcacion
   WHERE actividad_id = v_objetivo_id;
  GET DIAGNOSTICS v_del_verif_emb = ROW_COUNT;

  DELETE FROM public.actividad_participantes
   WHERE actividad_id = v_objetivo_id;
  GET DIAGNOSTICS v_del_participantes = ROW_COUNT;

  -- Ocurrencias NC de esta inspeccion (si no cayeron por cascada)
  DELETE FROM public.nc_hallazgo_ocurrencias
   WHERE informe_id = v_objetivo_id;
  GET DIAGNOSTICS v_del_ocurrencias = ROW_COUNT;

  -- ---------------------------------------------------------------------------
  -- 4) Borrar actividad objetivo
  -- ---------------------------------------------------------------------------
  DELETE FROM public.actividades
   WHERE id = v_objetivo_id;
  GET DIAGNOSTICS v_del_actividad = ROW_COUNT;

  IF v_del_actividad <> 1 THEN
    RAISE EXCEPTION 'No se pudo borrar la actividad objetivo id=%', v_objetivo_id;
  END IF;

  -- ---------------------------------------------------------------------------
  -- 5) Reajustar secuencia de embarcacion al max actual
  -- ---------------------------------------------------------------------------
  SELECT to_regclass('public.seq_inf_embarcacion') IS NOT NULL
    INTO v_tiene_seq;

  IF v_tiene_seq THEN
    SELECT COALESCE(MAX(numero_informe), 0)
      INTO v_max_embarcacion
    FROM public.actividades
    WHERE tipo_actividad = v_tipo_actividad;

    IF v_max_embarcacion > 0 THEN
      PERFORM setval('public.seq_inf_embarcacion', v_max_embarcacion, true);
    ELSE
      PERFORM setval('public.seq_inf_embarcacion', 1, false);
    END IF;
  END IF;

  -- ---------------------------------------------------------------------------
  -- 6) Resumen
  -- ---------------------------------------------------------------------------
  RAISE NOTICE 'tickets desvinculados ocurrencia: %', v_tickets_desvinc_ocurrencia;
  RAISE NOTICE 'tickets desvinculados inspeccion: %', v_tickets_desvinc_inspeccion;
  RAISE NOTICE 'hallazgos informe_inicial_id NULL: %', v_hallazgos_null_inicial;
  RAISE NOTICE 'hallazgos informe_ultima_ocurrencia_id NULL: %', v_hallazgos_null_ultima;

  RAISE NOTICE 'inspeccion_respuestas borradas: %', v_del_respuestas;
  RAISE NOTICE 'registro_fotografico borrado: %', v_del_fotos;
  RAISE NOTICE 'verificaciones_embarcacion borradas: %', v_del_verif_emb;
  RAISE NOTICE 'actividad_participantes borrados: %', v_del_participantes;
  RAISE NOTICE 'nc_hallazgo_ocurrencias borradas: %', v_del_ocurrencias;
  RAISE NOTICE 'actividades borradas: %', v_del_actividad;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- =============================================================================
-- VERIFICACION POSTERIOR (opcional)
-- =============================================================================
-- SELECT id, tipo_actividad, numero_informe
-- FROM public.actividades
-- WHERE tipo_actividad = 'INSPECCION_EMBARCACION'
--   AND numero_informe = 49;
--
-- SELECT COUNT(*) AS tickets_huerfanos_inspeccion
-- FROM public.tickets t
-- LEFT JOIN public.actividades a ON a.id = t.inspeccion_id
-- WHERE t.inspeccion_id IS NOT NULL AND a.id IS NULL;
--
-- SELECT COUNT(*) AS tickets_huerfanos_ocurrencia
-- FROM public.tickets t
-- LEFT JOIN public.nc_hallazgo_ocurrencias o ON o.id = t.hallazgo_ocurrencia_id
-- WHERE t.hallazgo_ocurrencia_id IS NOT NULL AND o.id IS NULL;
