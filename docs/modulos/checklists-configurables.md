# Checklists Configurables (motor de módulos genéricos)

> Sin clave en `ModuleRegistry`: las tarjetas salen de `checklist_navigation_nodes` por empresa.
> Estado: piloto (ninguna inspección finalizada en producción al 2026-10-22) · Última revisión: 2026-10-29
> Plan: [PLAN_MOTOR_CHECKLISTS_CONFIGURABLES.md](../planificacion/02_en_progreso/PLAN_MOTOR_CHECKLISTS_CONFIGURABLES.md).
> Crear o cambiar checklists: skill `nuevo-checklist`. Módulos que no caben: skill `nuevo-modulo`.

## Qué hace

Sirve para crear **módulos genéricos** sin programar. Todos comparten el
encabezado base y la misma pantalla (`GenericChecklistFormScreen`) y PDF; lo
único que cambia es el checklist. Así cada checklist se ve como un módulo propio
en el Inicio del usuario, de dos formas:

- **Tarjetas sueltas**: una tarjeta por checklist (modo usado hoy).
- **Grupo**: una tarjeta que agrupa varios checklists (ej. "Equipos Críticos").

Los módulos que no caben en este molde se hacen como módulo normal.

Hoy tiene 8 checklists: 5 de **Herramientas y Equipos** (M&S) y 3 de
**Equipos Críticos** (MB Embajadores). Ver [catálogo](../checklists/README.md).

## Piezas

| Pieza | Tabla | Qué define |
|---|---|---|
| Molde | `checklist_form_types` | Tipo de formulario y PDF (`generic_standard_form`). |
| Ficha | `checklists` | Clave, nombre, ícono, color, prefijo del informe, versión publicada. |
| Preguntas | `checklist_versions` | Preguntas congeladas por versión. |
| Encabezado | `checklist_campo_definiciones` + `checklist_campo_asignaciones` | Catálogo compartido de campos y cuáles usa cada checklist. |
| Tarjetas | `checklist_navigation_nodes` | Tarjetas sueltas y grupos por empresa. |
| Permisos | `checklist_permission_grants` | Ver / crear / editar borrador / finalizar, por usuario o por rol. |

## Reglas de negocio

- Respuestas Sí / No / No aplica (cumple / no cumple / no aplica en el PDF), con
  observación, criticidad y foto opcionales.
- Encabezado fijo: supervisor y correo de supervisor. Encabezado variable:
  campos del catálogo (obra/faena, región, área, jefatura, horas, correos de
  empresa, equipo inspeccionado, operador…), cada uno opcional u obligatorio.
- Cambiar preguntas = publicar una versión nueva. Una inspección finalizada
  congela su versión (trigger `trg_checklist_snapshot`). Un **borrador** se
  reabre con la última versión publicada y une respuestas por id de pregunta.
- Al finalizar (`En Seguimiento`) Supabase asigna el correlativo
  `<PREFIJO>-0001` por checklist y por empresa (trigger `trg_checklist_correlativo`,
  por empresa desde 2026-10-29).
- **Visibilidad**: la tarjeta se ve si está habilitada para la empresa **y** el
  usuario tiene permiso `ver` (RLS `checklist_user_can`). Sin permiso, el sync
  no baja la tarjeta y no deja subir inspecciones.
- Los informes aparecen en Historial (`historial_unificado` incluye `checklist_inspecciones`).

## Límites actuales (requieren código)

- Las marcas del molde (`requiere_observacion_nc`, `requiere_foto_nc`,
  `usa_criticidad`, `permite_firma`…) y `snapshot_reglas` **se guardan pero la
  app no las aplica**.
- Solo respuestas Sí/No/NA; sin respuestas numéricas, por persona ni grillas de N equipos.
- Sin responsable y fecha de cumplimiento por hallazgo.
- No genera tickets.
- PDF único estándar; 19 íconos soportados (`checklist_icons.dart`).

## Datos

Ver [esquema](../base-de-datos/esquema-por-modulo.md#checklists-configurables-motor).

## Pantallas

`ChecklistGroupScreen` (grupo) → `GenericChecklistFormScreen`. Administración
de tarjetas y permisos en [Administración](administracion.md) (`ChecklistNodesAdminScreen`).

## Archivos principales

- `lib/features/configurable_checklists/presentation/controllers/configurable_checklist_form_controller.dart`
- `lib/features/configurable_checklists/domain/checklist_navigation_tree.dart`
- `lib/features/configurable_checklists/services/checklist_pdf_generator_service.dart` (PDF v0.1.0)
- Plantillas SQL: `.claude/skills/nuevo-checklist/`

## Pendientes

- Los permisos de Herramientas y Equipos (M&S, Servimaf) siguen siendo **por
  usuario**: un usuario nuevo de M&S no verá las tarjetas hasta agregarle
  permisos. Pasarlos a por rol como se hizo con MB Embajadores ([decisión](../decisiones/permisos-checklists-por-rol.md)).
- Ninguna inspección finalizada en producción (15 borradores/eliminadas): validar el ciclo completo (finalizar, correlativo, PDF, Historial) en un piloto.
- Panel para crear checklists desde la app (en el plan; hoy se cargan por SQL con la skill).
- Validar las preguntas de Equipos Críticos con Prevención de Riesgos.
- "Registro de rotación de puestos" (`documentos_checklists/En Pausa`): no es inspección; fuera de alcance.
