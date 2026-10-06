# Conversacion de Producto - Reuniones de Agosto 2026

Fecha de consolidacion: 2026-09-02
Estado: Documento vivo para decidir y convertir ideas en planes

## Proposito

Este documento ordena las ideas de las minutas sin modificar sus fuentes.
Aqui se conversa y se toman decisiones; solo cuando una idea queda definida se
crea o actualiza su plan tecnico correspondiente.

## Fuentes sin modificar

- [REUNION-17-08-2026.md](../REUNION-17-08-2026.md)
- [REUNION-24-08-2026.md](../REUNION-24-08-2026.md)

## Como trabajar este documento

Para cada idea nueva, agregarla en "Bandeja de ideas". Al conversarla, moverla
a su tema y completar: decision, alcance inicial, dudas y siguiente paso.

Estados posibles:

- `IDEA`: anotada, aun sin decision.
- `POR DEFINIR`: requiere respuestas de negocio.
- `PLAN EXISTENTE`: ya tiene un documento que la desarrolla.
- `LISTA PARA PLANIFICAR`: alcance suficiente para escribir plan tecnico.
- `FUERA DE ALCANCE`: no se desarrollara por ahora.

---

## 1. Empresas, usuarios y modulos

Estado: `LISTA PARA PLANIFICAR`

### Decision de producto propuesta

- Un checklist se presenta al usuario como una tarjeta o "modulo" propio; no
  como una opcion escondida dentro de Registro de Visita.
- Los checklists que comparten cabecera, respuestas, evidencias, borradores,
  sincronizacion y formato de informe pertenecen a una **familia de
  formularios**. Crear uno nuevo dentro de la familia debe ser configuracion de
  datos, no una nueva pantalla, repositorio, tabla local ni rama de sync.
- La navegacion sera una estructura de nodos: un nodo puede abrir un checklist
  o agrupar otros nodos. Esto permite mostrar ocho checklists directamente en
  Home, o un solo modulo/carpeta que contiene los mismos ocho, sin mover ni
  alterar los informes existentes.
- La misma estructura permite varios niveles de agrupacion, por ejemplo:
  `Empresa -> Seguridad -> Equipos -> Checklist`.

### Ejemplo de resultado

Para una empresa se pueden habilitar ocho checklists de la familia
`INSPECCION_ESTANDAR`.

1. Vista directa: las ocho tarjetas aparecen en Home.
2. Vista agrupada: Home muestra la tarjeta "Inspecciones de Planta"; dentro
  aparecen las mismas ocho tarjetas.
3. Vista mixta: Home muestra "Inspecciones de Planta", un checklist directo y
  otra carpeta. Ninguna alternativa cambia el identificador del checklist ni
  los datos ya registrados.

### Arquitectura reutilizable propuesta

#### A. Motor comun de formularios

Un solo flujo generico se encarga de:

- crear, abrir, guardar y eliminar borradores;
- persistir cabecera, respuestas, fotos y firmas en SQLite;
- sincronizar los pendientes con Supabase;
- mostrar historial y pendientes de sincronizacion;
- aplicar permisos y dejar codigos de error visibles;
- generar el PDF indicado por la familia y el checklist.

No se copia un controlador ni una rama de sync por cada checklist. El motor
recibe una definicion de checklist y trabaja siempre con las mismas tablas de
cabecera y respuestas de su familia.

#### B. Familia de formularios

Una familia define el contrato que comparten sus checklists:

- `family_key`: identificador estable, por ejemplo `INSPECCION_ESTANDAR`.
- `permission_key`: permiso persistible requerido para abrirla.
- `header_schema`: campos de cabecera configurables (por ejemplo conductor,
  patente, marca, modelo o area).
- `response_schema`: reglas de respuesta, criticidad, observacion, fotos y
  firmas.
- `pdf_template_key`: plantilla PDF base que utiliza la familia.
- `storage_policy_key`: ruta y reglas de archivos.
- `ticket_policy_key`: regla de generacion de tickets, si aplica.

Solo se crea una familia nueva cuando cambian estos contratos. Ejemplos que
probablemente necesitan su propia familia: AST, actividades formativas y
registro de inmersiones. Un checklist de vehiculos y uno de gruas pueden vivir
en la misma familia si sus campos y PDF son compatibles.

#### C. Definicion de checklist

Cada checklist es un registro editable y versionable que referencia una
familia. Debe incluir:

- `checklist_key`: clave estable, nunca basada en el titulo visible.
- nombre, subtitulo, icono, color, orden y estado activo;
- `family_key` y `permission_key` propios;
- preguntas, categorias, criticidad y campos extra configurados por datos;
- `pdf_title` y variables permitidas para que una misma plantilla escriba el
  nombre correcto del checklist;
