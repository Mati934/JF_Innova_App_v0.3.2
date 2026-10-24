-- Equipos Criticos: MB Embajadores. Ejecutar MANUALMENTE en Supabase.
-- Requiere motor_checklists_configurables_v1 y checklist_campos_dinamicos_v1.
-- No modifica preguntas, campos ni informes de Herramientas y Equipos.
-- Publica 3 versiones iniciales, 1 grupo + 3 hijos + 3 alternativas sueltas
-- deshabilitadas, permisos de usuarios actuales y el modulo HISTORY.
-- Reejecutable: preserva versiones publicadas y decisiones del administrador.
-- Usar junto a la app actualizada (iconos y reintentos de campos dinamicos).

-- 0. SOLO LECTURA: comprobar el nombre/id y los requisitos ANTES de continuar.
SELECT id, nombre FROM public.empresas
WHERE lower(trim(nombre)) = 'mb embajadores';

SELECT to_regclass('public.checklists') AS checklists,
       to_regclass('public.checklist_versions') AS versiones,
       to_regclass('public.checklist_navigation_nodes') AS nodos,
       to_regclass('public.checklist_permission_grants') AS permisos,
       to_regclass('public.checklist_campo_definiciones') AS campos,
       to_regclass('public.checklist_campo_asignaciones') AS asignaciones,
       to_regclass('public.checklist_campo_valores') AS valores,
       to_regprocedure('public.historial_autorizado(uuid,uuid,uuid,text)') AS historial;

-- 1. Ejecutar TODO el bloque BEGIN...COMMIT. Cualquier error revierte el bloque.
BEGIN;

DO $$
BEGIN
  IF (SELECT count(*) FROM public.empresas
      WHERE lower(trim(nombre)) = 'mb embajadores') <> 1 THEN
    RAISE EXCEPTION 'MB_EMPRESA_REQUERIDA: debe existir una unica empresa llamada MB Embajadores. Revise el nombre antes de ejecutar.';
  END IF;
  IF to_regclass('public.checklist_campo_valores') IS NULL
     OR to_regclass('public.checklist_campo_asignaciones') IS NULL
     OR to_regprocedure('public.historial_autorizado(uuid,uuid,uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'MB_MIGRACIONES_REQUERIDAS: aplique las migraciones del motor, campos dinamicos e historial primero.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.checklist_form_types
    WHERE form_type_key = 'generic_standard_form' AND activo
  ) THEN
    RAISE EXCEPTION 'MB_FORMULARIO_REQUERIDO: generic_standard_form no esta activo.';
  END IF;
END $$;

CREATE TEMP TABLE mb_empresa ON COMMIT DROP AS
SELECT id FROM public.empresas WHERE lower(trim(nombre)) = 'mb embajadores';

CREATE TEMP TABLE mb_checklists ON COMMIT DROP AS
SELECT * FROM (VALUES
  ('chq_equipo_critico', 'Equipo Crítico', 'precision_manufacturing', '#1565C0', 'MEC', 1),
  ('chq_paradas_emergencia_cintas', 'Paradas de Emergencia de Cintas', 'emergency', '#D84315', 'MPE', 2),
  ('chq_transpaleta_manual', 'Transpaleta Manual', 'pallet', '#00897B', 'MTP', 3)
) AS c(checklist_key, titulo, icono, color, prefijo, orden);

DO $$
BEGIN
  IF (SELECT count(*) FROM public.checklist_campo_definiciones
      WHERE activo AND clave IN (
        'obra_faena', 'region', 'area_especifica', 'jefatura_a_cargo',
        'hora_inicio', 'hora_termino', 'correo_empresa_1', 'correo_empresa_2'
      )) <> 8 THEN
    RAISE EXCEPTION 'MB_CAMPOS_COMUNES_REQUERIDOS: faltan campos activos del encabezado de Herramientas y Equipos.';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.checklists c
    JOIN mb_checklists m ON m.prefijo = c.report_prefix
    WHERE c.activo AND c.checklist_key <> m.checklist_key
  ) THEN
    RAISE EXCEPTION 'MB_PREFIJO_OCUPADO: MEC, MPE o MTP ya pertenece a otro checklist.';
  END IF;
END $$;

