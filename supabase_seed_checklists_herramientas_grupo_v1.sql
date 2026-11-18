-- =============================================================================
-- SIEMBRA: 5 checklists de Herramientas y Equipos en el motor configurable
-- (agrupados en 1 sola tarjeta de Inicio, estilo "Eq. Buceo").
--
-- Origen de las preguntas: ya migradas por
-- supabase_migration_checklists_herramientas_r013_r017.sql en
-- public.formulario_items (tipo_actividad VISITA_CHEQUEO_*). Este script NO
-- vuelve a insertar preguntas: solo las copia (snapshot) hacia el motor
-- checklist_versions, sin tocar ni desactivar formulario_items.
--
-- EJECUCION MANUAL OBLIGATORIA
-- 1) Ejecuta primero la seccion 0 (solo lectura) y revisa que:
--    * Los 5 conteos de formulario_items coincidan con lo esperado (20, 13,
--      13, 16, 10).
--    * Los 5 checklist_key NO existan todavia (deben salir 0 filas).
--    * empresas_objetivo muestre las empresas que recibiran la tarjeta.
-- 2) Ejecuta todo el bloque BEGIN...COMMIT.
-- 3) Ejecuta la seccion final y confirma nodos y permisos creados.
--
-- ALCANCE / PENDIENTE IMPORTANTE
-- Este motor aun NO tiene UI para campos de encabezado personalizados
-- (supervisor, obra/faena, region, horas, correos de envio, etc. del PDF de
-- referencia). Solo se siembra el checklist (preguntas + criticidad); esos
-- datos de encabezado no se pueden capturar todavia. snapshot_campos_extra
-- queda vacio a proposito.
--
-- EMPRESA OBJETIVO
-- Solo M&S. Si el nombre real en public.empresas difiere de los patrones de
-- la seccion 0, ajusta el ILIKE ahi y en las 3 CTE empresas_objetivo de mas
-- abajo antes de ejecutar el BEGIN.
--
-- MODO DE PRESENTACION
-- Se crean 2 juegos de nodos: 1 grupo con sus 5 hijos (habilitado por
-- defecto) y 5 nodos sueltos equivalentes (deshabilitados por defecto). El
-- panel de administracion (pestana "Checklists") permite alternar entre
-- "agrupado" y "suelto" con un switch, sin volver a tocar SQL.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0) CHECK PREVIO DE SOLO LECTURA
-- -----------------------------------------------------------------------------
SELECT tipo_actividad, COUNT(*) AS items_activos
FROM public.formulario_items
WHERE tipo_actividad IN (
  'VISITA_CHEQUEO_HERRAMIENTAS_MANUALES',
  'VISITA_CHEQUEO_SOLDADORA_AL_ARCO',
  'VISITA_CHEQUEO_TALADRO_DESTORNILLADOR',
  'VISITA_CHEQUEO_ESMERIL_ANGULAR',
  'VISITA_CHEQUEO_EXTENSION_ELECTRICA'
) AND activo = true
GROUP BY tipo_actividad
ORDER BY tipo_actividad;
-- Esperado: HERRAMIENTAS_MANUALES=20, SOLDADORA_AL_ARCO=13,
-- TALADRO_DESTORNILLADOR=13, ESMERIL_ANGULAR=16, EXTENSION_ELECTRICA=10.

SELECT checklist_key FROM public.checklists
WHERE checklist_key IN (
  'chq_herramientas_manuales', 'chq_soldadora_arco',
  'chq_taladro_destornillador', 'chq_esmeril_angular',
  'chq_extension_electrica'
);
-- Esperado: 0 filas (aun no sembrados).

SELECT e.id AS empresa_id, e.nombre AS empresa_nombre
FROM public.empresas e
WHERE e.nombre ILIKE '%M&S%' OR e.nombre ILIKE '%M & S%' OR e.nombre ILIKE '%MyS%'
ORDER BY e.nombre;
-- Debe salir EXACTAMENTE 1 fila: la empresa M&S. Si sale 0 o mas de 1,
-- corrige el ILIKE aqui y en las 2 CTE empresas_objetivo antes de seguir.

