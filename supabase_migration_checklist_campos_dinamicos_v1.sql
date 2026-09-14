-- =============================================================================
-- MOTOR DE CHECKLISTS CONFIGURABLES — CAMPOS DINÁMICOS (v1)
-- =============================================================================
-- Objetivo: reemplazar los "campos extra" hardcodeados en la app (Supervisor,
-- Obra o faena, Región, etc.) por un catálogo de campos reutilizable entre
-- checklists, tipado (para poder graficarlo en un dashboard sin adivinar si
-- es texto o número) y asignable por checklist sin tocar código ni esquema.
--
-- Diseño (3 tablas nuevas):
--   1) checklist_campo_definiciones  -> catálogo global de campos (reutilizable).
--   2) checklist_campo_asignaciones  -> qué checklist usa qué campo, en qué
--      sección/orden, y si es obligatorio en ESE checklist en particular.
--   3) checklist_campo_valores       -> el valor real capturado por inspección,
--      guardado en la columna tipada que corresponde (texto/número/fecha/
--      booleano), listo para agregarse en un dashboard (AVG, SUM, etc.) sin
--      parsear JSON.
--
-- El "contrato" de campos de una versión publicada (snapshot_campos_extra)
-- se sigue usando igual que hoy: al publicar, se congela un snapshot de las
-- asignaciones+definiciones vigentes (mismo patrón que snapshot_preguntas
-- desde formulario_items), así la app offline no depende de estas 3 tablas
-- nuevas para RENDERIZAR el formulario, solo para ADMINISTRAR el catálogo.
--
-- No hay nada en producción todavía: este script reemplaza por completo el
-- uso de `checklist_inspecciones.campos_extra` (columna JSONB libre) para los
-- 8 campos que se habían agregado como fijos en el formulario (Obra o faena,
-- Región, Área específica, Jefatura a cargo, Hora inicio/término, Correo
-- empresa 1/2). La columna `campos_extra` queda en la tabla por compatibilidad
-- pero DEJA de ser la fuente de verdad para estos datos.
--
-- EJECUCIÓN MANUAL OBLIGATORIA en el SQL Editor de Supabase.
-- 1) Corre la SECCIÓN 0 (solo lectura) y confirma:
--    * Las 3 tablas nuevas NO existen todavía (0 filas / to_regclass NULL).
--    * Los 5 checklist_key de Herramientas y Equipos existen y tienen versión
--      PUBLICADA (para poder actualizarles el snapshot al final).
-- 2) Corre todo el bloque BEGIN...COMMIT (crea tablas + RLS + siembra catálogo
--    + asigna los 8 campos a los 5 checklists + recongela el snapshot).
-- 3) Corre la SECCIÓN FINAL y confirma que los 5 checklists quedaron con 8
--    campos en su snapshot_campos_extra.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0) CHECK PREVIO DE SOLO LECTURA
-- -----------------------------------------------------------------------------
SELECT
  to_regclass('public.checklist_campo_definiciones') AS tabla_definiciones,
  to_regclass('public.checklist_campo_asignaciones') AS tabla_asignaciones,
  to_regclass('public.checklist_campo_valores') AS tabla_valores;
-- Esperado: las 3 columnas en NULL (tablas todavía no existen).

SELECT checklist_key, nombre, published_version
FROM public.checklists
WHERE checklist_key IN (
  'chq_herramientas_manuales', 'chq_soldadora_arco',
  'chq_taladro_destornillador', 'chq_esmeril_angular',
  'chq_extension_electrica'
)
ORDER BY checklist_key;
-- Esperado: 5 filas, todas con published_version = 1.

BEGIN;

-- -----------------------------------------------------------------------------
-- 1) CATÁLOGO DE CAMPOS (reutilizable entre checklists)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.checklist_campo_definiciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clave TEXT UNIQUE NOT NULL CHECK (clave ~ '^[a-z][a-z0-9_]*$'),
  etiqueta TEXT NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN (
    'texto', 'texto_largo', 'numero', 'fecha', 'hora',
    'email', 'telefono', 'booleano', 'seleccion_unica', 'seleccion_multiple'
  )),
  opciones JSONB NOT NULL DEFAULT '[]'::jsonb, -- solo para seleccion_*
  unidad TEXT,                                  -- 'kg', 'hrs', '%', '$'...
  es_metrica BOOLEAN NOT NULL DEFAULT FALSE,     -- ¿debe salir en dashboards?
  agregacion_dashboard TEXT CHECK (agregacion_dashboard IN (
    'suma', 'promedio', 'conteo', 'ultimo_valor', 'minimo', 'maximo'
  )),
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (agregacion_dashboard IS NULL OR es_metrica),
  CHECK (tipo <> 'seleccion_unica' AND tipo <> 'seleccion_multiple'
         OR jsonb_typeof(opciones) = 'array')
);

