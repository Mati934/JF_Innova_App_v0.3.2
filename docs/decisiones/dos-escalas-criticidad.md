# Dos escalas de criticidad

- **Fecha:** 2026-03 (corrección del 2026-03-26/29)
- **Estado:** vigente, con backlog ([CRITICIDAD_BACKLOG.md](../planificacion/03_por_realizar/CRITICIDAD_BACKLOG.md))

## Qué se decidió

Se mantienen dos escalas:

- Inspecciones y visitas: `Tolerable / Moderado / Intolerable`.
- Tickets: `Bajo / Medio / Alto / Intolerable`.
- Equivalencia: Tolerable↔Bajo, Moderado↔Medio, Intolerable↔Alto/Intolerable.

## Por qué

Pendiente de confirmar el motivo original. El problema conocido: en 2026-03
`formulario_items` usaba la escala de Tickets y el selector convertía todo a
"Tolerable".

## Alternativas

- Unificar en una sola escala: en backlog, sin decisión.

## Consecuencias

- `inspeccion_respuestas.criticidad_registrada` anterior a 2026-03-29 quedó todo
  en "Tolerable" y no se puede recuperar: **no usar en métricas**.
