-- =============================================================================
-- MIGRACION COMPLETA: Modulo BUCEO_EQUIPAMIENTO independiente
-- Objetivo:
--   1) Crear tablas propias de listas, items, inspecciones y respuestas.
--   2) Crear correlativo propio del modulo.
--   3) Seed de catalogo (SAL/SAM) e items base.
--   4) Habilitar el modulo para todas las empresas existentes.
--
-- Seguro de ejecutar multiples veces (idempotente).
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- A) TABLAS PROPIAS DEL MODULO
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.buceo_equipamiento_listas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo TEXT NOT NULL UNIQUE,
  nombre TEXT NOT NULL,
  subtitulo TEXT,
  icono TEXT DEFAULT 'scuba_diving',
  orden INTEGER NOT NULL DEFAULT 0,
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.buceo_equipamiento_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lista_codigo TEXT NOT NULL REFERENCES public.buceo_equipamiento_listas(codigo) ON DELETE CASCADE,
  categoria TEXT NOT NULL,
  pregunta TEXT NOT NULL,
  aplica_por_buzo BOOLEAN NOT NULL DEFAULT false,
  criticidad TEXT,
  peso INTEGER NOT NULL DEFAULT 1,
  orden INTEGER NOT NULL DEFAULT 0,
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (lista_codigo, orden),
  UNIQUE (lista_codigo, pregunta)
);

CREATE TABLE IF NOT EXISTS public.buceo_equipamiento_inspecciones (
  id UUID PRIMARY KEY,
  usuario_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
  empresa_id UUID REFERENCES public.empresas(id) ON DELETE SET NULL,
  lista_codigo TEXT NOT NULL REFERENCES public.buceo_equipamiento_listas(codigo),
  fecha_realizacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  numero_informe INTEGER,
  correlativo TEXT,
  quien_inspecciona TEXT,
  observaciones TEXT,
  campos_extra JSONB NOT NULL DEFAULT '{}'::jsonb,
  firma_supervisor_nombre TEXT,
  firma_operador_nombre TEXT,
  estado_final TEXT NOT NULL DEFAULT 'Borrador',
  pdf_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.buceo_equipamiento_respuestas (
  id UUID PRIMARY KEY,
  inspeccion_id UUID NOT NULL REFERENCES public.buceo_equipamiento_inspecciones(id) ON DELETE CASCADE,
  item_id UUID REFERENCES public.buceo_equipamiento_items(id) ON DELETE SET NULL,
  buzo_idx INTEGER,
  estado TEXT,
  observacion TEXT,
  criticidad TEXT,
  foto_path TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_buceo_eq_buzo_idx CHECK (buzo_idx IS NULL OR buzo_idx BETWEEN 1 AND 5)
);

ALTER TABLE public.buceo_equipamiento_items
  ADD COLUMN IF NOT EXISTS aplica_por_buzo BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.buceo_equipamiento_inspecciones
  ADD COLUMN IF NOT EXISTS numero_informe INTEGER;

ALTER TABLE public.buceo_equipamiento_respuestas
  ADD COLUMN IF NOT EXISTS buzo_idx INTEGER;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_buceo_eq_buzo_idx'
      AND conrelid = 'public.buceo_equipamiento_respuestas'::regclass
  ) THEN
    ALTER TABLE public.buceo_equipamiento_respuestas
      ADD CONSTRAINT chk_buceo_eq_buzo_idx
      CHECK (buzo_idx IS NULL OR buzo_idx BETWEEN 1 AND 5);
  END IF;
END $$;

ALTER TABLE public.buceo_equipamiento_respuestas
  DROP CONSTRAINT IF EXISTS buceo_equipamiento_respuestas_inspeccion_id_item_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS ux_buceo_eq_resp_item_general
  ON public.buceo_equipamiento_respuestas(inspeccion_id, item_id)
  WHERE buzo_idx IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_buceo_eq_resp_item_buzo
  ON public.buceo_equipamiento_respuestas(inspeccion_id, item_id, buzo_idx)
  WHERE buzo_idx IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_buceo_eq_listas_activo
  ON public.buceo_equipamiento_listas(activo, orden);

CREATE INDEX IF NOT EXISTS idx_buceo_eq_items_lista
  ON public.buceo_equipamiento_items(lista_codigo, orden);

CREATE INDEX IF NOT EXISTS idx_buceo_eq_insp_empresa
  ON public.buceo_equipamiento_inspecciones(empresa_id);