-- -----------------------------------------------------------------------------
-- 2) ASIGNACIÓN DE CAMPOS A CHECKLISTS (N:N — un campo puede repetirse en
--    varios checklists sin duplicar su definición)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.checklist_campo_asignaciones (
  checklist_key TEXT NOT NULL REFERENCES public.checklists(checklist_key) ON DELETE CASCADE,
  campo_id UUID NOT NULL REFERENCES public.checklist_campo_definiciones(id) ON DELETE CASCADE,
  seccion TEXT NOT NULL DEFAULT 'Datos generales',
  orden INTEGER NOT NULL DEFAULT 0,
  requerido BOOLEAN NOT NULL DEFAULT FALSE,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (checklist_key, campo_id)
);
CREATE INDEX IF NOT EXISTS idx_checklist_campo_asig_checklist
  ON public.checklist_campo_asignaciones(checklist_key, orden);

-- -----------------------------------------------------------------------------
-- 3) VALORES CAPTURADOS POR INSPECCIÓN (EAV tipado — listo para dashboard)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.checklist_campo_valores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inspeccion_id UUID NOT NULL REFERENCES public.checklist_inspecciones(id) ON DELETE CASCADE,
  campo_id UUID NOT NULL REFERENCES public.checklist_campo_definiciones(id),
  valor_texto TEXT,
  valor_numero NUMERIC,
  valor_fecha DATE,
  valor_booleano BOOLEAN,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (inspeccion_id, campo_id)
);
CREATE INDEX IF NOT EXISTS idx_checklist_campo_valores_insp
  ON public.checklist_campo_valores(inspeccion_id);
-- Índice pensado para el dashboard: "dame todos los valores de este campo,
-- para esta empresa, en este rango de fechas" sin tener que abrir JSON.
CREATE INDEX IF NOT EXISTS idx_checklist_campo_valores_campo
  ON public.checklist_campo_valores(campo_id);

-- -----------------------------------------------------------------------------
-- 4) RLS (mismo patrón que checklist_evidencias / checklist_respuestas)
-- -----------------------------------------------------------------------------
ALTER TABLE public.checklist_campo_definiciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_campo_asignaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_campo_valores ENABLE ROW LEVEL SECURITY;

-- El catálogo y las asignaciones son de LECTURA para cualquier usuario
-- autenticado (son metadatos de formulario, no datos sensibles) y de
-- ESCRITURA solo para superadmin (se administran centralizadamente, igual
-- que checklist_form_types).
DROP POLICY IF EXISTS checklist_campo_def_read ON public.checklist_campo_definiciones;
CREATE POLICY checklist_campo_def_read ON public.checklist_campo_definiciones
  FOR SELECT TO authenticated USING (TRUE);
DROP POLICY IF EXISTS checklist_campo_def_admin ON public.checklist_campo_definiciones;
CREATE POLICY checklist_campo_def_admin ON public.checklist_campo_definiciones
  FOR ALL TO authenticated
  USING (public.is_superadmin_user())
  WITH CHECK (public.is_superadmin_user());

DROP POLICY IF EXISTS checklist_campo_asig_read ON public.checklist_campo_asignaciones;
CREATE POLICY checklist_campo_asig_read ON public.checklist_campo_asignaciones
  FOR SELECT TO authenticated USING (TRUE);
DROP POLICY IF EXISTS checklist_campo_asig_admin ON public.checklist_campo_asignaciones;
CREATE POLICY checklist_campo_asig_admin ON public.checklist_campo_asignaciones
  FOR ALL TO authenticated
  USING (public.is_superadmin_user())
  WITH CHECK (public.is_superadmin_user());

-- Los valores siguen la misma regla de dueño que checklist_respuestas /
-- checklist_evidencias: dueño de la inspección o admin.
DROP POLICY IF EXISTS checklist_campo_valores_owner ON public.checklist_campo_valores;
CREATE POLICY checklist_campo_valores_owner ON public.checklist_campo_valores
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.checklist_inspecciones i
                 WHERE i.id = inspeccion_id AND (i.usuario_id = auth.uid() OR public.is_admin_user())))
  WITH CHECK (EXISTS (SELECT 1 FROM public.checklist_inspecciones i
                      WHERE i.id = inspeccion_id AND (i.usuario_id = auth.uid() OR public.is_admin_user())));

