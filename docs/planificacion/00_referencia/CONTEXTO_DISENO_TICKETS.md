# Contexto para rediseño de UI — Módulo Tickets (JF Innova App)

> Este documento es para pasarlo a otra IA que va a proponer el **diseño
> visual** (colores, layout, jerarquía de información) de dos pantallas del
> módulo de Tickets de una app Flutter. La otra IA NO necesita tocar código:
> solo debe proponer el diseño (mockup, estructura de widgets, paleta,
> tipografía) que luego se copia/adapta al proyecto.

## Stack y convenciones del proyecto

- Flutter + Material 3. Paleta corporativa actual:
  - Azul primario: `#003366` (`AppTheme.primaryBlue`)
  - Rojo del logo: `#B71C1C`, Amarillo del logo: `#F9A825`, Gris del logo: `#455A64`
  - Fondo de pantallas: `#F4F6F8`
  - AppBar: gradiente diagonal azul → `#002244` → gris (`GradientAppBar`)
- Tarjetas actuales usan: fondo blanco, `borderRadius: 16`, sombra suave
  (`blurRadius: 10`, `alpha 0.04`), borde gris claro (o azul si "es mío").
- No hay Design System propio más allá de `AppTheme`: hay libertad para
  proponer mejoras de color/tipografía siempre que se mantenga coherencia
  con el resto de la app (que usa un estilo corporativo, sobrio, con
  gradientes azules).

---

## 1) Contexto: Tarjeta de Ticket en el listado (`TicketCard`)

Archivo actual: `lib/features/tickets/presentation/widgets/ticket_card.dart`.

### Qué muestra hoy
- Título (`asunto` o recorte del `motivo`) + chip de estado (Abierto /
  Tomado / Parcial / Pendiente de revisión / Cerrado), cada uno con su color.
- Fila de mini-chips: código del ticket (`TCK-2026-0001`), tipo (Revisión de
  observaciones / Solicitud), y opcionalmente "Rechazado" o "Vencido".
- Texto pequeño: "Generado por X · fecha".
- Si está tomado: "Tomado por Y".
- Botón "Tomar" alineado a la derecha si aplica.

### Problemas / pedidos del usuario
- El diseño se siente plano/poco informativo. Se pide **mejorar colores y
  jerarquía visual** (que destaque más el estado y la urgencia).
