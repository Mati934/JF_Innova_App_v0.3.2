-- =============================================================================
-- CHECKLIST(S) CONFIGURABLE(S): <<NOMBRE_DEL_LOTE>>
-- Generado con la skill nuevo-checklist (plantilla v1). Basada en
-- supabase_seed_checklists_equipos_criticos_mb_v1.sql.
--
-- Ejecutar MANUALMENTE en Supabase SQL Editor (o via MCP supabase-write con OK
-- explicito del usuario). Requiere el motor y los campos dinamicos:
--   supabase_migration_motor_checklists_configurables_v1.sql
--   supabase_migration_checklist_campos_dinamicos_v1.sql
--
-- Reejecutable: usa ON CONFLICT DO NOTHING; no sobrescribe versiones
-- publicadas, nodos ni permisos que el administrador ya haya cambiado.
-- Permisos POR ROL (PREVENCIONISTA; los admin no los necesitan): los usuarios que se
-- agreguen despues a la empresa los heredan sin volver a ejecutar nada.
--
-- Pasos:
--   0. Ejecutar SOLO la seccion 0 y revisar los "esperado".
--   1. Ejecutar TODO el bloque BEGIN ... COMMIT de una vez.
--   2. Ejecutar la seccion 2 y comparar con lo esperado.
-- =============================================================================


-- =============================================================================
-- 0. SOLO LECTURA: comprobar empresa, claves, prefijos, campos y roles
-- =============================================================================
WITH
empresas_objetivo(nombre) AS (VALUES
  ('<<EMPRESA_1>>')                       -- nombre exacto (sin distinguir mayusculas)
),
nuevos(checklist_key, prefijo) AS (VALUES
  ('chq_<<clave_1>>', '<<PREFIJO_1>>')    -- una fila por checklist del lote
),
campos_usados(clave) AS (VALUES
  ('obra_faena')                          -- claves de campos existentes que se reutilizan
)
SELECT 'empresa (esperado 1)' AS chequeo, eo.nombre AS valor, count(e.id) AS n
FROM empresas_objetivo eo
LEFT JOIN public.empresas e ON lower(e.nombre) = lower(eo.nombre)
GROUP BY eo.nombre
UNION ALL
SELECT 'clave ya existe (esperado 0; 1 si es reejecucion)', n.checklist_key, count(c.checklist_key)
FROM nuevos n LEFT JOIN public.checklists c ON c.checklist_key = n.checklist_key
GROUP BY n.checklist_key
UNION ALL
SELECT 'prefijo usado por otro checklist activo (esperado 0)', n.prefijo, count(c.checklist_key)
FROM nuevos n
LEFT JOIN public.checklists c
  ON c.report_prefix = n.prefijo AND c.activo AND c.checklist_key <> n.checklist_key
GROUP BY n.prefijo
UNION ALL
SELECT 'campo existente y activo (esperado 1)', cu.clave, count(d.id)
FROM campos_usados cu
LEFT JOIN public.checklist_campo_definiciones d ON d.clave = cu.clave AND d.activo
GROUP BY cu.clave
UNION ALL
SELECT 'rol (esperado ADMINISTRADOR y PREVENCIONISTA)', r.nombre, 1
FROM public.roles r
UNION ALL
SELECT 'form type generic_standard_form activo (esperado 1)', 'generic_standard_form', count(*)
FROM public.checklist_form_types
WHERE form_type_key = 'generic_standard_form' AND activo;


-- =============================================================================
-- 1. CONFIGURACION + CARGA (todo junto)
-- =============================================================================
BEGIN;

-- 1.1 Empresas destino ---------------------------------------------------------
CREATE TEMP TABLE cfg_empresas ON COMMIT DROP AS
SELECT e.id, replace(e.id::text, '-', '') AS hex
FROM public.empresas e
WHERE lower(e.nombre) IN (
  lower('<<EMPRESA_1>>')
);

DO $$
BEGIN
  IF (SELECT count(*) FROM cfg_empresas) <> <<CANTIDAD_EMPRESAS>> THEN
    RAISE EXCEPTION 'CFG_EMPRESA: no se encontro exactamente la cantidad de empresas esperada.';
  END IF;
END $$;

-- 1.2 Checklists del lote --------------------------------------------------------
-- icono: solo los soportados por lib/features/configurable_checklists/presentation/checklist_icons.dart
CREATE TEMP TABLE cfg_checklists ON COMMIT DROP AS
SELECT * FROM (VALUES
  -- checklist_key,     titulo,          subtitulo,          prefijo,       icono,      color,     orden
  ('chq_<<clave_1>>', '<<Titulo 1>>', '<<Subtitulo>>', '<<PREFIJO_1>>', '<<icono>>', '#1565C0', 1)
) AS t(checklist_key, titulo, subtitulo, prefijo, icono, color, orden);

