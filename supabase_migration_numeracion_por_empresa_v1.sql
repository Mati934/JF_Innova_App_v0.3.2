-- =============================================================================
-- NUMERACION DE INFORMES POR EMPRESA Y TIPO DE INFORME  ·  2026-10-29
-- Regla (Mati, 2026-10-29): cada tipo de informe de cada modulo tiene su propia
-- numeracion continua, separada por empresa, y un numero nunca se reutiliza.
-- Antes los numeros eran globales (secuencias o contadores compartidos por
-- todas las empresas) y al borrar el ultimo informe de buceo/embarcacion el
-- numero se volvia a usar (dejo numeros repetidos en buceo de Aquachile).
--
-- Contadores en public.numeradores_informe (empresa, modulo, anio). Parten en el
-- maximo actual de cada empresa: nadie salta ni retrocede. Empresa nueva parte en 1.
-- Si una fila llega sin empresa_id se completa desde el usuario
-- (usuario_empresas / usuarios.empresa_id); solo si no se resuelve se usa el
-- generador global anterior.
-- Ademas: un upsert del sync sobre una fila existente ya no gasta un numero.
--
-- Ejecutar MANUALMENTE. Reejecutable: si (IF NOT EXISTS, CREATE OR REPLACE,
-- backfill con GREATEST, DROP ... IF EXISTS).
-- DROP justificado: trigger trg_resetear_secuencia (reutilizaba numeros al
-- borrar; decision b del usuario) e indices unicos que asumian numero global
-- (se recrean incluyendo empresa_id).
-- Pasos: 0 (solo lectura) -> 1 (BEGIN..COMMIT) -> 2 (verificar).
-- Fuera de alcance: tickets (codigo de ticket, no es numero de informe).
-- =============================================================================

-- 0. SOLO LECTURA ----------------------------------------------------------------

-- 0.1 actividades (esperado 2026-10-29: Aquachile INSPECCION_BUCEO 715,
--     INSPECCION_EMBARCACION 77, ACTIVIDAD_FORMATIVA 2).
SELECT a.tipo_actividad, e.nombre AS empresa, MAX(a.numero_informe) AS max_numero, COUNT(*) AS filas
FROM public.actividades a
LEFT JOIN public.empresas e ON e.id = a.empresa_id
WHERE a.numero_informe > 0
GROUP BY 1, 2 ORDER BY 1, 2;

-- 0.2 Correlativos de texto (esperado: AST Aquachile 2026-0654, Servimaf 2026-0105;
--     Hidroser GH 2880, Servimaf GH 2210; Merieux visitas 0001; sin checklists
--     ni equipamiento numerados).
SELECT 'AST' AS modulo, e.nombre AS empresa, MAX(a.correlativo) AS max_correlativo, COUNT(*) AS filas
FROM public.ast_informes a LEFT JOIN public.empresas e ON e.id = a.empresa_id
WHERE COALESCE(a.correlativo, '') <> '' GROUP BY 1, 2
UNION ALL
SELECT 'HIDROSER ' || h.lista_codigo, e.nombre, MAX(h.correlativo), COUNT(*)
FROM public.hidroser_inspecciones h LEFT JOIN public.empresas e ON e.id = h.empresa_id
WHERE COALESCE(h.correlativo, '') <> '' GROUP BY 1, 2
UNION ALL
SELECT m.tipo_actividad, e.nombre, MAX(m.correlativo), COUNT(*)
FROM public.merieux_visitas m LEFT JOIN public.empresas e ON e.id = m.empresa_id
WHERE COALESCE(m.correlativo, '') <> '' GROUP BY 1, 2
UNION ALL
SELECT 'CHECKLIST ' || c.checklist_key, e.nombre, MAX(c.correlativo), COUNT(*)
FROM public.checklist_inspecciones c LEFT JOIN public.empresas e ON e.id = c.empresa_id
WHERE COALESCE(c.correlativo, '') <> '' GROUP BY 1, 2
UNION ALL
SELECT 'BUCEO_EQ ' || b.lista_codigo, e.nombre, MAX(b.numero_informe)::text, COUNT(*)
FROM public.buceo_equipamiento_inspecciones b LEFT JOIN public.empresas e ON e.id = b.empresa_id
WHERE b.numero_informe > 0 GROUP BY 1, 2
ORDER BY 1, 2;