CREATE INDEX IF NOT EXISTS idx_buceo_eq_insp_estado
  ON public.buceo_equipamiento_inspecciones(estado_final);

CREATE INDEX IF NOT EXISTS idx_buceo_eq_insp_fecha
  ON public.buceo_equipamiento_inspecciones(fecha_realizacion DESC);

CREATE INDEX IF NOT EXISTS idx_buceo_eq_resp_insp
  ON public.buceo_equipamiento_respuestas(inspeccion_id);

-- -----------------------------------------------------------------------------
-- B) CORRELATIVO PROPIO DEL MODULO
--    Formato: BUCEO-EQ-{LISTA}-AAAA-NNNN (solo al pasar a En Seguimiento)
--    numero_informe: correlativo numérico automático por lista (1..N).
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.buceo_equipamiento_numeradores (
  lista_codigo TEXT PRIMARY KEY REFERENCES public.buceo_equipamiento_listas(codigo) ON DELETE CASCADE,
  ultimo_numero INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.fn_buceo_equipamiento_set_correlativo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_next BIGINT;
  v_prefijo TEXT;
BEGIN
  IF NEW.estado_final = 'En Seguimiento' AND COALESCE(NEW.numero_informe, 0) <= 0 THEN
    INSERT INTO public.buceo_equipamiento_numeradores (lista_codigo, ultimo_numero)
    VALUES (NEW.lista_codigo, 1)
    ON CONFLICT (lista_codigo)
    DO UPDATE SET
      ultimo_numero = public.buceo_equipamiento_numeradores.ultimo_numero + 1,
      updated_at = now()
    RETURNING ultimo_numero INTO v_next;

    NEW.numero_informe := v_next;
  ELSE
    v_next := NEW.numero_informe;
  END IF;

  IF NEW.estado_final = 'En Seguimiento' AND (NEW.correlativo IS NULL OR NEW.correlativo = '') THEN
    v_prefijo := CASE NEW.lista_codigo
      WHEN 'BUCEO_SAL_20M' THEN 'SAL20'
      WHEN 'BUCEO_SAM_36M' THEN 'SAM36'
      ELSE 'GEN'
    END;

    NEW.correlativo := format(
      'BUCEO-EQ-%s-%s-%s',
      v_prefijo,
      to_char(COALESCE(NEW.fecha_realizacion, now()), 'YYYY'),
      lpad(COALESCE(v_next, NEW.numero_informe, 1)::text, 4, '0')
    );
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_buceo_equipamiento_correlativo ON public.buceo_equipamiento_inspecciones;

CREATE TRIGGER trg_buceo_equipamiento_correlativo
BEFORE INSERT OR UPDATE ON public.buceo_equipamiento_inspecciones
FOR EACH ROW
EXECUTE FUNCTION public.fn_buceo_equipamiento_set_correlativo();

WITH ranked AS (
  SELECT
    i.id,
    i.lista_codigo,
    ROW_NUMBER() OVER (
      PARTITION BY i.lista_codigo
      ORDER BY COALESCE(i.fecha_realizacion, i.created_at), i.id
    ) AS rn
  FROM public.buceo_equipamiento_inspecciones i
  WHERE i.estado_final = 'En Seguimiento'
)
UPDATE public.buceo_equipamiento_inspecciones i
SET numero_informe = r.rn
FROM ranked r
WHERE i.id = r.id
  AND COALESCE(i.numero_informe, 0) <= 0;

INSERT INTO public.buceo_equipamiento_numeradores (lista_codigo, ultimo_numero)
SELECT i.lista_codigo, MAX(i.numero_informe)
FROM public.buceo_equipamiento_inspecciones i
WHERE COALESCE(i.numero_informe, 0) > 0
GROUP BY i.lista_codigo
ON CONFLICT (lista_codigo)
DO UPDATE SET
  ultimo_numero = GREATEST(
    public.buceo_equipamiento_numeradores.ultimo_numero,
    EXCLUDED.ultimo_numero
  ),
  updated_at = now();

-- -----------------------------------------------------------------------------
-- C) CATALOGO BASE DEL MODULO (LISTAS + ITEMS)
-- -----------------------------------------------------------------------------

INSERT INTO public.buceo_equipamiento_listas (
  codigo,
  nombre,
  subtitulo,
  icono,
  orden,
  activo
)
VALUES
  ('BUCEO_SAL_20M', 'Inspeccion de equipo SAL', 'Lista de chequeo faena 20 metros', 'scuba_diving', 70, true),
  ('BUCEO_SAM_36M', 'Inspeccion de equipo SAM', 'Lista de chequeo faena 36 metros', 'scuba_diving', 71, true)
