# Plantilla Base — Creación de Módulos de Inspección

Fecha: 2026-06-26
Estado: Plantilla reutilizable (alineada al código actual)

> Esta plantilla describe el **patrón de "módulo independiente"** usado por
> los módulos `Hidroser`, `AST` y `Equipamiento de Buceo`. Cada módulo tiene
> **sus propias tablas** (local + Supabase), su propio repositorio, su
> controlador, su servicio de PDF y su rama de sincronización. No se reutilizan
> tablas de otros módulos.

---

## 0) Implementaciones de referencia (copiar de aquí)

Cuando crees un módulo nuevo, abre estos archivos y clónalos cambiando el
prefijo del módulo. El más reciente y limpio es **Equipamiento de Buceo**.

| Capa | Archivo de referencia (Equipamiento de Buceo) |
| --- | --- |
| Migración SQL | `supabase_migration_buceo_equipamiento_module.sql` |
| Esquema local | `lib/core/database/database_helper.dart` (parche v50 + `_repairCriticalSchema`) |
| Modelo | `lib/features/buceo_equipment/domain/models/buceo_equipment_inspeccion.dart` |
| Repositorio local | `lib/features/buceo_equipment/data/repositories/local_buceo_equipment_repository.dart` |
| Controlador form | `lib/features/buceo_equipment/presentation/controllers/buceo_equipment_form_controller.dart` |
| Pantalla módulo | `lib/features/buceo_equipment/presentation/screens/buceo_equipment_module_screen.dart` |
| Servicio PDF | `lib/features/buceo_equipment/services/buceo_equipment_pdf_service.dart` |
| Registro módulo | `lib/core/modules/module_registry.dart` |
| Sync (subida) | `lib/features/sync/services/sync_service.dart` → `_sincronizarBuceoEquipamiento()` |
| Borradores | `lib/features/home/domain/draft_card_mapper.dart`, `home_controller.dart`, `draft_list_widget.dart` |

---

## 1) Definición del módulo (rellenar antes de programar)

1. Nombre visible del módulo:
2. **Código del módulo** (`moduleKey`, MAYÚSCULAS, ej. `BUCEO_EQUIPAMIENTO`):
3. Prefijo técnico de tablas (ej. `buceo_equipamiento`):
4. Empresas habilitadas (todas / por nombre / por configuración):
5. ¿Necesita variantes/listas? (ej. SAL / SAM):
6. Entregables (PDF, fotos por pregunta, firmas, correlativo):
7. Formato de correlativo (ej. `BUCEO-EQ-AAAA-NNNN`):

## 2) Alcance funcional

1. Incluye (v1):
2. No incluye (v1):
3. Riesgos / dependencias:

---

## 3) Base de datos

> Regla de oro: el **nombre de cada columna debe coincidir** entre la tabla
> local `_pendientes` (SQLite) y la tabla remota de Supabase, para que el sync
> sea un `upsert` directo. Lo único local-only son: `firma_*_image` (BLOB),
> `pdf_path_local`, `subido`, `eliminado`.

### 3.1 Modelo de datos estándar

Cuatro tablas por módulo:

1. `<prefijo>_listas` — catálogo de listas/variantes (descargado, solo lectura).
2. `<prefijo>_items` — preguntas del checklist por lista (descargado, solo lectura).
3. `<prefijo>_inspecciones` — cabecera del informe.
4. `<prefijo>_respuestas` — una fila por ítem respondido.

### 3.2 SQLite local (`lib/core/database/database_helper.dart`)

Pasos obligatorios (todos, en orden):

1. **Subir `_dbVersion`** en una unidad (constante al inicio de la clase).
2. Crear las 4 tablas en **`_createDB`** (instalaciones nuevas).
3. Crear las 4 tablas en un bloque nuevo **`if (oldVersion < N)`** dentro de
   **`_onUpgrade`** (usuarios que actualizan) con `CREATE TABLE IF NOT EXISTS`.
4. Añadir las tablas también en **`_repairCriticalSchema`** con
   `CREATE TABLE IF NOT EXISTS` (resiliencia si un upgrade se interrumpió).
5. Añadir helpers `guardar<Modulo>ListasOffline` / `guardar<Modulo>ItemsOffline`
   y `get<Modulo>ListasActivas` (se usan desde el sync).

Esquema local de la cabecera (ajusta solo los campos de negocio):

