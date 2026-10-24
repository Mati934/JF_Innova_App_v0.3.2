-- supabase_migration_email_mvp.sql
-- Migración para Supabase (PostgreSQL) del módulo de correo MVP.
-- Idempotente: se puede ejecutar más de una vez.

BEGIN;

CREATE TABLE IF NOT EXISTS public.correo_plantillas (
  id text PRIMARY KEY,
  nombre text NOT NULL,
  asunto_template text NOT NULL,
  cuerpo_template text NOT NULL,
  modulo text,
  empresa_id uuid,
  variables_permitidas text,
  activo boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by text
);

CREATE TABLE IF NOT EXISTS public.correo_listas (
  id text PRIMARY KEY,
  nombre text NOT NULL,
  proposito text,
  activo boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.correo_lista_destinatarios (
  id text PRIMARY KEY,
  lista_id text NOT NULL,
  nombre text,
  correo text NOT NULL,
  tipo_sugerido text NOT NULL DEFAULT 'to',
  activo boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.correo_configuracion (
  id text PRIMARY KEY,
  empresa_id uuid,
  modulo text NOT NULL,
  plantilla_id text NOT NULL,
  lista_id text NOT NULL,
  prioridad integer NOT NULL DEFAULT 0,
  activo boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.correo_eventos (
  id text PRIMARY KEY,
  inspeccion_id text,
  empresa_id uuid,
  usuario_id uuid,
  event_type text NOT NULL,
  event_timestamp timestamptz NOT NULL DEFAULT now(),
  resultado_evento text NOT NULL,
  canal text,
  template_id text,
  template_version integer,
  asunto_generado text,
  adjunto_nombre text,
  adjunto_tipo text,
  error_code text,
  error_message text
);

CREATE TABLE IF NOT EXISTS public.correo_pendientes (
  id text PRIMARY KEY,
  registro_id text NOT NULL,
  modulo_key text NOT NULL,
  empresa_id uuid,
  usuario_id uuid,
  config_id text,
  lista_id text,
  estado text NOT NULL DEFAULT 'pendiente',
  payload_json jsonb,
  intentos integer NOT NULL DEFAULT 0,
  ultimo_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.correo_usuario_asignacion (
  id text PRIMARY KEY,
  usuario_id uuid NOT NULL,
  config_id text,
  lista_id text,
  activo boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_correo_cfg_modulo
ON public.correo_configuracion(modulo, activo, prioridad);

CREATE INDEX IF NOT EXISTS idx_correo_dest_lista
ON public.correo_lista_destinatarios(lista_id, activo, tipo_sugerido);

CREATE INDEX IF NOT EXISTS idx_correo_eventos_tipo_fecha
ON public.correo_eventos(event_type, event_timestamp);

CREATE UNIQUE INDEX IF NOT EXISTS idx_correo_pendiente_unique
ON public.correo_pendientes(registro_id, modulo_key);

CREATE INDEX IF NOT EXISTS idx_correo_pendiente_estado
ON public.correo_pendientes(estado, updated_at);

CREATE INDEX IF NOT EXISTS idx_correo_usuario_asig
ON public.correo_usuario_asignacion(usuario_id, activo);

-- Foreign keys (opcionalmente diferibles en etapas tempranas)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_correo_destinatarios_lista'
  ) THEN
    ALTER TABLE public.correo_lista_destinatarios
      ADD CONSTRAINT fk_correo_destinatarios_lista
      FOREIGN KEY (lista_id) REFERENCES public.correo_listas(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_correo_cfg_plantilla'
  ) THEN
    ALTER TABLE public.correo_configuracion
      ADD CONSTRAINT fk_correo_cfg_plantilla
      FOREIGN KEY (plantilla_id) REFERENCES public.correo_plantillas(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_correo_cfg_lista'
  ) THEN
    ALTER TABLE public.correo_configuracion
      ADD CONSTRAINT fk_correo_cfg_lista
      FOREIGN KEY (lista_id) REFERENCES public.correo_listas(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_correo_pendiente_cfg'
  ) THEN
    ALTER TABLE public.correo_pendientes
      ADD CONSTRAINT fk_correo_pendiente_cfg
      FOREIGN KEY (config_id) REFERENCES public.correo_configuracion(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_correo_asig_cfg'
  ) THEN
    ALTER TABLE public.correo_usuario_asignacion
      ADD CONSTRAINT fk_correo_asig_cfg
      FOREIGN KEY (config_id) REFERENCES public.correo_configuracion(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_correo_asig_lista'
  ) THEN
    ALTER TABLE public.correo_usuario_asignacion
      ADD CONSTRAINT fk_correo_asig_lista
      FOREIGN KEY (lista_id) REFERENCES public.correo_listas(id);
  END IF;
END $$;

-- Seed base del caso de prueba (Hidroser)
INSERT INTO public.correo_plantillas (
  id, nombre, asunto_template, cuerpo_template, modulo, empresa_id,
  variables_permitidas, activo, version, created_at, updated_at, updated_by
) VALUES (
  'tpl_hidroser_demo',
  'Lista de verificacion grua horquilla',
  'Lista de verificacion de grua horquilla patio fiordo austra - {{fecha_inspeccion}}',
  'Buenos dias / buenas tardes,\n\nSe adjunta la lista de verificacion correspondiente al registro realizado el dia {{fecha_inspeccion}} a las {{hora_inspeccion}}.\nRealizado por: {{supervisor_nombre}}\n\nSaludos cordiales,\n{{supervisor_nombre}}',
  'hidroser',
  NULL,
  'fecha_inspeccion,hora_inspeccion,supervisor_nombre',
  true,
  1,
  now(),
  now(),
  'manual_sql'
)
ON CONFLICT (id) DO UPDATE
SET
  nombre = EXCLUDED.nombre,
  asunto_template = EXCLUDED.asunto_template,
  cuerpo_template = EXCLUDED.cuerpo_template,
  modulo = EXCLUDED.modulo,
  empresa_id = EXCLUDED.empresa_id,
  variables_permitidas = EXCLUDED.variables_permitidas,
  activo = EXCLUDED.activo,
  version = EXCLUDED.version,
  updated_at = now(),
  updated_by = EXCLUDED.updated_by;

INSERT INTO public.correo_listas (
  id, nombre, proposito, activo, created_at, updated_at
) VALUES (
  'list_demo_hidroser',
  'Prueba Hidroser',
  'Destinatarios de prueba',
  true,
  now(),
  now()
)
ON CONFLICT (id) DO UPDATE
SET
  nombre = EXCLUDED.nombre,
  proposito = EXCLUDED.proposito,
  activo = EXCLUDED.activo,
  updated_at = now();

INSERT INTO public.correo_lista_destinatarios (
  id, lista_id, nombre, correo, tipo_sugerido, activo, created_at
) VALUES (
  'dest_demo_1',
  'list_demo_hidroser',
  'Matias',
  'matipro934@gmail.com',
  'to',
  true,
  now()
)
ON CONFLICT (id) DO UPDATE
SET
  lista_id = EXCLUDED.lista_id,
  nombre = EXCLUDED.nombre,
  correo = EXCLUDED.correo,
  tipo_sugerido = EXCLUDED.tipo_sugerido,
  activo = EXCLUDED.activo;

INSERT INTO public.correo_configuracion (
  id, empresa_id, modulo, plantilla_id, lista_id, prioridad, activo, created_at, updated_at
) VALUES (
  'cfg_demo_hidroser',
  NULL,
  'hidroser',
  'tpl_hidroser_demo',
  'list_demo_hidroser',
  0,
  true,
  now(),
  now()
)
ON CONFLICT (id) DO UPDATE
SET
  empresa_id = EXCLUDED.empresa_id,
  modulo = EXCLUDED.modulo,
  plantilla_id = EXCLUDED.plantilla_id,
  lista_id = EXCLUDED.lista_id,
  prioridad = EXCLUDED.prioridad,
  activo = EXCLUDED.activo,
  updated_at = now();

COMMIT;
