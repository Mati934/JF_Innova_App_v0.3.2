-- ============================================================
-- MIGRACIÓN: Agregar columna "peso" a formulario_items
-- Fecha: 2026-04-08
-- Propósito: Permitir ponderar preguntas en el cálculo de
--            porcentaje de cumplimiento.
--
-- Fórmula actual:  % = countC / (countC + countNC) × 100
-- Fórmula nueva:   % = sumPesoC / (sumPesoC + sumPesoNC) × 100
--
-- Todas las preguntas existentes quedan con peso=1.0 (sin cambio).
-- Las 9 preguntas nuevas de INSPECCION_BUCEO se ajustan a peso=0.53
-- para que con TODAS en NC, el % no baje de 88%.
--
-- Cálculo:
--   INSPECCION_BUCEO = 39 preguntas + 5 verificaciones bool (peso fijo 1.0)
--   Preguntas viejas: 30 × 1.0 + 5 × 1.0 = 35 puntos máximos
--   Si todas las viejas son C y las 9 nuevas son NC:
--     % = 35 / (35 + 9 × 0.53) = 35 / 39.77 = 88.0%
-- ============================================================

-- 1. Agregar columna peso con default 1.0
ALTER TABLE formulario_items
ADD COLUMN peso REAL NOT NULL DEFAULT 1.0;

-- 2. Actualizar peso de las 9 preguntas nuevas de INSPECCION_BUCEO
-- Ajustar el valor 0.53 si se necesita un piso diferente al 88%
UPDATE formulario_items
SET peso = 0.53
WHERE id IN (
  'eb5393df-265f-4ee1-8ad2-6c45d72a3460', -- [12] Supervisor distintivo chaleco
  'acc31d2f-701c-48f4-9267-17fecb2dc606', -- [13] Supervisor casco distintivo
  'db4fa982-cb9b-432d-be09-49c2f0825a78', -- [26] Consola comunicaciones protección
  '190b7da6-203f-4edc-87ac-d3cf75d30e62', -- [27] Pedestal protección banco auxiliar
  '309a9871-bad6-464c-baf8-8fbf5f2145c2', -- [34] Señalización áreas trabajo
  'ebd26ae7-01f1-4b0d-ab0d-b90f8642dde4', -- [35] Sistemas bloqueo y tarjetas
  '3883a04e-b9b7-475d-b672-86afa26fd0ad', -- [36] Escalera ascenso móvil
  '185f0f56-18ae-4af7-bd2e-f5c81530e470', -- [37] Señalización maniobras viraje
  '00115234-23db-4a9c-8189-336e12237864'  -- [38] Estación resguardo buzo emergencias
);

-- 3. Verificación
SELECT tipo_actividad, orden, pregunta, peso
FROM formulario_items
WHERE tipo_actividad = 'INSPECCION_BUCEO'
ORDER BY orden;
