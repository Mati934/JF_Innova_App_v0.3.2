# Módulos habilitados por empresa, no tablas por empresa

- **Fecha:** 2026-04-17 ("configuración de módulos por empresa")
- **Estado:** vigente

## Qué se decidió

La app es multi-tenant: los módulos se registran una vez en `ModuleRegistry` y
se habilitan por empresa en `empresa_modulos`. Un cliente con un flujo propio
(PROSESSO, Hidroser, Merieux) recibe un **módulo** habilitado solo para él, no
una tabla o app aparte.

## Por qué

Evitar duplicar estructura por cliente y poder activar/desactivar funciones
desde Administración sin publicar una versión nueva.

## Alternativas

- Tabla por empresa (evaluada para PROSESSO): descartada (ver [PROSESSO_MODULE.md](../PROSESSO_MODULE.md)).

## Consecuencias

- Sin configuración, la empresa ve los módulos por defecto.
- Los clientes con flujo propio igual requieren código nuevo; para checklists
  simples se creó el [motor configurable](motor-checklists-en-paralelo.md).
