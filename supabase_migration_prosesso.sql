-- =============================================================================
-- MIGRACIÓN: Módulo PROSESSO (Mantención y Recarga de Extintores)
-- Ejecutar en Supabase SQL Editor en orden, paso por paso.
-- =============================================================================

-- =============================================================================
-- PASO 1: Crear empresa "PROSESSO SpA"
-- =============================================================================
INSERT INTO empresas (id, nombre)
VALUES (gen_random_uuid(), 'PROSESSO SpA')
ON CONFLICT DO NOTHING;

-- =============================================================================
-- PASO 2: Tabla mantenciones_prosesso (cuerpo del servicio)
--          Cabecera del servicio = visitas_tecnicas (reutilizada).
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.mantenciones_prosesso (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visita_id UUID NOT NULL REFERENCES visitas_tecnicas(id) ON DELETE CASCADE,
  numero INTEGER NOT NULL,
  planta TEXT,
  ubicacion TEXT,
  ubicacion_sector TEXT,
  ubicacion_2 TEXT,
  certificado TEXT,                 -- alfanumérico (acepta "CN..")
  anio INTEGER,
  tipo TEXT,                        -- PQS, CO2, K, etc.
  peso TEXT,
  kg TEXT,
  fecha_vencimiento TEXT,
  observaciones TEXT,
  respuestas_json JSONB,
  fotos_json JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mantenciones_prosesso_visita
  ON public.mantenciones_prosesso(visita_id);

-- =============================================================================
-- PASO 3: Columnas extra en visitas_tecnicas para el certificado PROSESSO
-- =============================================================================
ALTER TABLE visitas_tecnicas ADD COLUMN IF NOT EXISTS cert_numero TEXT;
ALTER TABLE visitas_tecnicas ADD COLUMN IF NOT EXISTS cert_anio INTEGER;
ALTER TABLE visitas_tecnicas ADD COLUMN IF NOT EXISTS cert_correlativo INTEGER;
ALTER TABLE visitas_tecnicas ADD COLUMN IF NOT EXISTS cliente_nombre TEXT;
ALTER TABLE visitas_tecnicas ADD COLUMN IF NOT EXISTS cliente_direccion TEXT;
ALTER TABLE visitas_tecnicas ADD COLUMN IF NOT EXISTS fecha_servicio TEXT;
ALTER TABLE visitas_tecnicas ADD COLUMN IF NOT EXISTS pdf_certificado_url TEXT;

-- =============================================================================
-- PASO 4: Trigger de autoincremento del cert_correlativo por año
--         Solo se asigna cuando el servicio pasa a estado finalizado y no
--         tiene cert_correlativo aún (permite override manual).
-- =============================================================================
CREATE OR REPLACE FUNCTION asignar_cert_prosesso()
RETURNS TRIGGER AS $$
DECLARE
  proximo INTEGER;
  anio_objetivo INTEGER;
BEGIN
  IF NEW.tipo_actividad = 'MANTENCION_PROSESSO'
     AND NEW.estado_final IN ('Finalizada','En Seguimiento','Completada')
     AND (NEW.cert_correlativo IS NULL OR NEW.cert_correlativo = 0) THEN

    anio_objetivo := COALESCE(
      NEW.cert_anio,
      EXTRACT(YEAR FROM COALESCE(NEW.fecha_realizacion::timestamp, now()))::INTEGER
    );

    SELECT COALESCE(MAX(cert_correlativo), 0) + 1
      INTO proximo
      FROM visitas_tecnicas
     WHERE tipo_actividad = 'MANTENCION_PROSESSO'
       AND cert_anio = anio_objetivo;

    NEW.cert_anio := anio_objetivo;
    NEW.cert_correlativo := proximo;
    IF NEW.cert_numero IS NULL OR NEW.cert_numero = '' THEN
      NEW.cert_numero := anio_objetivo::TEXT || '/' || proximo::TEXT;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_asignar_cert_prosesso ON visitas_tecnicas;
CREATE TRIGGER trg_asignar_cert_prosesso
  BEFORE INSERT OR UPDATE ON visitas_tecnicas
  FOR EACH ROW
  EXECUTE FUNCTION asignar_cert_prosesso();

-- =============================================================================
-- PASO 5: Habilitar el módulo MANTENCION_PROSESSO SOLO para PROSESSO SpA
-- =============================================================================
INSERT INTO empresa_modulos (empresa_id, modulo_key, habilitado, orden)
SELECT e.id, 'MANTENCION_PROSESSO', true, 0
FROM empresas e
WHERE e.nombre = 'PROSESSO SpA'
ON CONFLICT (empresa_id, modulo_key) DO NOTHING;

-- (opcional) ocultar para PROSESSO los módulos que no aplican:
INSERT INTO empresa_modulos (empresa_id, modulo_key, habilitado, orden)
SELECT e.id, m.key, false, m.ord
FROM empresas e
CROSS JOIN (VALUES
  ('INSPECCION', 1),
  ('VISITA_R003', 2),
  ('VISITA_R004', 3),
  ('RENDICIONES', 4)
) AS m(key, ord)
WHERE e.nombre = 'PROSESSO SpA'
ON CONFLICT (empresa_id, modulo_key) DO NOTHING;

-- =============================================================================
-- PASO 6: Seed de las 9 preguntas del checklist
-- =============================================================================
INSERT INTO formulario_items (id, tipo_actividad, categoria, pregunta, criticidad, orden, activo)
VALUES
  (gen_random_uuid(), 'MANTENCION_PROSESSO', 'Inspección', 'Sello',       NULL, 1, true),
  (gen_random_uuid(), 'MANTENCION_PROSESSO', 'Inspección', 'Señalética',  NULL, 2, true),
  (gen_random_uuid(), 'MANTENCION_PROSESSO', 'Inspección', 'Etiqueta',    NULL, 3, true),
  (gen_random_uuid(), 'MANTENCION_PROSESSO', 'Inspección', 'Gabinete',    NULL, 4, true),
  (gen_random_uuid(), 'MANTENCION_PROSESSO', 'Inspección', 'Pintura',     NULL, 5, true),
  (gen_random_uuid(), 'MANTENCION_PROSESSO', 'Inspección', 'Seguro',      NULL, 6, true),
  (gen_random_uuid(), 'MANTENCION_PROSESSO', 'Inspección', 'Manómetro',   NULL, 7, true),
  (gen_random_uuid(), 'MANTENCION_PROSESSO', 'Inspección', 'Soporte',     NULL, 8, true),
  (gen_random_uuid(), 'MANTENCION_PROSESSO', 'Inspección', 'Manguera',    NULL, 9, true)
ON CONFLICT DO NOTHING;

-- =============================================================================
-- VERIFICACIÓN
-- =============================================================================
-- SELECT id, nombre FROM empresas WHERE nombre = 'PROSESSO SpA';
-- SELECT modulo_key, habilitado FROM empresa_modulos
--  WHERE empresa_id = (SELECT id FROM empresas WHERE nombre='PROSESSO SpA');
-- SELECT pregunta, orden FROM formulario_items
--  WHERE tipo_actividad = 'MANTENCION_PROSESSO' ORDER BY orden;
