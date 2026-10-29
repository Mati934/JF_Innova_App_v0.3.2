# JF Innova App

App Flutter de inspecciones y operaciones (buceo, embarcaciones, extintores, AST, checklists) para Android, web e iOS.
Offline-first: SQLite local + Supabase (auth y backend). Firebase solo para Crashlytics.

Reglas generales del proyecto (alcance de cambios, Supabase solo lectura, versionado de PDFs, delegación, Ponytail, graphify):
**leer `.github/copilot-instructions.md`**; aplican igual a Claude. Contexto de negocio y planes: `docs/planificacion/` (ver su `README.md`).

## Documentación (obligatorio)

- Qué hace la app hoy: `docs/README.md` (índice de módulos, base de datos, checklists, decisiones, changelog).
- **Antes de trabajar en un módulo**, leer su ficha en `docs/modulos/`.
- Códigos, claves de módulo, estados y empresas se traducen en `docs/glosario.md`. Un estado o código nuevo
  usa el mismo valor en Supabase (check/enum), en el código y en el glosario.
- Antes de afirmar que algo está desalineado, duplicado o sin uso, verificar qué columna lo usa realmente
  (tipo, checks, grep en código, filas). Que exista un enum, tabla o script no prueba que se use.
- Servimaf es la empresa propia (tiene todos los módulos); no deducir el uso de un cliente a partir de Servimaf.
- Checklists nuevos o cambios de preguntas: skill `nuevo-checklist`. Módulos nuevos: skill `nuevo-modulo`
  (primero decide si basta con un checklist del motor). Scripts SQL de Supabase: skill `migracion-supabase`.
- **Antes de dar por cerrado cualquier cambio en `lib/`, `test/` o SQL**: lanzar el agente `revisor-cambios`
  (sin preguntar) y corregir o reportar sus hallazgos. No hace falta para cambios solo de docs o config de Claude.
- Errores reportados ("no sale…", "falla…", "me comentaron que…"): skill `diagnosticar-error` (diagnóstico y plan antes de arreglar).
- Herramientas Dart/Flutter (analizar, tests, pub): MCP `dart`. Un hook formatea con `dart format` cada `.dart` editado.
- **Al terminar cualquier tarea que cambie funcionalidades, la base de datos (SQLite o Supabase) o los checklists**,
  usar la skill `documentar-app` antes de dar la tarea por terminada.

## Stack

- Flutter / Dart (`sdk: ^3.10.4`), versión de la app en `pubspec.yaml` (`version:` + comentarios con fecha de cada release).
- SQLite con `sqflite` (`sqflite_common_ffi` en tests). Supabase con `supabase_flutter`.
- Sin Provider ni estado global: cada screen crea y dispone su propio Controller (`ChangeNotifier`).
- Sesión del usuario y empresa activa: `UserSession` singleton (`lib/core/services/user_session.dart`).

## Estructura

- `lib/core/`: `database/` (`DatabaseHelper` singleton, esquema y migraciones), `modules/` (`ModuleRegistry`), `services/`, `utils/` (`rut_utils.dart`), `config/`, `errors/`, `theme/`.
- `lib/features/<módulo>/` con `data/`, `domain/`, `presentation/`, `services/` según el módulo:
  - `inspection` (buceo y embarcación), `visits` (R-003), `extintores` (R-004), `prosesso` (mantención extintores), `merieux`, `hidroser`, `ast`, `formative_activities`, `buceo_equipment`, `configurable_checklists`, `cronograma`, `email`, `tickets`.
  - `admin` (CRUD de maestros + módulos por empresa), `history` (historial, solo online), `home`, `auth`, `sync` (`SyncService`).
- `lib/shared/widgets/`: widgets reutilizables (ej. `CustomFilterSheet`).
- `test/`: tests planos por funcionalidad (`<tema>_test.dart`), helpers en `test/helpers/`.
- Raíz: scripts `supabase_*.sql` (migraciones, fixes, diagnósticos). Un script en el repo NO prueba que esté aplicado en la base real.

## Comandos

```bash
flutter pub get
flutter run                                    # dispositivo/emulador conectado
flutter run -d chrome                          # web
flutter analyze                                # obligatorio antes de cerrar un cambio Dart
flutter test test/<archivo>_test.dart          # test dirigido primero
flutter test                                   # suite completa si el cambio es amplio
flutter build apk --target-platform android-arm64
```

iOS se compila, firma y valida en Mac (`docs/IOS_HANDOFF_MAC_CHECKLIST.md`).

