-- =============================================================================
-- MIGRACION COMPLETA: Modulo TICKETS (rediseno, ver docs/PLAN_TICKETS_MVP.md)
-- Objetivo:
--   1) Eliminar el diseno viejo de tickets (tabla `tickets` + `ticket_categorias`).
--   2) Crear el nuevo modelo: tickets, ticket_items, ticket_historial_tomas,
--      ticket_notificaciones.
--   3) Correlativo propio TCK-AAAA-NNNN.
--   4) Funciones helper de RLS (is_admin_user, user_has_empresa) + politicas.
--   5) Publicar las tablas en Supabase Realtime.
--
-- Notas de diseno (ver plan para el detalle completo):
--   - El modulo es 100% online: no hay tablas `_pendientes` en SQLite para Tickets.
--   - Un usuario ve solo los tickets de su propia empresa, EXCEPTO los usuarios
--     con rol admin (cualquier empresa), que ven y revisan todos.
--   - Maximo 1 ticket automatico (origen=INSPECCION) por inspeccion.
--
-- Seguro de ejecutar multiples veces (idempotente), salvo el DROP inicial del
-- diseno viejo, que solo se ejecuta una vez (IF EXISTS).
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- A) ELIMINAR DISENO VIEJO DE TICKETS
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS public.tickets CASCADE;
DROP TABLE IF EXISTS public.ticket_categorias CASCADE;

