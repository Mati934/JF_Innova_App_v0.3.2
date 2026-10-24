-- =============================================================================
-- FIX: ticket_items basura generados desde fotos que NO son observaciones
-- Archivo: supabase_fix_tickets_fotos_evidencia_basura_v1.sql
-- Fecha: 2026-08-31
--
-- EJECUTAR MANUALMENTE EN EL SQL EDITOR DE SUPABASE (paso por paso).
--
-- CONTEXTO
-- Las fotos de evidencia del formulario se suben a `registro_fotografico` sin
-- `inspeccion_respuesta_id`, igual que las "fotos con observación". Como la
-- tabla no guarda el item_id, el generador de tickets las confundía y creaba
-- un `ticket_item` por cada una:
--   * Verificaciones críticas del estado de la faena -> 'Verificación: <clave>'
--   * Registros fotográficos complementarios         -> título del slot
--   * Fotos de pregunta huérfanas                    -> 'Item <uuid>'
--   * Foto anexa sin texto                           -> 'Fotografía anexa'
--   * Galería general                                -> 'General' / ''
--
-- La app ya está corregida (TicketReglas.esObservacionFotoReal). Este script
-- limpia lo que quedó creado ANTES del fix.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- PASO 1 (SOLO LECTURA): ¿cuántos ítems basura hay y en qué tickets?
-- Ejecuta esto primero. Si devuelve 0 filas, no hay nada que limpiar.
-- -----------------------------------------------------------------------------
WITH basura AS (
  SELECT
    ti.id,
    ti.ticket_id,
    ti.descripcion,
    CASE
      WHEN COALESCE(TRIM(ti.descripcion), '') = '' THEN 'vacia'
      WHEN LOWER(TRIM(ti.descripcion)) LIKE 'verificaci_n:%' THEN 'verificacion_faena'
      WHEN LOWER(TRIM(ti.descripcion)) ~ '^item [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN 'foto_pregunta_huerfana'
      WHEN LOWER(TRIM(ti.descripcion)) IN (
        'general', 'fotografía anexa', 'fotografia anexa',
        'anexo fotográfico de visita técnica'
      ) THEN 'placeholder_app'
      ELSE 'complementaria_obligatoria'
    END AS motivo
  FROM public.ticket_items ti
  WHERE ti.origen_item = 'FOTO_OBSERVACION'
    AND (
      COALESCE(TRIM(ti.descripcion), '') = ''
      OR LOWER(TRIM(ti.descripcion)) LIKE 'verificaci_n:%'
      OR LOWER(TRIM(ti.descripcion)) ~ '^item [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      OR LOWER(TRIM(ti.descripcion)) IN (
        'general', 'fotografía anexa', 'fotografia anexa',
        'anexo fotográfico de visita técnica',
        -- Registros fotográficos complementarios (mandatoryBuceoPhotoSlots)
        'compresor general',
        'estado de aceite vegetal compresor principal',
        'estado aceite vegetal compresor back up',
        'matriculas de buceo',
        'bitacora de compresores',
        'bitacora de buceo supervisor',
        'registro aplicacion oxigeno normobarico',
        'certificado de inspeccion de compresores'
      )
    )
)
SELECT
  b.motivo,
  COUNT(*)                        AS items_basura,
  COUNT(DISTINCT b.ticket_id)     AS tickets_afectados
FROM basura b
GROUP BY b.motivo
ORDER BY items_basura DESC;

-- Cómo interpretar: cada fila es un tipo de foto que NO debía generar ticket.
-- 'complementaria_obligatoria' y 'verificacion_faena' son el bug reportado.


-- -----------------------------------------------------------------------------
-- PASO 2 (SOLO LECTURA): detalle por ticket, para revisar antes de borrar.
-- Muestra cuántos ítems basura y cuántos ítems VÁLIDOS quedan en cada ticket.
-- -----------------------------------------------------------------------------
SELECT
  t.id                                             AS ticket_id,
  t.codigo_ticket,
  t.estado,
  t.eliminado,
  COUNT(*) FILTER (WHERE ti.origen_item = 'FOTO_OBSERVACION') AS items_de_foto,
  COUNT(*) FILTER (WHERE ti.origen_item <> 'FOTO_OBSERVACION') AS items_de_nc,
  STRING_AGG(DISTINCT ti.descripcion, ' | ') FILTER (
    WHERE ti.origen_item = 'FOTO_OBSERVACION'
  ) AS descripciones_de_foto
FROM public.tickets t
JOIN public.ticket_items ti ON ti.ticket_id = t.id
WHERE t.id IN (
  SELECT ticket_id FROM public.ticket_items
  WHERE origen_item = 'FOTO_OBSERVACION'
)
GROUP BY t.id, t.codigo_ticket, t.estado, t.eliminado
ORDER BY t.codigo_ticket;

