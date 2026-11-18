# Registro de inmersiones

> **Para qué es:** Ficha del módulo Registro de inmersiones: qué hace hoy, reglas de negocio, tablas, pantallas y pendientes.

> Clave: `REGISTRO_INMERSIONES` · Estado: en desarrollo (app lista, migración Supabase sin ejecutar) · Última revisión: 2026-11-18
> Empresas con el módulo (2026-11-18): ninguna todavía. La migración lo habilita para AquaChile.

## Qué hace

Registra cuánto bajó cada buzo en una faena: cargo, si buceó, profundidad máxima, desde–hasta, nota y fotos
(profundímetro, registrador Sensus Ultra, foto del buzo y galería general). Reemplaza los datos de inmersión que
los auditores escribían en el correo. Es un informe aparte de la inspección de buceo, vinculado a ella.
Plan y decisiones: [PLAN_REGISTRO_INMERSIONES.md](../planificacion/02_en_progreso/PLAN_REGISTRO_INMERSIONES.md).

## Reglas de negocio

- Un registro por inspección de buceo (`INSPECCION_BUCEO`), solo de las inspecciones del propio auditor que están
  en su teléfono y ya finalizadas.
- Al finalizar una inspección de buceo, si la empresa tiene el módulo y la inspección no tiene registro, la app
  pregunta "¿Quieres hacer el registro de inmersiones ahora?". "Más tarde" → tarjeta "Registro de inmersiones" en Inicio.
  Funciona sin señal.
- Los buzos (rol `Buzo`) vienen cargados de la cuadrilla. Se pueden agregar otras personas de la cuadrilla o
  personas nuevas (nombre y RUT opcional). Cargos: los de la cuadrilla más "Buzo de emergencia".
- Cada buzo tiene una inmersión por defecto; "+ Agregar otra inmersión" permite más. El buzo guarda el resumen:
  profundidad mayor, tiempo total y cantidad de inmersiones.
- "Desde" se llena con la hora en que se crea el registro y se puede cambiar (se guarda si se cambió). El tiempo se
  calcula solo; si "hasta" es menor que "desde", cruzó la medianoche.
- La profundidad autorizada la ingresa el auditor en el encabezado: la inspección no la captura
  (`verificaciones_buceo.profundidad_maxima` vale 0 en todas las filas). Vacía o 0 = sin dato, nunca exceso.
- Si la profundidad supera la autorizada, la app pregunta "¿Desea marcarlo en rojo?". El exceso
  (`excede_autorizada`) se guarda siempre; el rojo (`marcado_rojo`) solo si el auditor dijo que sí.
- Para finalizar: al menos una persona, y cada persona que buceó con la profundidad de su primera inmersión. Fotos,
  horas, equipo y nota son opcionales. Sin firma ni correo. No genera tickets.
- Borradores: se guardan apenas se abre el registro y cada 20 s; quedan en el teléfono (aparecen en Inicio), no suben
  a Supabase ni cuentan como pendientes de sincronizar. Solo sube el registro finalizado.
- Número propio `RI-NNNN` por empresa (contador `REGISTRO_INMERSIONES` en `numeradores_informe`), asignado por
  Supabase al subir el finalizado. Ver [numeración por empresa](../decisiones/numeracion-por-empresa.md).
- El PDF se genera en el sync, cuando existen el RI-NNNN y el N° de la inspección de buceo; si falta alguno, se
  reintenta en el siguiente sync.
- Si la inspección de buceo pasa a `Eliminada` en Supabase, su registro también (trigger).

## Datos

Supabase: `registros_inmersion`, `registro_inmersion_buzos`, `registro_inmersion_inmersiones`,
`registro_inmersion_fotos` (fotos en el bucket `evidencias`, carpeta `inmersiones/`; PDF en `pdfs_visitas`).
Locales: las mismas con sufijo `_pendientes`. Detalle en
[esquema por módulo](../base-de-datos/esquema-por-modulo.md#registro-de-inmersiones).
Lee de la inspección: `actividades_pendientes`, `verificaciones_buceo.profundidad_maxima`,
`actividad_participantes` y `personal_externo`.

## Pantallas

- `RegistroInmersionModuleScreen`: lista de mis inspecciones de buceo con su estado (sin registro, borrador, RI-NNNN).
- `RegistroInmersionFormScreen`: encabezado de la inspección, una tarjeta por persona, observación, galería,
  "Ver PDF" y "Finalizar". Un registro finalizado se abre en solo lectura.
- Aviso al finalizar la inspección: `InspectionFormScreen` → formulario del registro.

## Archivos principales

- `lib/features/registro_inmersiones/presentation/controllers/registro_inmersion_form_controller.dart`
- `lib/features/registro_inmersiones/data/repositories/local_registro_inmersion_repository.dart`
- `lib/features/registro_inmersiones/services/registro_inmersion_sync.dart`
- `lib/features/registro_inmersiones/services/registro_inmersion_pdf_service.dart` (PDF v0.1.0, desde 2026-11-18)
- `supabase_migration_registro_inmersiones_v1.sql`

## Pendientes

- Ejecutar la migración Supabase, probar en dispositivo y publicar la versión de la app.
- Métricas en el dashboard: [PENDIENTES_DASHBOARD.md §5](../planificacion/03_por_realizar/PENDIENTES_DASHBOARD.md).
- Habilitar para Searov u otras empresas: pendiente de decidir.
- La lista de inspecciones no filtra por empresa: pendiente de decidir si importa (auditores con varias empresas).
- En web el módulo usa archivos locales (`dart:io`) para fotos y PDF: pendiente de confirmar si se oculta en web.
