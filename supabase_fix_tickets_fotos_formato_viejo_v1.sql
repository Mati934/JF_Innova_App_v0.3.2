-- =============================================================================
-- Tickets de fotos con observacion en formato viejo -> formato nuevo  ·  2026-10-29
-- Antes del fix del 2026-09-03 (y en APKs viejos hasta 2026-10-20) se creaba UN
-- ticket FOTOS_OBSERVACION por inspeccion con todas sus observaciones como items.
-- Este script toma solo los que siguen ABIERTO (nadie los trabajo), crea un
-- ticket nuevo por observacion distinta (formato actual, con
-- observacion_foto_key) y da de baja logica el viejo. Los viejos con trabajo
-- (TOMADO, PARCIAL, FINALIZADO_PENDIENTE_REVISION, CERRADO) NO se tocan.
-- Se descartan items que hoy no son observaciones (titulos de fotos obligatorias
-- de buceo, placeholders), igual que TicketReglas.esObservacionFotoReal.
-- Ejecutar MANUALMENTE. Reejecutable: si (solo procesa viejos aun no eliminados
-- y no crea un ticket si ya existe uno vivo con la misma clave).
-- Pasos: 0 (solo lectura) -> 1 (BEGIN..COMMIT) -> 2 (verificar).
-- =============================================================================

-- 0. SOLO LECTURA ------------------------------------------------------------

-- 0.1 Tickets viejos a procesar. Esperado (2026-10-29): 26 tickets, 72 items.
select count(distinct t.id) tickets, count(i.id) items
from public.tickets t
join public.ticket_items i on i.ticket_id = t.id
where t.eliminado = false
  and t.estado = 'ABIERTO'
  and t.campos_extra_json ->> 'automatico_tipo' = 'FOTOS_OBSERVACION'
  and not (t.campos_extra_json ? 'observacion_foto_key');

-- 0.2 Tickets nuevos que se crearian (observaciones reales distintas por
-- inspeccion). Esperado (2026-10-29): 67 (72 items - 5 titulos de fotos
-- obligatorias de TCK-2026-0119).
with viejos as (
  select t.*
  from public.tickets t
  where t.eliminado = false
    and t.estado = 'ABIERTO'
    and t.campos_extra_json ->> 'automatico_tipo' = 'FOTOS_OBSERVACION'
    and not (t.campos_extra_json ? 'observacion_foto_key')
)
select count(distinct (v.inspeccion_id, lower(trim(i.descripcion)))) tickets_nuevos
from viejos v
join public.ticket_items i on i.ticket_id = v.id
where lower(trim(i.descripcion)) <> ''
  and lower(trim(i.descripcion)) not in (
    'general', 'fotografía anexa', 'fotografia anexa',
    'anexo fotográfico de visita técnica',
    'compresor general', 'estado de aceite vegetal compresor principal',
    'estado aceite vegetal compresor back up', 'matriculas de buceo',
    'bitacora de compresores', 'bitacora de buceo supervisor',
    'registro aplicacion oxigeno normobarico',
    'certificado de inspeccion de compresores')
  and lower(trim(i.descripcion)) not like 'verificación:%'
  and lower(trim(i.descripcion)) not like 'verificacion:%'
  and lower(trim(i.descripcion)) !~ '^item\s+[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

-- 0.3 Debe haber al menos un admin (el trigger trg_ticket_borrado_permiso exige
-- auth.uid() admin o autor para cambiar "eliminado"). Esperado: >= 1.
select count(*) admins
from public.usuarios u
join public.roles r on r.id = u.rol_id
where lower(r.nombre) in ('admin', 'administrador');


-- 1. CAMBIO -------------------------------------------------------------------
BEGIN;

DO $$
DECLARE
  v_admin uuid;
  v_viejo record;
  v_obs record;
  v_nuevo uuid;
  v_creados int := 0;
  v_eliminados int := 0;
