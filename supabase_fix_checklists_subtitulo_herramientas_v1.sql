-- =============================================================================
-- FIX: quitar el subtitulo generico "Registro de Visita" de los 5 checklists
-- de Herramientas y Equipos (motor configurable).
--
-- Origen del problema: supabase_seed_checklists_herramientas_grupo_v1.sql
-- sembro `checklists.subtitulo = 'Registro de Visita'` para los 5 checklists
-- (copy/paste de otro modulo). Ese subtitulo se muestra en la tarjeta de
-- Inicio y en el listado del grupo "Herramientas y Equipos", haciendo creer
-- que el checklist es un "Registro de Visita" generico en vez de mostrar su
-- nombre completo (ej. "Chequeo Esmeril Angular").
--
-- EJECUCION MANUAL OBLIGATORIA en el SQL Editor de Supabase.
-- 1) Ejecuta primero el SELECT de solo lectura (seccion 0) y revisa que:
--    * Salgan EXACTAMENTE 5 filas.
--    * La columna `subtitulo_actual` diga 'Registro de Visita' en todas.
--    Si alguna fila ya tiene otro subtitulo (porque alguien la edito a mano),
--    NO la sobrescribas: ajusta el WHERE del UPDATE para excluirla.
-- 2) Ejecuta el UPDATE (seccion 1).
-- 3) Ejecuta el SELECT final (seccion 2) y confirma que `subtitulo` quedo NULL
--    en las 5 filas.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0) CHECK PREVIO DE SOLO LECTURA
-- -----------------------------------------------------------------------------
SELECT checklist_key, nombre, subtitulo AS subtitulo_actual
FROM public.checklists
WHERE checklist_key IN (
  'chq_herramientas_manuales', 'chq_soldadora_arco',
  'chq_taladro_destornillador', 'chq_esmeril_angular',
  'chq_extension_electrica'
)
ORDER BY checklist_key;
-- Esperado: 5 filas, todas con subtitulo_actual = 'Registro de Visita'.

-- -----------------------------------------------------------------------------
-- 1) UPDATE (deja el subtitulo vacio; la tarjeta y el listado mostraran solo
--    el nombre completo del checklist, sin texto generico enganoso).
-- -----------------------------------------------------------------------------
UPDATE public.checklists
SET subtitulo = NULL, updated_at = now()
WHERE checklist_key IN (
  'chq_herramientas_manuales', 'chq_soldadora_arco',
  'chq_taladro_destornillador', 'chq_esmeril_angular',
  'chq_extension_electrica'
)
AND subtitulo = 'Registro de Visita';

-- -----------------------------------------------------------------------------
-- 2) VERIFICACION FINAL
-- -----------------------------------------------------------------------------
SELECT checklist_key, nombre, subtitulo AS subtitulo_actual
FROM public.checklists
WHERE checklist_key IN (
  'chq_herramientas_manuales', 'chq_soldadora_arco',
  'chq_taladro_destornillador', 'chq_esmeril_angular',
  'chq_extension_electrica'
)
ORDER BY checklist_key;
-- Esperado: subtitulo_actual = NULL en las 5 filas.
--
-- NOTA: si la app tiene el catalogo de checklists cacheado en SQLite (mirror
-- local), el cambio se reflejara despues del proximo sync de datos maestros
-- (o reinstalando/recargando la sesion). No requiere cambios de codigo.
