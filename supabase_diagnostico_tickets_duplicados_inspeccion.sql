-- =============================================================================
-- DIAGNOSTICO DE SOLO LECTURA: tickets duplicados para la misma inspeccion
-- (bloquean el indice unico de supabase_migration_tickets_borrado_y_mejoras.sql).
-- Ejecutar en el SQL Editor de Supabase. No modifica nada.
-- =============================================================================

-- 1) Todos los tickets duplicados por inspeccion_id (origen INSPECCION, no eliminados)
SELECT t.id, t.codigo_ticket, t.estado, t.eliminado, t.generado_por_id,
       t.tomado_por_id, t.created_at, t.updated_at,
       (SELECT count(*) FROM public.ticket_items ti WHERE ti.ticket_id = t.id) AS total_items,
       (SELECT count(*) FROM public.ticket_items ti WHERE ti.ticket_id = t.id AND ti.subsanado) AS items_subsanados
FROM public.tickets t
WHERE t.origen = 'INSPECCION'
  AND t.eliminado = false
  AND t.inspeccion_id IN (
    SELECT inspeccion_id FROM public.tickets
    WHERE origen = 'INSPECCION' AND eliminado = false AND inspeccion_id IS NOT NULL
    GROUP BY inspeccion_id
    HAVING count(*) > 1
  )
ORDER BY t.inspeccion_id, t.created_at;

-- 2) Resumen: cuantas inspecciones tienen mas de 1 ticket activo (para saber el alcance)
SELECT inspeccion_id, count(*) AS tickets_activos
FROM public.tickets
WHERE origen = 'INSPECCION' AND eliminado = false AND inspeccion_id IS NOT NULL
GROUP BY inspeccion_id
HAVING count(*) > 1
ORDER BY tickets_activos DESC;