```sql
CREATE TABLE <prefijo>_inspecciones_pendientes (
  id TEXT PRIMARY KEY,                 -- UUID generado en el cliente
  usuario_id TEXT,
  empresa_id TEXT,
  lista_codigo TEXT NOT NULL,
  fecha_realizacion TEXT,
  correlativo TEXT,                    -- lo asigna el trigger de Supabase
  quien_inspecciona TEXT,
  observaciones TEXT,
  campos_extra TEXT,                   -- JSON serializado (jsonb en Supabase)
  firma_supervisor_nombre TEXT,
  firma_operador_nombre TEXT,
  firma_supervisor_image BLOB,         -- local-only (no sube)
  firma_operador_image BLOB,           -- local-only (no sube)
  estado_final TEXT NOT NULL DEFAULT 'Borrador',
  pdf_url TEXT,
  pdf_path_local TEXT,                 -- local-only
  subido INTEGER NOT NULL DEFAULT 0,   -- local-only
  eliminado INTEGER NOT NULL DEFAULT 0,-- local-only (borrado zombie)
  created_at TEXT
);

CREATE TABLE <prefijo>_respuestas_pendientes (
  id TEXT PRIMARY KEY,
  inspeccion_id TEXT NOT NULL,
  item_id TEXT NOT NULL,
  estado TEXT,                         -- 'C' | 'NC' | 'NA'
  observacion TEXT,
  criticidad TEXT,
  foto_path TEXT,
  subido INTEGER NOT NULL DEFAULT 0
);
```

### 3.3 Supabase remoto (`supabase_migration_<modulo>_module.sql`)

Un único archivo idempotente envuelto en `BEGIN; ... COMMIT;`. Secciones:

- **A) Tablas** (`_listas`, `_items`, `_inspecciones`, `_respuestas`) con PK
  `UUID`, FKs a `usuarios` / `empresas` y entre sí, `campos_extra JSONB`,
  `created_at/updated_at timestamptz default now()`.
- **B) Correlativo propio**: `CREATE SEQUENCE seq_<modulo>_correlativo` +
  función `fn_<modulo>_set_correlativo()` + trigger `BEFORE INSERT OR UPDATE`.
  Solo asigna correlativo cuando `estado_final = 'En Seguimiento'`.
- **C) Seed** de catálogo (`_listas` con `ON CONFLICT (codigo) DO UPDATE`,
  `_items` con `ON CONFLICT (lista_codigo, pregunta) DO UPDATE`).
- **D) Habilitar el módulo** en `empresa_modulos` (ver §4). Para TODAS las
  empresas: `INSERT ... SELECT FROM empresas ON CONFLICT (empresa_id, modulo_key) DO UPDATE`.
- **D.2) RLS**: catálogo `SELECT` para `authenticated`; inspecciones y
  respuestas restringidas al dueño (`usuario_id = auth.uid()`).
- **E) Historial unificado**: `DROP VIEW ... ; CREATE VIEW public.historial_unificado AS ...`
  con TODAS las ramas existentes + la rama nueva del módulo, y
  `GRANT SELECT ... TO anon, authenticated` (ver §8).

Trigger de correlativo (plantilla):

```sql
CREATE OR REPLACE FUNCTION public.fn_<modulo>_set_correlativo()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_next BIGINT;
BEGIN
  IF NEW.estado_final = 'En Seguimiento'
     AND (NEW.correlativo IS NULL OR NEW.correlativo = '') THEN
    v_next := nextval('public.seq_<modulo>_correlativo');
    NEW.correlativo := format('<PREFIJO>-%s-%s',
      to_char(COALESCE(NEW.fecha_realizacion, now()), 'YYYY'),
      lpad(v_next::text, 4, '0'));
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END; $$;
```

---

## 4) Registrar y habilitar el módulo

1. **`lib/core/modules/module_registry.dart`**: agregar un `ModuleDefinition`
   en `_all` con `moduleKey`, `title`, `subtitle`, `icon`, `color` y
   `screenBuilder`. Usar `requiresAdmin: true` solo para módulos de admin.
2. La **visibilidad la decide `empresa_modulos`**, NO el código.
   - `home_controller.enabledModules` filtra `ModuleRegistry.all`:
     `requiresAdmin → UserSession().esSuperAdmin`; el resto →
     `_enabledModuleKeys.contains(moduleKey)` (cargado desde
     `getModulosHabilitados(empresaId)`).
   - **No hardcodear** comprobaciones por nombre de empresa (ej. "JF Innova")
     en la UI. La fuente de verdad es `empresa_modulos`.
3. La migración SQL (§3.3 D) habilita el módulo por empresa.

Ejemplo real (`ModuleDefinition`):

```dart
ModuleDefinition(
  moduleKey: 'BUCEO_EQUIPAMIENTO',
  title: 'Eq. Buceo',
  subtitle: 'SAL / SAM',
  icon: Icons.scuba_diving,
  color: const Color(0xFF005B8A),
  screenBuilder: (_) => const BuceoEquipmentModuleScreen(),
),
```

---

## 5) Capa Dart (modelo, repositorio, controlador)

### 5.1 Modelo (`domain/models/<modulo>_inspeccion.dart`)