ON CONFLICT (codigo)
DO UPDATE SET
  nombre = EXCLUDED.nombre,
  subtitulo = EXCLUDED.subtitulo,
  icono = EXCLUDED.icono,
  orden = EXCLUDED.orden,
  activo = EXCLUDED.activo,
  updated_at = now();

WITH base_items(lista_codigo, categoria, pregunta, aplica_por_buzo, criticidad, peso, orden, activo) AS (
  VALUES
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Compresor de buceo profesional de baja presión, con entrega mínima de 115 lt/min y 8 bar para un buzo hasta 20 m.', false, 'Intolerable', 1, 10, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Motor combustión en buen estado, sin filtración, piola de arranque en buen estado.', false, 'Alto', 1, 20, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Nivel de aceite motor y cabezal en buen estado.', false, 'Alto', 1, 30, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Estanque acumulador en buen estado, limpio y sin partículas en su interior.', false, 'Alto', 1, 40, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Compresor con filtros de purificación de aire en buen estado y no saturados.', false, 'Intolerable', 1, 50, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Partes móviles del compresor protegidas.', false, 'Alto', 1, 60, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Correas de transmisión en buen estado sin desgaste.', false, 'Alto', 1, 70, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Filtros de aspiración de aire en buen estado, no saturados ni húmedos, orientados a barlovento.', false, 'Intolerable', 1, 80, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Manguera de toma de aire atóxica y en buen estado, sin desgaste ni rotura.', false, 'Intolerable', 1, 90, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Válvula de alivio cabezal en buen estado sin filtración.', false, 'Alto', 1, 100, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Válvula de seguridad en buen estado y regulada a 8 bar mínimo.', false, 'Intolerable', 1, 110, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Válvula corte rápido en buen estado a la salida del acumulador.', false, 'Alto', 1, 120, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Manguera de alta presión operativa, sin desgaste ni rotura.', false, 'Intolerable', 1, 130, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Válvula de retención operativa y en buen estado.', false, 'Alto', 1, 140, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Válvula de despiche acumulador operativa, sin filtración.', false, 'Alto', 1, 150, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Manómetro operativo (números legibles, vidrio en buen estado, aguja funcional).', false, 'Alto', 1, 160, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Niples y conectores de compresor general sin corrosión y en buen estado.', false, 'Alto', 1, 170, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Mosquetón de acero inoxidable.', false, 'Medio', 1, 180, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Manillas adecuadas para transporte.', false, 'Medio', 1, 190, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Ruedas en buen estado.', false, 'Medio', 1, 200, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Bandera alfa disponible.', false, 'Intolerable', 1, 210, true),
  ('BUCEO_SAL_20M', 'Equipos y elementos de apoyo para faenas de 20 metros', 'Otros elementos de apoyo verificados.', false, 'Bajo', 1, 220, true),

  ('BUCEO_SAL_20M', 'Manguera de buceo', 'Buen estado visual.', false, 'Intolerable', 1, 300, true),
  ('BUCEO_SAL_20M', 'Manguera de buceo', 'Cumple marcas reglamentarias cada 10 m.', false, 'Intolerable', 1, 310, true),
  ('BUCEO_SAL_20M', 'Manguera de buceo', 'Sin roturas ni rayas en sus tramos.', false, 'Intolerable', 1, 320, true),
  ('BUCEO_SAL_20M', 'Manguera de buceo', 'Válvula de retención en buen estado.', false, 'Alto', 1, 330, true),
  ('BUCEO_SAL_20M', 'Manguera de buceo', 'Apta para continuar su uso en faena.', false, 'Intolerable', 1, 340, true),

  ('BUCEO_SAL_20M', 'Emergencia', 'Botiquín de primeros auxilios básico.', false, 'Intolerable', 1, 400, true),
  ('BUCEO_SAL_20M', 'Emergencia', 'Procedimiento o Manual de Primeros Auxilios (plastificado).', false, 'Intolerable', 1, 410, true),
  ('BUCEO_SAL_20M', 'Emergencia', 'Unidad de O2 medicinal para emergencia.', false, 'Intolerable', 1, 420, true),
  ('BUCEO_SAL_20M', 'Emergencia', 'Tablas de Descompresión plastificadas (I a V).', false, 'Intolerable', 1, 430, true),

  ('BUCEO_SAL_20M', 'Documentos', 'Permiso de buceo autorizado por la AAMM.', false, 'Intolerable', 1, 500, true),
  ('BUCEO_SAL_20M', 'Documentos', 'Matrículas del personal de buzos vigentes.', false, 'Intolerable', 1, 510, true),
  ('BUCEO_SAL_20M', 'Documentos', 'Matrícula del compresor vigente.', false, 'Intolerable', 1, 520, true),
  ('BUCEO_SAL_20M', 'Documentos', 'Plan de contingencia en caso de accidentes de buceo.', false, 'Intolerable', 1, 530, true),
  ('BUCEO_SAL_20M', 'Documentos', 'Resolución de autorización del plan de contingencia o carta de entrega.', false, 'Intolerable', 1, 540, true),
  ('BUCEO_SAL_20M', 'Documentos', 'Bitácora de buceo y lista de chequeo diaria de faena.', false, 'Alto', 1, 550, true),
  ('BUCEO_SAL_20M', 'Documentos', 'Bitácora de mantención del compresor u otro respaldo de trazabilidad.', false, 'Alto', 1, 560, true),
  ('BUCEO_SAL_20M', 'Documentos', 'Exámenes pre/ocupacionales por buzo aptos.', false, 'Intolerable', 1, 570, true),
  ('BUCEO_SAL_20M', 'Documentos', 'Registro de entrega de EPP para buceo y trabajo en superficie.', false, 'Alto', 1, 580, true)
),
personal_items(pregunta_base, orden_base) AS (
  VALUES
  ('Traje de buceo en buen estado', 1),
  ('Botines de buceo', 2),
  ('Slip de buceo (Opcional)', 3),
  ('Polera de buceo (Opcional)', 4),
  ('Calcetas de buceo (Opcional)', 5),
  ('Guantes de protección', 6),
  ('Cuchillos de buceo, sin punta, con amarre y funda', 7),
  ('Computador de buceo o profundímetro digital operativo', 8),
  ('Regulador de buceo con chicote (buen estado)', 9),
  ('Arnés con hebilla de escape rápido en buen estado', 10),
  ('Caperuza', 11)
),
sam_items(lista_codigo, categoria, pregunta, aplica_por_buzo, criticidad, peso, orden, activo) AS (
  VALUES
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Compresor de buceo profesional de baja presion, con entrega de volumen y presion, minima de 350 lt./min. y 13 bar respectivamente considerando la operacion de dos buzos, hasta una profundidad maxima de 36 metros', false, 'Intolerable', 1, 10, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Motor combustion en buen estado, sin filtracion, piola de arranque en buen estado.', false, 'Alto', 1, 20, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Nivel de aceite motor y cabezal en buen estado', false, 'Alto', 1, 30, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Estanque acumulador visualmente en buen estado sin golpes ni desgaste, limpio y sin particulas en su interior.', false, 'Alto', 1, 40, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Compresor cuenta con sistemas de filtros de purificacion de aire en buen estado y no saturados', false, 'Intolerable', 1, 50, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Partes moviles compresor protegidas', false, 'Alto', 1, 60, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Correas de transmision en buen estado sin desgaste.', false, 'Alto', 1, 70, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Filtros de aspiracion de aire en buen estado (no saturado/sin humedad o mojado) orientado a barlovento', false, 'Intolerable', 1, 80, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Manguera de toma de aire atoxica y en buen estado, sin desgaste o rotura.', false, 'Intolerable', 1, 90, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Valvula de alivio cabezal en buen estado sin filtracion', false, 'Alto', 1, 100, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Valvula de seguridad en buen estado y regulada a presion de trabajo de 13 bar como minimo.', false, 'Intolerable', 1, 110, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Valvula corte rapido en buen estado, salida del acumulador.', false, 'Alto', 1, 120, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Manguera de alta presion operativa, sin desgaste o rotura', false, 'Intolerable', 1, 130, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Valvula de retencion operativa y en buen estado', false, 'Alto', 1, 140, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Valvula de despiche acumulador operativo sin filtracion', false, 'Alto', 1, 150, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Manometro operativo (Numeros legibles, Buen estado esfera de vidrio, Aguja funciona)', false, 'Alto', 1, 160, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Niples y conectores de compresor general sin corrosion y en buen estado', false, 'Alto', 1, 170, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Banco auxiliar (botellas cargadas a alta presion) volumen minimo de 48 lt. y 204 bar. (sin corrosion ni filtracion)', false, 'Intolerable', 1, 180, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Panel de control de gases de superficie (consola) en buen estado sin corrosion ni filtracion', false, 'Alto', 1, 190, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Indicadores panel control de gases (manometros) Numeros legibles, Buen estado esfera de vidrio, Aguja funciona.', false, 'Alto', 1, 200, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Sistema de comunicaciones operativa, en buen estado y bateria cargada.', false, 'Intolerable', 1, 210, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Conectores bananas y hi-use 4 pin, en buen estado y operativos.', false, 'Alto', 1, 220, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Mascara facial con comunicaciones en buen estado, sin filtracion, purga operativa y con membrana, broches sin desgaste ni trizados.', false, 'Intolerable', 1, 230, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Umbilical en buen estado', false, 'Intolerable', 1, 240, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Latiguillo compresor 5M en buen estado niples sin corrosion ni filtracion', false, 'Alto', 1, 250, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Manifold Block Kirby Morgan en buen estado, sin corrosion, valvula de retencion operativa y sin filtracion', false, 'Alto', 1, 260, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Botellas de emergencia de 5ltrs con manometro y regulador 1 y 2 estado, operativos sin filtracion y cargadas.', false, 'Intolerable', 1, 270, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Arnes de buceo antienredo con hebilla de escape rapido en buen estado', false, 'Intolerable', 1, 280, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Mosqueton de acero inoxidable', false, 'Medio', 1, 290, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Manillas adecuadas para transporte', false, 'Medio', 1, 300, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Ruedas en buen estado', false, 'Medio', 1, 310, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Bandera alfa', false, 'Intolerable', 1, 320, true),
  ('BUCEO_SAM_36M', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Otros', false, 'Bajo', 1, 330, true),
  ('BUCEO_SAM_36M', 'Manguera de buceo', 'Buen estado visual', false, 'Intolerable', 1, 400, true),
  ('BUCEO_SAM_36M', 'Manguera de buceo', 'Cumple con las marcas reglamentarias cada 10 m.', false, 'Intolerable', 1, 410, true),
  ('BUCEO_SAM_36M', 'Manguera de buceo', 'Cumple con no tener roturas y/o rayas en sus tramos', false, 'Intolerable', 1, 420, true),
  ('BUCEO_SAM_36M', 'Manguera de buceo', 'Valvula de retencion en buen estado', false, 'Alto', 1, 430, true),
  ('BUCEO_SAM_36M', 'Manguera de buceo', 'Apta para continuar su uso en faena', false, 'Intolerable', 1, 440, true),
  ('BUCEO_SAM_36M', 'Union compresora / manguera de buceo', 'Buen estado Niple de union', false, 'Alto', 1, 500, true),
  ('BUCEO_SAM_36M', 'Emergencia', 'Botiquin de primeros auxilios basico', false, 'Intolerable', 1, 600, true),
  ('BUCEO_SAM_36M', 'Emergencia', 'Procedimiento o Manual de 1 Auxilios (plastificado)', false, 'Intolerable', 1, 610, true),
  ('BUCEO_SAM_36M', 'Emergencia', 'Unidad de O2 medicinal para emergencia', false, 'Intolerable', 1, 620, true),
  ('BUCEO_SAM_36M', 'Emergencia', 'Tablas de Descompresion Plastificadas (I a V)', false, 'Intolerable', 1, 630, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Permiso de buceo autorizado por la AAMM', false, 'Intolerable', 1, 700, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Matriculas del personal de buzos vigentes', false, 'Intolerable', 1, 710, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Matricula del compresor vigente', false, 'Intolerable', 1, 720, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Plan de contingencia en caso de accidentes de buceo', false, 'Intolerable', 1, 730, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Resolucion de autorizacion del plan de contingencia o carta de entrega', false, 'Intolerable', 1, 740, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Bitacora de buceo y lista de chequeo diaria de faena', false, 'Alto', 1, 750, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Bitacora de mantencion del compresor u otro respaldo de trazabilidad', false, 'Alto', 1, 760, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Examenes pre/ocupacionales por buzo aptos', false, 'Intolerable', 1, 770, true),
  ('BUCEO_SAM_36M', 'Documentos', 'Registro de entrega de EPP para buceo y trabajo en superficie', false, 'Alto', 1, 780, true)
),
personal_expandido AS (
  SELECT
    'BUCEO_SAL_20M'::TEXT AS lista_codigo,
    'Personal por buzo'::TEXT AS categoria,
    format('%s (BUZO %s)', p.pregunta_base, b.buzo_idx)::TEXT AS pregunta,
    true AS aplica_por_buzo,
    'Moderado'::TEXT AS criticidad,
    1::INTEGER AS peso,
    (600 + (p.orden_base * 10) + b.buzo_idx)::INTEGER AS orden,
    true AS activo
  FROM personal_items p
  CROSS JOIN (SELECT generate_series(1, 4) AS buzo_idx) b
),
all_items AS (
  SELECT * FROM base_items
  UNION ALL
  SELECT * FROM personal_expandido
  UNION ALL
  SELECT * FROM sam_items
)
INSERT INTO public.buceo_equipamiento_items (
  lista_codigo,
  categoria,
  pregunta,
  aplica_por_buzo,
  criticidad,
  peso,
  orden,
  activo
)
SELECT
  lista_codigo,
  categoria,
  pregunta,
  aplica_por_buzo,
  criticidad,
  peso,
  orden,
  activo