-- -----------------------------------------------------------------------------
-- 5) SIEMBRA: catálogo de los 8 campos que hoy están fijos en la app, y
--    asignación a los 5 checklists de Herramientas y Equipos.
-- -----------------------------------------------------------------------------
INSERT INTO public.checklist_campo_definiciones
  (clave, etiqueta, tipo, es_metrica, agregacion_dashboard)
VALUES
  ('obra_faena', 'Obra o faena', 'texto', FALSE, NULL),
  ('region', 'Región', 'texto', FALSE, NULL),
  ('area_especifica', 'Área específica', 'texto', FALSE, NULL),
  ('jefatura_a_cargo', 'Jefatura a cargo', 'texto', FALSE, NULL),
  ('hora_inicio', 'Hora inicio', 'hora', FALSE, NULL),
  ('hora_termino', 'Hora término', 'hora', FALSE, NULL),
  ('correo_empresa_1', 'Correo empresa 1 (donde enviar informe)', 'email', FALSE, NULL),
  ('correo_empresa_2', 'Correo empresa 2 (donde enviar informe)', 'email', FALSE, NULL)
ON CONFLICT (clave) DO NOTHING;

INSERT INTO public.checklist_campo_asignaciones
  (checklist_key, campo_id, seccion, orden, requerido)
SELECT c.checklist_key, d.id, 'Datos generales', o.orden, FALSE
FROM public.checklists c
CROSS JOIN LATERAL (VALUES
  ('obra_faena', 1), ('region', 2), ('area_especifica', 3),
  ('jefatura_a_cargo', 4), ('hora_inicio', 5), ('hora_termino', 6),
  ('correo_empresa_1', 7), ('correo_empresa_2', 8)
) AS o(clave, orden)
JOIN public.checklist_campo_definiciones d ON d.clave = o.clave
WHERE c.checklist_key IN (
  'chq_herramientas_manuales', 'chq_soldadora_arco',
  'chq_taladro_destornillador', 'chq_esmeril_angular',
  'chq_extension_electrica'
)
ON CONFLICT (checklist_key, campo_id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 6) RECONGELAR snapshot_campos_extra de la versión PUBLICADA de cada uno de
--    los 5 checklists, a partir del catálogo+asignaciones recién creados.
--    Mismo patrón que snapshot_preguntas: la versión queda inmutable para la
--    app offline, el catálogo queda como fuente editable para el futuro.
-- -----------------------------------------------------------------------------
UPDATE public.checklist_versions cv
SET snapshot_campos_extra = campos.snapshot
FROM (
  SELECT
    a.checklist_key,
    jsonb_agg(
      jsonb_build_object(
        'id', d.id::text,
        'clave', d.clave,
        'etiqueta', d.etiqueta,
        'tipo', d.tipo,
        'opciones', d.opciones,
        'unidad', d.unidad,
        'seccion', a.seccion,
        'orden', a.orden,
        'requerido', a.requerido
      ) ORDER BY a.orden
    ) AS snapshot
  FROM public.checklist_campo_asignaciones a
  JOIN public.checklist_campo_definiciones d ON d.id = a.campo_id
  WHERE a.checklist_key IN (
    'chq_herramientas_manuales', 'chq_soldadora_arco',
    'chq_taladro_destornillador', 'chq_esmeril_angular',
    'chq_extension_electrica'
  ) AND a.activo
  GROUP BY a.checklist_key
) campos
WHERE cv.checklist_key = campos.checklist_key
  AND cv.estado = 'PUBLICADA';

REVOKE ALL ON public.checklist_campo_definiciones FROM anon;
REVOKE ALL ON public.checklist_campo_asignaciones FROM anon;
REVOKE ALL ON public.checklist_campo_valores FROM anon;

COMMIT;

-- -----------------------------------------------------------------------------
-- SECCIÓN FINAL: VERIFICACIÓN
-- -----------------------------------------------------------------------------
SELECT checklist_key, jsonb_array_length(snapshot_campos_extra) AS n_campos
FROM public.checklist_versions
WHERE checklist_key IN (
  'chq_herramientas_manuales', 'chq_soldadora_arco',
  'chq_taladro_destornillador', 'chq_esmeril_angular',
  'chq_extension_electrica'
) AND estado = 'PUBLICADA'
ORDER BY checklist_key;
-- Esperado: n_campos = 8 en las 5 filas.

SELECT clave, etiqueta, tipo, es_metrica
FROM public.checklist_campo_definiciones
ORDER BY clave;
-- Esperado: 8 filas (las listadas en la sección 5).
