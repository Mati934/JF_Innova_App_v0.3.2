# Inspección Searov (buceo y embarcación)

> **Para qué es:** Ficha del módulo Inspección Searov (buceo y embarcación): qué hace hoy, reglas de negocio, tablas, pantallas y pendientes.

> Clave: `INSPECCION_SEAROV` · Estado: en desarrollo (demo, sin publicar) · Última revisión: 2026-10-29
> Empresas con el módulo (2026-10-29): Searov SpA (módulo, preguntas y 1 usuario ya en la base).
> Plan: [PLAN_DEMO_SEAROV.md](../planificacion/02_en_progreso/PLAN_DEMO_SEAROV.md).

## Qué hace

Módulo propio de **Searov SpA** (servicio de buceo). Hace inspección de **buceo**
y de **embarcaciones** con el mismo flujo que [Inspección](inspeccion-buceo-embarcacion.md)
(mismas pantallas), pero con las **preguntas** de Searov y un **PDF propio**.
En Inicio la tarjeta se llama igual ("Nueva Inspección"); la clave y el formato
son internos.

No usa el motor de checklists porque pide preguntas por buzo y PDF propio.

## Reglas de negocio

- Cada actividad creada desde este módulo guarda `formato_informe = 'SEAROV'`.
  `tipo_actividad` sigue siendo `INSPECCION_BUCEO` / `INSPECCION_EMBARCACION`:
  número de informe por empresa (Searov parte en 1), Historial y sync igual que Inspección.
- Preguntas: banco `INSPECCION_BUCEO_SEAROV` (68) e `INSPECCION_EMBARCACION_SEAROV` (75)
  en `formulario_items`. Si no hay preguntas Searov descargadas, usa las estándar.
- **Buceo, ítems por buzo** (`aplica_por_buzo`, 11 ítems de equipo personal):
  cada buzo agregado a la cuadrilla parte con todo en Cumple; el inspector marca
  lo que falla. La pregunta queda No cumple si algún buzo no cumple (observación
  "No cumple: nombres"). Sin buzos, queda N/A.
- **Embarcación, potencialidad** (`ALTA` / `MEDIA`, separada de la criticidad):
  1 incumplimiento ALTA o 6+ MEDIA → **Rechazada**; 1–5 MEDIA → **Autorizada
  condicional** (7 días); sin incumplimientos → **Faena autorizada**. El resultado
  se guarda en `estado_faena` y sale en el PDF.
- Buceo **no** tiene estado final de faena, verificaciones críticas IV–VIII ni
  registro fotográfico complementario (no están en el formato de Searov);
  sí mantiene "Observaciones generales", que salen en el PDF.
  Internamente la actividad sigue guardando `HABILITADA` / `SUSPENDIDA`
  (para tickets e Historial), calculado solo con los hallazgos Intolerables;
  no se muestra en el formulario ni en el PDF. Al finalizar solo avisa si queda suspendida.
- PDF: el checklist tiene la misma estructura que el PDF estándar de buceo
  (N°, pregunta con la observación en un recuadro debajo, fotos a la derecha,
  estado Cumple / No cumple / N/A), con bordes y colores de planilla Searov.
  Embarcación agrega la columna Potencialidad. Sin Inicial / Consecutiva.
  Las fotos de cada pregunta salen solo en el checklist (grandes); el
  registro fotográfico del final trae las fotos con observación y la galería
  general. Buceo muestra los compresores en una tabla (matrícula, vigencia,
  vigencia P.H., N° buzos a cargo). Firmas lado a lado: firma, línea y nombre.
- Usuario general por empresa: el formulario tiene la sección **Firmas** con
  quién realiza la inspección (obligatorio para finalizar) y quién recibe
  (buceo: jefe de centro, supervisor de buceo o rep. contratista), cada uno
  con firma en pizarra. Los nombres suben a Supabase; las firmas quedan en el
  dispositivo y salen en el PDF. El PDF usa ese nombre como Inspector.
