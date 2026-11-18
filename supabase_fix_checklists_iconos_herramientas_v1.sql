-- =============================================================================
-- ICONOS DE LOS CHECKLISTS DE HERRAMIENTAS Y EQUIPOS
-- Archivo: supabase_fix_checklists_iconos_herramientas_v1.sql
-- EJECUCION MANUAL en el SQL Editor de Supabase (este archivo NO se aplica
-- solo por estar en el repo).
--
-- CONTEXTO: el seed original dejo iconos genericos ('build_circle',
-- 'construction') repetidos en varios checklists, y la app ademas los
-- ignoraba dibujando siempre Icons.fact_check_outlined. La app ya fue
-- corregida (checklist_icons.dart lee el campo 'icono'); este SQL corrige
-- los DATOS ya sembrados para que cada herramienta muestre su icono.
--
-- Solo toca la columna 'icono' de checklists y checklist_navigation_nodes.
-- No cambia permisos, ni habilitado, ni preguntas.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) CHECK (solo lectura): que iconos hay hoy
-- -----------------------------------------------------------------------------
SELECT checklist_key, nombre, icono
FROM public.checklists
WHERE checklist_key IN (
  'chq_herramientas_manuales', 'chq_soldadora_arco',
  'chq_taladro_destornillador', 'chq_esmeril_angular',
  'chq_extension_electrica'
)
ORDER BY checklist_key;
-- Interpretacion: si ya ves handyman / local_fire_department / hardware /
-- construction / electrical_services, esta migracion YA fue aplicada y puedes
-- detenerte aqui.

SELECT node_key, empresa_id, node_type, checklist_key, titulo, icono, habilitado
FROM public.checklist_navigation_nodes
WHERE checklist_key IN (
  'chq_herramientas_manuales', 'chq_soldadora_arco',
  'chq_taladro_destornillador', 'chq_esmeril_angular',
  'chq_extension_electrica'
)
ORDER BY empresa_id, orden;

-- -----------------------------------------------------------------------------
-- 2) MIGRACION
-- -----------------------------------------------------------------------------
BEGIN;

WITH iconos(checklist_key, icono) AS (
  VALUES
    ('chq_herramientas_manuales', 'handyman'),
    ('chq_soldadora_arco',        'local_fire_department'),
    ('chq_taladro_destornillador','hardware'),
    ('chq_esmeril_angular',       'construction'),
    ('chq_extension_electrica',   'electrical_services')
)
UPDATE public.checklists c
SET icono = i.icono, updated_at = now()
FROM iconos i
WHERE c.checklist_key = i.checklist_key
  AND c.icono IS DISTINCT FROM i.icono;

WITH iconos(checklist_key, icono) AS (
  VALUES
    ('chq_herramientas_manuales', 'handyman'),
    ('chq_soldadora_arco',        'local_fire_department'),
    ('chq_taladro_destornillador','hardware'),
    ('chq_esmeril_angular',       'construction'),
    ('chq_extension_electrica',   'electrical_services')
)
UPDATE public.checklist_navigation_nodes n
SET icono = i.icono, updated_at = now()
FROM iconos i
WHERE n.checklist_key = i.checklist_key
  AND n.node_type = 'CHECKLIST'
  AND n.icono IS DISTINCT FROM i.icono;

COMMIT;

-- -----------------------------------------------------------------------------
-- 3) TEST (solo lectura): verificacion final
-- -----------------------------------------------------------------------------
SELECT checklist_key, icono FROM public.checklists
WHERE checklist_key LIKE 'chq_%' ORDER BY checklist_key;
-- Esperado: handyman, local_fire_department, hardware, construction,
-- electrical_services (uno por checklist, sin repetir salvo 'construction').

SELECT icono, count(*) AS nodos
FROM public.checklist_navigation_nodes
WHERE node_type = 'CHECKLIST' AND checklist_key LIKE 'chq_%'
GROUP BY icono ORDER BY icono;
-- Esperado: 2 nodos por icono y por empresa (el agrupado + el suelto).

SELECT count(*) AS nodos_sin_icono_esperado
FROM public.checklist_navigation_nodes
WHERE node_type = 'CHECKLIST'
  AND checklist_key LIKE 'chq_%'
  AND icono NOT IN ('handyman', 'local_fire_department', 'hardware',
                    'construction', 'electrical_services');
-- Esperado: 0.
