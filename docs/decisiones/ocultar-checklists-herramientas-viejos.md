# Ocultar los checklists de herramientas viejos del Registro de Visita

- **Fecha:** 2026-10-22
- **Estado:** vigente
- **Fuente:** decisión del usuario en conversación (2026-10-22)

## Qué se decidió

Los 5 checklists de herramientas del banco clásico (`VISITA_CHEQUEO_*`) dejan de
ofrecerse en el desplegable del Registro de Visita. Se **ocultan, no se
eliminan**: sus preguntas siguen en `formulario_items` y las visitas que ya los
usaron se ven igual. Las herramientas se inspeccionan solo con los checklists
nuevos del motor configurable (`chq_*`).

## Por qué

Eran duplicados: los `chq_*` se crearon el 2026-09-14 copiando esas mismas
preguntas. Los viejos se usaron solo entre el 2026-09-04 y el 2026-09-07 (2
visitas); los nuevos desde el 2026-09-14.

## Alternativas

- Eliminar las preguntas de la base: descartado (se pierde trazabilidad).
- Mostrar los nuevos dentro del Registro de Visita: descartado (integración grande entre dos motores).

## Consecuencias

- Exclusión en `getTiposChecklistVisita` (`local_visit_repository.dart`).
- Un borrador antiguo que ya tenía uno de esos checklists lo sigue mostrando solo en ese borrador.
