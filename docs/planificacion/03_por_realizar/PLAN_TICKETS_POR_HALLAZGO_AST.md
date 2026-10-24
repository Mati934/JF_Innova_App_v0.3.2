# Plan: Tickets por hallazgo AST

**Estado:** Pendiente de implementacion.  
**Alcance:** Extender el modulo de Tickets para que cada hallazgo de un informe
AST finalizado pueda tener su propio ticket, manteniendo intacto el flujo
actual de inspecciones de buceo y embarcacion.

## 1. Objetivo y regla de negocio

- Crear **un ticket por cada registro `ast_hallazgos`** de un informe AST
  finalizado (`En Seguimiento`).
- El ticket debe quedar relacionado con el informe AST y con el hallazgo AST
  que lo origino, y mostrar su evidencia cuando este disponible.
- Reintentar la sincronizacion del mismo informe no debe crear tickets ni
  items duplicados.
- En esta primera version, dos registros de hallazgo AST distintos generan
  dos tickets distintos, aunque su titulo o detalle sean iguales. No se
  fusionan hallazgos entre informes AST: AST no tiene la clave estructurada de
  continuidad que usan los NC de inspeccion.
- Los borradores AST (`En Progreso`), informes sin hallazgos y AST no
  sincronizados completamente no generan tickets.

## 2. Situacion actual y limite de reutilizacion

- La sincronizacion AST sube por separado `ast_informes`, `ast_hallazgos` y
  sus evidencias; al completar tambien sube el PDF. No invoca la generacion de
  Tickets.
- Las inspecciones ya tienen generacion automatica por hallazgo, pero sus
  vinculos no son intercambiables: `tickets.hallazgo_id` apunta a
  `nc_hallazgos`, mientras `tickets.inspeccion_id` apunta a
  `actividades`. Ninguno debe reutilizarse para un AST.
- El modelo actual de Tickets tampoco distingue origen AST, y sus items no
  tienen una categoria `AST_HALLAZGO`.

Por lo tanto se reutilizan el ciclo de vida y las pantallas de Tickets, no las
relaciones de datos de inspecciones.

## 3. Diseno de datos propuesto

Agregar soporte aditivo, sin cambiar ni reinterpretar columnas existentes:

1. En `tickets`, incorporar una referencia nullable al informe AST y otra al
   hallazgo AST (`ast_informe_id` y `ast_hallazgo_id`), con claves foraneas a
   `ast_informes` y `ast_hallazgos`.
2. Incorporar `AST` como origen de ticket en las restricciones de base de datos
   y en `TicketOrigen`. Los tickets AST usan `REVISION_OBSERVACIONES`.
3. Garantizar la relacion uno-a-uno con un indice unico para
   `ast_hallazgo_id` no nulo, incluyendo tickets cerrados. La eliminacion
   logica de un ticket no debe permitir que un reintento cree otro para el
   mismo hallazgo fuente.
4. Incorporar `AST_HALLAZGO` como origen de `ticket_items`. Cada ticket AST
   contiene un item que conserva el titulo, detalle y URL de evidencia del
   hallazgo. Usar el ID de `ast_hallazgos` como referencia del item, sin
   confundirlo con una respuesta de inspeccion.
5. Extender `TicketModel` y `TicketItemModel`, sus mappers y las consultas de
   detalle/listado para transportar las referencias y representar el origen
   AST.
6. Completar el contexto util del ticket con empresa, area, centro,
   contratista, embarcacion y correlativo del informe AST. El correlativo AST
   debe mostrarse como referencia del informe, no como tipo de inspeccion.

La migracion Supabase debe ser aditiva e idempotente, preservar tickets
existentes y mantener sus politicas RLS. No cambiar el significado de
`inspeccion_id` ni de `hallazgo_id`.

## 4. Generacion e idempotencia

1. Ejecutar la generacion solo despues de que el AST este en `En Seguimiento`
   y se hayan sincronizado informe, hallazgos y evidencia necesaria.
2. Procesar AST solo si el modulo `TICKETS` esta habilitado para la empresa.
   Si esta deshabilitado, conservar el AST sincronizado y permitir que un sync
   posterior genere los tickets al habilitarlo.
3. Para cada hallazgo fuente, buscar primero el ticket por
   `ast_hallazgo_id`. Si ya existe (abierto, tomado, finalizado, cerrado o
   eliminado logicamente), no insertar otro.
4. Crear el ticket y su item con referencias AST y contexto del informe.
   Evitar tickets sin item: la creacion debe manejar atomicidad o compensacion
   ante un fallo parcial, siguiendo las garantias del flujo actual.