FROM all_items
ON CONFLICT (lista_codigo, pregunta)
DO UPDATE SET
  categoria = EXCLUDED.categoria,
  aplica_por_buzo = EXCLUDED.aplica_por_buzo,
  criticidad = EXCLUDED.criticidad,
  peso = EXCLUDED.peso,
  orden = EXCLUDED.orden,
  activo = EXCLUDED.activo,
  updated_at = now();

-- Espejo opcional en formulario_items (compatibilidad):
-- Permite reutilizar este checklist en flujos que aún lean formulario_items.
DELETE FROM public.formulario_items
WHERE tipo_actividad IN ('BUCEO_SAL_20M', 'BUCEO_SAM_36M');

INSERT INTO public.formulario_items
  (id, tipo_actividad, categoria, pregunta, criticidad, orden, activo, peso)
SELECT
  gen_random_uuid(),
  i.lista_codigo,
  i.categoria,
  i.pregunta,
  CASE
    WHEN i.criticidad IN ('Bajo', 'Baja') THEN 'Bajo'::nivel_criticidad
    WHEN i.criticidad IN ('Medio', 'Media', 'Moderado') THEN 'Medio'::nivel_criticidad
    WHEN i.criticidad IN ('Alto', 'Alta') THEN 'Alto'::nivel_criticidad
    WHEN i.criticidad = 'Intolerable' THEN 'Intolerable'::nivel_criticidad
    ELSE 'Medio'::nivel_criticidad
  END,
  i.orden,
  i.activo,
  (i.peso::numeric)
