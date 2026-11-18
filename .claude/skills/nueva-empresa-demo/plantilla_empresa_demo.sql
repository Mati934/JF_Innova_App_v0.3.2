-- =============================================================================
-- ALTA DE EMPRESA <NOMBRE>  ·  <AAAA-MM-DD>
-- Crea la empresa y le habilita los modulos pedidos + Historial.
-- Los usuarios los crea y asocia Mati (usuario_empresas).
-- Ejecutar MANUALMENTE. Reejecutable: si (ON CONFLICT / NOT EXISTS).
-- Pasos: 0 (solo lectura) -> 1 (BEGIN..COMMIT) -> 2 (verificar).
-- =============================================================================

-- 0. SOLO LECTURA: la empresa no existe (esperado: 0 filas la primera vez).
SELECT id, nombre FROM public.empresas WHERE nombre ILIKE '<NOMBRE>';

-- 1. CAMBIO
BEGIN;

INSERT INTO public.empresas (nombre)
VALUES ('<NOMBRE>')
ON CONFLICT (nombre) DO NOTHING;

-- Claves de ModuleRegistry y su orden en Inicio. HISTORY va siempre.
INSERT INTO public.empresa_modulos (empresa_id, modulo_key, habilitado, orden)
SELECT e.id, m.modulo_key, true, m.orden
FROM public.empresas e
CROSS JOIN (VALUES
  ('<MODULO_1>', 0),
  ('HISTORY', 90)
) AS m(modulo_key, orden)
WHERE e.nombre = '<NOMBRE>'
ON CONFLICT (empresa_id, modulo_key) DO UPDATE SET habilitado = true;

COMMIT;

-- 2. VERIFICAR: correr diagnostico_empresa.sql con este nombre.
