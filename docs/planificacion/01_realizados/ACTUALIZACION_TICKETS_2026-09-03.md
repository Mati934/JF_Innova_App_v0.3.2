# Actualizacion de Tickets - 2026-09-03

## Estado

Modulo de Tickets corregido y con las migraciones de esta etapa ejecutadas en Supabase.

## Como funcionan ahora

### Generacion automatica

- Se generan tickets desde inspecciones de buceo y embarcacion en estado finalizado.
- La inspeccion debe tener `embarcacion_id`.
- Si no tiene embarcacion, la inspeccion se sube normalmente con sus respuestas y fotos, pero no genera ticket ni hallazgo.
- Esa inspeccion no se marca como procesada; si despues se le asigna una embarcacion, puede procesarse en el siguiente sync.
- La embarcacion se toma exclusivamente desde `actividades.embarcacion_id`; no se adivina por centro, texto o fecha.

### Unidad de seguimiento

- Un `ticket` representa un hallazgo que debe atenderse.
- Cada `ticket_item` representa una observacion concreta dentro del ticket.
- Para respuestas `NC`, la continuidad usa empresa + tipo de inspeccion + `item_id` + embarcacion + hallazgo abierto.
- Si la misma observacion aparece otra vez en la misma embarcacion, se reutiliza el hallazgo y el ticket, y se agrega la nueva ocurrencia al historial.
- Una embarcacion distinta representa un contexto distinto y no se mezcla automaticamente.

### Fotos con observacion

- La unidad es la observacion escrita, no la foto.
- Varias fotos con la misma observacion se agrupan en un solo ticket y un solo item.
- Eso requiere una sola subsanacion.
- Observaciones distintas generan tickets independientes.
- Fotos `General`, anexos, verificaciones y fotos de pregunta no generan tickets.
- Se guarda una clave `observacion_foto_key` para evitar duplicados cuando se repite una sincronizacion.
- El registro fotografico conserva las fotos originales; el item de ticket mantiene una foto representativa visible.

### Subsanacion y cierre

- Un usuario toma el ticket y puede subsanar sus items.
- Cada item requiere una foto de subsanacion.
- Al completar todos los items, el ticket pasa a `FINALIZADO_PENDIENTE_REVISION`.
- Un administrador aprueba y lo pasa a `CERRADO`, o rechaza con motivo y lo devuelve a `PARCIAL`.
- La subsanacion se registra tambien en `ticket_item_subsanaciones`.

## Correcciones incluidas

- Se eliminaron los tickets vacios nuevos: los items se preparan antes de insertar la cabecera y hay rollback si falla la insercion.
- Se bloqueo el reprocesamiento automatico de inspecciones antiguas al usar el corte de lanzamiento `2026-08-31`.
- Se elimino el fallback `CENTRO_FALLBACK` para tickets nuevos.
- Se corrigio la generacion sin embarcacion.
- Se cambio el ticket fotografico unico por tickets separados por observacion.
- Se agrego deduplicacion por observacion fotografica.

## Tablas principales

- `actividades`: inspeccion de origen y `embarcacion_id`.
- `inspeccion_respuestas`: respuestas del checklist, incluyendo `NC`.
- `registro_fotografico`: fotos originales.
- `nc_hallazgos`: hallazgo unico por contexto.
- `nc_hallazgo_ocurrencias`: apariciones del hallazgo en informes.
- `tickets`: expediente de seguimiento.
- `ticket_items`: observaciones a subsanar.
- `ticket_item_subsanaciones`: historial de evidencias de subsanacion.

## Validacion

- Tests de robustez de tickets: 13 pasaron.
- `flutter analyze` del flujo de tickets: sin errores.
- Migracion ejecutada: `supabase_migration_tickets_fotos_por_observacion_v1.sql`.

## Pendiente conocido

- Los tickets historicos creados antes de esta correccion pueden conservar la estructura antigua. No se regeneran automaticamente.
- La desactivacion de tickets antiguos o vacios es un proceso separado de limpieza de datos.
- Si en el futuro se necesitan varias fotos distintas visibles dentro de un mismo item, habra que agregar una tabla hija de evidencias; hoy se conserva una foto representativa en el ticket.