INSERT INTO public.checklists (
  checklist_key, form_type_key, permission_key, report_prefix,
  nombre, subtitulo, icono, color
)
SELECT checklist_key, 'generic_standard_form', 'checklist.' || checklist_key,
       prefijo, titulo, 'Inspección de Equipos Críticos', icono, color
FROM mb_checklists
ON CONFLICT (checklist_key) DO NOTHING;

-- Definiciones compartidas: no se crean columnas ni tablas por formulario.
INSERT INTO public.checklist_campo_definiciones (clave, etiqueta, tipo)
VALUES
  ('equipo_identificacion', 'Equipo inspeccionado (código y descripción)', 'texto'),
  ('operador_equipo', 'Operador del equipo', 'texto')
ON CONFLICT (clave) DO NOTHING;

DO $$
BEGIN
  IF (SELECT count(*) FROM public.checklist_campo_definiciones
      WHERE clave IN ('equipo_identificacion', 'operador_equipo')
        AND tipo = 'texto' AND activo) <> 2 THEN
    RAISE EXCEPTION 'MB_CAMPO_INCOMPATIBLE: identificacion de equipo/operador debe ser texto y estar activo.';
  END IF;
END $$;

INSERT INTO public.checklist_campo_asignaciones (
  checklist_key, campo_id, seccion, orden, requerido
)
SELECT c.checklist_key, d.id, 'Datos generales', f.orden, f.requerido
FROM mb_checklists c
CROSS JOIN (VALUES
  ('obra_faena', 1, FALSE), ('region', 2, FALSE),
  ('area_especifica', 3, FALSE), ('jefatura_a_cargo', 4, FALSE),
  ('hora_inicio', 5, FALSE), ('hora_termino', 6, FALSE),
  ('correo_empresa_1', 7, FALSE), ('correo_empresa_2', 8, FALSE),
  ('equipo_identificacion', 9, TRUE), ('operador_equipo', 10, TRUE)
) AS f(clave, orden, requerido)
JOIN public.checklist_campo_definiciones d ON d.clave = f.clave
ON CONFLICT (checklist_key, campo_id) DO NOTHING;

CREATE TEMP TABLE mb_preguntas ON COMMIT DROP AS
SELECT * FROM (VALUES
  ('chq_equipo_critico', 1, 'Señalización', '¿La máquina o equipo cuenta con señalización de seguridad visible y legible?'),
  ('chq_equipo_critico', 2, 'Funcionamiento', '¿Se comprobó que la máquina o equipo funciona correctamente?'),
  ('chq_equipo_critico', 3, 'Controles de seguridad', '¿Las paradas de emergencia y los sensores, cuando corresponden, funcionan correctamente?'),
  ('chq_equipo_critico', 4, 'Guardas y atrapamiento', '¿Las partes móviles y accesorios tienen protecciones que evitan el atrapamiento?'),
  ('chq_equipo_critico', 5, 'Electricidad', '¿Las conexiones eléctricas están en buen estado y sin conductores expuestos?'),
  ('chq_equipo_critico', 6, 'Personal y EPP', '¿El personal está capacitado y cuenta con el equipo de protección personal requerido?'),
  ('chq_equipo_critico', 7, 'Salud ocupacional', '¿Las personas del área utilizan correctamente la protección auditiva exigida por PREXOR, cuando corresponde?'),
  ('chq_paradas_emergencia_cintas', 1, 'Funcionamiento', '¿Al accionar cada parada de emergencia de la cinta, esta detiene el funcionamiento según el procedimiento de prueba aprobado?'),
  ('chq_paradas_emergencia_cintas', 2, 'Estado físico', '¿Las paradas de emergencia se encuentran íntegras y en buen estado?'),
  ('chq_paradas_emergencia_cintas', 3, 'Electricidad', '¿El cableado eléctrico asociado se encuentra en buen estado y sin daños visibles?'),
  ('chq_paradas_emergencia_cintas', 4, 'Accesibilidad', '¿Las paradas de emergencia están ubicadas y accesibles para accionarlas fácilmente?'),
  ('chq_transpaleta_manual', 1, 'Estructura', '¿La empuñadura está íntegra, sin fisuras ni bordes dañados?'),
  ('chq_transpaleta_manual', 2, 'Freno', '¿El freno de mano funciona correctamente, si este modelo dispone de freno?'),
  ('chq_transpaleta_manual', 3, 'Sistema hidráulico', '¿El conjunto hidráulico está limpio y lubricado, sin pernos sueltos ni fugas visibles?'),
  ('chq_transpaleta_manual', 4, 'Ruedas', '¿Las ruedas delanteras y traseras están en buen estado, sin roturas y con desgaste uniforme?'),
  ('chq_transpaleta_manual', 5, 'Funcionamiento', '¿La transpaleta opera sin ruidos extraños?'),
  ('chq_transpaleta_manual', 6, 'Estructura de carga', '¿La barra y las horquillas de elevación están íntegras, sin roturas ni deformaciones?'),
  ('chq_transpaleta_manual', 7, 'Competencia', '¿El operador cuenta con capacitación para utilizar esta transpaleta?')
) AS p(checklist_key, orden, categoria, pregunta);