-- -----------------------------------------------------------------------------
-- B) TABLAS NUEVAS DEL MODULO
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.tickets (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo_ticket       TEXT UNIQUE,
  empresa_id          UUID NOT NULL REFERENCES public.empresas(id),
  origen              TEXT NOT NULL CHECK (origen IN ('INSPECCION', 'SOLICITUD')),
  tipo_ticket         TEXT NOT NULL CHECK (tipo_ticket IN ('REVISION_OBSERVACIONES', 'SOLICITUD')),
  inspeccion_id       UUID REFERENCES public.actividades(id),
  tipo_inspeccion     TEXT,
  numero_informe      TEXT,
  area_id             UUID REFERENCES public.areas(id),
  centro_id           UUID REFERENCES public.centros(id),
  embarcacion_id      UUID REFERENCES public.embarcaciones(id),
  asunto              TEXT,
  motivo              TEXT NOT NULL,
  generado_por_id     UUID NOT NULL,
  estado              TEXT NOT NULL DEFAULT 'ABIERTO'
                        CHECK (estado IN ('ABIERTO', 'TOMADO', 'PARCIAL', 'FINALIZADO_PENDIENTE_REVISION', 'CERRADO')),
  tomado_por_id       UUID,
  fecha_limite        TIMESTAMPTZ,
  revisado_por_id     UUID,
  revisado_at         TIMESTAMPTZ,
  rechazado           BOOLEAN NOT NULL DEFAULT false,
  motivo_rechazo      TEXT,
  rechazado_por_id    UUID,
  rechazado_at        TIMESTAMPTZ,
  campos_extra_json   JSONB NOT NULL DEFAULT '{}'::jsonb,
  eliminado           BOOLEAN NOT NULL DEFAULT false,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Maximo 1 ticket automatico por inspeccion (decision 17 del plan).
CREATE UNIQUE INDEX IF NOT EXISTS uq_tickets_inspeccion_automatico
  ON public.tickets(inspeccion_id)
  WHERE origen = 'INSPECCION' AND inspeccion_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tickets_empresa       ON public.tickets(empresa_id);
CREATE INDEX IF NOT EXISTS idx_tickets_estado         ON public.tickets(estado);
CREATE INDEX IF NOT EXISTS idx_tickets_generado_por    ON public.tickets(generado_por_id);
CREATE INDEX IF NOT EXISTS idx_tickets_tomado_por      ON public.tickets(tomado_por_id);
CREATE INDEX IF NOT EXISTS idx_tickets_inspeccion      ON public.tickets(inspeccion_id);

COMMENT ON TABLE public.tickets IS
  'Modulo Tickets (seguimiento de no conformidades / solicitudes). 100% online, ver docs/PLAN_TICKETS_MVP.md.';

-- Cada fila = una observacion/no-cumple a subsanar dentro de un ticket.
CREATE TABLE IF NOT EXISTS public.ticket_items (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id             UUID NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  origen_item           TEXT NOT NULL CHECK (origen_item IN ('RESPUESTA_INSPECCION', 'FOTO_OBSERVACION', 'MANUAL')),
  referencia_id         UUID,
  descripcion           TEXT NOT NULL,
  foto_original_url     TEXT,
  subsanado             BOOLEAN NOT NULL DEFAULT false,
  foto_subsanacion_url  TEXT,
  subsanado_por_id      UUID,
  subsanado_at          TIMESTAMPTZ,
  orden                 INTEGER NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_ticket_item_foto_subsanacion CHECK (NOT subsanado OR foto_subsanacion_url IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_ticket_items_ticket ON public.ticket_items(ticket_id);

-- Bitacora de todo el recorrido del ticket (tomar/soltar/finalizar/revisar).
CREATE TABLE IF NOT EXISTS public.ticket_historial_tomas (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id    UUID NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  usuario_id   UUID NOT NULL,
  accion       TEXT NOT NULL CHECK (accion IN ('TOMADO', 'SOLTADO', 'FINALIZADO', 'REVISADO_APROBADO', 'REVISADO_RECHAZADO')),
  comentario   TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ticket_historial_ticket ON public.ticket_historial_tomas(ticket_id);

-- Notificaciones in-app (etapa 1, ver plan seccion 8.4).
CREATE TABLE IF NOT EXISTS public.ticket_notificaciones (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id           UUID NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  usuario_destino_id  UUID NOT NULL,
  tipo                TEXT NOT NULL CHECK (tipo IN ('TOMADO', 'PARCIAL', 'APROBADO', 'RECHAZADO')),
  mensaje             TEXT NOT NULL,
  leido               BOOLEAN NOT NULL DEFAULT false,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ticket_notif_destino ON public.ticket_notificaciones(usuario_destino_id, leido);

-- -----------------------------------------------------------------------------
-- C) CORRELATIVO PROPIO (TCK-AAAA-NNNN) + updated_at automatico
-- -----------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.ticket_codigo_seq AS BIGINT START 1;

CREATE OR REPLACE FUNCTION public.next_ticket_codigo()
RETURNS TEXT AS $$
DECLARE
  v_year INT    := EXTRACT(YEAR FROM now())::int;
  v_num  BIGINT := nextval('public.ticket_codigo_seq');
BEGIN
  RETURN format('TCK-%s-%s', v_year, LPAD(v_num::text, 4, '0'));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.assign_ticket_codigo()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.codigo_ticket IS NULL OR NEW.codigo_ticket = '' THEN
    NEW.codigo_ticket := public.next_ticket_codigo();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ticket_codigo ON public.tickets;
CREATE TRIGGER trg_ticket_codigo
  BEFORE INSERT ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.assign_ticket_codigo();

CREATE OR REPLACE FUNCTION public.touch_ticket_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ticket_touch ON public.tickets;
CREATE TRIGGER trg_ticket_touch
  BEFORE UPDATE ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.touch_ticket_updated_at();

-- -----------------------------------------------------------------------------
-- D) HELPERS DE RLS
-- -----------------------------------------------------------------------------

-- true si el usuario autenticado tiene rol admin/administrador (sin importar empresa).
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.usuarios u
    JOIN public.roles r ON r.id = u.rol_id
    WHERE u.id = auth.uid()
      AND lower(r.nombre) IN ('admin', 'administrador')
  );
$$;

-- true si el usuario autenticado pertenece a la empresa indicada
-- (soporta multi-empresa via usuario_empresas y el legado usuarios.empresa_id).
CREATE OR REPLACE FUNCTION public.user_has_empresa(p_empresa_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.usuario_empresas ue
    WHERE ue.usuario_id = auth.uid() AND ue.empresa_id = p_empresa_id
  )
  OR EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.id = auth.uid() AND u.empresa_id = p_empresa_id
  );
$$;

-- -----------------------------------------------------------------------------
-- E) ROW LEVEL SECURITY
-- -----------------------------------------------------------------------------
ALTER TABLE public.tickets                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_items            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_historial_tomas  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_notificaciones   ENABLE ROW LEVEL SECURITY;

