-- =====================================================
-- MIGRACIÓN: Estado final de faena (aprobada / suspendida)
-- Ejecutar en Supabase SQL Editor (Dashboard > SQL Editor)
-- =====================================================
-- Guarda el resultado de la inspección que hasta ahora solo se calculaba
-- en memoria para el PDF y el correo:
--   INSPECCION_BUCEO       -> 'HABILITADA' | 'SUSPENDIDA'
--   INSPECCION_EMBARCACION -> 'REALIZADA'
-- Ojo: 'estado_final' sigue siendo el estado del flujo
-- ('En Progreso' | 'En Seguimiento' | 'Eliminada'), no se toca.

ALTER TABLE public.actividades
  ADD COLUMN IF NOT EXISTS estado_faena TEXT;

COMMENT ON COLUMN public.actividades.estado_faena IS
  'Resultado de la faena: HABILITADA / SUSPENDIDA / REALIZADA. Distinto de estado_final (flujo).';

CREATE INDEX IF NOT EXISTS idx_actividades_estado_faena
  ON public.actividades (estado_faena);

-- Backfill de registros históricos ya finalizados:
-- Embarcación nunca se suspende.
UPDATE public.actividades
SET estado_faena = 'REALIZADA'
WHERE estado_faena IS NULL
  AND tipo_actividad = 'INSPECCION_EMBARCACION'
  AND estado_final = 'En Seguimiento';

-- Buceo: se reconstruye desde las verificaciones críticas + forzado manual.
-- (No se consideran los hallazgos intolerables del checklist porque el
--  histórico se recalcularía con criterios que ya cambiaron.)
UPDATE public.actividades a
SET estado_faena = CASE
  WHEN v.estado_manual = 'APROBADO' THEN 'HABILITADA'
  WHEN v.estado_manual = 'SUSPENDIDO' THEN 'SUSPENDIDA'
  WHEN (v.autorizacion_autoridad_maritima)::text IN ('true', 't', '1')
   AND (v.induccion_centro_cultivo)::text IN ('true', 't', '1')
   AND (v.permiso_buceo_centro_correcto)::text IN ('true', 't', '1')
   AND (v.plan_contingencias_centro_ok)::text IN ('true', 't', '1')
   AND (v.examenes_ocupacionales_vigentes)::text IN ('true', 't', '1')
   THEN 'HABILITADA'
  ELSE 'SUSPENDIDA'
END
FROM public.verificaciones_buceo v
WHERE v.actividad_id = a.id
  AND a.estado_faena IS NULL
  AND a.tipo_actividad = 'INSPECCION_BUCEO'
  AND a.estado_final = 'En Seguimiento';

-- Verificación
SELECT tipo_actividad, estado_faena, COUNT(*)
FROM public.actividades
GROUP BY 1, 2
ORDER BY 1, 2;