-- 1.3 Navegacion en Inicio ---------------------------------------------------------
-- modo 'GRUPO'   = una tarjeta de grupo con los checklists adentro.
-- modo 'SUELTAS' = una tarjeta por checklist directamente en Inicio.
-- Se crean ambas variantes; la que no se usa queda deshabilitada y el admin
-- puede alternarla desde Administracion > Checklists.
CREATE TEMP TABLE cfg_navegacion ON COMMIT DROP AS
SELECT * FROM (VALUES
  -- grupo_base (a-z0-9_), grupo_titulo,     grupo_icono, grupo_color, modo
  ('<<grupo_base>>',      '<<Titulo grupo>>', 'category', '#1565C0', 'SUELTAS')
) AS t(grupo_base, grupo_titulo, grupo_icono, grupo_color, modo);

-- 1.4 Campos nuevos del encabezado (dejar sin filas si solo se reutilizan) -------
-- tipo: texto, texto_largo, numero, fecha, hora, email, telefono, booleano,
--       seleccion_unica, seleccion_multiple (estas dos requieren opciones).
CREATE TEMP TABLE cfg_campos_nuevos ON COMMIT DROP AS
SELECT * FROM (VALUES
  ('<<clave_campo>>', '<<Etiqueta visible>>', 'texto', '[]'::jsonb)
) AS t(clave, etiqueta, tipo, opciones);

-- 1.5 Campos asignados a cada checklist ---------------------------------------------
-- checklist_key NULL = se asigna a todos los checklists del lote.
CREATE TEMP TABLE cfg_campos ON COMMIT DROP AS
SELECT * FROM (VALUES
  (NULL::text, 'obra_faena',       1, FALSE),
  (NULL,       'region',           2, FALSE),
  (NULL,       'area_especifica',  3, FALSE),
  (NULL,       'jefatura_a_cargo', 4, FALSE),
  (NULL,       'hora_inicio',      5, FALSE),
  (NULL,       'hora_termino',     6, FALSE),
  (NULL,       'correo_empresa_1', 7, FALSE),
  (NULL,       'correo_empresa_2', 8, FALSE)
) AS t(checklist_key, clave, orden, requerido);

-- 1.6 Preguntas -----------------------------------------------------------------------
-- criticidad: Tolerable / Moderado / Intolerable (escala de inspecciones).
CREATE TEMP TABLE cfg_preguntas ON COMMIT DROP AS
SELECT * FROM (VALUES
  ('chq_<<clave_1>>', 1, '<<Categoria>>', '<<¿Pregunta?>>', 'Tolerable')
) AS t(checklist_key, orden, categoria, pregunta, criticidad);

-- 1.7 Validaciones de la configuracion ----------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cfg_checklists WHERE checklist_key !~ '^chq_[a-z0-9_]+$') THEN
    RAISE EXCEPTION 'CFG_CLAVE: checklist_key debe ser chq_ + minusculas, numeros o _.';
  END IF;
  IF EXISTS (SELECT 1 FROM cfg_checklists WHERE prefijo !~ '^[A-Z0-9-]+$') THEN
    RAISE EXCEPTION 'CFG_PREFIJO: el prefijo debe ser MAYUSCULAS, numeros o guion.';
  END IF;
  IF EXISTS (SELECT 1 FROM cfg_navegacion WHERE modo NOT IN ('GRUPO', 'SUELTAS')
                                         OR grupo_base !~ '^[a-z0-9_]+$') THEN
    RAISE EXCEPTION 'CFG_NAVEGACION: modo GRUPO o SUELTAS y grupo_base en minusculas.';
  END IF;
  IF EXISTS (
    SELECT 1 FROM cfg_checklists c
    JOIN public.checklists x ON x.report_prefix = c.prefijo
    WHERE x.activo AND x.checklist_key <> c.checklist_key
  ) THEN
    RAISE EXCEPTION 'CFG_PREFIJO_OCUPADO: un prefijo ya pertenece a otro checklist activo.';
  END IF;
  IF EXISTS (
    SELECT 1 FROM cfg_checklists c
    WHERE NOT EXISTS (SELECT 1 FROM cfg_preguntas p WHERE p.checklist_key = c.checklist_key)
  ) OR EXISTS (
    SELECT 1 FROM cfg_preguntas p
    WHERE NOT EXISTS (SELECT 1 FROM cfg_checklists c WHERE c.checklist_key = p.checklist_key)
  ) THEN
    RAISE EXCEPTION 'CFG_PREGUNTAS: cada checklist necesita preguntas y cada pregunta un checklist del lote.';
  END IF;
  IF EXISTS (
    SELECT 1 FROM cfg_preguntas
    WHERE criticidad NOT IN ('Tolerable', 'Moderado', 'Intolerable')
  ) THEN
    RAISE EXCEPTION 'CFG_CRITICIDAD: usar Tolerable, Moderado o Intolerable.';
  END IF;