-- tickets: ver solo mi empresa, salvo admin (ve todas).
DROP POLICY IF EXISTS tickets_select ON public.tickets;
CREATE POLICY tickets_select ON public.tickets FOR SELECT TO authenticated
  USING (public.is_admin_user() OR public.user_has_empresa(empresa_id));

DROP POLICY IF EXISTS tickets_insert ON public.tickets;
CREATE POLICY tickets_insert ON public.tickets FOR INSERT TO authenticated
  WITH CHECK (public.user_has_empresa(empresa_id));

DROP POLICY IF EXISTS tickets_update ON public.tickets;
CREATE POLICY tickets_update ON public.tickets FOR UPDATE TO authenticated
  USING      (public.is_admin_user() OR public.user_has_empresa(empresa_id))
  WITH CHECK (public.is_admin_user() OR public.user_has_empresa(empresa_id));

-- ticket_items: acceso segun el ticket padre.
DROP POLICY IF EXISTS ticket_items_all ON public.ticket_items;
CREATE POLICY ticket_items_all ON public.ticket_items FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.tickets t WHERE t.id = ticket_id
            AND (public.is_admin_user() OR public.user_has_empresa(t.empresa_id)))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.tickets t WHERE t.id = ticket_id
            AND (public.is_admin_user() OR public.user_has_empresa(t.empresa_id)))
  );

-- ticket_historial_tomas: lectura + insercion segun el ticket padre (sin update/delete, es bitacora).
DROP POLICY IF EXISTS ticket_hist_select ON public.ticket_historial_tomas;
CREATE POLICY ticket_hist_select ON public.ticket_historial_tomas FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.tickets t WHERE t.id = ticket_id
            AND (public.is_admin_user() OR public.user_has_empresa(t.empresa_id)))
  );

DROP POLICY IF EXISTS ticket_hist_insert ON public.ticket_historial_tomas;
CREATE POLICY ticket_hist_insert ON public.ticket_historial_tomas FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.tickets t WHERE t.id = ticket_id
            AND (public.is_admin_user() OR public.user_has_empresa(t.empresa_id)))
  );

-- ticket_notificaciones: cada quien ve/marca-leido solo las suyas; insercion abierta
-- (la hace la app al cambiar de estado un ticket al que ya tiene acceso).
DROP POLICY IF EXISTS ticket_notif_select ON public.ticket_notificaciones;
CREATE POLICY ticket_notif_select ON public.ticket_notificaciones FOR SELECT TO authenticated
  USING (usuario_destino_id = auth.uid());

DROP POLICY IF EXISTS ticket_notif_insert ON public.ticket_notificaciones;
CREATE POLICY ticket_notif_insert ON public.ticket_notificaciones FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS ticket_notif_update ON public.ticket_notificaciones;
CREATE POLICY ticket_notif_update ON public.ticket_notificaciones FOR UPDATE TO authenticated
  USING      (usuario_destino_id = auth.uid())
  WITH CHECK (usuario_destino_id = auth.uid());

-- -----------------------------------------------------------------------------
-- F) REALTIME: publicar las tablas para que la app reciba cambios en vivo.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'tickets'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.tickets;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'ticket_items'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.ticket_items;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'ticket_notificaciones'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.ticket_notificaciones;
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- G) MODULO EN empresa_modulos
-- -----------------------------------------------------------------------------
-- No se necesita seed aqui: `ModuleRegistry` ya incluye 'TICKETS' y la pantalla
-- de administracion (`empresa_modulos_screen.dart`) agrega automaticamente las
-- filas faltantes con habilitado=false la primera vez que un admin abre esa
-- pantalla para una empresa. Cada empresa lo activa manualmente cuando quiera.

COMMIT;