-- Cómo interpretar: si un ticket queda con items_de_nc = 0 y TODOS sus
-- items_de_foto son basura, ese ticket completo no debió existir.
-- Estado esperado al 31-08-2026:
--   TCK-2026-0003 -> 4 items, los 4 basura        => queda VACÍO, se elimina.
--   TCK-2026-0007 -> 14 items, 11 basura          => sobreviven 3 reales.


-- -----------------------------------------------------------------------------
-- PASO 2b (SOLO LECTURA): tickets que quedarán SIN ningún ítem tras la
-- limpieza. Son los que nacieron 100% de fotos complementarias/verificaciones
-- y no deberían existir.
-- -----------------------------------------------------------------------------
SELECT
  t.codigo_ticket,
  t.estado,
  t.numero_informe,
  t.campos_extra_json ->> 'automatico_tipo' AS automatico_tipo,
  COUNT(ti.id) AS items_que_sobreviven
FROM public.tickets t
LEFT JOIN public.ticket_items ti
  ON ti.ticket_id = t.id
 AND NOT (
      ti.origen_item = 'FOTO_OBSERVACION'
  AND (
        COALESCE(TRIM(ti.descripcion), '') = ''
        OR LOWER(TRIM(ti.descripcion)) LIKE 'verificaci_n:%'
        OR LOWER(TRIM(ti.descripcion)) ~ '^item [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        OR LOWER(TRIM(ti.descripcion)) IN (
          'general', 'fotografía anexa', 'fotografia anexa',
          'anexo fotográfico de visita técnica',
          'compresor general',
          'estado de aceite vegetal compresor principal',
          'estado aceite vegetal compresor back up',
          'matriculas de buceo',
          'bitacora de compresores',
          'bitacora de buceo supervisor',
          'registro aplicacion oxigeno normobarico',
          'certificado de inspeccion de compresores'
        )
      )
    )
WHERE t.eliminado = FALSE
  AND t.campos_extra_json ->> 'automatico_tipo' = 'FOTOS_OBSERVACION'
GROUP BY t.id
HAVING COUNT(ti.id) = 0
ORDER BY t.codigo_ticket;

-- Cómo interpretar: cada fila es un ticket que se va a eliminar completo
-- en el Paso 3. Al 31-08-2026 debería salir solo TCK-2026-0003.


-- -----------------------------------------------------------------------------
-- PASO 3 (DESTRUCTIVO): borrar los ítems basura y los tickets que quedan vacíos.
-- Descomenta y ejecuta SOLO después de revisar los pasos 1, 2 y 2b.
--
-- Va todo dentro de una transacción: si algo falla, no se aplica nada.
-- -----------------------------------------------------------------------------
/*
BEGIN;

-- 3.1 Borrar los ítems que nunca debieron generarse.
DELETE FROM public.ticket_items ti
WHERE ti.origen_item = 'FOTO_OBSERVACION'
  AND (
    COALESCE(TRIM(ti.descripcion), '') = ''
    OR LOWER(TRIM(ti.descripcion)) LIKE 'verificaci_n:%'
    OR LOWER(TRIM(ti.descripcion)) ~ '^item [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    OR LOWER(TRIM(ti.descripcion)) IN (
      'general', 'fotografía anexa', 'fotografia anexa',
      'anexo fotográfico de visita técnica',
      'compresor general',
      'estado de aceite vegetal compresor principal',
      'estado aceite vegetal compresor back up',
      'matriculas de buceo',
      'bitacora de compresores',
      'bitacora de buceo supervisor',
      'registro aplicacion oxigeno normobarico',
      'certificado de inspeccion de compresores'
    )
  );

-- 3.2 Eliminar los tickets que quedaron SIN ningún ítem (nacieron solo de
-- fotos complementarias/verificaciones).
--
-- OPCIÓN A (recomendada): borrado lógico. El ticket desaparece de la app pero
-- se conserva el registro y NO se reutiliza su correlativo TCK-2026-XXXX.
UPDATE public.tickets t
SET eliminado = TRUE
WHERE t.eliminado = FALSE
  AND NOT EXISTS (SELECT 1 FROM public.ticket_items ti WHERE ti.ticket_id = t.id)
  AND t.campos_extra_json ->> 'automatico_tipo' = 'FOTOS_OBSERVACION';

COMMIT;
*/


-- -----------------------------------------------------------------------------
-- PASO 3-BIS (OPCIONAL, MÁS AGRESIVO): borrado FÍSICO del ticket vacío.
--
-- Úsalo solo si NO quieres dejar rastro de TCK-2026-0003 (era 100% basura).
-- Arrastra su historial y notificaciones. Es irreversible.
-- Ejecuta esto EN VEZ del UPDATE de la opción A, no además.
-- -----------------------------------------------------------------------------
/*
BEGIN;

CREATE TEMP TABLE tickets_a_borrar AS
SELECT t.id
FROM public.tickets t
WHERE NOT EXISTS (SELECT 1 FROM public.ticket_items ti WHERE ti.ticket_id = t.id)
  AND t.campos_extra_json ->> 'automatico_tipo' = 'FOTOS_OBSERVACION';

-- Revisa qué se va a borrar antes de seguir:
SELECT t.codigo_ticket, t.estado, t.numero_informe
FROM public.tickets t
JOIN tickets_a_borrar b ON b.id = t.id;

DELETE FROM public.ticket_historial_tomas WHERE ticket_id IN (SELECT id FROM tickets_a_borrar);
DELETE FROM public.ticket_notificaciones  WHERE ticket_id IN (SELECT id FROM tickets_a_borrar);
DELETE FROM public.tickets                WHERE id IN (SELECT id FROM tickets_a_borrar);

COMMIT;
*/


