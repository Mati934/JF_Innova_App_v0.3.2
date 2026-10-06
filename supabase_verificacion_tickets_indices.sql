-- =============================================================================
-- VERIFICACION (SOLO LECTURA): estado de índices únicos y marcas del módulo
-- Tickets. NO modifica nada. Ejecutar manualmente en el SQL Editor de Supabase
-- (Dashboard > SQL Editor) y comparar con la sección "CÓMO INTERPRETAR" de
-- abajo.
--
-- Contexto: incidente 2026-08-21 — tras la limpieza total de tickets
-- aparecieron TCK-2026-0001 y TCK-2026-0005 (salto de correlativo) generados
-- por el sync de otro usuario, y las inspecciones quedaron sin marcar
-- (tickets_generados_at NULL). Sospecha principal: el índice legacy
-- `uq_tickets_inspeccion_automatico` (1 ticket por inspección) pudo quedar
-- RE-CREADO si supabase_migration_tickets_borrado_y_mejoras.sql (sección D)
-- se ejecutó DESPUÉS de supabase_migration_tickets_automaticos_al_finalizar.sql
-- / supabase_migration_tickets_hallazgo_index_fix.sql, que lo eliminan.
-- =============================================================================

-- 1) ÍNDICES de las tablas del módulo (tickets, ticket_items, nc_hallazgos):
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('tickets', 'ticket_items', 'nc_hallazgos', 'nc_hallazgo_ocurrencias')
ORDER BY tablename, indexname;

-- CÓMO INTERPRETAR (1):
--   ✅ CORRECTO (flujo 1 ticket por hallazgo):
--      - NO aparece `uq_tickets_inspeccion_automatico`.
--      - SÍ aparece `uq_tickets_hallazgo_activo` (1 ticket activo por hallazgo).
--      - SÍ aparece `uq_tickets_fotos_observacion_automatico`.
--      - SÍ aparece `uq_ticket_items_respuesta_ocurrencia`.
--      - SÍ aparece `uq_nc_hallazgos_activo_dedupe`.
--   ❌ PROBLEMA si aparece `uq_tickets_inspeccion_automatico`:
--      está limitando a 1 ticket por inspección y cada ticket de
--      FOTOS_OBSERVACION choca con él (23505), consumiendo correlativo sin
--      crear nada (eso explica saltos tipo 0001 -> 0005).
--      FIX: re-ejecutar supabase_migration_tickets_hallazgo_index_fix.sql
--      (ese archivo ya existe en el repo y es idempotente).

-- 2) SECUENCIA del correlativo TCK-AAAA-NNNN (valor actual):
SELECT last_value, is_called FROM public.ticket_codigo_seq;

-- CÓMO INTERPRETAR (2):
--   Si last_value es mayor que el correlativo más alto visible en `tickets`,
--   la diferencia son números consumidos por INSERTs que fallaron (23505/otros
--   errores). Las secuencias de Postgres NO devuelven números al hacer
--   rollback: es normal y no indica tickets borrados.

-- 3) Inspecciones finalizadas PENDIENTES de procesar tickets (debería ser 0
--    en régimen; cada fila aquí se reintenta en cada sync de su autor):
SELECT a.id, a.tipo_actividad, a.numero_informe, a.usuario_id, u.nombre_completo
FROM public.actividades a
LEFT JOIN public.usuarios u ON u.id = a.usuario_id
WHERE a.estado_final = 'En Seguimiento'
  AND a.tipo_actividad IN ('INSPECCION_BUCEO', 'INSPECCION_EMBARCACION')
  AND a.tickets_generados_at IS NULL
ORDER BY a.numero_informe;

-- CÓMO INTERPRETAR (3):
--   Filas aquí = inspecciones que generarán tickets (o reintentarán) en el
--   próximo sync DE SU AUTOR (con el fix de 2026-08-21, cada app solo
--   procesa las inspecciones del usuario logueado, porque la policy
--   `actividades_owner_write` solo permite UPDATE al dueño).

-- 4) Tickets activos y su atribución (generado_por vs autor de la inspección):
SELECT t.codigo_ticket, t.estado, t.numero_informe,
       ug.nombre_completo AS generado_por,
       ua.nombre_completo AS autor_inspeccion
FROM public.tickets t
LEFT JOIN public.usuarios ug ON ug.id = t.generado_por_id
LEFT JOIN public.actividades a ON a.id = t.inspeccion_id
LEFT JOIN public.usuarios ua ON ua.id = a.usuario_id
WHERE t.eliminado = false
ORDER BY t.created_at;

-- CÓMO INTERPRETAR (4):
--   Si `generado_por` no coincide con `autor_inspeccion`, el ticket fue
--   creado por el sync de otro usuario (bug corregido 2026-08-21: ahora cada
--   app procesa solo las inspecciones propias). Se puede corregir a mano con:
--   UPDATE public.tickets SET generado_por_id = <autor_real> WHERE codigo_ticket = '...';
-- =============================================================================