FROM public.buceo_equipamiento_items i
WHERE i.lista_codigo IN ('BUCEO_SAL_20M', 'BUCEO_SAM_36M');

-- -----------------------------------------------------------------------------
-- D) HABILITAR MODULO PARA TODAS LAS EMPRESAS
-- -----------------------------------------------------------------------------

INSERT INTO public.empresa_modulos (
  id,
  empresa_id,
  modulo_key,
  habilitado,
  orden
)
SELECT
  gen_random_uuid(),
  e.id,
  'BUCEO_EQUIPAMIENTO',
  true,
  70
FROM public.empresas e
ON CONFLICT (empresa_id, modulo_key)
DO UPDATE SET
  habilitado = true,
  orden = EXCLUDED.orden;

-- -----------------------------------------------------------------------------
-- D.2) RLS — catálogo legible por autenticados; inspecciones/respuestas
--      restringidas al usuario dueño (mismo patrón que Hidroser).
-- -----------------------------------------------------------------------------
ALTER TABLE public.buceo_equipamiento_listas        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.buceo_equipamiento_items         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.buceo_equipamiento_inspecciones  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.buceo_equipamiento_respuestas    ENABLE ROW LEVEL SECURITY;

-- Lectura de catálogo: todos los autenticados.
DROP POLICY IF EXISTS buceo_eq_listas_select_all ON public.buceo_equipamiento_listas;
CREATE POLICY buceo_eq_listas_select_all
  ON public.buceo_equipamiento_listas FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS buceo_eq_items_select_all ON public.buceo_equipamiento_items;
