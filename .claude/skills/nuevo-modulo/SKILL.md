---
name: nuevo-modulo
description: Guía para crear un módulo nuevo en JF Innova App (tarjeta propia en Inicio con pantalla, tablas, sync y PDF), decidiendo primero si basta con un checklist del motor configurable. Usar cuando el usuario pida "un módulo nuevo", "un formulario nuevo para la empresa X", "un registro de…", "algo como AST/Hidroser/extintores pero para…", o cuando la skill nuevo-checklist determine que un pedido no cabe en el motor.
---

# Nuevo módulo

Un **módulo genérico** (tarjeta que abre la pantalla genérica con otro
checklist) se crea con datos: skill `nuevo-checklist`. Un **módulo normal** es
código: pantalla, controlador, tablas SQLite y Supabase, rama de sync, PDF,
borradores en Inicio e Historial. Cuesta mucho más; solo se hace si el motor no alcanza.

## Paso 1: decidir el camino (siempre primero)

Aplicar el "Paso 1: ¿cabe en el motor?" de `.claude/skills/nuevo-checklist/SKILL.md`.

| Resultado | Camino |
|---|---|
| Cabe completo | Usar `nuevo-checklist`. Fin. |
| Cabe salvo 1–2 capacidades que otros pedidos también necesitarán (ej. observación obligatoria en NC, campo de responsable) | Proponer **mejorar el motor** una vez y luego `nuevo-checklist`. |
| Es un flujo distinto (grilla de equipos, mediciones, varias firmas con roles, cálculos, certificado, PDF propio) | Módulo normal (pasos siguientes). |
| Reutiliza una pantalla existente con otro filtro (como Vehículos sobre Registro de Visita) | Variante: nueva `ModuleDefinition` que abre la pantalla existente con parámetros. Mínimo código. |

Presentar la recomendación con su costo aproximado (archivos a tocar) y esperar OK.

## Paso 2: definir antes de programar

Completar la sección 1–2 de
`docs/planificacion/99_plantillas/PLANTILLA_CREACION_MODULOS_INSPECCION.md`
(nombre visible, `moduleKey`, prefijo de tablas, empresas, variantes,
entregables, correlativo, alcance v1 / fuera de v1) y crear el plan en
`docs/planificacion/02_en_progreso/PLAN_<MODULO>.md`. Preguntar:

- Empresa(s) cliente (Servimaf, empresa propia, lo recibe para probar).
- Si el PDF lleva el pie "Generado por Servimaf" (regla del proyecto: siempre preguntar en un PDF nuevo).
- Si debe generar tickets (hoy solo inspecciones de buceo/embarcación lo hacen).

## Paso 3: implementar

1. Leer la ficha del módulo más parecido en `docs/modulos/` y copiar su patrón
   (referencias en la sección 0 de la plantilla; Equipamiento de Buceo es el
   ejemplo más reciente y completo).
2. Seguir las secciones 3–11 de la plantilla, en orden: SQLite (`_dbVersion`,
   `_createDB`, `onUpgrade`, `_repairCriticalSchema`), migración Supabase
   (archivo `supabase_migration_<modulo>_module.sql`, sin ejecutar), registro en
   `ModuleRegistry`, modelo/repositorio/controlador, PDF con
   `static const String _pdfVersion = '0.1.0'` visible, sync, Historial
   (`historial_unificado`), borradores en Inicio, RLS, pruebas.
3. Valores de estados, códigos y claves: los mismos en Supabase (check/enum), en
   el código y en `docs/glosario.md`.
4. Supabase: inspeccionar en solo lectura; la migración la ejecuta el usuario o
   se ejecuta con `supabase-write` solo con su OK explícito.

## Paso 4: validar

- `flutter analyze` sin problemas nuevos.
- Tests dirigidos del módulo (`test/<modulo>_test.dart`) y `upgrade_data_integrity_test.dart`.
- La "Definición de Terminado" de la sección 12 de la plantilla.
- Prueba en dispositivo: crear, salir (borrador en Inicio), reabrir, finalizar offline, sincronizar, ver número y PDF, ver en Historial.

## Paso 5: documentar

Skill `documentar-app`: ficha nueva en `docs/modulos/`, índices, esquema por
módulo, glosario, versión del PDF en `docs/decisiones/version-por-pdf.md`,
decisión si se eligió módulo normal sobre el motor, y CHANGELOG.
