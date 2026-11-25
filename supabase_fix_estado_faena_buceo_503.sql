-- =====================================================
-- FIX PUNTUAL: Cambiar estado_faena de inspección de buceo N° 503
-- Inspector: Yoselin Barriga
-- Ejecutar en Supabase SQL Editor (Dashboard > SQL Editor)
-- =====================================================
-- OJO: esto NO regenera el PDF ni reenvía correos.
-- Solo cambia lo que muestra la app / panel de control / historial.

-- =====================================================
-- PASO 1 (SOLO LECTURA): Verificar el registro antes de tocar nada.
-- Ejecuta este SELECT primero y revisa el resultado.
-- =====================================================
SELECT
  a.id,
  a.numero_informe,
  a.tipo_actividad,
  a.estado_final,        -- flujo (En Seguimiento = finalizada)
  a.estado_faena,        -- <-- lo que vamos a cambiar (HABILITADA/SUSPENDIDA)
  a.fecha_realizacion,
  u.nombre_completo AS inspector,
  c.nombre          AS centro,
  a.pdf_url
FROM public.actividades a
LEFT JOIN public.usuarios u ON u.id = a.usuario_id
LEFT JOIN public.centros  c ON c.id = a.centro_id
WHERE a.tipo_actividad = 'INSPECCION_BUCEO'
  AND a.numero_informe = 503
  AND u.nombre_completo ILIKE '%barriga%'
ORDER BY a.fecha_realizacion;

-- CÓMO INTERPRETAR EL RESULTADO:
-- * 1 fila  -> perfecto, esa es la inspección. Anota su "id".
-- * 0 filas -> el número o el apellido no coinciden. Quita algún filtro
--              (ej: deja solo numero_informe = 503) para encontrarla.
-- * 2+ filas -> hay duplicados de correlativo. Identifica la correcta por
--              fecha_realizacion / centro y usa el UPDATE por "id" (PASO 2B).

-- =====================================================
-- PASO 2A (UPDATE): Usar SOLO si el PASO 1 devolvió 1 sola fila.
-- Elige el valor destino: 'HABILITADA' o 'SUSPENDIDA'
-- (descomenta la línea que necesites y borra/comenta la otra)
-- =====================================================
-- UPDATE public.actividades
-- SET estado_faena = 'HABILITADA'     -- <- opción A: dejarla habilitada
-- SET estado_faena = 'SUSPENDIDA'     -- <- opción B: dejarla suspendida
-- WHERE tipo_actividad = 'INSPECCION_BUCEO'
--   AND numero_informe = 503
--   AND usuario_id IN (SELECT id FROM public.usuarios
--                      WHERE nombre_completo ILIKE '%barriga%');

-- =====================================================
-- PASO 2B (UPDATE alternativo, más seguro): por ID exacto.
-- Copia el "id" que te entregó el PASO 1 y pégalo en el WHERE.
-- =====================================================
-- UPDATE public.actividades
-- SET estado_faena = 'HABILITADA'     -- o 'SUSPENDIDA'
-- WHERE id = 'PEGAR-UUID-AQUI';

-- =====================================================
-- PASO 3 (OPCIONAL, consistencia): dejar la marca manual en
-- verificaciones_buceo para que coincida con el nuevo estado.
-- ('APROBADO' -> HABILITADA, 'SUSPENDIDO' -> SUSPENDIDA)
-- Solo aplica si esa inspección tiene fila en verificaciones_buceo.
-- =====================================================
-- UPDATE public.verificaciones_buceo
-- SET estado_manual = 'APROBADO'      -- o 'SUSPENDIDO'
-- WHERE actividad_id = 'PEGAR-UUID-AQUI';

-- =====================================================
-- PASO 4 (SOLO LECTURA): Confirmar que quedó como querías.
-- =====================================================
-- SELECT a.id, a.numero_informe, a.estado_faena, u.nombre_completo
-- FROM public.actividades a
-- LEFT JOIN public.usuarios u ON u.id = a.usuario_id
-- WHERE a.tipo_actividad = 'INSPECCION_BUCEO'
--   AND a.numero_informe = 503;