5. Marcar el informe como procesado solo cuando todos sus hallazgos tengan
   ticket y item asociados. Los errores deben dejar el AST elegible para
   reintento y registrarse sin dar el proceso por exitoso.
6. Persistir un marcador de proceso AST/Tickets remoto para poder detectar
   informes ya sincronizados en ejecuciones posteriores; no depender de que el
   informe siga en la cola local de AST.
7. Establecer un corte de activacion para no crear tickets retroactivos en
   todos los AST historicos al desplegar. La migracion debe marcar la linea
   base historica como ya evaluada; solo AST finalizados posteriores al corte
   entran automaticamente, salvo una futura tarea explicita de backfill.

## 5. Seguridad, permisos y UX

- Reutilizar la visibilidad por empresa y la excepcion administrativa ya
  implementadas para Tickets; validar que el origen AST no permita acceder a
  informes o evidencia de otra empresa.
- Mantener el requisito online del modulo Tickets. AST sigue siendo
  offline-first; no crear tickets locales ni bloquear el guardado AST cuando no
  haya internet.
- En lista y detalle, identificar claramente el origen AST y mostrar el
  correlativo del informe, el titulo/detalle del hallazgo y su foto cuando
  exista.
- Mantener tomar, subsanar con evidencia, historial, revision, notificaciones
  y cierre tal como funcionan para Tickets; confirmar que las acciones se
  comportan bien para un ticket con un solo item.
- No generar un ticket por informe ni un ticket compartido para todos los
  hallazgos AST.

## 6. Fases de implementacion

1. **Migracion y restricciones:** agregar las referencias AST, origenes
   permitidos, item AST, indice de unicidad y marcador/corte de procesamiento;
   verificar RLS y Realtime.
2. **Dominio y repositorio:** ampliar modelos, mappers, consultas e insercion
   sin alterar el flujo NC de inspecciones ni las solicitudes manuales.
3. **Sincronizacion:** despues del sync completo de AST, generar/reconciliar
   ticket e item por hallazgo; mantener elegibles los fallos y casos con
   Tickets deshabilitado.
4. **Presentacion:** mostrar de forma coherente el contexto AST en listado,
   detalle, historial y notificaciones.
5. **Validacion y activacion:** desplegar migracion antes de la app, probar
   con una empresa habilitada, y activar solo para AST posteriores al corte.

## 7. Criterios de aceptacion

- Un AST finalizado con N hallazgos sincronizados produce exactamente N
  tickets, cada uno relacionado con su hallazgo y con un item utilizable.
- AST sin hallazgos, borradores y AST con sincronizacion incompleta no crean
  tickets.
- Repetir sync, incluso desde dos dispositivos, no duplica ticket ni item.
- Deshabilitar Tickets no pierde el trabajo; al habilitarlo, un sync posterior
  procesa los AST elegibles.
- Los AST anteriores al corte no reciben tickets automaticamente.
- Tickets existentes de inspecciones y solicitudes conservan sus datos,
  filtros, acciones y permisos; el flujo de inspecciones sigue creando un
  ticket por hallazgo NC como hoy.
- Un ticket AST puede recorrer completo el ciclo de tomar, subsanar con foto,
  revision, rechazo/reintento y cierre.

## 8. Pruebas requeridas

- Pruebas de modelo y mapeo para origen AST y referencias.
- Pruebas de generacion para cero, uno y varios hallazgos.
- Pruebas de idempotencia, concurrencia, reintento despues de fallo parcial,
  hallazgo sin foto, ticket eliminado logicamente y ticket ya cerrado.
- Pruebas de gating del modulo, permisos/RLS y corte historico.
- Regresion de los tests existentes de generacion y reglas de Tickets.
- Verificacion manual de lista, detalle, notificaciones y subsanacion con un
  AST real de prueba.

## 9. Dependencias y documentos relacionados

- [Actualizacion vigente de Tickets](../01_realizados/ACTUALIZACION_TICKETS_2026-09-03.md).
- [Continuidad de informes y Tickets NC](../01_realizados/PLAN_CONTINUIDAD_INFORMES_Y_TICKETS_NC.md).
- [Registro de errores y verificaciones de Tickets](../02_en_progreso/ERRORES_PENDIENTES_TICKETS.md).
- [Plan original del modulo Tickets](../02_en_progreso/PLAN_TICKETS_MVP.md), solo como referencia historica.

Este plan describe trabajo futuro. No implica cambios de codigo, migracion ni
activacion del flujo AST/Tickets.