END $$;

-- 1.8 Ficha de cada checklist -----------------------------------------------------------
INSERT INTO public.checklists (
  checklist_key, form_type_key, permission_key, report_prefix,
  nombre, subtitulo, icono, color
)
SELECT checklist_key, 'generic_standard_form', 'checklist.' || checklist_key,
       prefijo, titulo, subtitulo, icono, color
FROM cfg_checklists
ON CONFLICT (checklist_key) DO NOTHING;

-- 1.9 Campos: definiciones nuevas + asignaciones ----------------------------------------
INSERT INTO public.checklist_campo_definiciones (clave, etiqueta, tipo, opciones)
SELECT clave, etiqueta, tipo, opciones FROM cfg_campos_nuevos
ON CONFLICT (clave) DO NOTHING;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM cfg_campos_nuevos n
    JOIN public.checklist_campo_definiciones d ON d.clave = n.clave
    WHERE d.tipo <> n.tipo OR NOT d.activo
  ) THEN
    RAISE EXCEPTION 'CFG_CAMPO_INCOMPATIBLE: un campo nuevo ya existe con otro tipo o inactivo.';
  END IF;
  IF EXISTS (
    SELECT 1 FROM cfg_campos f
    LEFT JOIN public.checklist_campo_definiciones d ON d.clave = f.clave AND d.activo
    WHERE d.id IS NULL
  ) THEN
    RAISE EXCEPTION 'CFG_CAMPO_FALTANTE: un campo asignado no existe o esta inactivo.';
  END IF;
END $$;

INSERT INTO public.checklist_campo_asignaciones (
  checklist_key, campo_id, seccion, orden, requerido
)
SELECT c.checklist_key, d.id, 'Datos generales', f.orden, f.requerido
FROM cfg_checklists c
JOIN cfg_campos f ON f.checklist_key IS NULL OR f.checklist_key = c.checklist_key
JOIN public.checklist_campo_definiciones d ON d.clave = f.clave
ON CONFLICT (checklist_key, campo_id) DO NOTHING;

-- 1.10 Version 1 publicada (preguntas y campos congelados) -------------------------------
INSERT INTO public.checklist_versions (
  checklist_key, version, estado, snapshot_preguntas,
  snapshot_campos_extra, snapshot_reglas, published_at
)
SELECT c.checklist_key, 1, 'PUBLICADA',
  (SELECT jsonb_agg(jsonb_build_object(
     'id', p.checklist_key || '_q' || p.orden,
     'pregunta', p.pregunta, 'categoria', p.categoria,
     'orden', p.orden, 'peso', 1.0, 'criticidad', p.criticidad
   ) ORDER BY p.orden)
   FROM cfg_preguntas p WHERE p.checklist_key = c.checklist_key),
  COALESCE((SELECT jsonb_agg(jsonb_build_object(
     'id', d.id::text, 'clave', d.clave, 'etiqueta', d.etiqueta,
     'tipo', d.tipo, 'opciones', d.opciones, 'unidad', d.unidad,
     'seccion', a.seccion, 'orden', a.orden, 'requerido', a.requerido
   ) ORDER BY a.orden)
   FROM public.checklist_campo_asignaciones a
   JOIN public.checklist_campo_definiciones d ON d.id = a.campo_id
   WHERE a.checklist_key = c.checklist_key AND a.activo AND d.activo), '[]'::jsonb),
  '{}'::jsonb, now()
FROM cfg_checklists c
ON CONFLICT (checklist_key, version) DO NOTHING;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM cfg_checklists c
    JOIN public.checklists x ON x.checklist_key = c.checklist_key
    JOIN public.checklist_versions v ON v.checklist_key = c.checklist_key AND v.version = 1
    WHERE x.published_version IN (0, 1)  -- checklists en v2+ (modo C) no se revisan aqui
      AND (v.estado <> 'PUBLICADA'
       OR jsonb_array_length(v.snapshot_preguntas) <>
          (SELECT count(*) FROM cfg_preguntas p WHERE p.checklist_key = c.checklist_key))
  ) THEN
    RAISE EXCEPTION 'CFG_VERSION_EXISTENTE: ya hay una version 1 distinta. Usar la plantilla de nueva version.';
  END IF;
END $$;

UPDATE public.checklists x
SET published_version = 1, activo = TRUE, updated_at = now()
FROM cfg_checklists c
WHERE x.checklist_key = c.checklist_key AND x.published_version = 0;