INSERT INTO public.checklist_versions (
  checklist_key, version, estado, snapshot_preguntas,
  snapshot_campos_extra, snapshot_reglas, published_at
)
SELECT c.checklist_key, 1, 'PUBLICADA',
  (SELECT jsonb_agg(jsonb_build_object(
    'id', p.checklist_key || '_q' || p.orden,
    'pregunta', p.pregunta, 'categoria', p.categoria,
    'orden', p.orden, 'peso', 1.0, 'criticidad', 'Tolerable'
  ) ORDER BY p.orden) FROM mb_preguntas p WHERE p.checklist_key = c.checklist_key),
  (SELECT jsonb_agg(jsonb_build_object(
    'id', d.id::text, 'clave', d.clave, 'etiqueta', d.etiqueta,
    'tipo', d.tipo, 'opciones', d.opciones, 'unidad', d.unidad,
    'seccion', a.seccion, 'orden', a.orden, 'requerido', a.requerido
  ) ORDER BY a.orden)
   FROM public.checklist_campo_asignaciones a
   JOIN public.checklist_campo_definiciones d ON d.id = a.campo_id
   WHERE a.checklist_key = c.checklist_key AND a.activo AND d.activo),
  '{}'::jsonb, now()
FROM mb_checklists c
ON CONFLICT (checklist_key, version) DO NOTHING;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM mb_checklists m
    JOIN public.checklists c USING (checklist_key)
    JOIN public.checklist_versions v ON v.checklist_key = m.checklist_key AND v.version = 1
    WHERE c.form_type_key <> 'generic_standard_form'
       OR v.estado <> 'PUBLICADA'
       OR jsonb_array_length(v.snapshot_preguntas) <> (SELECT count(*) FROM mb_preguntas p WHERE p.checklist_key = m.checklist_key)
       OR jsonb_array_length(v.snapshot_campos_extra) <> 10
  ) THEN
    RAISE EXCEPTION 'MB_VERSION_EXISTENTE_INCOMPATIBLE: revise el catalogo; no se sobrescriben versiones existentes.';
  END IF;
END $$;

UPDATE public.checklists c
SET published_version = 1, activo = TRUE, updated_at = now()
FROM mb_checklists m
WHERE c.checklist_key = m.checklist_key AND c.published_version = 0;

-- UUID completo: evita colisiones entre empresas con el mismo prefijo.
-- El orden de raiz se calcula sin ocupar posiciones de otros grupos/nodos.
INSERT INTO public.checklist_navigation_nodes (
  node_key, empresa_id, node_type, permission_key, titulo, icono, color, orden
)
SELECT 'grp_equipos_criticos_' || replace(e.id::text, '-', ''),
       e.id, 'GROUP', 'checklist.grupo_equipos_criticos',
       'Equipos Críticos', 'factory', '#1565C0',
       COALESCE((SELECT max(n.orden) FROM public.checklist_navigation_nodes n
                 WHERE n.empresa_id = e.id AND n.parent_node_key IS NULL), 50) + 10
FROM mb_empresa e
ON CONFLICT (node_key) DO NOTHING;

INSERT INTO public.checklist_navigation_nodes (
  node_key, empresa_id, parent_node_key, node_type, checklist_key,
  permission_key, titulo, icono, color, orden
)
SELECT 'nod_' || c.checklist_key || '_' || replace(e.id::text, '-', ''),
       e.id, 'grp_equipos_criticos_' || replace(e.id::text, '-', ''),
       'CHECKLIST', c.checklist_key, 'checklist.' || c.checklist_key,
       c.titulo, c.icono, c.color, c.orden