BEGIN;

-- -----------------------------------------------------------------------------
-- 1) CHECKLISTS (identidad estable, sin preguntas todavia)
-- -----------------------------------------------------------------------------
INSERT INTO public.checklists
  (checklist_key, form_type_key, permission_key, report_prefix, nombre, subtitulo, icono, color)
VALUES
  ('chq_herramientas_manuales', 'generic_standard_form', 'checklist.chq_herramientas_manuales', 'HM',
    'Herramientas Manuales', 'Registro de Visita', 'build_circle', '#8D6E63'),
  ('chq_soldadora_arco', 'generic_standard_form', 'checklist.chq_soldadora_arco', 'SA',
    'Soldadora al Arco', 'Registro de Visita', 'electrical_services', '#F9A825'),
  ('chq_taladro_destornillador', 'generic_standard_form', 'checklist.chq_taladro_destornillador', 'TD',
    'Taladro Destornillador', 'Registro de Visita', 'construction', '#546E7A'),
  ('chq_esmeril_angular', 'generic_standard_form', 'checklist.chq_esmeril_angular', 'EA',
    'Esmeril Angular', 'Registro de Visita', 'construction', '#455A64'),
  ('chq_extension_electrica', 'generic_standard_form', 'checklist.chq_extension_electrica', 'EE',
    'Extensión Eléctrica', 'Registro de Visita', 'power', '#EF6C00')
ON CONFLICT (checklist_key) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 2) VERSION PUBLICADA (snapshot inmutable desde formulario_items)
-- -----------------------------------------------------------------------------
INSERT INTO public.checklist_versions
  (checklist_key, version, estado, snapshot_preguntas, snapshot_campos_extra, snapshot_reglas, published_at)
SELECT
  origen.checklist_key, 1, 'PUBLICADA', origen.preguntas, '[]'::jsonb, '{}'::jsonb, now()
FROM (
  SELECT
    CASE fi.tipo_actividad
      WHEN 'VISITA_CHEQUEO_HERRAMIENTAS_MANUALES' THEN 'chq_herramientas_manuales'
      WHEN 'VISITA_CHEQUEO_SOLDADORA_AL_ARCO' THEN 'chq_soldadora_arco'
      WHEN 'VISITA_CHEQUEO_TALADRO_DESTORNILLADOR' THEN 'chq_taladro_destornillador'
      WHEN 'VISITA_CHEQUEO_ESMERIL_ANGULAR' THEN 'chq_esmeril_angular'
      WHEN 'VISITA_CHEQUEO_EXTENSION_ELECTRICA' THEN 'chq_extension_electrica'
    END AS checklist_key,
    jsonb_agg(
      jsonb_build_object(
        'id', fi.id::text, 'pregunta', fi.pregunta, 'categoria', fi.categoria,
        'criticidad', fi.criticidad, 'orden', fi.orden, 'peso', fi.peso,
        'info_adicional', fi.info_adicional
      ) ORDER BY fi.orden
    ) AS preguntas
  FROM public.formulario_items fi
  WHERE fi.tipo_actividad IN (
    'VISITA_CHEQUEO_HERRAMIENTAS_MANUALES', 'VISITA_CHEQUEO_SOLDADORA_AL_ARCO',
    'VISITA_CHEQUEO_TALADRO_DESTORNILLADOR', 'VISITA_CHEQUEO_ESMERIL_ANGULAR',
    'VISITA_CHEQUEO_EXTENSION_ELECTRICA'
  ) AND fi.activo = true
  GROUP BY fi.tipo_actividad
) origen
WHERE NOT EXISTS (
  SELECT 1 FROM public.checklist_versions cv
  WHERE cv.checklist_key = origen.checklist_key AND cv.version = 1
);

