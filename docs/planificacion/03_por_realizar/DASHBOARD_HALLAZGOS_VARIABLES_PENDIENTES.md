# Dashboard Hallazgos Unicos - Variables Pendientes

Fecha: 2026-08-03
Estado: levantamiento inicial para diseno de dashboard

## 1) Lo que ya puedes responder hoy

Con el esquema actual + cambios aplicados:
- Si un punto/hallazgo sigue abierto o no (`nc_hallazgos.estado_hallazgo`).
- Ultima deteccion del hallazgo (`fecha_ultima_deteccion`).
- Cuantas veces reaparecio (`count` en `nc_hallazgo_ocurrencias`).
- Si el ticket sigue activo o cerrado (tabla `tickets`).
- Ultima subsanacion por item (nuevo log `ticket_item_subsanaciones`).

## 2) Variables criticas que faltaba considerar

## 2.1 Gobernanza del hallazgo
- `cerrado_por`, `cerrado_at`, `motivo_cierre` en `nc_hallazgos`.
- `reabierto_por`, `reabierto_at`, `motivo_reapertura`.
- `reaperturas_count` (o derivado por eventos).

Sin esto, sabras estado final pero no la historia de decision de cierre.

## 2.2 Calidad de dedupe
- Indicador de confianza de match (`score` o `match_rule`) por ocurrencia.
- Motivo de dedupe aplicado (`EMBARCACION`, `CENTRO_FALLBACK`, etc).
- Flag de caso ambiguo (cuando falta embarcacion y centro cambia seguido).

Sin esto, no podras auditar por que un NC se unio o no.

## 2.3 Ciclo de vida operativo (SLA)
- `first_ticket_created_at` por hallazgo.
- `first_taken_at` por ticket.
- `time_to_take`, `time_to_first_subsanacion`, `time_to_close`.
- `age_open_days` para backlog vivo.

Sin esto, no hay KPIs de eficiencia del proceso.

## 2.4 Subsanacion detallada
- Resultado tecnico de subsanacion (aprobada/rechazada por item, no solo por ticket).
- Comentario tecnico de subsanacion por item.
- Conteo de retrabajos por item (`SUBSANADO` -> `DESHECHO` -> `SUBSANADO`).

Sin esto, veras estado final, pero no calidad de la correccion.

## 2.5 Contexto operacional
- Turno (dia/noche), faena, responsable en terreno.
- Tipo de criticidad normalizada (catalogo, no solo texto libre).
- Version de pauta (`formulario_items` version) para comparabilidad historica.

Sin esto, comparar periodos y causas es inestable.

## 2.6 Riesgos de data quality
- Porcentaje de inspecciones con `embarcacion_id` nulo por empresa/tipo.
- Ocurrencias con `centro_id` nulo.
- Duplicidad sospechosa (mismo item, misma fecha, distinta observacion corta).

Sin esto, el dashboard puede dar conclusiones incorrectas.

## 3) Preguntas de negocio que habilita el modelo

- Este hallazgo puntual ya fue subsanado alguna vez?
- Cual fue la ultima subsanacion y quien la hizo?
- Cuantas veces reaparecio despues de una subsanacion?
- Cuanto tarda en promedio desde deteccion hasta cierre aprobado?
- Que centros/embarcaciones concentran mayor recurrencia?

## 4) Consultas base recomendadas para dashboard

1. Ultima subsanacion por item de ticket:
- Tabla base: `ticket_item_subsanaciones`
- Filtro: `accion = 'SUBSANADO'`
- Orden: `created_at desc`

2. Estado vivo de hallazgo:
- Tabla base: `nc_hallazgos`
- Join opcional: `tickets` (ticket activo por `hallazgo_id`)

3. Recurrencia:
- `count(*)` de `nc_hallazgo_ocurrencias` por `hallazgo_id`
- Ventana temporal mensual/semanal

4. Retrabajo:
- Conteo de eventos `DESHECHO` por `ticket_item_id`

## 5) Recomendacion de siguiente iteracion

Antes de construir dashboard final:
1. Agregar eventos de cierre/reapertura de hallazgo.
2. Agregar comentario tecnico opcional en `ticket_item_subsanaciones`.
3. Definir catalogo de criticidad estable para analitica.
4. Definir diccionario de metricas (formula y fuente oficial).
