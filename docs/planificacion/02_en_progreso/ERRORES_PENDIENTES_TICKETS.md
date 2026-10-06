# Errores de Tickets

Registro resumido despues de la correccion del 2026-09-03.

## INC-001: Tickets vacios

**Estado:** Corregido en codigo. Limpieza historica pendiente.

- Los nuevos tickets preparan sus items antes de insertar la cabecera.
- Si falla la insercion de items, se elimina el ticket recien creado.
- El camino legacy tambien evita crear tickets sin items.
- Los tickets vacios que ya existian se desactivan con `supabase_fix_tickets_vacios_v1.sql`.

## INC-002: Inspecciones sin embarcacion

**Estado:** Corregido en codigo.

- La inspeccion se sube normalmente.
- No crea hallazgo, ocurrencia, ticket ni item mientras no tenga `embarcacion_id`.
- No se marca como procesada, para que pueda reintentarse al asignar la embarcacion.
- La continuidad usa empresa + tipo de inspeccion + `item_id` + embarcacion + hallazgo abierto.
- Ya no se usa `CENTRO_FALLBACK` para generar tickets nuevos.
- Los historicos creados con la regla anterior no se fusionan automaticamente.

## INC-003: Tickets de inspecciones antiguas

**Estado:** Corregido en codigo. Limpieza historica pendiente.

- El sincronizador ignora actividades creadas antes del `2026-08-31`.
- Esto se controla por `actividades.created_at`, no por numero de informe.
- El boton manual para generar tickets antiguos ya no esta disponible desde el historial.
- Los tickets antiguos existentes se desactivan con `supabase_fix_tickets_historicos_antes_lanzamiento_v1.sql`.

## INC-004: Fotos con observacion

**Estado:** Corregido en codigo y migracion ejecutada.

- La unidad de seguimiento es la observacion, no la foto.
- Varias fotos con la misma observacion generan un solo ticket y un solo `ticket_item`.
- Una observacion requiere una sola subsanacion.
- Observaciones diferentes generan tickets independientes.
- Se excluyen fotos `General`, anexos, verificaciones y fotos de pregunta.
- Se persiste `observacion_foto_key` para evitar duplicados en reintentos.
- Se reemplazo el indice de un ticket fotografico por inspeccion por un indice de un ticket por observacion.

## Verificaciones realizadas

- [x] No hay codigos de tickets repetidos.
- [x] No hay referencias de items repetidas.
- [x] No hay `hallazgo_id` duplicados entre tickets.
- [x] Tests de robustez de tickets: 13 pasaron.
- [x] `flutter analyze` del flujo de tickets: sin errores.
- [x] Migracion de fotos por observacion ejecutada en Supabase.
- [ ] Ejecutar limpieza de tickets antiguos y vacios, si aun no se ha hecho.
- [ ] Validar en produccion una inspeccion sin embarcacion y otra posterior con embarcacion.

## Archivos SQL de limpieza pendientes

Los archivos SQL no se ejecutan solos y requieren ejecucion manual en el SQL Editor de Supabase:

- `supabase_fix_tickets_vacios_v1.sql`
- `supabase_fix_tickets_historicos_antes_lanzamiento_v1.sql`

Ambos incluyen consultas de solo lectura antes del cambio de datos.
