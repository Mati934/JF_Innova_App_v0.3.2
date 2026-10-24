BEGIN;

-- =============================================================================
-- MIGRACION: correlativo AST sin huecos por rollback/reintentos
--
-- Problema:
-- - Las secuencias (nextval) no son transaccionales: si una transaccion falla,
--   el numero ya se consumio y queda hueco.
--
-- Solucion:
-- - Reemplazar el generador por un contador transaccional por anio.
-- - El contador vive en tabla y se incrementa con UPDATE dentro de la misma
--   transaccion; si falla, se revierte.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.ast_correlativo_counters (
  anio INTEGER PRIMARY KEY,
  ultimo_numero BIGINT NOT NULL CHECK (ultimo_numero >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Backfill inicial desde correlativos existentes para no retroceder numeracion.
WITH parsed AS (
  SELECT
    ((regexp_match(correlativo, '^AST-([0-9]{4})-([0-9]+)$'))[1])::int AS anio,
    ((regexp_match(correlativo, '^AST-([0-9]{4})-([0-9]+)$'))[2])::bigint AS numero
  FROM public.ast_informes
  WHERE correlativo ~ '^AST-[0-9]{4}-[0-9]+$'
),
maximos AS (
  SELECT anio, MAX(numero) AS max_numero
  FROM parsed
  GROUP BY anio
)
INSERT INTO public.ast_correlativo_counters (anio, ultimo_numero)
SELECT anio, max_numero
FROM maximos
ON CONFLICT (anio)
DO UPDATE SET ultimo_numero = GREATEST(public.ast_correlativo_counters.ultimo_numero, EXCLUDED.ultimo_numero),
              updated_at = now();

CREATE OR REPLACE FUNCTION public.next_ast_correlativo_gapless(p_fecha TIMESTAMPTZ DEFAULT now())
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_anio INT := EXTRACT(YEAR FROM p_fecha)::int;
  v_num BIGINT;
BEGIN
  INSERT INTO public.ast_correlativo_counters (anio, ultimo_numero)
  VALUES (v_anio, 0)
  ON CONFLICT (anio) DO NOTHING;

  UPDATE public.ast_correlativo_counters
  SET ultimo_numero = ultimo_numero + 1,
      updated_at = now()
  WHERE anio = v_anio
  RETURNING ultimo_numero INTO v_num;

  RETURN format('AST-%s-%s', v_anio, LPAD(v_num::text, 4, '0'));
END;
$$;

-- Compatibilidad: mantenemos el nombre historico apuntando al nuevo generador.
CREATE OR REPLACE FUNCTION public.next_ast_correlativo()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN public.next_ast_correlativo_gapless(now());
END;
$$;

CREATE OR REPLACE FUNCTION public.assign_ast_correlativo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.estado_final = 'En Seguimiento'
     AND COALESCE(NEW.correlativo, '') = ''
     AND (
       TG_OP = 'INSERT'
       OR COALESCE(OLD.estado_final, '') IS DISTINCT FROM 'En Seguimiento'
     ) THEN
    NEW.correlativo := public.next_ast_correlativo_gapless(
      COALESCE(NEW.fecha_realizacion, now())
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ast_correlativo ON public.ast_informes;
CREATE TRIGGER trg_ast_correlativo
  BEFORE INSERT OR UPDATE ON public.ast_informes
  FOR EACH ROW EXECUTE FUNCTION public.assign_ast_correlativo();

COMMIT;
