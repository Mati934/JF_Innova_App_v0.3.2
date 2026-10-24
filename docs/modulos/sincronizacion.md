# Sincronización offline

> Transversal · Última revisión: 2026-10-22

## Qué hace

Mantiene el teléfono y Supabase al día: **sube** lo creado offline y **baja**
maestros y catálogos. También genera tickets automáticos y PDFs diferidos.

## Qué hace `sincronizarTodo()` (en orden aproximado)

1. Sube actividades (inspecciones, bitácoras, formativas) con verificaciones,
   participantes, respuestas y fotos.
2. Sube visitas (R-003, R-004, vehículos, PROSESSO) con extintores y mantenciones.
3. Sube checklists configurables, Hidroser, Equipamiento de Buceo, AST y Merieux.
4. Sube eventos de correo.
5. Genera **tickets automáticos** desde inspecciones finalizadas.
6. Recupera números de informe faltantes y genera **PDFs diferidos**
   (inspecciones y formativas).

Además: `descargarDatosMaestros()` (maestros y catálogos), `sincronizarEmpresaModulos()`,
`hidratarContextoInicial()` y la pantalla de pendientes de sincronización.

## Reglas de negocio

- Una sola sincronización a la vez (`SyncExecutionGate`).
- Lo creado offline lleva `subido = 0`; tras subir, `subido = 1`.
- Borrados: soft delete local y borrado real en Supabase durante el sync.
- Antes del upsert se quitan columnas solo locales (`pdf_path_local`,
  `numero_informe`).
- Una tabla maestra que falla no detiene las demás; se informa y se registra en Crashlytics.
- El guardado de un formulario no espera al sync (para no colgar la app con mala señal).

## Pantallas

`SyncPendingScreen` (lista de lo pendiente por subir).

## Archivos principales

- `lib/features/sync/services/sync_service.dart`
- `lib/features/sync/services/sync_execution_gate.dart`
- `lib/core/services/connectivity_service.dart`

## Pendientes

- Ninguno conocido. Errores históricos: [ERRORES_PLAYBOOK_Y_HISTORIAL.md](../planificacion/02_en_progreso/ERRORES_PLAYBOOK_Y_HISTORIAL.md).
