# Actividades Formativas

> Clave: `ACTIVIDADES_FORMATIVAS` · Estado: en producción, en ajustes · Última revisión: 2026-10-22
> Empresas con el módulo (2026-10-22): las 11 empresas.
> Plan: [PLAN_REGISTRO_ACTIVIDADES_FORMATIVAS.md](../planificacion/02_en_progreso/PLAN_REGISTRO_ACTIVIDADES_FORMATIVAS.md).

## Qué hace

Registra **charlas, servicios, capacitaciones u otras actividades** que realiza
la empresa, para contar actividades y **horas-hombre (HH)**. En Home aparece como
"Registro de Actividad".

## Reglas de negocio

- Tipo: `Charla`, `Servicio`, `Capacitación` u `Otro` (si es Otro, se pide el tipo).
- Fecha, hora de inicio y término (término debe ser posterior al inicio).
- **Número de asistentes** (no se guarda nómina ni RUT de asistentes).
- Relator y firma del relator (sin firmas de asistentes).
- Centro y área opcionales ("Sin centro", área "Otro").
- **Duración contabilizada**: se redondea hacia arriba a bloques de 15 minutos.
- **HH**: se guardan las dos cifras (sin relator = asistentes × horas; con
  relator = (asistentes + 1) × horas). El PDF muestra **solo HH con relator**.
- PDF con `N° Informe` bajo el logo (no "Correlativo") y pie "Generado por
  Servimaf" con contacto y versión. Desde 2026-10-21 incluye galería de fotos.
- Correlativo independiente asignado en Supabase. A diferencia de las
  inspecciones, aquí sí se llena `actividades.empresa_id`.
- PDF diferido si se finaliza sin conexión.

## Datos

`actividades` (cabecera) + `actividad_formativa_registros` (detalle);
local `actividades_formativas_pendientes`, `formativa_fotos_eliminadas`.

## Pantallas

`FormativeActivityModuleScreen` → `FormativeActivityFormScreen`.

## Archivos principales

- `lib/features/formative_activities/domain/models/formative_activity.dart` (cálculo de HH)
- `lib/features/formative_activities/services/formative_activity_pdf_service.dart` (PDF v0.1.4)
- `lib/features/formative_activities/data/repositories/local_formative_activity_repository.dart`

## Pendientes

- Ver el plan (estado "implementación en progreso").