-- -----------------------------------------------------------------------------
-- PASO 4 (TESTS de verificación): correr DESPUÉS del paso 3.
-- -----------------------------------------------------------------------------

-- 4.1 Debe devolver 0. Si devuelve > 0, la limpieza no se aplicó.
SELECT COUNT(*) AS items_basura_restantes
FROM public.ticket_items
WHERE origen_item = 'FOTO_OBSERVACION'
  AND (
    COALESCE(TRIM(descripcion), '') = ''
    OR LOWER(TRIM(descripcion)) LIKE 'verificaci_n:%'
    OR LOWER(TRIM(descripcion)) ~ '^item [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    OR LOWER(TRIM(descripcion)) IN (
      'general', 'fotografía anexa', 'fotografia anexa',
      'anexo fotográfico de visita técnica',
      'compresor general',
      'estado de aceite vegetal compresor principal',
      'estado aceite vegetal compresor back up',
      'matriculas de buceo',
      'bitacora de compresores',
      'bitacora de buceo supervisor',
      'registro aplicacion oxigeno normobarico',
      'certificado de inspeccion de compresores'
    )
  );

-- 4.2 Los ítems de foto que SOBREVIVEN deben ser observaciones reales del
-- inspector. Revisa la lista a ojo: no debe aparecer ninguna evidencia.
SELECT descripcion, COUNT(*) AS veces
FROM public.ticket_items
WHERE origen_item = 'FOTO_OBSERVACION'
GROUP BY descripcion
ORDER BY veces DESC;

-- 4.3 No deben quedar tickets activos sin ningún ítem.
SELECT t.id, t.codigo_ticket, t.estado
FROM public.tickets t
WHERE t.eliminado = FALSE
  AND t.campos_extra_json ->> 'automatico_tipo' = 'FOTOS_OBSERVACION'
  AND NOT EXISTS (SELECT 1 FROM public.ticket_items ti WHERE ti.ticket_id = t.id);


-- =============================================================================
-- PASO 5: tickets VACÍOS (0 ítems) — causa distinta, ya corregida en la app.
--
-- TCK-2026-0001 (informe 517) está ABIERTO con 0 ítems y sin `hallazgo_id`.
-- Causa: el flujo legacy de generación insertaba el ticket ANTES de saber si
-- había algo que subsanar; si no había NC ni fotos con observación (p.ej. las
-- respuestas aún no habían sincronizado), quedaba un ticket vacío sin
-- rollback, además quemando un correlativo.
--
-- Ya está arreglado en la app: ahora los ítems se arman primero y, si no hay
-- ninguno, no se crea el ticket. Este paso solo limpia lo que quedó.
-- =============================================================================

-- 5.1 (SOLO LECTURA) ¿qué tickets activos no tienen ningún ítem?
SELECT
  t.codigo_ticket,
  t.estado,
  t.numero_informe,
  t.tipo_ticket,
  t.hallazgo_id,
  t.campos_extra_json ->> 'automatico_tipo' AS automatico_tipo,
  t.created_at
FROM public.tickets t
WHERE t.eliminado = FALSE
  AND NOT EXISTS (SELECT 1 FROM public.ticket_items ti WHERE ti.ticket_id = t.id)
ORDER BY t.codigo_ticket;

-- Cómo interpretar: un ticket sin ítems no se puede tomar ni subsanar; queda
-- ABIERTO para siempre. Todos los que salgan aquí son basura.
-- OJO: córrelo ANTES del Paso 3 para no confundirlo con los que ese paso
-- vacía. Al 31-08-2026 debería salir solo TCK-2026-0001.

-- 5.2 (DESTRUCTIVO) Borrado lógico de los tickets vacíos. Descomenta para usar.
/*
UPDATE public.tickets t
SET eliminado = TRUE
WHERE t.eliminado = FALSE
  AND NOT EXISTS (SELECT 1 FROM public.ticket_items ti WHERE ti.ticket_id = t.id);
*/

-- 5.3 (TEST) Debe devolver 0 filas después del 5.2.
SELECT COUNT(*) AS tickets_vacios_restantes
FROM public.tickets t
WHERE t.eliminado = FALSE
  AND NOT EXISTS (SELECT 1 FROM public.ticket_items ti WHERE ti.ticket_id = t.id);