- Clase `<Modulo>Inspeccion` (cabecera) + `<Modulo>Respuesta` (con `toMap()`).
- `camposExtra` como `Map<String, String>`.
- Firmas como `Uint8List?`.

### 5.2 Repositorio local (`data/repositories/local_<modulo>_repository.dart`)

Métodos estándar (clonar del repo de buceo):

1. `getItemsForLista(String listaCodigo)` → lee `<prefijo>_items` por
   `lista_codigo AND activo = 1`, `ORDER BY orden ASC`.
2. `guardarInspeccion(insp, respuestas)` → en **una transacción**: `insert`
   cabecera (`ConflictAlgorithm.replace`) + `delete` respuestas previas +
   `insert` respuestas con `subido: 0`.
3. `getBorradores()` → `where: 'eliminado = 0 AND estado_final = ?'`,
   `['Borrador']`, `ORDER BY created_at DESC`.
4. `getInspeccionConRespuestasById(id)` → cabecera + clave `respuestas`.
5. `setPdfPathLocal(id, path)` → marca `pdf_path_local` y `subido = 0`.
6. `eliminarBorrador(id)` / `softDelete(id)` → `eliminado = 1, subido = 0`.

### 5.3 Controlador (`presentation/controllers/<modulo>_form_controller.dart`)

1. Inyectar `LocalRepo` y `SyncService` (con defaults para producción).
2. `init()`: cargar items con `getItemsForLista(variant.codigo)`; **fallback
   hardcodeado** si el catálogo local viene vacío (offline antes del 1er sync).
3. `_buildInspeccionModel({estadoFinal})`: arma cabecera + `campos_extra`.
4. `guardarBorradorSilencioso()`: `estadoFinal: 'Borrador'`.
5. `guardarDefinitivo()`: `estadoFinal: 'En Seguimiento'` (dispara correlativo),
   genera PDF, guarda `pdf_path_local`, llama `_sync.sincronizarTodo()`.

---

## 6) PDF (`services/<modulo>_pdf_service.dart`)

1. Servicio dedicado que recibe un `<Modulo>PdfData`.
2. Incluir logo de empresa (`EmpresaLogoService`), encabezado, checklist,
   fotos por pregunta y firmas.
3. Guardar PDF en `getApplicationDocumentsDirectory()` y registrar
   `pdf_path_local` para que el sync lo suba.
4. Nombre de archivo: `<Modulo>_<correlativo|id8>.pdf`.

---

## 7) Sincronización (`lib/features/sync/services/sync_service.dart`)

### 7.1 Descarga de maestros (catálogo)

En `descargarDatosMaestros` (o equivalente): agregar dos `descargarTabla`
nuevos (`<prefijo>_listas`, `<prefijo>_items`) al final del `Future.wait`,
respetando los índices, y luego guardarlos con
`guardar<Modulo>ListasOffline` / `guardar<Modulo>ItemsOffline`.

### 7.2 Subida (`_sincronizar<Modulo>()`)

Clonar `_sincronizarBuceoEquipamiento()`. Pasos:

1. `query('<prefijo>_inspecciones_pendientes', where: 'subido = 0')`.
2. **Borrado zombie**: si `eliminado == 1` → `update estado_final = 'Eliminada'`
   en Supabase y `delete` local de cabecera + respuestas; `continue`.
3. **Sanitizar** antes de subir: `remove('subido')`, `remove('eliminado')`,
   `remove('firma_supervisor_image')`, `remove('firma_operador_image')`,
   `remove('pdf_path_local')`, `remove('correlativo')` (lo asigna el trigger).
4. `campos_extra`: si es `String`, `jsonDecode` (en Supabase es `jsonb`).
5. Asegurar `usuario_id` (usar `auth.currentUser?.id` si falta).
6. `upsert(datosNube, onConflict: 'id').select('correlativo').maybeSingle()` y
   guardar el correlativo devuelto en local.
7. Subir respuestas (`upsert onConflict 'id'`, marcar `subido = 1`).
8. Subir PDF al bucket **`pdfs_visitas`**, path `<id>/<Modulo>_<id>.pdf`;
   guardar `pdf_url`.
9. Marcar la cabecera `subido = 1` solo si no quedó PDF pendiente.

### 7.3 Enganchar al flujo

- Llamar `_sincronizar<Modulo>()` dentro de `sincronizarTodo()`.
- Sumar el resultado a `totalSubidas`.

Reglas clave: sync **idempotente** (`upsert onConflict 'id'`); el correlativo
solo lo asigna Supabase; nunca subir BLOBs ni campos local-only.

---

## 8) Historial unificado (`historial_unificado`)

Cada módulo agrega una **rama `UNION ALL`** a la vista. Patrón de columnas:
`id, modulo, tipo_registro, estado, ubicacion, fecha_realizacion,
numero_reporte, pdf_url, pdf_certificado_url, inspector_nombre,
numero_seguimiento, usuario_id, centro_id, embarcacion_id`.

