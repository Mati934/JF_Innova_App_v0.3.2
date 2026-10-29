-- =============================================================================
-- HISTORIAL: visibilidad por empresa y superadmin
-- Ejecutar MANUALMENTE en Supabase SQL Editor.
-- Regla: usuario = propios; admin = empresa activa; superadmin = todas.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) SOLO LECTURA: ejecutar primero y revisar los pendientes.
--    actividad/visita se asignara desde usuarios.empresa_id.
--    Si pendiente_sin_empresa > 0, NO continuar: esos informes requieren
--    asignacion manual antes de restringir el historial.
-- -----------------------------------------------------------------------------
SELECT 'actividades' AS origen, count(*) AS pendiente_sin_empresa
FROM public.actividades a
LEFT JOIN public.usuarios u ON u.id = a.usuario_id
WHERE u.empresa_id IS NULL
UNION ALL
SELECT 'visitas_tecnicas', count(*)
FROM public.visitas_tecnicas v
LEFT JOIN public.usuarios u ON u.id = v.usuario_id
WHERE u.empresa_id IS NULL;

BEGIN;

-- -----------------------------------------------------------------------------
-- 2) Persistir empresa en las cabeceras historicas y completar los registros
--    existentes usando la empresa legacy del inspector.
-- -----------------------------------------------------------------------------
ALTER TABLE public.actividades
  ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);
ALTER TABLE public.visitas_tecnicas
  ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

UPDATE public.actividades a
SET empresa_id = u.empresa_id
FROM public.usuarios u
WHERE a.usuario_id = u.id
  AND a.empresa_id IS NULL
  AND u.empresa_id IS NOT NULL;

UPDATE public.visitas_tecnicas v
SET empresa_id = u.empresa_id
FROM public.usuarios u
WHERE v.usuario_id = u.id
  AND v.empresa_id IS NULL
  AND u.empresa_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_actividades_empresa_id
  ON public.actividades(empresa_id);
CREATE INDEX IF NOT EXISTS idx_visitas_tecnicas_empresa_id
  ON public.visitas_tecnicas(empresa_id);

-- -----------------------------------------------------------------------------
-- 3) La vista mantiene todas las ramas y ahora expone empresa_id. Las tablas
--    de modulos nuevos ya la guardan; las dos ramas historicas usan la columna
--    agregada arriba. Repite el alta/backfill de forma idempotente para que este
--    bloque tambien funcione si se ejecuta aislado en SQL Editor.
-- -----------------------------------------------------------------------------
ALTER TABLE public.actividades
  ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);
ALTER TABLE public.visitas_tecnicas
  ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

UPDATE public.actividades a
SET empresa_id = u.empresa_id
FROM public.usuarios u
WHERE a.usuario_id = u.id
  AND a.empresa_id IS NULL
  AND u.empresa_id IS NOT NULL;

UPDATE public.visitas_tecnicas v
SET empresa_id = u.empresa_id
FROM public.usuarios u
WHERE v.usuario_id = u.id
  AND v.empresa_id IS NULL
  AND u.empresa_id IS NOT NULL;

DROP VIEW IF EXISTS public.historial_unificado;

CREATE VIEW public.historial_unificado AS
SELECT a.id::text AS id, 'Inspección'::text AS modulo,
       a.tipo_actividad::text AS tipo_registro, a.estado_final::text AS estado,
       COALESCE(c.nombre, 'Sin ubicación') AS ubicacion,
       a.fecha_realizacion::timestamptz AS fecha_realizacion,
       a.numero_informe::text AS numero_reporte, a.pdf_url,
       NULL::text AS pdf_certificado_url, u.nombre_completo AS inspector_nombre,
       COALESCE(a.numero_seguimiento, 0)::integer AS numero_seguimiento,
       a.usuario_id, a.centro_id, a.embarcacion_id, a.empresa_id
FROM public.actividades a
LEFT JOIN public.centros c ON c.id = a.centro_id
LEFT JOIN public.usuarios u ON u.id = a.usuario_id
WHERE a.estado_final NOT IN ('Eliminada', 'En Progreso')
UNION ALL
SELECT v.id::text,
       CASE WHEN v.tipo_actividad = 'VISITA_R004' THEN 'Inspección Extintores'
            WHEN v.tipo_actividad = 'MANTENCION_PROSESSO' THEN 'Mantención de Extintores'
            ELSE 'Visita Técnica' END::text,
       v.tipo_actividad::text, v.estado_final::text,
       COALESCE(NULLIF(v.cliente_nombre, ''), NULLIF(v.lugar_visita, ''), 'Sin ubicación'),
       v.fecha_realizacion::timestamptz, v.cert_numero::text, v.pdf_url,
       v.pdf_certificado_url, u.nombre_completo, 0::integer, v.usuario_id,
       NULL::uuid, NULL::uuid, v.empresa_id
FROM public.visitas_tecnicas v
LEFT JOIN public.usuarios u ON u.id = v.usuario_id
WHERE v.estado_final NOT IN ('Eliminada', 'En Progreso')
UNION ALL
SELECT h.id::text, 'Hidroser'::text, h.lista_codigo::text, h.estado_final::text,
       COALESCE(NULLIF(hl.nombre, ''), 'Sin ubicación'), h.fecha_realizacion::timestamptz,
       h.correlativo::text, h.pdf_url, NULL::text,
       COALESCE(NULLIF(h.quien_inspecciona, ''), u.nombre_completo), 0::integer,
       h.usuario_id, NULL::uuid, NULL::uuid, h.empresa_id
