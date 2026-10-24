# Inspección de Buceo y Embarcación

> Clave: `INSPECCION` · Estado: en producción · Última revisión: 2026-10-22
> Empresas con el módulo (2026-10-22): AquaChile, JF Innova, Servimaf.

## Qué hace

Es el módulo original de la app. El prevencionista inspecciona una **faena de
buceo** o una **embarcación** de un contratista en un centro de cultivo,
responde el checklist (Cumple / No cumple / No aplica), registra la cuadrilla,
verificaciones críticas y fotos, y genera el **informe técnico PDF** con número
de informe oficial. Los "No cumple" alimentan el módulo de [Tickets](tickets.md).

## Reglas de negocio

- **Configuración inicial**: área y centro siempre obligatorios. Se indica si el
  puerto está **ABIERTO** o **CERRADO**.
  - Puerto abierto, o cerrado con actividad `PRE_INSPECCION` → inspección completa:
    exige tipo (`INSPECCION_BUCEO` / `INSPECCION_EMBARCACION`) y contratista.
  - Puerto cerrado con otra actividad → se registra solo como **BITACORA**.
- **Buceo**: exige al menos **1 participante** en la cuadrilla para finalizar
  (confirmado 2026-10-22). Registra nivel de buceo (`Superficie, Basico,
  Intermedio, Avanzado`), profundidad máxima, compresores y supervisor.
- **Faena habilitada**: lo está si el estado manual es "APROBADO" o si se cumplen
  todos los checks críticos (autorización autoridad marítima, inducción del
  centro, permiso de buceo del centro, plan de contingencias, exámenes
  ocupacionales vigentes). Hay fotos obligatorias de buceo por "slot".
- **NC** exige observación; se registra criticidad (`Tolerable / Moderado / Intolerable`).
- **Número de informe**: lo asigna Supabase al pasar a `En Seguimiento`
  (secuencias `seq_inf_buceo`, `seq_inf_embarcacion`). Sin número no hay PDF:
  si se finaliza offline, el PDF se genera en el siguiente sync.
- **Informe de seguimiento**: una actividad puede referir a otra
  (`actividad_origen_id`) como seguimiento/consecutiva.
- Las inspecciones finalizadas **con embarcación** generan hallazgos y tickets
  automáticos (desde el corte 2026-08-31).

## Datos

`actividades`, `verificaciones_buceo`, `verificaciones_embarcacion`,
`actividad_participantes`, `inspeccion_respuestas`, `registro_fotografico`,
`formulario_items` (tipos `INSPECCION_BUCEO`: 39 preguntas,
`INSPECCION_EMBARCACION`: 54). Ver [esquema](../base-de-datos/esquema-por-modulo.md#inspección-de-buceo-y-embarcación-inspeccion).

## Pantallas

1. `InspectionSetupScreen`: datos iniciales (área, centro, puerto, tipo, contratista, embarcación).
2. `InspectionFormScreen`: encabezado según tipo, parámetros de faena, preguntas
   por categoría, verificaciones, fotos y botón Finalizar.

## Archivos principales

- `lib/features/inspection/presentation/controllers/inspection_setup_controller.dart`
- `lib/features/inspection/presentation/controllers/inspection_form_controller.dart`
- `lib/features/inspection/services/pdf_generator_service.dart` (PDF v0.2.0)
- `lib/features/inspection/services/deferred_pdf_service.dart`

## Pendientes

- Rediseño del informe HTML de buceo: [plan](../planificacion/02_en_progreso/PLAN_REDISENO_INFORME_BUCEO_HTML_V0_2_0.md).
- Criticidad histórica no confiable antes de 2026-03-29: [backlog](../planificacion/03_por_realizar/CRITICIDAD_BACKLOG.md).