- configuracion por empresa: habilitado, orden y nodo de navegacion.

La app debe guardar tanto `family_key` como `checklist_key` en cada informe.
Asi el historial, el PDF, los tickets y la sincronizacion saben que se ejecutó
sin depender de donde estaba ubicada la tarjeta en Home.

#### D. Arbol de navegacion por empresa

Reemplazar gradualmente la lista plana `empresa_modulos` por nodos
configurables por empresa:

- `node_key`: identificador estable del nodo.
- `parent_node_key`: nulo para Home; referencia a otro nodo para crear grupos.
- `node_type`: `GROUP` o `CHECKLIST`.
- `checklist_key`: obligatorio solo en nodos `CHECKLIST`.
- titulo, icono, color, orden, habilitado y permiso requerido.

Cambiar un checklist de directo a agrupado consiste solo en actualizar su
`parent_node_key`. El informe conserva su `checklist_key`, por lo que el
cambio es reversible y no requiere migrar registros.

### Reglas que no se deben romper

1. La configuracion de modulos, familias, permisos y navegacion debe venir de
  Supabase y tener espejo SQLite para operar offline.
2. Cada tarjeta, grupo y checklist tiene identificador de permiso y clave
  persistible desde el inicio.
3. El panel de control es la fuente para reportes de actividad; no se crean
  consultas duplicadas por familia o checklist.
4. Un grupo no es un modulo de datos: solo organiza navegacion. No tiene
  borradores, informes ni sincronizacion propios.
5. El PDF se comparte por familia, pero recibe el nombre, preguntas, campos y
  logo del checklist. Si el formato cambia materialmente, se crea otra familia
  o una plantilla PDF declarada compatible.

### Relacion con lo que existe hoy

Hidroser ya demuestra parte de este modelo: una pantalla lista varios
checklists y usa `campos_extra` junto a `formulario_items`. Sin embargo, su
padre esta fijo en `ModuleRegistry`, sus tablas y sync son propias, y solo
soporta un nivel. La propuesta conserva el aprendizaje, pero extrae un motor
generico y hace la navegacion configurable por datos.

### Ideas recopiladas que cubre

- Crear empresa M&S con dos usuarios: dueno y supervisor. `LISTO`
- Crear otra empresa con usuario general y habilitar solo el chequeo de
  vehiculos livianos como registro de actividad.
- Soportar varias listas de chequeo y varios modulos por empresa.
- El pauteo general debe servir a todas las empresas, no quedar amarrado a M&S.
- A futuro, permitir crear y administrar listas de chequeo.

### Decisiones que aun necesitamos cerrar

1. Confirmar la primera familia a migrar o crear: vehiculos livianos seria el
  piloto recomendado porque prueba campos, checklist, PDF y permisos sin
  afectar los modulos especializados actuales.
2. Decidir que roles pueden crear, editar, activar, desactivar y reordenar
  familias, checklists y grupos. Recomendado: solo Super Admin al inicio.
3. Definir si una empresa puede sobrescribir preguntas globales o solo elegir
  de un catalogo central. Recomendado: catalogo central versionado y
  asignacion por empresa; las excepciones se modelan explicitamente.
4. Confirmar el limite de niveles de grupos. Recomendado: soportar varios en
  datos, pero limitar la interfaz inicial a dos o tres para no confundir.
5. Definir si el usuario ve todos los grupos habilitados o si algunos se
  asignan por rol/usuario dentro de la empresa.

### Siguiente paso propuesto

Escribir un plan tecnico separado para el "Motor de checklists configurables",
con migracion, espejo SQLite, sincronizacion, permisos y piloto de vehiculos
livianos. No se debe empezar a programar otro checklist independiente antes de
cerrar ese plan.

---

## 2. Inspeccion de extintores y registro de visita

Estado: `POR DEFINIR`

### Ideas recopiladas

- Mostrar el detalle del "No cumple" de cada extintor en el informe.
- Corregir observaciones generales de la inspeccion de extintores.
- Agregar correlativo a la inspeccion de extintores.
- Permitir anexar o referir una inspeccion de extintores desde un registro de
  visita.
- En el registro de visita, agregar conductor, marca y modelo del vehiculo.

### Decisiones pendientes

1. Definir si la referencia visita-inspeccion sera una sola inspeccion o varias.
2. Definir donde se mostrara la referencia: formulario, PDF, historial o los
   cuatro.