- Filtrar `WHERE estado_final NOT IN ('Eliminada', 'En Progreso')`.
- Si el módulo se separó de otro (como buceo de Hidroser), **excluir** sus
  códigos en la rama del módulo padre para evitar duplicados.
- La vista corre con privilegios del owner (RLS de las tablas base no aplica);
  el filtro por usuario lo hace `SupabaseHistoryRepository` en la app.

---

## 9) Borradores en Home

1. **`draft_card_data.dart`**: agregar valor al enum `DraftKind` y su título.
2. **`draft_card_mapper.dart`**: método `from<Modulo>(raw)` que mapea la fila
   de `<prefijo>_inspecciones_pendientes` a `DraftCardData`.
3. **`home_controller.dart`**:
   - Crear `_<modulo>Repo`.
   - Agregar `_<modulo>Repo.getBorradores()` al `Future.wait` de
     `cargarBorradores` y mapear con `from<Modulo>`.
   - Agregar el `case DraftKind.<modulo>` en `eliminarBorrador`.
4. **`draft_list_widget.dart`**: agregar el `case DraftKind.<modulo>` en
   `_abrirBorrador` que reabre el formulario con
   `getInspeccionConRespuestasById` del repo del módulo.

---

## 10) Seguridad y permisos (OWASP)

1. Validar autenticación antes de crear/editar (`UserSession`).
2. Setear `usuario_id` y `empresa_id` desde la sesión, no desde input.
3. RLS en Supabase: catálogo legible por `authenticated`; inspecciones y
   respuestas solo del dueño (`usuario_id = auth.uid()`).
4. Visibilidad del módulo por `empresa_modulos` (sin hardcodear empresas).

---

## 11) Pruebas

1. Modelo + mapper (`from<Modulo>`).
2. Repositorio local (guardar / borradores / reabrir) con `sqflite_common_ffi`.
3. Upgrade de esquema: usar `test/upgrade_data_integrity_test.dart` como guía.
4. Generación de PDF.
5. Flujo de sync (subida OK y borrado zombie).

Comandos:

```pwsh
flutter analyze
flutter test test/<modulo>_test.dart
```

---

## 12) Definición de Terminado (DoD)

1. `_dbVersion` subido; tablas en `_createDB`, `_onUpgrade` y `_repairCriticalSchema`.
2. Migración SQL idempotente lista (tablas + trigger + seed + RLS + historial + empresa_modulos).
3. Modelo, repositorio, controlador, pantalla y servicio PDF creados.
4. Módulo registrado en `module_registry` y visible por `empresa_modulos`.
5. Sync: descarga de catálogo + `_sincronizar<Modulo>()` enganchado.
6. Borradores: mapper + home_controller + draft_list_widget actualizados.
7. Rama agregada a `historial_unificado`.
8. `flutter analyze` limpio y pruebas mínimas en verde.

---

## 13) Orden de ejecución recomendado

1. Definir §1 y §2.
2. Escribir la migración SQL (§3.3) — pero **no ejecutarla todavía**.
3. Esquema local + helpers (§3.2).
4. Modelo y repositorio (§5.1, §5.2).
5. Controlador + pantalla + PDF (§5.3, §6).
6. Registro del módulo (§4).
7. Sync: descarga + subida (§7).
8. Borradores e historial (§8, §9).
9. `flutter analyze` + pruebas (§11).
10. **Recién ahora** ejecutar la migración SQL en Supabase (la app ya escribe,
    lee y sincroniza contra las tablas nuevas).

> Lección del refactor de Equipamiento de Buceo: dejar la app cableada a las
> tablas nuevas **antes** de correr el SQL evita tablas huérfanas y permite
> ejecutar la migración "sin preocupaciones".

---

## 14) Checklist rápido (copiar y marcar)

```text
[ ] moduleKey y prefijo definidos
[ ] _dbVersion subido + tablas en _createDB / _onUpgrade / _repairCriticalSchema
[ ] helpers guardar/ get catálogo offline
[ ] Migración SQL (tablas, trigger correlativo, seed, RLS, historial, empresa_modulos)
[ ] Modelo (Inspeccion + Respuesta)
[ ] Repositorio local (items, guardar, borradores, reabrir, eliminar)
[ ] Controlador (init+fallback, borrador, definitivo)
[ ] Pantalla del módulo + servicio PDF
[ ] ModuleDefinition en module_registry
[ ] Sync: descarga catálogo + _sincronizar<Modulo>() en sincronizarTodo
[ ] DraftKind + from<Modulo> + home_controller + draft_list_widget
[ ] Rama en historial_unificado
[ ] flutter analyze limpio + pruebas
[ ] Ejecutar migración SQL en Supabase (al final)
```