BEGIN
  SELECT u.id INTO v_admin
  FROM public.usuarios u
  JOIN public.roles r ON r.id = u.rol_id
  WHERE lower(r.nombre) IN ('admin', 'administrador')
  ORDER BY u.id
  LIMIT 1;
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'SIN_ADMIN: no hay usuario admin para la baja logica';
  END IF;

  -- auth.uid() lee el "sub" del JWT: se simula una sesion admin solo dentro de
  -- esta transaccion para pasar trg_ticket_borrado_permiso.
  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text,
    true
  );

  FOR v_viejo IN
    SELECT t.*
    FROM public.tickets t
    WHERE t.eliminado = false
      AND t.estado = 'ABIERTO'
      AND t.campos_extra_json ->> 'automatico_tipo' = 'FOTOS_OBSERVACION'
      AND NOT (t.campos_extra_json ? 'observacion_foto_key')
    ORDER BY t.created_at
  LOOP
    -- Un ticket por observacion distinta; el item toma la primera foto (menor
    -- orden), igual que _agregarTicketFotosConObservacion.
    FOR v_obs IN
      SELECT DISTINCT ON (lower(trim(i.descripcion)))
        lower(trim(i.descripcion)) AS clave,
        trim(i.descripcion) AS descripcion,
        i.referencia_id,
        i.foto_original_url
      FROM public.ticket_items i
      WHERE i.ticket_id = v_viejo.id
        AND lower(trim(i.descripcion)) <> ''
        AND lower(trim(i.descripcion)) NOT IN (
          'general', 'fotografía anexa', 'fotografia anexa',
          'anexo fotográfico de visita técnica',
          'compresor general', 'estado de aceite vegetal compresor principal',
          'estado aceite vegetal compresor back up', 'matriculas de buceo',
          'bitacora de compresores', 'bitacora de buceo supervisor',
          'registro aplicacion oxigeno normobarico',
          'certificado de inspeccion de compresores')
        AND lower(trim(i.descripcion)) NOT LIKE 'verificación:%'
        AND lower(trim(i.descripcion)) NOT LIKE 'verificacion:%'
        AND lower(trim(i.descripcion)) !~ '^item\s+[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      ORDER BY lower(trim(i.descripcion)), i.orden
    LOOP
      IF EXISTS (
        SELECT 1 FROM public.tickets t2
        WHERE t2.inspeccion_id = v_viejo.inspeccion_id
          AND t2.eliminado = false
          AND t2.campos_extra_json ->> 'automatico_tipo' = 'FOTOS_OBSERVACION'
          AND t2.campos_extra_json ->> 'observacion_foto_key' = v_obs.clave
      ) THEN
        CONTINUE;
      END IF;

      v_nuevo := gen_random_uuid();
      INSERT INTO public.tickets (
        id, empresa_id, origen, tipo_ticket, inspeccion_id, tipo_inspeccion,
        numero_informe, area_id, centro_id, embarcacion_id, contratista_id,
        generado_por_id, fecha_limite, created_at, campos_extra_json
      ) VALUES (
        v_nuevo, v_viejo.empresa_id, v_viejo.origen, v_viejo.tipo_ticket,
        v_viejo.inspeccion_id, v_viejo.tipo_inspeccion, v_viejo.numero_informe,
        v_viejo.area_id, v_viejo.centro_id, v_viejo.embarcacion_id,
        v_viejo.contratista_id, v_viejo.generado_por_id, v_viejo.fecha_limite,
        v_viejo.created_at,
        jsonb_build_object(
          'automatico_tipo', 'FOTOS_OBSERVACION',
          'observacion_foto_key', v_obs.clave,
          'reemplaza_ticket', v_viejo.codigo_ticket
        )
      );

      INSERT INTO public.ticket_items (
        ticket_id, origen_item, referencia_id, descripcion,
        foto_original_url, orden
      ) VALUES (
        v_nuevo, 'FOTO_OBSERVACION', v_obs.referencia_id, v_obs.descripcion,
        v_obs.foto_original_url, 0
      );
      v_creados := v_creados + 1;
    END LOOP;

    UPDATE public.tickets
    SET eliminado = true,
        campos_extra_json = campos_extra_json || jsonb_build_object(
          'eliminado_por_fix', 'supabase_fix_tickets_fotos_formato_viejo_v1',
          'eliminado_fix_at', '2026-10-29'
        )
    WHERE id = v_viejo.id;
    v_eliminados := v_eliminados + 1;
  END LOOP;

  RAISE NOTICE 'Tickets viejos dados de baja: %, tickets nuevos creados: %',
    v_eliminados, v_creados;
END $$;

COMMIT;


-- 2. SOLO LECTURA: verificar ---------------------------------------------------

-- 2.1 No quedan viejos ABIERTO vivos. Esperado: 0.
select count(*) viejos_abiertos_vivos
from public.tickets t
where t.eliminado = false
  and t.estado = 'ABIERTO'
  and t.campos_extra_json ->> 'automatico_tipo' = 'FOTOS_OBSERVACION'
  and not (t.campos_extra_json ? 'observacion_foto_key');

-- 2.2 Nuevos creados por el fix, con 1 item cada uno. Esperado: 67 tickets,
-- 67 items, maximo 1 item por ticket.
select count(distinct t.id) tickets, count(i.id) items,
       max(n.c) max_items_por_ticket
from public.tickets t
join public.ticket_items i on i.ticket_id = t.id
join lateral (select count(*) c from public.ticket_items x where x.ticket_id = t.id) n on true
where t.campos_extra_json ? 'reemplaza_ticket';

-- 2.3 Los viejos con trabajo siguen intactos. Esperado: 13 (8 CERRADO,
-- 2 FINALIZADO_PENDIENTE_REVISION, 2 PARCIAL, 1 TOMADO).
select estado, count(*)
from public.tickets t
where t.eliminado = false
  and t.campos_extra_json ->> 'automatico_tipo' = 'FOTOS_OBSERVACION'
  and not (t.campos_extra_json ? 'observacion_foto_key')
group by estado;

-- REVERSION (si hiciera falta): reactivar los viejos y eliminar los nuevos.
-- update public.tickets set eliminado = false,
--   campos_extra_json = campos_extra_json - 'eliminado_por_fix' - 'eliminado_fix_at'
-- where campos_extra_json ->> 'eliminado_por_fix' = 'supabase_fix_tickets_fotos_formato_viejo_v1';
-- update public.tickets set eliminado = true where campos_extra_json ? 'reemplaza_ticket';
-- (ambos requieren sesion admin por trg_ticket_borrado_permiso)