-- 0.3 La tabla nueva no debe existir aun (esperado: NULL la primera vez).
SELECT to_regclass('public.numeradores_informe') AS tabla;


-- 1. CAMBIO ----------------------------------------------------------------------
BEGIN;

-- 1.1 Contadores. modulo = tipo de informe (ver lista en la seccion 2.1);
--     anio = 0 salvo AST, que reinicia cada anio como hasta ahora.
CREATE TABLE IF NOT EXISTS public.numeradores_informe (
  empresa_id    uuid        NOT NULL REFERENCES public.empresas(id),
  modulo        text        NOT NULL,
  anio          integer     NOT NULL DEFAULT 0,
  ultimo_numero bigint      NOT NULL DEFAULT 0 CHECK (ultimo_numero >= 0),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (empresa_id, modulo, anio)
);

-- Solo la escriben funciones SECURITY DEFINER; ningun cliente la lee ni escribe.
ALTER TABLE public.numeradores_informe ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.numeradores_informe FROM anon, authenticated;

-- 1.2 Backfill: cada empresa parte en su maximo actual (nunca retrocede).
INSERT INTO public.numeradores_informe (empresa_id, modulo, anio, ultimo_numero)
SELECT x.empresa_id, x.modulo, x.anio, MAX(x.numero)
FROM (
  -- Buceo, embarcacion, actividad formativa
  SELECT a.empresa_id, a.tipo_actividad AS modulo, 0 AS anio, a.numero_informe::bigint AS numero
  FROM public.actividades a
  WHERE a.numero_informe > 0
    AND a.tipo_actividad IN ('INSPECCION_BUCEO', 'INSPECCION_EMBARCACION', 'ACTIVIDAD_FORMATIVA')
  UNION ALL
  -- AST-AAAA-NNNN
  SELECT a.empresa_id, 'AST',
         ((regexp_match(a.correlativo, '^AST-([0-9]{4})-([0-9]+)$'))[1])::int,
         ((regexp_match(a.correlativo, '^AST-([0-9]{4})-([0-9]+)$'))[2])::bigint
  FROM public.ast_informes a
  WHERE a.correlativo ~ '^AST-[0-9]{4}-[0-9]+$'
  UNION ALL
  -- HIDROSER-<prefijo>-AAAA-NNNN, por lista
  SELECT h.empresa_id, 'HIDROSER:' || h.lista_codigo, 0,
         ((regexp_match(h.correlativo, '-([0-9]+)$'))[1])::bigint
  FROM public.hidroser_inspecciones h
  WHERE h.correlativo ~ '-[0-9]+$'
  UNION ALL
  -- MERIEUX-EXT|VIS-AAAA-NNNN, por tipo de informe
  SELECT m.empresa_id, m.tipo_actividad, 0,
         ((regexp_match(m.correlativo, '-([0-9]+)$'))[1])::bigint
  FROM public.merieux_visitas m
  WHERE m.correlativo ~ '-[0-9]+$'
  UNION ALL
  -- <PREFIJO>-NNNN, por checklist
  SELECT c.empresa_id, 'CHECKLIST:' || c.checklist_key, 0,
         ((regexp_match(c.correlativo, '-([0-9]+)$'))[1])::bigint
  FROM public.checklist_inspecciones c
  WHERE c.correlativo ~ '-[0-9]+$'
  UNION ALL
  -- Equipamiento de buceo, por lista
  SELECT b.empresa_id, 'BUCEO_EQ:' || b.lista_codigo, 0, b.numero_informe::bigint
  FROM public.buceo_equipamiento_inspecciones b
  WHERE b.numero_informe > 0
) x
WHERE x.empresa_id IS NOT NULL
GROUP BY x.empresa_id, x.modulo, x.anio
ON CONFLICT (empresa_id, modulo, anio) DO UPDATE
  SET ultimo_numero = GREATEST(public.numeradores_informe.ultimo_numero, EXCLUDED.ultimo_numero),
      updated_at = now();