CREATE POLICY buceo_eq_items_select_all
  ON public.buceo_equipamiento_items FOR SELECT
  TO authenticated
  USING (true);

-- Inspecciones: el dueño ve / inserta / actualiza las suyas.
DROP POLICY IF EXISTS buceo_eq_insp_owner_all ON public.buceo_equipamiento_inspecciones;
CREATE POLICY buceo_eq_insp_owner_all
  ON public.buceo_equipamiento_inspecciones FOR ALL
  TO authenticated
  USING      (usuario_id = auth.uid())
  WITH CHECK (usuario_id = auth.uid());

-- Respuestas: el dueño de la inspección.
DROP POLICY IF EXISTS buceo_eq_resp_owner_all ON public.buceo_equipamiento_respuestas;
CREATE POLICY buceo_eq_resp_owner_all
  ON public.buceo_equipamiento_respuestas FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.buceo_equipamiento_inspecciones i
             WHERE i.id = inspeccion_id AND i.usuario_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.buceo_equipamiento_inspecciones i
             WHERE i.id = inspeccion_id AND i.usuario_id = auth.uid())
  );

-- -----------------------------------------------------------------------------
-- E) HISTORIAL UNIFICADO
--    Recrea la vista agregando la rama del módulo Equipamiento de Buceo
--    (tablas propias) y excluyendo los códigos de buceo de la rama Hidroser
--    para evitar duplicados de registros heredados.
--    Se conservan TODAS las ramas existentes (Inspección, Visitas, Hidroser, AST).
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS public.historial_unificado;