UPDATE public.checklists
SET published_version = 1, activo = true, updated_at = now()
WHERE checklist_key IN (
  'chq_herramientas_manuales', 'chq_soldadora_arco', 'chq_taladro_destornillador',
  'chq_esmeril_angular', 'chq_extension_electrica'
) AND published_version < 1;

-- -----------------------------------------------------------------------------
-- 3) NAVEGACION: 1 grupo + 5 checklists hijos, por cada empresa objetivo.
-- node_key es GLOBAL (no compuesto por empresa), por eso se deriva del id
-- de la empresa para que cada compania tenga sus propios nodos.
-- -----------------------------------------------------------------------------
WITH empresas_objetivo AS (
  SELECT e.id AS empresa_id
  FROM public.empresas e
  WHERE e.nombre ILIKE '%M&S%' OR e.nombre ILIKE '%M & S%' OR e.nombre ILIKE '%MyS%'
),
grupos AS (
  SELECT
    empresa_id,
    'grp_chq_herramientas_' || left(replace(empresa_id::text, '-', ''), 8) AS node_key
  FROM empresas_objetivo
)
INSERT INTO public.checklist_navigation_nodes
  (node_key, empresa_id, parent_node_key, node_type, checklist_key, permission_key, titulo, icono, color, orden)
SELECT node_key, empresa_id, NULL, 'GROUP', NULL, 'checklist.grupo_herramientas',
       'Herramientas y Equipos', 'build_circle', '#5D4037', 50
FROM grupos
ON CONFLICT (node_key) DO NOTHING;

WITH empresas_objetivo AS (
  SELECT e.id AS empresa_id
  FROM public.empresas e
  WHERE e.nombre ILIKE '%M&S%' OR e.nombre ILIKE '%M & S%' OR e.nombre ILIKE '%MyS%'
),
hijos AS (
  SELECT empresa_id,
         'grp_chq_herramientas_' || left(replace(empresa_id::text, '-', ''), 8) AS parent_node_key,
         checklist_key, permission_key, titulo, icono, color, orden
  FROM empresas_objetivo
  CROSS JOIN (VALUES
    ('chq_herramientas_manuales', 'checklist.chq_herramientas_manuales', 'Herramientas Manuales', 'build_circle', '#8D6E63', 1),
    ('chq_soldadora_arco', 'checklist.chq_soldadora_arco', 'Soldadora al Arco', 'electrical_services', '#F9A825', 2),
    ('chq_taladro_destornillador', 'checklist.chq_taladro_destornillador', 'Taladro Destornillador', 'construction', '#546E7A', 3),
    ('chq_esmeril_angular', 'checklist.chq_esmeril_angular', 'Esmeril Angular', 'construction', '#455A64', 4),
    ('chq_extension_electrica', 'checklist.chq_extension_electrica', 'Extensión Eléctrica', 'power', '#EF6C00', 5)
  ) AS v(checklist_key, permission_key, titulo, icono, color, orden)
)
INSERT INTO public.checklist_navigation_nodes
  (node_key, empresa_id, parent_node_key, node_type, checklist_key, permission_key, titulo, icono, color, orden)
SELECT
  'nod_' || h.checklist_key || '_' || left(replace(h.empresa_id::text, '-', ''), 8),
  h.empresa_id, h.parent_node_key, 'CHECKLIST', h.checklist_key, h.permission_key,
  h.titulo, h.icono, h.color, h.orden
