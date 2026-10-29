# Tickets: hallazgo único y unidad = observación

- **Fecha:** 2026-09-03
- **Estado:** vigente
- **Fuente:** [ACTUALIZACION_TICKETS_2026-09-03.md](../planificacion/01_realizados/ACTUALIZACION_TICKETS_2026-09-03.md), [IMPLEMENTACION_HALLAZGO_UNICO_NC.md](../IMPLEMENTACION_HALLAZGO_UNICO_NC.md)

## Qué se decidió

- Un NC repetido (misma empresa, tipo de inspección, pregunta y embarcación,
  con hallazgo abierto) **reutiliza** el hallazgo y el ticket y suma una ocurrencia.
- La embarcación sale solo de `actividades.embarcacion_id`; sin embarcación no
  hay ticket automático.
- En fotos, la unidad es la **observación escrita**: varias fotos con la misma
  observación = un ítem, una subsanación.
- Solo se procesan inspecciones desde 2026-08-31.

## Por qué

Antes se creaban tickets duplicados, tickets vacíos y un único ticket
fotográfico que mezclaba observaciones; se adivinaba el contexto por centro.

## Alternativas

- Ticket por cada informe: descartado (duplica seguimiento del mismo problema).
- Ticket fotográfico único por informe: reemplazado.
- Fallback por centro (`CENTRO_FALLBACK`): eliminado.

## Consecuencias

- Tickets históricos anteriores conservan la estructura antigua.
- Un ítem muestra una sola foto representativa.