CREATE VIEW public.historial_unificado AS

-- INSPECCIONES (actividades)
SELECT
  a.id::text                                  AS id,
  'Inspección'::text                          AS modulo,
  a.tipo_actividad::text                      AS tipo_registro,
  a.estado_final::text                        AS estado,
  COALESCE(c.nombre, 'Sin ubicación')         AS ubicacion,
  a.fecha_realizacion::timestamptz            AS fecha_realizacion,
  a.numero_informe::text                      AS numero_reporte,
  a.pdf_url                                   AS pdf_url,
  NULL::text                                  AS pdf_certificado_url,
  u.nombre_completo                           AS inspector_nombre,
  COALESCE(a.numero_seguimiento, 0)::integer  AS numero_seguimiento,
  a.usuario_id                                AS usuario_id,
  a.centro_id                                 AS centro_id,
  a.embarcacion_id                            AS embarcacion_id
FROM actividades a
LEFT JOIN centros  c ON c.id = a.centro_id
LEFT JOIN usuarios u ON u.id = a.usuario_id
WHERE a.estado_final NOT IN ('Eliminada', 'En Progreso')

UNION ALL

-- VISITAS TÉCNICAS (R003, R004, MANTENCION_PROSESSO, etc.)
SELECT
  v.id::text                                  AS id,
  CASE
    WHEN v.tipo_actividad = 'VISITA_R004'         THEN 'Inspección Extintores'
    WHEN v.tipo_actividad = 'MANTENCION_PROSESSO' THEN 'Mantención de Extintores'
    ELSE 'Visita Técnica'
  END::text                                   AS modulo,
  v.tipo_actividad::text                      AS tipo_registro,
  v.estado_final::text                        AS estado,
  COALESCE(NULLIF(v.cliente_nombre, ''),
           NULLIF(v.lugar_visita,   ''),
           'Sin ubicación')                   AS ubicacion,
  v.fecha_realizacion::timestamptz            AS fecha_realizacion,
  v.cert_numero::text                         AS numero_reporte,
  v.pdf_url                                   AS pdf_url,
  v.pdf_certificado_url                       AS pdf_certificado_url,
  u.nombre_completo                           AS inspector_nombre,
  0::integer                                  AS numero_seguimiento,
  v.usuario_id                                AS usuario_id,
  NULL::uuid                                  AS centro_id,
  NULL::uuid                                  AS embarcacion_id
FROM visitas_tecnicas v
LEFT JOIN usuarios u ON u.id = v.usuario_id
WHERE v.estado_final NOT IN ('Eliminada', 'En Progreso')

UNION ALL

-- HIDROSER (módulo independiente; excluye códigos de buceo)
SELECT
  h.id::text                                                   AS id,
  'Hidroser'::text                                             AS modulo,
  h.lista_codigo::text                                         AS tipo_registro,
  h.estado_final::text                                         AS estado,
  COALESCE(NULLIF(hl.nombre, ''), 'Sin ubicación')             AS ubicacion,
  h.fecha_realizacion::timestamptz                             AS fecha_realizacion,
  h.correlativo::text                                          AS numero_reporte,
  h.pdf_url                                                    AS pdf_url,
  NULL::text                                                   AS pdf_certificado_url,
  COALESCE(NULLIF(h.quien_inspecciona, ''), u.nombre_completo) AS inspector_nombre,
  0::integer                                                   AS numero_seguimiento,
  h.usuario_id                                                 AS usuario_id,
  NULL::uuid                                                   AS centro_id,
  NULL::uuid                                                   AS embarcacion_id
