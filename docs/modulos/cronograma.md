# Cronograma

> Claves: `CRONOGRAMA_EMPRESAS` (operativo), `CRONOGRAMA_PLANTILLAS` (admin)
> Estado: implementación parcial · Solo online · Última revisión: 2026-10-22
> Empresas con el módulo (2026-10-22): Servimaf.
> Plan: [PLAN_CRONOGRAMA_EMPRESAS_MVP.md](../planificacion/02_en_progreso/PLAN_CRONOGRAMA_EMPRESAS_MVP.md).

## Qué hace

Gestiona **tareas programadas por empresa cliente** (inspecciones, chequeos,
capacitaciones) que se generan según una frecuencia, se toman por un responsable
y se completan con trazabilidad.

## Reglas de negocio

- Empresas cliente propias del módulo (`cronograma_clientes_empresas`),
  independientes de `empresas`.
- Plantillas con tareas tipo; al **asignar** una plantilla activa a una empresa
  cliente se generan los planes según frecuencia.
- Tareas asignables a usuarios o grupos; "Completar tarea" deja historial y evidencias.
- Una tarea puede vincularse a una inspección (`cronograma_tarea_inspecciones`) y
  a tickets (`tickets.cronograma_tarea_id`).

## Datos

Tablas `cronograma_*` (ver [esquema](../base-de-datos/esquema-por-modulo.md#cronograma-solo-online)).
Casi sin datos al 2026-10-22.

## Pantallas

`CronogramaEmpresasScreen` (operativo), `CronogramaTemplatesAdminScreen`
(pestañas tipos / plantillas / asignaciones), `CronogramaAdminScreen`.

## Archivos principales

- `lib/features/cronograma/data/repositories/cronograma_operativo_repository.dart`
- `lib/features/cronograma/data/repositories/cronograma_templates_repository.dart`

## Pendientes

- El plan dice "sin implementar", pero hay código y tablas: **pendiente de
  confirmar** qué parte del MVP está terminada.
- Vínculo con tickets (manual/automático) por decidir con Jorge (según plan).
