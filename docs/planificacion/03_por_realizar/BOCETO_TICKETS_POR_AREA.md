# Boceto UI - Tickets por Area (Vista Jefatura)

## Objetivo
Al entrar al modulo Tickets, en vez de ver primero el listado plano, mostrar un tablero por area con estado operacional rapido:

- Cuantos tickets tiene cada area.
- Porcentaje de avance real (subsanacion).
- Cuantos estan cerrados/aprobados.
- Cuantos estan atrasados o estancados.

La idea es que un jefe vea en menos de 10 segundos donde esta el problema.

---

## Estructura de la pantalla

1. Header superior
- Titulo: Tickets por Area
- Subtitulo: Resumen ejecutivo de operacion
- Ultima actualizacion

2. Bloque KPI general (global)
- Total tickets activos
- % avance global de subsanacion
- % aprobacion global (cerrados)
- Tickets vencidos

3. Busqueda y filtros rapidos
- Buscar area
- Chips: Todas | Criticas | Con atraso | Sin tickets
- Selector de periodo: Hoy | 7 dias | 30 dias

4. Grid/Lista de tarjetas por area
- Una tarjeta por area
- Orden por prioridad (primero las peores)

5. CTA flotante
- Ver listado completo de tickets (vista actual)

---

## Tarjeta por Area (lo clave para jefatura)

### Encabezado
- Nombre del area
- Estado semaforo:
  - Rojo: alta carga + vencidos o baja aprobacion
  - Amarillo: carga media o tendencia negativa
  - Verde: controlado

### KPI principal en la tarjeta
- Tickets totales
- Abiertos
- En trabajo (tomado/parcial)
- Pendiente revision
- Cerrados (aprobados)

### KPI de calidad/eficiencia
- % avance subsanacion del area
- % tickets cerrados del area
- % tickets dentro de plazo
- Edad promedio del ticket (dias)

### Alertas de foco
- Vencidos: N
- Sin responsable (abiertos no tomados): N
- Rechazados por revision: N

### Mini contexto operativo
- Ultimo ticket creado: hace X horas
- Ticket mas antiguo abierto: X dias

### Acciones rapidas
- Ver tickets del area
- Ver solo vencidos
- Ver solo pendientes de revision

---

## Formula sugerida de indicadores

- Tickets totales area = todos los tickets del area en el periodo
- Activos area = estado distinto de CERRADO
- % avance subsanacion = subsanados / total items * 100
- % cierre area = tickets cerrados / tickets totales * 100
- % en plazo = tickets no vencidos / tickets activos * 100
- Edad promedio = promedio(dias desde created_at en activos)

Notas:
- Para tickets de tipo solicitud (sin items), no se usa subsanacion por item.
- En esos casos, su avance puede depender del estado del ticket.

---

## Ranking recomendado (orden de tarjetas)

Score de riesgo area (alto a bajo):

Riesgo = (vencidos * 4) + (rechazados * 3) + (abiertos * 2) + (pendiente_revision * 1)

Mostrar primero las areas con mayor riesgo.

---

## Propuesta visual (wireframe rapido)

Pantalla:

- Header + KPIs globales en 2 filas
- Filtros en chips horizontales
- Tarjetas area en lista vertical (mobile) y grid 2 columnas (tablet)

Tarjeta Area:

- Fila 1: [Semaforo] [Nombre area] [Badge riesgo]
- Fila 2: Total | Abiertos | En trabajo | Pendiente rev | Cerrados
- Fila 3: Barra avance subsanacion + %
- Fila 4: Vencidos | Sin responsable | Rechazados
- Fila 5: Botones: Ver area / Vencidos / Revision

---

## Lo que mas valora un jefe (prioridad alta)

1. Donde esta el atraso hoy (vencidos y abiertos sin tomar)
2. Que area esta peor (ranking)
3. Si el equipo esta cerrando (tasa de cierre)
4. Si lo finalizado se aprueba o se devuelve (rechazos)
5. Que tan viejo es el backlog (edad promedio)

---

## MVP (sin cambiar mucho backend)

Se puede lanzar una primera version usando datos que ya existen:

- area_id del ticket
- estado
- fecha_limite
- created_at
- conteo de items/subsanados por ticket (ya calculado en lista)

Con eso alcanza para:
- Totales por area
- Estado por area
- % cierre
- Vencidos
- % avance por items

---

## V2 (mejora recomendada)

Agregar campos derivados para analitica fina:

- SLA objetivo por tipo de ticket
- Tiempo en cada estado
- Motivo de rechazo clasificado
- Tendencia 7 dias (sube/baja)

---

## Siguiente paso para implementacion

1. Crear nueva pantalla: DashboardTicketsAreaScreen.
2. Agregar agrupacion por area en TicketListController.
3. Crear componente AreaTicketCard.
4. Navegar desde AreaTicketCard al listado filtrado por area.
5. Mantener boton para volver a la vista clasica de tickets.