FROM hidroser_inspecciones h
LEFT JOIN hidroser_listas hl ON hl.codigo = h.lista_codigo
LEFT JOIN usuarios        u  ON u.id      = h.usuario_id
WHERE h.estado_final NOT IN ('Eliminada', 'En Progreso')
  AND h.lista_codigo NOT IN ('BUCEO_SAL_20M', 'BUCEO_SAM_36M')

UNION ALL

-- AST (Análisis Seguro de Trabajo)
SELECT
  a.id::text                                                   AS id,
  'AST'::text                                                  AS modulo,
  'AST'::text                                                  AS tipo_registro,
  a.estado_final::text                                         AS estado,
  COALESCE(NULLIF(a.centro_nombre, ''),
           NULLIF(a.contratista_nombre, ''),
           'Sin ubicación')                                    AS ubicacion,
  a.fecha_realizacion::timestamptz                             AS fecha_realizacion,
  a.correlativo::text                                          AS numero_reporte,
  a.pdf_url                                                    AS pdf_url,
  NULL::text                                                   AS pdf_certificado_url,
  COALESCE(NULLIF(a.profesional, ''), u.nombre_completo)       AS inspector_nombre,
  0::integer                                                   AS numero_seguimiento,
  a.usuario_id                                                 AS usuario_id,
  a.centro_id                                                  AS centro_id,
  a.embarcacion_id                                             AS embarcacion_id
FROM ast_informes a
LEFT JOIN usuarios u ON u.id = a.usuario_id
WHERE a.estado_final NOT IN ('Eliminada', 'En Progreso')

UNION ALL

-- EQUIPAMIENTO DE BUCEO (módulo independiente, tablas propias)
SELECT
  b.id::text                                                   AS id,
  'Equipamiento de Buceo'::text                                AS modulo,
  b.lista_codigo::text                                         AS tipo_registro,
  b.estado_final::text                                         AS estado,
  COALESCE(NULLIF(bl.nombre, ''), 'Sin ubicación')             AS ubicacion,
  b.fecha_realizacion::timestamptz                             AS fecha_realizacion,
  b.correlativo::text                                          AS numero_reporte,
  b.pdf_url                                                    AS pdf_url,
  NULL::text                                                   AS pdf_certificado_url,
  COALESCE(NULLIF(b.quien_inspecciona, ''), u.nombre_completo) AS inspector_nombre,
  0::integer                                                   AS numero_seguimiento,
  b.usuario_id                                                 AS usuario_id,
  NULL::uuid                                                   AS centro_id,
  NULL::uuid                                                   AS embarcacion_id
FROM buceo_equipamiento_inspecciones b
LEFT JOIN buceo_equipamiento_listas bl ON bl.codigo = b.lista_codigo
LEFT JOIN usuarios                  u  ON u.id       = b.usuario_id
WHERE b.estado_final NOT IN ('Eliminada', 'En Progreso');

GRANT SELECT ON public.historial_unificado TO anon, authenticated;

COMMIT;

-- -----------------------------------------------------------------------------
-- VERIFICACIONES SUGERIDAS
-- -----------------------------------------------------------------------------
-- 1) Tablas nuevas:
-- SELECT table_name
-- FROM information_schema.tables
-- WHERE table_schema = 'public'
--   AND table_name LIKE 'buceo_equipamiento_%'
-- ORDER BY table_name;
--
-- 2) Listas e items:
-- SELECT codigo, nombre, orden, activo
-- FROM public.buceo_equipamiento_listas
-- ORDER BY orden;
--
-- SELECT lista_codigo, categoria, orden, pregunta
-- FROM public.buceo_equipamiento_items
-- ORDER BY lista_codigo, orden;
--
-- 2.1) Número de informe por lista:
-- SELECT lista_codigo, numero_informe, correlativo, estado_final
-- FROM public.buceo_equipamiento_inspecciones
-- ORDER BY lista_codigo, numero_informe;
--
-- 3) Modulo habilitado por empresa:
-- SELECT e.nombre, em.habilitado, em.orden
-- FROM public.empresa_modulos em
-- JOIN public.empresas e ON e.id = em.empresa_id
-- WHERE em.modulo_key = 'BUCEO_EQUIPAMIENTO'
-- ORDER BY e.nombre;