-- 1.11 Tarjetas en Inicio (grupo + hijos + sueltas) --------------------------------------
INSERT INTO public.checklist_navigation_nodes (
  node_key, empresa_id, node_type, permission_key, titulo, icono, color, orden, habilitado
)
SELECT 'grp_' || n.grupo_base || '_' || e.hex, e.id, 'GROUP',
       'checklist.grupo_' || n.grupo_base, n.grupo_titulo, n.grupo_icono, n.grupo_color,
       COALESCE((SELECT max(x.orden) FROM public.checklist_navigation_nodes x
                 WHERE x.empresa_id = e.id AND x.parent_node_key IS NULL), 50) + 10,
       n.modo = 'GRUPO'
FROM cfg_empresas e CROSS JOIN cfg_navegacion n
ON CONFLICT (node_key) DO NOTHING;

INSERT INTO public.checklist_navigation_nodes (
  node_key, empresa_id, parent_node_key, node_type, checklist_key,
  permission_key, titulo, icono, color, orden, habilitado
)
SELECT 'nod_' || c.checklist_key || '_' || e.hex, e.id,
       'grp_' || n.grupo_base || '_' || e.hex, 'CHECKLIST', c.checklist_key,
       'checklist.' || c.checklist_key, c.titulo, c.icono, c.color,
       COALESCE((SELECT max(x.orden) FROM public.checklist_navigation_nodes x
                 WHERE x.parent_node_key = 'grp_' || n.grupo_base || '_' || e.hex), 0) + c.orden,
       n.modo = 'GRUPO'
FROM cfg_empresas e CROSS JOIN cfg_navegacion n CROSS JOIN cfg_checklists c
ON CONFLICT (node_key) DO NOTHING;

INSERT INTO public.checklist_navigation_nodes (
  node_key, empresa_id, node_type, checklist_key, permission_key,
  titulo, icono, color, orden, habilitado
)
SELECT 'nod_flat_' || c.checklist_key || '_' || e.hex, e.id, 'CHECKLIST', c.checklist_key,
       'checklist.' || c.checklist_key, c.titulo, c.icono, c.color,
       (SELECT max(x.orden) FROM public.checklist_navigation_nodes x
        WHERE x.empresa_id = e.id AND x.parent_node_key IS NULL) + c.orden,
       n.modo = 'SUELTAS'
FROM cfg_empresas e CROSS JOIN cfg_navegacion n CROSS JOIN cfg_checklists c
ON CONFLICT (node_key) DO NOTHING;

-- 1.12 Permisos por rol (heredados por usuarios futuros) ---------------------------------
INSERT INTO public.checklist_permission_grants (empresa_id, checklist_key, rol_id, capacidad)
SELECT e.id, c.checklist_key, r.id, cap.capacidad
FROM cfg_empresas e
CROSS JOIN cfg_checklists c
-- Solo PREVENCIONISTA: los administradores ya tienen acceso por is_admin_user().
JOIN public.roles r ON r.nombre = 'PREVENCIONISTA'
CROSS JOIN (VALUES ('ver'), ('crear'), ('editar_borrador'), ('finalizar')) AS cap(capacidad)
ON CONFLICT (empresa_id, checklist_key, rol_id, capacidad)
WHERE rol_id IS NOT NULL DO NOTHING;

-- 1.13 (Opcional) Historial para ver los informes. Descomentar solo si el usuario lo pidio.
-- INSERT INTO public.empresa_modulos (empresa_id, modulo_key, habilitado, orden)
-- SELECT id, 'HISTORY', TRUE, 90 FROM cfg_empresas
-- ON CONFLICT (empresa_id, modulo_key) DO UPDATE SET habilitado = TRUE;

COMMIT;


-- =============================================================================
-- 2. SOLO LECTURA: verificar el resultado
-- =============================================================================
-- Reemplazar la lista de claves por las del lote.
SELECT c.checklist_key, c.nombre, c.report_prefix, c.published_version, c.activo,
       jsonb_array_length(v.snapshot_preguntas)    AS preguntas,
       jsonb_array_length(v.snapshot_campos_extra) AS campos,
       (SELECT count(*) FROM public.checklist_navigation_nodes n
        WHERE n.checklist_key = c.checklist_key AND n.habilitado)  AS tarjetas_habilitadas,
       (SELECT count(*) FROM public.checklist_permission_grants g
        WHERE g.checklist_key = c.checklist_key AND g.rol_id IS NOT NULL) AS permisos_por_rol
FROM public.checklists c
JOIN public.checklist_versions v
  ON v.checklist_key = c.checklist_key AND v.version = c.published_version
WHERE c.checklist_key IN ('chq_<<clave_1>>');
-- Esperado por checklist: published_version 1, activo true, preguntas y campos
-- segun lo aprobado, tarjetas_habilitadas = 1 por empresa,
-- permisos_por_rol = 4 por empresa (PREVENCIONISTA x 4 capacidades).
