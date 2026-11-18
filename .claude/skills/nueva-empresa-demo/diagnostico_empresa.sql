-- Diagnostico de una empresa (SOLO LECTURA). Reemplazar el nombre en cfg.
WITH cfg AS (SELECT 'Nombre Empresa'::text AS nombre),
e AS (
  SELECT em.* FROM public.empresas em, cfg WHERE em.nombre ILIKE cfg.nombre
)
SELECT 'empresa' AS paso, coalesce((SELECT nombre FROM e), 'NO EXISTE') AS detalle
UNION ALL
SELECT 'modulos', coalesce(string_agg(m.modulo_key || CASE WHEN m.habilitado THEN '' ELSE ' (deshabilitado)' END, ', ' ORDER BY m.orden), 'SIN MODULOS')
FROM e LEFT JOIN public.empresa_modulos m ON m.empresa_id = e.id
UNION ALL
SELECT 'usuarios', coalesce(string_agg(u.nombre_completo || ' (' || (
         SELECT count(*) FROM public.usuario_empresas x WHERE x.usuario_id = u.id
       ) || ' empresa/s)', ', '), 'SIN USUARIOS')
FROM e
LEFT JOIN public.usuario_empresas ue ON ue.empresa_id = e.id
LEFT JOIN public.usuarios u ON u.id = ue.usuario_id
UNION ALL
SELECT 'usuarios_legacy', coalesce(string_agg(u.nombre_completo, ', '), '-')
FROM e LEFT JOIN public.usuarios u ON u.empresa_id = e.id
UNION ALL
SELECT 'areas', coalesce(string_agg(a.nombre, ', '), 'SIN AREAS PROPIAS (vera las de todas las empresas)')
FROM e LEFT JOIN public.empresa_areas ea ON ea.empresa_id = e.id
LEFT JOIN public.areas a ON a.id = ea.area_id
UNION ALL
SELECT 'centros', count(c.id)::text
FROM e JOIN public.empresa_areas ea ON ea.empresa_id = e.id
JOIN public.centros c ON c.area_id = ea.area_id
UNION ALL
SELECT 'checklists_motor', coalesce(string_agg(DISTINCT n.checklist_key, ', '), '-')
FROM e LEFT JOIN public.checklist_navigation_nodes n ON n.empresa_id = e.id;