FROM hijos h
ON CONFLICT (node_key) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 3.b) VISTA ALTERNATIVA: los mismos 5 checklists como tarjetas SUELTAS
-- (sin grupo), deshabilitadas por defecto. Sirven para que el admin cambie
-- de "1 tarjeta agrupada" a "5 tarjetas sueltas" sin volver a ejecutar SQL:
-- solo activa estos 5 nodos y desactiva el grupo (o viceversa) desde la
-- pestana "Checklists" del panel de administracion.
-- -----------------------------------------------------------------------------
WITH empresas_objetivo AS (
  SELECT e.id AS empresa_id
  FROM public.empresas e
  WHERE e.nombre ILIKE '%M&S%' OR e.nombre ILIKE '%M & S%' OR e.nombre ILIKE '%MyS%'
),
sueltos AS (
  SELECT empresa_id, checklist_key, permission_key, titulo, icono, color, orden
  FROM empresas_objetivo
  CROSS JOIN (VALUES
    ('chq_herramientas_manuales', 'checklist.chq_herramientas_manuales', 'Herramientas Manuales', 'build_circle', '#8D6E63', 51),
    ('chq_soldadora_arco', 'checklist.chq_soldadora_arco', 'Soldadora al Arco', 'electrical_services', '#F9A825', 52),
    ('chq_taladro_destornillador', 'checklist.chq_taladro_destornillador', 'Taladro Destornillador', 'construction', '#546E7A', 53),
    ('chq_esmeril_angular', 'checklist.chq_esmeril_angular', 'Esmeril Angular', 'construction', '#455A64', 54),
    ('chq_extension_electrica', 'checklist.chq_extension_electrica', 'Extensión Eléctrica', 'power', '#EF6C00', 55)
  ) AS v(checklist_key, permission_key, titulo, icono, color, orden)
)
INSERT INTO public.checklist_navigation_nodes
  (node_key, empresa_id, parent_node_key, node_type, checklist_key, permission_key, titulo, icono, color, orden, habilitado)
SELECT
  'nod_flat_' || s.checklist_key || '_' || left(replace(s.empresa_id::text, '-', ''), 8),
  s.empresa_id, NULL, 'CHECKLIST', s.checklist_key, s.permission_key,
  s.titulo, s.icono, s.color, s.orden, FALSE
FROM sueltos s
ON CONFLICT (node_key) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 4) PERMISOS: todo usuario actual de esas empresas puede ver, crear,
-- editar su borrador y finalizar estos 5 checklists.
-- -----------------------------------------------------------------------------
WITH empresas_objetivo AS (
  SELECT e.id AS empresa_id
  FROM public.empresas e
  WHERE e.nombre ILIKE '%M&S%' OR e.nombre ILIKE '%M & S%' OR e.nombre ILIKE '%MyS%'
),
checklists_objetivo AS (
  SELECT unnest(ARRAY[
    'chq_herramientas_manuales', 'chq_soldadora_arco', 'chq_taladro_destornillador',
    'chq_esmeril_angular', 'chq_extension_electrica'
  ]) AS checklist_key
),
capacidades AS (
  SELECT unnest(ARRAY['ver', 'crear', 'editar_borrador', 'finalizar']) AS capacidad
)
INSERT INTO public.checklist_permission_grants
  (empresa_id, checklist_key, usuario_id, capacidad)
SELECT DISTINCT u.empresa_id, c.checklist_key, u.id, cap.capacidad
FROM public.usuarios u
JOIN empresas_objetivo eo ON eo.empresa_id = u.empresa_id
CROSS JOIN checklists_objetivo c
CROSS JOIN capacidades cap
ON CONFLICT (empresa_id, checklist_key, usuario_id, capacidad)
  WHERE usuario_id IS NOT NULL DO NOTHING;

COMMIT;

-- -----------------------------------------------------------------------------
-- 5) RESULTADO FINAL
-- -----------------------------------------------------------------------------
SELECT checklist_key, published_version, activo FROM public.checklists
WHERE checklist_key LIKE 'chq_%' ORDER BY checklist_key;

SELECT node_type, count(*) AS filas
FROM public.checklist_navigation_nodes
WHERE node_key LIKE 'grp_chq_herramientas_%' OR node_key LIKE 'nod_chq_%'
   OR node_key LIKE 'nod_flat_%'
GROUP BY node_type;

SELECT checklist_key, capacidad, count(*) AS permisos_otorgados
FROM public.checklist_permission_grants
WHERE checklist_key LIKE 'chq_%'
GROUP BY checklist_key, capacidad
ORDER BY checklist_key, capacidad;