- Configuración: no pregunta Inicial / Consecutiva (siempre Inicial).
- PDF sin logo de la empresa: escribe el nombre (no usa el logo de respaldo de AquaChile).
- El nombre del mandante del formato de barcos (Cermaq) no aparece en preguntas ni PDF.

## Datos

Mismas tablas que Inspección. Columnas propias (v63 / `supabase_migration_inspeccion_searov_module.sql`;
v64 / `supabase_migration_inspeccion_firmas_v1.sql`: `actividades.inspector_nombre`,
`recibe_nombre` y, solo local, `firma_inspector_path` / `firma_recibe_path`):
`actividades.formato_informe`, `formulario_items.potencialidad`,
`formulario_items.aplica_por_buzo`, `actividad_participantes.respuestas_personal`
(`{item_id: C|NC|N/A}`). Ver [esquema](../base-de-datos/esquema-por-modulo.md#inspección-de-buceo-y-embarcación-inspeccion).

## Pantallas

`InspectionSetupScreen(formato: SEAROV)` → `InspectionFormScreen` con la sección
"Checklist por buzo" (`ChecklistPorBuzoWidget`) y "Firmas" (`FirmasInspeccionWidget`).

## Archivos principales

- `lib/features/inspection/domain/formato_inspeccion.dart` (banco, consolidado por buzo, resultado por potencialidad)
- `lib/features/inspection/presentation/widgets/checklist_por_buzo_widget.dart`
- `lib/features/inspection/services/searov_pdf_service.dart` (PDF v0.3.0)
- Fuentes: `documentos_checklists/Hechos/` (PDF de Searov y xlsx de barcos)

## Pendientes

- Publicar la app (SQL ejecutado y usuario creado el 2026-10-29).
- Validar con el cliente: campos de encabezado faltantes (persona que recibe,
  N° de trabajadores, motivo), secciones de 20 y 36 m, máximo de buzos.
  "Tipo de faena" (interna / contratista) del formato original se descartó (2026-10-29).
- Ítems por buzo: sin selector de criticidad ni fotos (quedan Tolerable y no
  suspenden la faena ni suben la criticidad del ticket). Decidir con el cliente
  si algunos (ej. arnés, regulador) deben ser críticos.
- Si no hay preguntas Searov descargadas (ej. sin sincronizar), cae a las
  estándar y el resultado por potencialidad sale "Faena autorizada".
- La potencialidad no se muestra en la tarjeta de cada pregunta (solo en el PDF).

### Observación: dashboard (si algún día lo piden, 2026-10-29)

Los datos se pueden extraer sin problema. Notas para cuando se haga:

- Filtrar por **empresa Searov y `formato_informe = 'SEAROV'`**, no solo por
  formato: Servimaf tiene inspecciones de prueba con formato Searov.
  Finalizadas: `estado_final = 'En Seguimiento'`.
- Respuestas: `inspeccion_respuestas` + `formulario_items` (sección, pregunta,
  potencialidad). Por buzo: `actividad_participantes.respuestas_personal`
  (jsonb `{item_id: C|NC|N/A}`). Compresores, horas y observaciones:
  `verificaciones_buceo`. Fotos: `registro_fotografico`.
- `inspector_nombre` / `recibe_nombre` son texto libre: para un dashboard por
  inspector habría que normalizar o pasar a lista de personas.
- Criticidad (todo Tolerable) y `estado_faena` de buceo (casi siempre
  HABILITADA) no sirven como métrica; en embarcación `estado_faena` sí
  (resultado por potencialidad).
- Las firmas no están en Supabase (solo en el teléfono y en el PDF).
- Si cambian preguntas: desactivar (`activo = false`) y crear nuevas, no editar
  el texto, para no deformar el histórico.
- Idea: una vista `v_searov_respuestas` con los joins hechos.
