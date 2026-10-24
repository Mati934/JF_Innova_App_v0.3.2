# Motor de checklists configurables en paralelo

- **Fecha:** 2026-09-02 (plan) / 2026-09-14 (implementación)
- **Estado:** vigente, en piloto
- **Fuente:** [PLAN_MOTOR_CHECKLISTS_CONFIGURABLES.md](../planificacion/02_en_progreso/PLAN_MOTOR_CHECKLISTS_CONFIGURABLES.md)

## Qué se decidió

Crear un motor genérico donde un checklist nuevo es solo configuración (datos),
con versiones publicadas, navegación y permisos por empresa. **No** se migran
AST, Buceo, Extintores, Hidroser ni Visitas; solo se evaluará migrarlos tras un
piloto estable.

## Por qué

Cada checklist nuevo requería copiar pantallas, controladores, tablas SQLite y
ramas del sync.

## Alternativas

- Seguir agregando tipos a `formulario_items` + Registro de Visita: es lo que se
  hacía (R005–R017); no soporta campos, permisos ni navegación por empresa.
- Migrar todo al motor de una vez: descartado por riesgo.

## Consecuencias

- Conviven dos fuentes de checklists. Los 5 de herramientas estaban en ambas;
  desde 2026-10-22 los viejos están ocultos ([decisión](ocultar-checklists-herramientas-viejos.md)).
- Los checklists se cargan hoy por SQL; el panel de creación está pendiente.
