-- sqlite_migration_email_mvp.sql
-- Migración local (SQLite) para módulo de correo MVP.
-- NO usar en Supabase SQL Editor (PostgreSQL).
-- Para Supabase usar: supabase_migration_email_mvp.sql
-- Es idempotente: se puede ejecutar más de una vez.

BEGIN TRANSACTION;

CREATE TABLE IF NOT EXISTS correo_plantillas (
  id TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  asunto_template TEXT NOT NULL,
  cuerpo_template TEXT NOT NULL,
  modulo TEXT,
  empresa_id TEXT,
  variables_permitidas TEXT,
  activo INTEGER NOT NULL DEFAULT 1,
  version INTEGER NOT NULL DEFAULT 1,
  created_at TEXT,
  updated_at TEXT,
  updated_by TEXT
);

CREATE TABLE IF NOT EXISTS correo_listas (
  id TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  proposito TEXT,
  activo INTEGER NOT NULL DEFAULT 1,
  created_at TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS correo_lista_destinatarios (
  id TEXT PRIMARY KEY,
  lista_id TEXT NOT NULL,
  nombre TEXT,
  correo TEXT NOT NULL,
  tipo_sugerido TEXT NOT NULL DEFAULT 'to',
  activo INTEGER NOT NULL DEFAULT 1,
  created_at TEXT
);

CREATE TABLE IF NOT EXISTS correo_configuracion (
  id TEXT PRIMARY KEY,
  empresa_id TEXT,
  modulo TEXT NOT NULL,
  plantilla_id TEXT NOT NULL,
  lista_id TEXT NOT NULL,
  prioridad INTEGER NOT NULL DEFAULT 0,
  activo INTEGER NOT NULL DEFAULT 1,
  created_at TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS correo_eventos (
  id TEXT PRIMARY KEY,
  inspeccion_id TEXT,
  empresa_id TEXT,
  usuario_id TEXT,
  event_type TEXT NOT NULL,
  event_timestamp TEXT NOT NULL,
  resultado_evento TEXT NOT NULL,
  canal TEXT,
  template_id TEXT,
  template_version INTEGER,
  asunto_generado TEXT,
  adjunto_nombre TEXT,
  adjunto_tipo TEXT,
  error_code TEXT,
  error_message TEXT
);

CREATE TABLE IF NOT EXISTS correo_pendientes (
  id TEXT PRIMARY KEY,
  registro_id TEXT NOT NULL,
  modulo_key TEXT NOT NULL,
  empresa_id TEXT,
  usuario_id TEXT,
  config_id TEXT,
  lista_id TEXT,
  estado TEXT NOT NULL DEFAULT 'pendiente',
  payload_json TEXT,
  intentos INTEGER NOT NULL DEFAULT 0,
  ultimo_error TEXT,
  created_at TEXT,
  updated_at TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_correo_pendiente_unique
ON correo_pendientes(registro_id, modulo_key);

CREATE INDEX IF NOT EXISTS idx_correo_pendiente_estado
ON correo_pendientes(estado, updated_at);

CREATE TABLE IF NOT EXISTS correo_usuario_asignacion (
  id TEXT PRIMARY KEY,
  usuario_id TEXT NOT NULL,
  config_id TEXT,
  lista_id TEXT,
  activo INTEGER NOT NULL DEFAULT 1,
  created_at TEXT,
  updated_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_correo_usuario_asig
ON correo_usuario_asignacion(usuario_id, activo);

CREATE INDEX IF NOT EXISTS idx_correo_cfg_modulo
ON correo_configuracion(modulo, activo, prioridad);

CREATE INDEX IF NOT EXISTS idx_correo_dest_lista
ON correo_lista_destinatarios(lista_id, activo, tipo_sugerido);

CREATE INDEX IF NOT EXISTS idx_correo_eventos_tipo_fecha
ON correo_eventos(event_type, event_timestamp);

-- Seed base del caso de prueba (Hidroser)
INSERT OR REPLACE INTO correo_plantillas (
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
  1,
  1,
  datetime('now'),
  datetime('now'),
  'manual_sql'
);

INSERT OR REPLACE INTO correo_listas (
  id, nombre, proposito, activo, created_at, updated_at
) VALUES (
  'list_demo_hidroser',
  'Prueba Hidroser',
  'Destinatarios de prueba',
  1,
  datetime('now'),
  datetime('now')
);

INSERT OR REPLACE INTO correo_lista_destinatarios (
  id, lista_id, nombre, correo, tipo_sugerido, activo, created_at
) VALUES (
  'dest_demo_1',
  'list_demo_hidroser',
  'Matias',
  'matipro934@gmail.com',
  'to',
  1,
  datetime('now')
);

INSERT OR REPLACE INTO correo_configuracion (
  id, empresa_id, modulo, plantilla_id, lista_id, prioridad, activo, created_at, updated_at
) VALUES (
  'cfg_demo_hidroser',
  NULL,
  'hidroser',
  'tpl_hidroser_demo',
  'list_demo_hidroser',
  0,
  1,
  datetime('now'),
  datetime('now')
);

COMMIT;
