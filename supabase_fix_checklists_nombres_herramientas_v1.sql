-- =============================================================================
-- FIX: quitar el prefijo "Chequeo" de los nombres del catalogo Herramientas
-- y Equipos del motor de Checklists configurables.
--
-- EJECUCION MANUAL OBLIGATORIA en el SQL Editor de Supabase.
-- 1) Ejecuta primero la seccion 0 y verifica las cinco filas.
-- 2) Ejecuta la seccion 1.
-- 3) Ejecuta la seccion 2 y confirma los nombres finales.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0) CHECK PREVIO DE SOLO LECTURA
-- -----------------------------------------------------------------------------
SELECT checklist_key, nombre AS nombre_actual
FROM public.checklists
WHERE checklist_key IN (
  'chq_herramientas_manuales',
  'chq_soldadora_arco',
  'chq_taladro_destornillador',
  'chq_esmeril_angular',
  'chq_extension_electrica'
)
ORDER BY checklist_key;
-- Esperado: cinco filas. Los nombres antiguos comienzan con "Chequeo".

-- -----------------------------------------------------------------------------
-- 1) MIGRACION IDEMPOTENTE
-- -----------------------------------------------------------------------------
UPDATE public.checklists
SET nombre = CASE checklist_key
  WHEN 'chq_herramientas_manuales' THEN 'Herramientas Manuales'
  WHEN 'chq_soldadora_arco' THEN 'Soldadora al Arco'
  WHEN 'chq_taladro_destornillador' THEN 'Taladro Destornillador'
  WHEN 'chq_esmeril_angular' THEN 'Esmeril Angular'
  WHEN 'chq_extension_electrica' THEN 'Extensión Eléctrica'
END,
updated_at = now()
WHERE checklist_key IN (
  'chq_herramientas_manuales',
  'chq_soldadora_arco',
  'chq_taladro_destornillador',
  'chq_esmeril_angular',
  'chq_extension_electrica'
)
AND nombre IN (
  'Chequeo Herramientas Manuales',
  'Chequeo Soldadora al Arco',
  'Chequeo Taladro Destornillador',
  'Chequeo Esmeril Angular',
  'Chequeo Extensión Eléctrica'
);

-- -----------------------------------------------------------------------------
-- 2) VERIFICACION FINAL
-- -----------------------------------------------------------------------------
SELECT checklist_key, nombre AS nombre_final
FROM public.checklists
WHERE checklist_key IN (
  'chq_herramientas_manuales',
  'chq_soldadora_arco',
  'chq_taladro_destornillador',
  'chq_esmeril_angular',
  'chq_extension_electrica'
)
ORDER BY checklist_key;
-- Esperado: cinco filas sin el prefijo "Chequeo".