## Convenciones

- Buscar el módulo vecino más parecido y copiar su patrón antes de crear algo nuevo.
- Controllers async: flag `_disposed` + `_safeNotify()` para no notificar tras `dispose`.
- Versión de la DB local: `_dbVersion` en `lib/core/database/database_helper.dart`. Toda migración nueva va en `onUpgrade` con `if (oldVersion < N)` y columnas con `_safeAddColumn`. Subir `_dbVersion`.
- Registros creados/editados offline llevan `subido = 0`; `SyncService` los sube y marca `subido = 1`.
- Soft delete: `eliminado = 1, subido = 0` → el sync hace el delete real en Supabase.
- `guardarMaestros` (DatabaseHelper): nunca con lista vacía; en tablas filtradas por empresa pasar `scopeWhere`/`scopeArgs`, si no borra datos de otras empresas.
- RUT: se guarda normalizado (sin puntos ni guion, minúsculas) en SQLite y Supabase. Usar `rut_utils.dart` (`normalize`, `isValid`, `format`, `RutInputFormatter`).
- Módulos de la pantalla de inicio: se registran en `ModuleRegistry` y se habilitan por empresa en la tabla `empresa_modulos`.
- Código muerto conocido: `BatchDraftController`, `MasterDataBatchService`, `DependencyGraph` (sistema batch viejo del admin). No extenderlo.
- No abrir ni imprimir archivos de claves (ej. `service_role_api_key`, gitignored).

## Trampas de negocio (no repetir)

### Dos escalas de criticidad
- Inspecciones y visitas: `Tolerable / Moderado / Intolerable`.
- Tickets: `Bajo / Medio / Alto / Intolerable`.
- Equivalencia: Tolerable↔Bajo, Moderado↔Medio, Intolerable↔Alto/Intolerable.
- En 2026-03 `formulario_items` usaba la escala de Tickets y el dropdown lo convertía todo a "Tolerable". Ya está corregido,
  pero `inspeccion_respuestas.criticidad_registrada` anterior a 2026-03-29 quedó todo en "Tolerable" y no se puede recuperar: no usarlo en métricas.
- Backlog: `docs/planificacion/03_por_realizar/CRITICIDAD_BACKLOG.md`.

### numero_informe y PDFs
- El número lo asigna el trigger de Supabase `trg_asignar_numero_informe`, solo al pasar a "En Seguimiento".
  Los borradores tienen `numero_informe = NULL`.
- Desde 2026-10-29 todo número/correlativo de informe (todos los módulos) es por empresa y tipo, en `numeradores_informe`
  (`next_numero_informe`); un número nunca se reutiliza. Las secuencias `seq_inf_*` y los contadores viejos son solo respaldo.
  Detalle: `docs/decisiones/numeracion-por-empresa.md`.
- El PDF solo se genera con número real. Si se finaliza offline, `_generarPdfsDiferidos()` (llama a `DeferredPdfService`) lo genera al final de `sincronizarTodo()`.
- No volver a crear números provisorios `PROV-*`; el código solo filtra registros antiguos con ese prefijo.
- Cada generador PDF tiene versión propia: todo cambio de contenido o diseño sube su patch (ver copilot-instructions).

### Sync
- Antes de hacer upsert a Supabase, quitar las columnas solo locales: `pdf_path_local` (si no, error PGRST204) y `numero_informe` (lo pone el trigger).
- `descargarDatosMaestros()` descarga cada tabla por separado con try/catch + Crashlytics y retorna la lista de tablas que fallaron.

### Multiempresa
- Un usuario puede tener varias empresas (`usuario_empresas`); `usuarios.empresa_id` es legacy y sirve de respaldo.
- `actividades_pendientes.empresa_id` existe desde v61, pero solo lo llenan las actividades formativas: las inspecciones lo dejan NULL.
  `visitas_tecnicas_pendientes` no tiene `empresa_id`. Para esas, filtrar con JOIN a `usuarios`.
- Las áreas se descargan todas; el filtro por empresa es N:N con `empresa_areas` (`getAreasByEmpresa`). Si devuelve vacío, se usa `getAreas()`.
- Contratistas y embarcaciones son compartidos entre empresas (no tienen `empresa_id`).
- La HomeScreen muestra la empresa fija, sin selector (decisión del usuario).

### Supabase
- Antes de tocar persistencia, sync o correlativos, revisar el objeto real en Supabase (solo lectura). Nunca escribir, migrar ni ejecutar DDL sin autorización explícita.
