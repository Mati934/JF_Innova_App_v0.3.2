---
name: migracion-supabase
description: Crea scripts SQL para Supabase de JF Innova App (migraciones de esquema, fixes de datos, seeds, cambios de RLS/permisos, triggers o correlativos) con chequeo previo de solo lectura, bloque transaccional reejecutable y verificación, sin ejecutar escrituras sin OK explícito. Usar cuando haya que crear o cambiar tablas, columnas, índices, funciones, triggers, políticas RLS, permisos o datos en Supabase, o el usuario diga "migración", "script SQL", "arregla los datos de…", "agrega la columna…". Para checklists del motor usar nuevo-checklist.
---

# Migración Supabase

Reglas de base: `.github/copilot-instructions.md` y
`.github/instructions/sql.instructions.md` (aplican igual a Claude).
Supabase real **manda sobre el repo**: un `supabase_*.sql` en la raíz no prueba
que esté aplicado.

## Paso 1: inspeccionar la base real (solo lectura)

Con el MCP `supabase` (solo lectura), antes de escribir una línea:

- Tablas y columnas afectadas: tipo, `udt_name`, nulos, defaults (`information_schema.columns`).
- Restricciones e índices (`pg_get_constraintdef`, `pg_indexes`), checks y enums.
- Triggers (`pg_trigger`, no solo `information_schema.triggers`) y funciones que tocan la tabla (`pg_get_functiondef`).
- Políticas RLS (`pg_policies`) y funciones de permiso usadas (`is_admin_user`, `user_has_empresa`, etc.).
- Cuántas filas se verán afectadas.

No invocar RPC ni funciones de negocio, `nextval` ni `setval` para inspeccionar.

## Paso 2: revisar el impacto en la app

- SQLite: ¿la tabla tiene espejo local? Si cambia una columna que sube o baja el
  sync, hay que tocar `database_helper.dart` (`_dbVersion`, `onUpgrade` con
  `if (oldVersion < N)` y `_safeAddColumn`) y `sync_service.dart`.
- Columnas solo locales (`pdf_path_local`, `numero_informe`) no van a Supabase.
- Correlativos: los asigna Supabase (`trg_asignar_numero_informe`, secuencias);
  nunca reiniciar secuencias sin autorización.
- `guardarMaestros`: nunca con lista vacía; en tablas por empresa, usar `scopeWhere`.
- RLS: un cambio de política puede ocultar datos a usuarios de terreno (ver el
  caso de permisos por rol en `docs/decisiones/permisos-checklists-por-rol.md`).
- Valores de estados y códigos: iguales en el check/enum, en el código y en `docs/glosario.md`.

## Paso 3: escribir el script

Nombre en la raíz según su tipo:

| Tipo | Archivo |
|---|---|
| Cambio de esquema | `supabase_migration_<tema>_v<N>.sql` |
| Corrección de datos o permisos | `supabase_fix_<tema>_v<N>.sql` |
| Datos iniciales | `supabase_seed_<tema>_v<N>.sql` |
| Solo lectura (diagnóstico) | `supabase_check_<tema>.sql` o `supabase_diagnostico_<tema>.sql` |

Estructura obligatoria (salvo diagnóstico, que es solo la sección 0):

```sql
-- =============================================================================
-- <TITULO>  ·  <fecha AAAA-MM-DD>
-- Que hace y por que (2-4 lineas). Ejecutar MANUALMENTE.
-- Reejecutable: <si/no y como>.
-- Pasos: 0 (solo lectura) -> 1 (BEGIN..COMMIT) -> 2 (verificar).
-- =============================================================================

-- 0. SOLO LECTURA: estado actual y "esperado" de cada consulta.

-- 1. CAMBIO
BEGIN;
-- Guardas DO $$ ... RAISE EXCEPTION 'CODIGO: explicacion' ... $$ si el estado
-- no es el esperado (asi un error revierte todo).
-- DDL con IF NOT EXISTS / CREATE OR REPLACE; datos con ON CONFLICT o WHERE
-- que hagan el script reejecutable.
COMMIT;

-- 2. SOLO LECTURA: verificar el resultado con "esperado".
```

Reglas:

- Idempotente siempre que sea posible.
- Nada destructivo sin necesidad (preferir soft delete, desactivar, renombrar).
  Un `DELETE`/`DROP` debe tener guarda y estar justificado en el encabezado.
- Una tabla nueva lleva RLS habilitado y sus políticas en el mismo script.
- Sin claves, tokens, RUT ni datos personales en el script.
- Verificar sintaxis con un parser antes de entregar si está disponible (ej.
  `pglast` en un venv del scratchpad).

## Paso 4: ejecutar

1. Ejecutar la sección 0 con el MCP de solo lectura y comparar con lo esperado.
2. El bloque `BEGIN…COMMIT` escribe en producción: mostrar qué cambia, cuántas
   filas y el riesgo, y pedir **OK explícito**. Con OK, ejecutarlo con
   `supabase-write` (o el usuario lo pega en el SQL Editor).
3. Ejecutar la sección 2.

## Paso 5: cerrar

- Si cambió Dart: `flutter analyze` y tests dirigidos (incluido `upgrade_data_integrity_test.dart` si cambió SQLite).
- Para cambios de sync, RLS o datos: ofrecer el agente `revisor-cambios`.
- Documentar con `documentar-app` (esquema, glosario, decisiones, CHANGELOG).