FROM mb_empresa e CROSS JOIN mb_checklists c
ON CONFLICT (node_key) DO NOTHING;

INSERT INTO public.checklist_navigation_nodes (
  node_key, empresa_id, node_type, checklist_key, permission_key,
  titulo, icono, color, orden, habilitado
)
SELECT 'nod_flat_' || c.checklist_key || '_' || replace(e.id::text, '-', ''),
       e.id, 'CHECKLIST', c.checklist_key, 'checklist.' || c.checklist_key,
       c.titulo, c.icono, c.color,
       (SELECT max(n.orden) FROM public.checklist_navigation_nodes n
        WHERE n.empresa_id = e.id AND n.parent_node_key IS NULL) + c.orden,
       FALSE
FROM mb_empresa e CROSS JOIN mb_checklists c
ON CONFLICT (node_key) DO NOTHING;

INSERT INTO public.checklist_permission_grants (
  empresa_id, checklist_key, usuario_id, capacidad
)
SELECT e.id, c.checklist_key, u.usuario_id, cap.capacidad
FROM mb_empresa e CROSS JOIN mb_checklists c
CROSS JOIN (VALUES ('ver'), ('crear'), ('editar_borrador'), ('finalizar')) cap(capacidad)
JOIN (
  SELECT id AS usuario_id, empresa_id FROM public.usuarios WHERE empresa_id IS NOT NULL
  UNION
  SELECT usuario_id, empresa_id FROM public.usuario_empresas
) u ON u.empresa_id = e.id
ON CONFLICT (empresa_id, checklist_key, usuario_id, capacidad)
WHERE usuario_id IS NOT NULL DO NOTHING;

INSERT INTO public.empresa_modulos (empresa_id, modulo_key, habilitado, orden)
SELECT id, 'HISTORY', TRUE, 90 FROM mb_empresa
ON CONFLICT (empresa_id, modulo_key) DO UPDATE SET habilitado = TRUE;

COMMIT;

-- 2. SOLO LECTURA: esperados 3 checklists con 7/4/7 preguntas y 10 campos.
SELECT c.checklist_key, c.nombre, c.activo, c.published_version,
       jsonb_array_length(v.snapshot_preguntas) AS preguntas,
       jsonb_array_length(v.snapshot_campos_extra) AS campos
FROM public.checklists c
JOIN public.checklist_versions v ON v.checklist_key = c.checklist_key
  AND v.version = c.published_version
WHERE c.checklist_key IN ('chq_equipo_critico', 'chq_paradas_emergencia_cintas', 'chq_transpaleta_manual')
ORDER BY c.checklist_key;

-- Esperados: grupo + 3 hijos habilitados y 3 alternativas deshabilitadas
-- en la primera ejecucion. Reejecuciones preservan los cambios del admin.
SELECT e.nombre, n.node_key, n.parent_node_key, n.titulo, n.icono, n.habilitado
FROM public.checklist_navigation_nodes n
JOIN public.empresas e ON e.id = n.empresa_id
WHERE lower(trim(e.nombre)) = 'mb embajadores'
  AND (n.permission_key = 'checklist.grupo_equipos_criticos'
       OR n.checklist_key IN ('chq_equipo_critico', 'chq_paradas_emergencia_cintas', 'chq_transpaleta_manual'))
ORDER BY n.parent_node_key NULLS FIRST, n.orden;

SELECT e.nombre, em.modulo_key, em.habilitado
FROM public.empresa_modulos em JOIN public.empresas e ON e.id = em.empresa_id
WHERE lower(trim(e.nombre)) = 'mb embajadores' AND em.modulo_key = 'HISTORY';

SELECT e.nombre, g.checklist_key, g.capacidad, count(*) AS usuarios_con_permiso
FROM public.checklist_permission_grants g JOIN public.empresas e ON e.id = g.empresa_id
WHERE lower(trim(e.nombre)) = 'mb embajadores'
  AND g.checklist_key IN ('chq_equipo_critico', 'chq_paradas_emergencia_cintas', 'chq_transpaleta_manual')
GROUP BY e.nombre, g.checklist_key, g.capacidad
ORDER BY g.checklist_key, g.capacidad;