- Falta mostrar más información clave de un vistazo, por ejemplo:
  - **Número de informe** (`numeroInforme`, solo existe si `origen ==
    INSPECCION`) — actualmente NO se muestra en la tarjeta.
  - **Tipo de inspección** (`tipoInspeccion`: `INSPECCION_BUCEO` /
    `INSPECCION_EMBARCACION`) — actualmente NO se muestra en la tarjeta.
  - Cantidad de observaciones / progreso de subsanación (ej. "3/5
    subsanadas") cuando el ticket tiene ítems — hoy solo se ve al entrar al
    detalle.
  - Centro / embarcación / área si existen (`centroId`, `embarcacionId`,
    `areaId` — hoy son solo IDs, se podría resolver a nombre si aporta).
  - Fecha límite (`fechaLimite`) y si está vencido — hoy solo se muestra en
    el detalle, no en la tarjeta.
- El usuario quiere "mejorar la eficiencia de los clicks", es decir, reducir
  pasos/fricción para acciones comunes (tomar un ticket, ver progreso) sin
  tener que entrar siempre al detalle.

### Datos disponibles en `TicketModel` para usar en el diseño
```
codigoTicket, empresaId, origen (INSPECCION|SOLICITUD),
tipoTicket (REVISION_OBSERVACIONES|SOLICITUD), inspeccionId, tipoInspeccion,
numeroInforme, areaId, centroId, embarcacionId, asunto, motivo,
generadoPorId, estado (ABIERTO|TOMADO|PARCIAL|
FINALIZADO_PENDIENTE_REVISION|CERRADO), tomadoPorId, fechaLimite,
revisadoPorId, revisadoAt, rechazado, motivoRechazo, createdAt, updatedAt
```
También se puede pedir al repositorio la cantidad de ítems / subsanados de
cada ticket si el diseño lo requiere (hoy no se trae en el listado por
performance, pero se puede agregar).

### Qué se espera del diseño propuesto
- Mockup/estructura de la tarjeta con mejor jerarquía visual y color por
  estado/urgencia.
- Qué campos nuevos mostrar y con qué prioridad (dado que no puede caber
  todo sin saturar la tarjeta).
- Sugerencias de micro-interacciones para reducir clicks (ej. swipe
  actions, botones de acceso directo, badges).

---

## 2) Contexto: Pantalla de detalle de Ticket (`TicketDetailScreen`)

Archivo actual: `lib/features/tickets/presentation/screens/ticket_detail_screen.dart`.

### Qué muestra hoy (de arriba hacia abajo)
1. AppBar con el código del ticket + (nuevo) botón eliminar si corresponde.
2. Título + chip de estado.
3. Aviso de "Rechazado" con motivo, si aplica.
4. Texto del `motivo`.
5. Metadatos en una fila (`Wrap`): generado por, tomado por, N° de informe,
   fecha límite.
6. Sección "Observaciones (N/M subsanadas)" con la lista de
   `TicketItemTile` — **se oculta por completo si el ticket no tiene ítems**
   (recién corregido: antes mostraba "Observaciones (0/0 subsanadas)" en
   tickets de tipo SOLICITUD, lo cual confundía porque ese tipo de ticket
   nunca tiene ítems que subsanar).
7. Sección "Historial" con la bitácora de acciones (tomado/soltado/
   finalizado/aprobado/rechazado).
8. Botonera inferior fija con acciones según estado/rol: Tomar, Soltar,
   Finalizar (nuevo), Rechazar/Aprobar (solo admin).

### Problemas / pedidos del usuario
- Se pide mejorar el diseño en general (layout, colores, mejor uso del
  espacio) y la eficiencia de los clicks para las acciones.
- Falta más contexto visible: tipo de inspección, centro/embarcación/área,
  no solo el número de informe.
- Los `TicketItemTile` (cada observación a subsanar) deberían mostrar, de
  forma clara y ordenada:
  - **Categoría de la pregunta** (viene de `formulario_items.categoria`,
    hoy NO se guarda en `ticket_items`, solo se concatena en el texto de
    `descripcion` la pregunta + observación).
  - **Número/orden de la pregunta** (viene de `formulario_items.orden`, hoy
    tampoco se guarda por separado).
  - **Foto** original (ya existe: `fotoOriginalUrl`).
  - **Texto de observación** del inspector (ya existe, concatenado dentro
    de `descripcion`).
  - Si el ítem es de origen `FOTO_OBSERVACION` (una foto general con
    observación, no ligada a una pregunta `NC`), debería verse claramente
    distinto: solo la foto + el texto de observación, SIN categoría/número
    de pregunta (porque no aplica).
  - Estado de subsanación (ya existe: switch + foto de subsanación).
- Nota importante para quien diseñe: **solo se generan ítems para
  respuestas "No Cumple" (NC) y fotos con observación** — esto ya está
  bien filtrado en el backend (`TicketRepository._armarItemsDesdeInspeccion`),
  no hay que preocuparse de que aparezcan ítems de preguntas "Cumple".

### Datos disponibles en `TicketItemModel` hoy
```
id, ticketId, origenItem (RESPUESTA_INSPECCION|FOTO_OBSERVACION|MANUAL),
referenciaId, descripcion, fotoOriginalUrl, subsanado, fotoSubsanacionUrl,
subsanadoPorId, subsanadoAt, orden, createdAt
```
**Nota:** `categoria` y `numeroPregunta` NO existen todavía como columnas
separadas en `ticket_items` (hoy van embebidos dentro de `descripcion` como
texto libre: `"<pregunta> — <observación>"`). Si el nuevo diseño necesita
mostrarlos como elementos visuales separados (badge de categoría, número en
un círculo, etc.), habrá que agregar esas columnas a la tabla
`ticket_items` y poblarlas en `_armarItemsDesdeInspeccion` — evaluar esto
recién cuando el diseño esté definido, para no migrar la BD dos veces.

### Qué se espera del diseño propuesto
- Reestructuración de la pantalla de detalle (qué va arriba, qué se agrupa,
  qué se colapsa).
- Diseño específico de la tarjeta de cada "ítem a subsanar" (ver lista de
  campos arriba), diferenciando el caso "pregunta NC" vs "foto con
  observación".
- Sugerencias para que las acciones (tomar/soltar/finalizar/aprobar/
  rechazar) sean más rápidas de ejecutar (menos scroll, botones más
  visibles, confirmaciones más livianas cuando no son destructivas).

---

## 3) Fuera de alcance para este rediseño (ya resuelto aparte)

- Ya se corrigió que un ticket sin observaciones (tipo SOLICITUD) pueda
  finalizarse/cerrarse (antes quedaba trabado en estado "Tomado" para
  siempre porque la única vía de finalización dependía de subsanar ítems
  que no existían).
- Ya se agregó confirmación al generar un ticket desde una inspección con
  100% de cumplimiento (sin ningún "No Cumple"), avisando si además hay
  fotos con observación registradas.
- Ya se agregó borrado (lógico) de tickets propios / por admin.
- Estos cambios son de lógica/backend, no afectan el diseño visual que se
  pide acá, salvo que se quiera agregar un botón "Eliminar" con buen
  affordance visual en la tarjeta o el detalle.
