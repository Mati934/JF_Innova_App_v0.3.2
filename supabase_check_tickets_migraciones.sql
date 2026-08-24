-- =============================================================================
-- VERIFICACION DE SOLO LECTURA: ¿que migraciones de Tickets ya corrieron?
-- Ejecutar manualmente en el SQL Editor de Supabase. No modifica nada.
-- Como interpretar: cada fila con existe = false indica una migracion
-- pendiente de correr (ver el archivo .sql indicado en esa fila).
-- =============================================================================

WITH checks AS (
  SELECT 'tickets (tabla base)' AS chequeo,
         EXISTS (SELECT 1 FROM information_schema.tables
                 WHERE table_schema='public' AND table_name='tickets') AS existe,
         'supabase_migration_tickets_module.sql' AS archivo
  UNION ALL
  SELECT 'tickets.eliminado + indice unico sin eliminado',
         EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema='public' AND table_name='tickets' AND column_name='eliminado')
         AND EXISTS (SELECT 1 FROM pg_indexes
                 WHERE schemaname='public' AND indexname='uq_tickets_inspeccion_automatico'
                 AND indexdef ILIKE '%eliminado%'),
         'supabase_migration_tickets_borrado_y_mejoras.sql'
  UNION ALL
  SELECT 'ticket_items.categoria/numero_pregunta/pregunta',
         EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema='public' AND table_name='ticket_items' AND column_name='categoria')
         AND EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema='public' AND table_name='ticket_items' AND column_name='numero_pregunta')
         AND EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema='public' AND table_name='ticket_items' AND column_name='pregunta'),
         'supabase_migration_tickets_borrado_y_mejoras.sql'
  UNION ALL
  SELECT 'nc_hallazgos + nc_hallazgo_ocurrencias (hallazgos unicos)',
         EXISTS (SELECT 1 FROM information_schema.tables
                 WHERE table_schema='public' AND table_name='nc_hallazgos')
         AND EXISTS (SELECT 1 FROM information_schema.tables
                 WHERE table_schema='public' AND table_name='nc_hallazgo_ocurrencias')
         AND EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema='public' AND table_name='tickets' AND column_name='hallazgo_id'),
         'supabase_migration_nc_hallazgos_unicos_v1.sql'
  UNION ALL
  SELECT 'indice hallazgo_id (fix)',
         EXISTS (SELECT 1 FROM pg_indexes
                 WHERE schemaname='public' AND tablename='nc_hallazgos'
                 AND indexname='uq_nc_hallazgos_activo_dedupe'),
         'supabase_migration_tickets_hallazgo_index_fix.sql'
  UNION ALL
  SELECT 'ticket_item_subsanaciones (tabla historial correcta)',
         EXISTS (SELECT 1 FROM information_schema.tables
                 WHERE table_schema='public' AND table_name='ticket_item_subsanaciones'),
         'supabase_migration_ticket_item_subsanaciones_historial.sql'
  UNION ALL
  SELECT 'tickets.contratista_id (filtro contratista)',
         EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema='public' AND table_name='tickets' AND column_name='contratista_id'),
         'supabase_migration_tickets_contratista_filtro.sql'
  UNION ALL
  SELECT 'tickets automaticos al finalizar (motivo opcional + indice expediente)',
         (SELECT is_nullable = 'YES' FROM information_schema.columns
                 WHERE table_schema='public' AND table_name='tickets' AND column_name='motivo')
         AND EXISTS (SELECT 1 FROM pg_indexes
                 WHERE schemaname='public' AND indexname='uq_ticket_items_respuesta_ocurrencia')
         AND EXISTS (SELECT 1 FROM pg_constraint
                 WHERE conname='ticket_historial_tomas_accion_check'
                 AND pg_get_constraintdef(oid) ILIKE '%NUEVA_OCURRENCIA%'),
         'supabase_migration_tickets_automaticos_al_finalizar.sql'
)
SELECT chequeo, existe, archivo,
       CASE WHEN existe THEN 'OK - ya aplicada' ELSE 'FALTA correr este .sql' END AS estado
FROM checks
ORDER BY existe ASC, chequeo;