3. Confirmar formato y fuente del correlativo de extintores.

### Siguiente paso propuesto

Revisar un PDF real de extintores y una visita real para definir campos,
vinculo y resultado esperado antes de modificar datos historicos.

---

## 3. AST y criticidad

Estado: `PLAN EXISTENTE`

### Ideas recopiladas

- Si se marca "No" en AST, exigir determinacion de medida de control u
  observacion.
- Hacer obligatoria la criticidad.

### Documento relacionado

- [CRITICIDAD_BACKLOG.md](../03_por_realizar/CRITICIDAD_BACKLOG.md)

### Decision pendiente

Precisar si la criticidad obligatoria aplica solo a AST o a todos los modulos
que usan hallazgos. La regla debe provenir de datos maestros y mantenerse igual
en app, PDF, sincronizacion, tickets y panel de control.

---

## 4. Registro de inmersiones de buceo

Estado: `IDEA`

### Idea recopilada

Crear un registro posterior a la inspeccion de buceo, con fotos de
profundimetros y otros elementos. Debiera vincularse automaticamente a los
buzos participantes de la inspeccion.

### Preguntas para definir

1. Que campos y fotos son obligatorios?
2. Una inspeccion puede tener uno o varios registros de inmersion?
3. El registro necesita PDF, correlativo, firmas o tickets?
4. Se puede crear sin una inspeccion de buceo previa?
5. Que roles pueden crear, editar y ver el registro?

### Siguiente paso propuesto

Conseguir un ejemplo real del registro actual en papel o planilla y completar
la plantilla de creacion de modulos antes de programar.

---

## 5. Actividades formativas

Estado: `IDEA`

### Idea recopilada

Registrar charlas, servicios u otras actividades formativas. El relator firma
y las personas asistentes quedan como oyentes. Debe registrar fecha, hora de
inicio y termino, participantes, tipo y descripcion; calcular horas-hombre.

### Regla de negocio propuesta

Horas-hombre = cantidad de participantes x duracion de la actividad.

La duracion se redondea siempre hacia arriba a bloques de 15 minutos. Por
ejemplo, 16 minutos se registran como 30 minutos; el minimo es 15 minutos.

### Preguntas para definir

1. El tipo sera una lista cerrada (`Charla`, `Servicio`, `Otro`) o administrable?
2. Los oyentes deben firmar individualmente o basta el registro del relator?
3. Se requiere PDF, correlativo, fotos, ubicacion y empresa?
4. Las horas-hombre se muestran por actividad, mes, empresa y usuario?
5. Que permiso persistible controlara este modulo?

### Siguiente paso propuesto

Definir un formulario de ejemplo con una actividad real y confirmar la regla
de firmas antes de crear su plan tecnico.

---

## 6. Cronogramas por empresa

Estado: `PLAN EXISTENTE`

### Idea recopilada

Recibir una matriz anual por empresa para generar cronogramas automaticamente,
con tareas mensuales, cumplimiento por empresa y mes, y enlace hacia el modulo
que ejecuta cada tarea.

### Documento relacionado

- [PLAN_CRONOGRAMA_EMPRESAS_MVP.md](PLAN_CRONOGRAMA_EMPRESAS_MVP.md)

### Punto pendiente principal

Definir la plantilla o matriz anual que entregara cada empresa. Sin ese formato
no se debe automatizar la importacion.

---

## 7. Correo desde la aplicacion

Estado: `PLAN EXISTENTE / BLOQUEADO`

### Idea recopilada

Evaluar envio de correo desde la aplicacion.

### Documento relacionado

- [PLAN_CORREO_OUTLOOK_MVP.md](PLAN_CORREO_OUTLOOK_MVP.md)

### Bloqueo

Esperar confirmacion de negocio antes de avanzar en el alcance o integracion.

---

## 8. Usabilidad movil

Estado: `POR DEFINIR`

### Idea recopilada

Corregir reposicionamiento y comportamiento de zonas de texto en la app.

### Para diagnosticar

Registrar pantalla, modelo de telefono, orientacion, accion que provoca el
problema y captura o video. Es necesario distinguir teclado, scroll, texto que
se corta o controles que se superponen.

---

## Bandeja de ideas

Usar este bloque para notas nuevas antes de clasificarlas:

- [ ]

## Proxima conversacion sugerida

Elegir un solo tema para aterrizar primero. La prioridad recomendada es:

1. Empresas, usuarios y permisos.
2. Inspeccion de extintores y su vinculo con visita.
3. Actividades formativas o registro de inmersiones.
4. Plantilla anual para cronogramas.