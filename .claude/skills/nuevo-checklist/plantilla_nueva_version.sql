-- =============================================================================
-- NUEVA VERSION DEL CHECKLIST: <<chq_clave>>  (version <<N>>)
-- Generado con la skill nuevo-checklist (plantilla v1).
--
-- Publica una version nueva con las preguntas completas (no un diff). Las
-- inspecciones ya hechas conservan su version; las nuevas usan esta.
-- Los IDs de pregunta deben MANTENERSE para preguntas que no cambian de
-- sentido (asi las metricas comparan entre versiones). Pregunta nueva = id nuevo.
--
-- Pasos: 0 (solo lectura) -> 1 (BEGIN..COMMIT) -> 2 (verificar).
-- =============================================================================

-- 0. SOLO LECTURA: version actual y sus preguntas
SELECT c.checklist_key, c.published_version, v.estado,
       jsonb_array_length(v.snapshot_preguntas) AS preguntas,
       (SELECT max(version) FROM public.checklist_versions x
        WHERE x.checklist_key = c.checklist_key) AS ultima_version
FROM public.checklists c
JOIN public.checklist_versions v
  ON v.checklist_key = c.checklist_key AND v.version = c.published_version
WHERE c.checklist_key = '<<chq_clave>>';
-- Esperado: ultima_version = published_version = <<N>> - 1.

SELECT p->>'id' AS id, p->>'orden' AS orden, p->>'categoria' AS categoria, p->>'pregunta' AS pregunta
FROM public.checklists c
JOIN public.checklist_versions v
  ON v.checklist_key = c.checklist_key AND v.version = c.published_version
CROSS JOIN LATERAL jsonb_array_elements(v.snapshot_preguntas) p
WHERE c.checklist_key = '<<chq_clave>>'
ORDER BY (p->>'orden')::int;


-- 1. PUBLICAR
BEGIN;

CREATE TEMP TABLE cfg_preguntas ON COMMIT DROP AS
SELECT * FROM (VALUES
  -- id (conservar el anterior si la pregunta sigue igual), orden, categoria, pregunta, criticidad
  ('<<chq_clave>>_q1', 1, '<<Categoria>>', '<<¿Pregunta?>>', 'Tolerable')
) AS t(id, orden, categoria, pregunta, criticidad);

DO $$
BEGIN
  IF (SELECT published_version FROM public.checklists
      WHERE checklist_key = '<<chq_clave>>') <> <<N>> - 1 THEN
    RAISE EXCEPTION 'CFG_VERSION: la version publicada no es la esperada (<<N>> - 1).';
  END IF;
  IF EXISTS (SELECT 1 FROM cfg_preguntas GROUP BY id HAVING count(*) > 1) THEN
    RAISE EXCEPTION 'CFG_ID_DUPLICADO: hay ids de pregunta repetidos.';
  END IF;
  IF EXISTS (SELECT 1 FROM cfg_preguntas
             WHERE criticidad NOT IN ('Tolerable', 'Moderado', 'Intolerable')) THEN
    RAISE EXCEPTION 'CFG_CRITICIDAD: usar Tolerable, Moderado o Intolerable.';
  END IF;
END $$;

-- Si cambian campos del encabezado, ajustar checklist_campo_asignaciones AQUI,
-- antes de congelar el snapshot.

INSERT INTO public.checklist_versions (
  checklist_key, version, estado, snapshot_preguntas,
  snapshot_campos_extra, snapshot_reglas, published_at
)
SELECT '<<chq_clave>>', <<N>>, 'PUBLICADA',
  (SELECT jsonb_agg(jsonb_build_object(
     'id', p.id, 'pregunta', p.pregunta, 'categoria', p.categoria,
     'orden', p.orden, 'peso', 1.0, 'criticidad', p.criticidad
   ) ORDER BY p.orden) FROM cfg_preguntas p),
  COALESCE((SELECT jsonb_agg(jsonb_build_object(
     'id', d.id::text, 'clave', d.clave, 'etiqueta', d.etiqueta,
     'tipo', d.tipo, 'opciones', d.opciones, 'unidad', d.unidad,
     'seccion', a.seccion, 'orden', a.orden, 'requerido', a.requerido
   ) ORDER BY a.orden)
   FROM public.checklist_campo_asignaciones a
   JOIN public.checklist_campo_definiciones d ON d.id = a.campo_id
   WHERE a.checklist_key = '<<chq_clave>>' AND a.activo AND d.activo), '[]'::jsonb),
  '{}'::jsonb, now()
ON CONFLICT (checklist_key, version) DO NOTHING;

UPDATE public.checklist_versions
SET estado = 'RETIRADA'
WHERE checklist_key = '<<chq_clave>>' AND version = <<N>> - 1 AND estado = 'PUBLICADA';

UPDATE public.checklists
SET published_version = <<N>>, updated_at = now()
WHERE checklist_key = '<<chq_clave>>' AND published_version = <<N>> - 1;

COMMIT;


-- 2. VERIFICAR
SELECT v.version, v.estado, jsonb_array_length(v.snapshot_preguntas) AS preguntas,
       c.published_version
FROM public.checklist_versions v
JOIN public.checklists c USING (checklist_key)
WHERE v.checklist_key = '<<chq_clave>>'
ORDER BY v.version;
-- Esperado: version <<N>> PUBLICADA y published_version = <<N>>; la anterior RETIRADA.