-- 1.3 Empresa de un usuario, para filas que llegan sin empresa_id. Prefiere
--     usuario_empresas si hay una sola; si no, usuarios.empresa_id (legacy).
--     Al 2026-10-29 los 37 usuarios se resuelven y ninguno tiene mas de una.
CREATE OR REPLACE FUNCTION public.resolver_empresa_usuario(p_usuario_id uuid)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_empresa uuid;
BEGIN
  IF p_usuario_id IS NULL THEN
    RETURN NULL;
  END IF;
  SELECT CASE WHEN COUNT(*) = 1 THEN (array_agg(ue.empresa_id))[1] END
    INTO v_empresa
  FROM public.usuario_empresas ue
  WHERE ue.usuario_id = p_usuario_id;
  IF v_empresa IS NULL THEN
    SELECT u.empresa_id INTO v_empresa FROM public.usuarios u WHERE u.id = p_usuario_id;
  END IF;
  RETURN v_empresa;
END;
$$;

-- 1.4 Generador transaccional: el contador se incrementa dentro de la misma
--     transaccion (un rollback no deja hueco) y la fila queda bloqueada hasta
--     el commit (dos informes simultaneos no reciben el mismo numero).
CREATE OR REPLACE FUNCTION public.next_numero_informe(
  p_empresa_id uuid,
  p_modulo text,
  p_anio integer DEFAULT 0
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_num bigint;
BEGIN
  INSERT INTO public.numeradores_informe (empresa_id, modulo, anio, ultimo_numero)
  VALUES (p_empresa_id, p_modulo, p_anio, 1)
  ON CONFLICT (empresa_id, modulo, anio) DO UPDATE
    SET ultimo_numero = public.numeradores_informe.ultimo_numero + 1,
        updated_at = now()
  RETURNING ultimo_numero INTO v_num;
  RETURN v_num;
END;
$$;

-- Nadie las llama por RPC: solo los triggers (SECURITY DEFINER, mismo owner).
REVOKE ALL ON FUNCTION public.resolver_empresa_usuario(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.next_numero_informe(uuid, text, integer) FROM PUBLIC, anon, authenticated;

-- 1.5 actividades: buceo, embarcacion y actividad formativa.
--     Misma logica de cuando se asigna; solo cambia de donde sale el numero.
CREATE OR REPLACE FUNCTION public.asignar_numero_informe()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NEW.tipo_actividad NOT IN ('INSPECCION_BUCEO', 'INSPECCION_EMBARCACION', 'ACTIVIDAD_FORMATIVA') THEN
    RETURN NEW;
  END IF;

  IF NEW.empresa_id IS NULL THEN
    NEW.empresa_id := public.resolver_empresa_usuario(NEW.usuario_id);
  END IF;

  IF NEW.tipo_actividad = 'ACTIVIDAD_FORMATIVA' THEN
    -- Permite recuperar finalizados sin numero en un reintento de sincronizacion.
    IF NEW.estado_final = 'En Seguimiento'
       AND (NEW.numero_informe IS NULL OR NEW.numero_informe = 0) THEN
      IF NEW.empresa_id IS NULL THEN
        NEW.numero_informe := nextval('public.seq_inf_actividad_formativa');
      ELSE
        NEW.numero_informe := public.next_numero_informe(NEW.empresa_id, NEW.tipo_actividad);
      END IF;
    END IF;
  ELSIF NEW.estado_final = 'En Seguimiento'
     AND (TG_OP = 'INSERT' OR OLD.estado_final IS NULL OR OLD.estado_final != 'En Seguimiento')
     AND (NEW.numero_informe IS NULL OR NEW.numero_informe = 0) THEN
    IF NEW.empresa_id IS NOT NULL THEN
      NEW.numero_informe := public.next_numero_informe(NEW.empresa_id, NEW.tipo_actividad);
    ELSIF NEW.tipo_actividad = 'INSPECCION_BUCEO' THEN
      NEW.numero_informe := nextval('public.seq_inf_buceo');
    ELSE
      NEW.numero_informe := nextval('public.seq_inf_embarcacion');
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 1.6 Un numero nunca se reutiliza: se quita el trigger que, al borrar el
--     ultimo informe, devolvia la secuencia a ese numero. La funcion
--     resetear_secuencia_al_borrar queda sin uso (no se borra).
DROP TRIGGER IF EXISTS trg_resetear_secuencia ON public.actividades;

-- 1.7 AST: mismo formato AST-AAAA-NNNN, contador por empresa y anio.
CREATE OR REPLACE FUNCTION public.assign_ast_correlativo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_fecha timestamptz;
  v_anio integer;
BEGIN
  IF NEW.empresa_id IS NULL THEN
    NEW.empresa_id := public.resolver_empresa_usuario(NEW.usuario_id);
  END IF;

  -- El sync sube AST con upsert: Postgres dispara BEFORE INSERT aunque la fila
  -- ya exista, y se gastaba un numero en cada reintento. Si existe, numera el
  -- BEFORE UPDATE.
  IF TG_OP = 'INSERT'
     AND EXISTS (SELECT 1 FROM public.ast_informes WHERE id = NEW.id) THEN
    RETURN NEW;
  END IF;

  IF NEW.estado_final = 'En Seguimiento'
     AND COALESCE(NEW.correlativo, '') = ''
     AND (
       TG_OP = 'INSERT'
       OR COALESCE(OLD.estado_final, '') IS DISTINCT FROM 'En Seguimiento'
     ) THEN
    v_fecha := COALESCE(NEW.fecha_realizacion, now());
    IF NEW.empresa_id IS NULL THEN
      NEW.correlativo := public.next_ast_correlativo_gapless(v_fecha);
    ELSE
      v_anio := EXTRACT(YEAR FROM v_fecha)::int;
      NEW.correlativo := format(
        'AST-%s-%s',
        v_anio,
        LPAD(public.next_numero_informe(NEW.empresa_id, 'AST', v_anio)::text, 4, '0')
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- 1.8 Hidroser: mismo formato HIDROSER-<prefijo>-AAAA-NNNN, contador por
--     empresa y lista (antes una secuencia global para todas).
CREATE OR REPLACE FUNCTION public.assign_hidroser_correlativo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_prefix text;
BEGIN
  IF NEW.empresa_id IS NULL THEN
    NEW.empresa_id := public.resolver_empresa_usuario(NEW.usuario_id);
  END IF;

  IF TG_OP = 'INSERT'
     AND EXISTS (SELECT 1 FROM public.hidroser_inspecciones WHERE id = NEW.id) THEN
    RETURN NEW;
  END IF;

  IF NEW.estado_final = 'En Seguimiento' AND (NEW.correlativo IS NULL OR NEW.correlativo = '') THEN
    IF NEW.empresa_id IS NULL THEN
      NEW.correlativo := public.next_hidroser_correlativo(NEW.lista_codigo);
    ELSE
      v_prefix := CASE NEW.lista_codigo
                    WHEN 'GRUA_HORQUILLA_PFA' THEN 'HIDROSER-GH'
                    ELSE 'HIDROSER-' || regexp_replace(NEW.lista_codigo, '[^A-Z0-9]+', '', 'g')
                  END;
      NEW.correlativo := format(
        '%s-%s-%s',
        v_prefix,
        EXTRACT(YEAR FROM now())::int,
        LPAD(public.next_numero_informe(NEW.empresa_id, 'HIDROSER:' || NEW.lista_codigo)::text, 4, '0')
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 1.9 Merieux: mismo formato MERIEUX-EXT|VIS-AAAA-NNNN, contador por empresa
--     y tipo de informe (antes visitas y extintores compartian secuencia).
CREATE OR REPLACE FUNCTION public.assign_merieux_correlativo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_prefix text;
BEGIN
  IF NEW.empresa_id IS NULL THEN
    NEW.empresa_id := public.resolver_empresa_usuario(NEW.usuario_id);
  END IF;

  IF TG_OP = 'INSERT'
     AND EXISTS (SELECT 1 FROM public.merieux_visitas WHERE id = NEW.id) THEN
    RETURN NEW;
  END IF;

  IF NEW.estado_final = 'En Seguimiento' AND (NEW.correlativo IS NULL OR NEW.correlativo = '') THEN
    IF NEW.empresa_id IS NULL THEN
      NEW.correlativo := public.next_merieux_correlativo(NEW.tipo_actividad);
    ELSE
      v_prefix := CASE NEW.tipo_actividad
                    WHEN 'MERIEUX_EXTINTORES' THEN 'MERIEUX-EXT'
                    ELSE 'MERIEUX-VIS'
                  END;
      NEW.correlativo := format(
        '%s-%s-%s',
        v_prefix,
        EXTRACT(YEAR FROM now())::int,
        LPAD(public.next_numero_informe(NEW.empresa_id, NEW.tipo_actividad)::text, 4, '0')
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 1.10 Equipamiento de Buceo: mismo formato BUCEO-EQ-<lista>-AAAA-NNNN y
--      numero_informe, contador por empresa y lista.
CREATE OR REPLACE FUNCTION public.fn_buceo_equipamiento_set_correlativo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_next bigint;
  v_prefijo text;
BEGIN
  IF NEW.empresa_id IS NULL THEN
    NEW.empresa_id := public.resolver_empresa_usuario(NEW.usuario_id);
  END IF;

  IF TG_OP = 'INSERT'
     AND EXISTS (SELECT 1 FROM public.buceo_equipamiento_inspecciones WHERE id = NEW.id) THEN
    RETURN NEW;
  END IF;

  IF NEW.estado_final = 'En Seguimiento' AND COALESCE(NEW.numero_informe, 0) <= 0 THEN
    IF NEW.empresa_id IS NULL THEN
      INSERT INTO public.buceo_equipamiento_numeradores (lista_codigo, ultimo_numero)
      VALUES (NEW.lista_codigo, 1)
      ON CONFLICT (lista_codigo) DO UPDATE
        SET ultimo_numero = public.buceo_equipamiento_numeradores.ultimo_numero + 1,
            updated_at = now()
      RETURNING ultimo_numero INTO v_next;
    ELSE
      v_next := public.next_numero_informe(NEW.empresa_id, 'BUCEO_EQ:' || NEW.lista_codigo);
    END IF;
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
$function$;

-- 1.11 Motor de checklists: mismo formato <PREFIJO>-NNNN, contador por empresa
--      y checklist. Si el checklist no existe o esta inactivo, mismo error de antes.
CREATE OR REPLACE FUNCTION public.assign_checklist_correlativo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_prefix text;
BEGIN
  IF NEW.empresa_id IS NULL THEN
    NEW.empresa_id := public.resolver_empresa_usuario(NEW.usuario_id);
  END IF;

  IF TG_OP = 'INSERT'
     AND EXISTS (SELECT 1 FROM public.checklist_inspecciones WHERE id = NEW.id) THEN
    RETURN NEW;
  END IF;

  IF NEW.estado_final NOT IN ('Borrador', 'En Progreso', 'Eliminada')
     AND COALESCE(NEW.correlativo, '') = ''
     AND (TG_OP = 'INSERT' OR OLD.estado_final IN ('Borrador', 'En Progreso')) THEN
    IF NEW.empresa_id IS NULL THEN
      NEW.correlativo := public.next_checklist_correlativo(NEW.checklist_key);
    ELSE
      SELECT c.report_prefix INTO v_prefix
      FROM public.checklists c
      WHERE c.checklist_key = NEW.checklist_key AND c.activo = TRUE;
      IF v_prefix IS NULL THEN
        RAISE EXCEPTION 'CHECKLIST_CORRELATIVO_INVALIDO';
      END IF;
      NEW.correlativo := format(
        '%s-%s',
        v_prefix,
        lpad(public.next_numero_informe(NEW.empresa_id, 'CHECKLIST:' || NEW.checklist_key)::text, 4, '0')
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 1.11b Generadores anteriores (respaldo cuando no hay empresa): search_path
--       propio porque hacen nextval sin esquema, y nadie los llama por RPC
--       (la app no los usa; solo los triggers, que corren como owner).
ALTER FUNCTION public.next_hidroser_correlativo(text) SET search_path TO 'public';
ALTER FUNCTION public.next_merieux_correlativo(text) SET search_path TO 'public';
REVOKE EXECUTE ON FUNCTION public.next_hidroser_correlativo(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.next_merieux_correlativo(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.next_checklist_correlativo(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.next_ast_correlativo() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.next_ast_correlativo_gapless(timestamptz) FROM PUBLIC, anon, authenticated;

-- 1.12 Unicidad por empresa (antes asumia numeracion global).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.actividades
    WHERE tipo_actividad = 'ACTIVIDAD_FORMATIVA' AND numero_informe > 0
    GROUP BY empresa_id, numero_informe HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'FORMATIVA_DUPLICADA: numeros repetidos dentro de una empresa; revisar antes de cambiar el indice';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.checklist_inspecciones
    WHERE COALESCE(correlativo, '') <> ''
    GROUP BY empresa_id, checklist_key, correlativo HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'CHECKLIST_DUPLICADO: correlativos repetidos dentro de una empresa; revisar antes de cambiar la restriccion';
  END IF;
END $$;

DROP INDEX IF EXISTS public.idx_actividades_formativas_numero_informe;
CREATE UNIQUE INDEX IF NOT EXISTS idx_actividades_formativas_empresa_numero_informe
  ON public.actividades (empresa_id, numero_informe)
  WHERE tipo_actividad = 'ACTIVIDAD_FORMATIVA' AND numero_informe > 0;

ALTER TABLE public.checklist_inspecciones
  DROP CONSTRAINT IF EXISTS checklist_inspecciones_checklist_key_correlativo_key;
CREATE UNIQUE INDEX IF NOT EXISTS idx_checklist_inspecciones_empresa_key_correlativo
  ON public.checklist_inspecciones (empresa_id, checklist_key, correlativo);

COMMIT;


-- 2. VERIFICAR (solo lectura) -----------------------------------------------------

-- 2.1 Contadores (esperado: Aquachile INSPECCION_BUCEO 715, INSPECCION_EMBARCACION 77,
--     ACTIVIDAD_FORMATIVA 2, AST 2026 654; Servimaf AST 2026 105;
--     Hidroser HIDROSER:GRUA_HORQUILLA_PFA 2880; Servimaf HIDROSER:GRUA_HORQUILLA_PFA 2210;
--     Merieux NutriSciences MERIEUX_VISITAS 1).
SELECT e.nombre AS empresa, n.modulo, n.anio, n.ultimo_numero
FROM public.numeradores_informe n
JOIN public.empresas e ON e.id = n.empresa_id
ORDER BY 1, 2, 3;

-- 2.2 Triggers de numeracion (esperado: 6 funciones con prosecdef = true).
SELECT proname, prosecdef FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN ('asignar_numero_informe', 'assign_ast_correlativo', 'assign_hidroser_correlativo',
                  'assign_merieux_correlativo', 'fn_buceo_equipamiento_set_correlativo',
                  'assign_checklist_correlativo');

-- 2.3 El trigger de reinicio ya no existe (esperado: 0 filas).
SELECT tgname FROM pg_trigger WHERE tgname = 'trg_resetear_secuencia';

-- 2.4 Indices unicos nuevos (esperado: 2 filas).
SELECT indexname FROM pg_indexes
WHERE indexname IN ('idx_actividades_formativas_empresa_numero_informe',
                    'idx_checklist_inspecciones_empresa_key_correlativo');