FROM public.hidroser_inspecciones h
LEFT JOIN public.hidroser_listas hl ON hl.codigo = h.lista_codigo
LEFT JOIN public.usuarios u ON u.id = h.usuario_id
WHERE h.estado_final NOT IN ('Eliminada', 'En Progreso')
  AND h.lista_codigo NOT IN ('BUCEO_SAL_20M', 'BUCEO_SAM_36M')
UNION ALL
SELECT a.id::text, 'AST'::text, 'AST'::text, a.estado_final::text,
       COALESCE(NULLIF(a.centro_nombre, ''), NULLIF(a.contratista_nombre, ''), 'Sin ubicación'),
       a.fecha_realizacion::timestamptz, a.correlativo::text, a.pdf_url, NULL::text,
       COALESCE(NULLIF(a.profesional, ''), u.nombre_completo), 0::integer,
       a.usuario_id, a.centro_id, a.embarcacion_id, a.empresa_id
FROM public.ast_informes a
LEFT JOIN public.usuarios u ON u.id = a.usuario_id
WHERE a.estado_final NOT IN ('Eliminada', 'En Progreso')
UNION ALL
SELECT b.id::text, 'Equipamiento de Buceo'::text, b.lista_codigo::text,
       b.estado_final::text, COALESCE(NULLIF(bl.nombre, ''), 'Sin ubicación'),
       b.fecha_realizacion::timestamptz, b.correlativo::text, b.pdf_url, NULL::text,
       COALESCE(NULLIF(b.quien_inspecciona, ''), u.nombre_completo), 0::integer,
       b.usuario_id, NULL::uuid, NULL::uuid, b.empresa_id
FROM public.buceo_equipamiento_inspecciones b
LEFT JOIN public.buceo_equipamiento_listas bl ON bl.codigo = b.lista_codigo
LEFT JOIN public.usuarios u ON u.id = b.usuario_id
WHERE b.estado_final NOT IN ('Eliminada', 'En Progreso')
UNION ALL
SELECT m.id::text,
       CASE WHEN m.tipo_actividad = 'MERIEUX_EXTINTORES' THEN 'Merieux - Mantención de Extintores'
            ELSE 'Merieux - Registro de Visita' END::text,
       COALESCE(m.checklist_tipo, m.tipo_actividad)::text, m.estado_final::text,
       COALESCE(NULLIF(m.area, ''), NULLIF(m.region, ''), 'Sin ubicación'),
       m.fecha_realizacion::timestamptz, m.correlativo::text, m.pdf_url, NULL::text,
       COALESCE(NULLIF(m.profesional, ''), u.nombre_completo), 0::integer,
       m.usuario_id, NULL::uuid, NULL::uuid, m.empresa_id
FROM public.merieux_visitas m
LEFT JOIN public.usuarios u ON u.id = m.usuario_id
WHERE m.estado_final NOT IN ('Eliminada', 'En Progreso') AND m.eliminado = false;

-- -----------------------------------------------------------------------------
-- 4) Solo un admin asociado a empresa administradora puede cruzar empresas.
--    La RPC es la unica API de lectura; la vista ya no se expone directamente.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_superadmin_user()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.is_admin_user() AND (
    EXISTS (
      SELECT 1 FROM public.usuario_empresas ue
      JOIN public.empresas e ON e.id = ue.empresa_id
      WHERE ue.usuario_id = auth.uid() AND e.es_administradora = true
    ) OR EXISTS (
      SELECT 1 FROM public.usuarios u
      JOIN public.empresas e ON e.id = u.empresa_id
      WHERE u.id = auth.uid() AND e.es_administradora = true
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.historial_autorizado(
  p_empresa_id uuid DEFAULT NULL,
  p_usuario_id uuid DEFAULT NULL,
  p_centro_id uuid DEFAULT NULL,
  p_modulo text DEFAULT NULL
)
RETURNS TABLE (
  id text, modulo text, tipo_registro text, estado text, ubicacion text,
  fecha_realizacion timestamptz, numero_reporte text, pdf_url text,
  pdf_certificado_url text, inspector_nombre text, numero_seguimiento integer,
  usuario_id uuid, centro_id uuid, embarcacion_id uuid, empresa_id uuid,
  empresa_nombre text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT h.*, e.nombre
  FROM public.historial_unificado h
  LEFT JOIN public.empresas e ON e.id = h.empresa_id
  WHERE h.estado NOT IN ('Eliminada', 'En Progreso', 'Borrador')
    AND (p_centro_id IS NULL OR h.centro_id = p_centro_id)
    AND (p_modulo IS NULL OR h.modulo = p_modulo)
    AND (p_usuario_id IS NULL OR h.usuario_id = p_usuario_id)
    AND (
      public.is_superadmin_user()
      OR (public.is_admin_user()
          AND p_empresa_id IS NOT NULL
          AND public.user_has_empresa(p_empresa_id)
          AND h.empresa_id = p_empresa_id)
      OR (NOT public.is_admin_user() AND h.usuario_id = auth.uid())
    )
  ORDER BY h.fecha_realizacion DESC;
$$;

REVOKE ALL ON public.historial_unificado FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.historial_autorizado(uuid, uuid, uuid, text)
  TO authenticated;

COMMIT;

-- -----------------------------------------------------------------------------
-- 5) VERIFICACIONES posteriores a la migracion.
--    0 pendientes = todos los informes tienen empresa; cada total debe ser 0.
-- -----------------------------------------------------------------------------
SELECT modulo, count(*) AS informes_sin_empresa
FROM public.historial_unificado
WHERE empresa_id IS NULL
GROUP BY modulo
ORDER BY modulo;

SELECT p.proname, has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_puede_ejecutar
FROM pg_proc p
WHERE p.proname = 'historial_autorizado';