-- =============================================================================
-- DESACTIVAR AST-2026-0301 (BAJA LOGICA)
--
-- No borra el informe, hallazgos, evidencias ni PDF. Solo cambia su estado a
-- 'Eliminada', por lo que deja de aparecer en el historial de la aplicacion.
--
-- PASO OBLIGATORIO 1: ejecutar solo la seccion A y verificar el resultado.
-- PASO 2: si devuelve exactamente una AST con correlativo AST-2026-0301,
--         ejecutar la seccion B.
-- PASO 3: ejecutar la seccion C para confirmar la baja.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- A) CHECK PREVIO (SOLO LECTURA)
--
-- Esperado: exactamente 1 fila, con correlativo AST-2026-0301.
-- Si devuelve 0 filas, no ejecutes la seccion B.
-- Si devuelve mas de 1 fila, no ejecutes la seccion B: hay duplicados.
-- -----------------------------------------------------------------------------
SELECT
  i.id,
  i.correlativo,
  i.estado_final,
  i.fecha_realizacion,
  i.created_at,
  i.usuario_id,
  i.empresa_id,
  i.descripcion_actividad,
  i.pdf_url,
  (
    SELECT COUNT(*)
    FROM public.ast_hallazgos h
    WHERE h.informe_id = i.id
  ) AS total_hallazgos
FROM public.ast_informes i
WHERE i.correlativo = 'AST-2026-0301';

-- Diagnostico adicional: archivos de evidencia que se conservaran en Storage.
-- Puede devolver 0 filas si la migracion ast_evidencias aun no fue aplicada.
DO $$
DECLARE
  v_evidencias INTEGER;
BEGIN
  IF to_regclass('public.ast_evidencias') IS NULL THEN
    RAISE NOTICE 'ast_evidencias no existe: no hay evidencias registradas en esta tabla.';
  ELSE
    EXECUTE
      'SELECT COUNT(*)
       FROM public.ast_evidencias e
       JOIN public.ast_informes i ON i.id = e.informe_id
       WHERE i.correlativo = ''AST-2026-0301'''
    INTO v_evidencias;
    RAISE NOTICE 'Evidencias registradas para AST-2026-0301: %', v_evidencias;
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- B) BAJA LOGICA (CAMBIO DE DATOS)
--
-- Ejecuta esta seccion SOLO despues de validar A. La guardia aborta si no hay
-- exactamente una coincidencia o si ya estaba eliminada.
-- -----------------------------------------------------------------------------
BEGIN;

LOCK TABLE public.ast_informes IN SHARE ROW EXCLUSIVE MODE;

DO $$
DECLARE
  v_count INTEGER;
  v_estado TEXT;
BEGIN
  SELECT COUNT(*), MIN(estado_final)
  INTO v_count, v_estado
  FROM public.ast_informes
  WHERE correlativo = 'AST-2026-0301';

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'No se desactivo AST-2026-0301: se esperaban 1 fila y se encontraron %.',
      v_count;
  END IF;

  IF v_estado = 'Eliminada' THEN
    RAISE EXCEPTION 'AST-2026-0301 ya estaba desactivada; no se realizaron cambios.';
  END IF;
END;
$$;

UPDATE public.ast_informes
SET estado_final = 'Eliminada'
WHERE correlativo = 'AST-2026-0301'
RETURNING id, correlativo, estado_final, fecha_realizacion, created_at;

COMMIT;

-- -----------------------------------------------------------------------------
-- C) VERIFICACION POSTERIOR (SOLO LECTURA)
--
-- Esperado: estado_final = Eliminada y no debe aparecer en historial_unificado.
-- -----------------------------------------------------------------------------
SELECT id, correlativo, estado_final
FROM public.ast_informes
WHERE correlativo = 'AST-2026-0301';

SELECT id, modulo, numero_reporte, estado
FROM public.historial_unificado
WHERE modulo = 'AST'
  AND numero_reporte = 'AST-2026-0301';
-- Esperado: 0 filas.

-- IMPORTANTE:
-- Antes de volver a abrir/sincronizar la app en dispositivos que trabajaron
-- offline, confirma que no tengan una copia pendiente de esta AST. Una copia
-- local con subido = 0 podria reenviarla a Supabase.
