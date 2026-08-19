# Arquitectura de Correos y Listas por Area

## Estado actual

El modulo de correo funciona con cuatro entidades principales y una cola operativa:

```text
correo_plantillas
        |
        | plantilla_id
        v
correo_configuracion ---- lista_id ----> correo_listas ----> correo_lista_destinatarios
        |
        | config_id / lista_id
        v
correo_usuario_asignacion
```

La misma estructura existe en SQLite y en Supabase. SQLite se usa como fuente local/offline y Supabase como persistencia remota sincronizada.

## Relaciones actuales

### 1. Plantillas: `correo_plantillas`

Representa el contenido del correo:

- `id`: identificador persistible.
- `nombre`: nombre administrativo.
- `asunto_template`: asunto con variables.
- `cuerpo_template`: cuerpo con variables.
- `modulo`: modulo al que pertenece la plantilla.
- `empresa_id`: opcional; `NULL` significa plantilla global.
- `version`, `activo`, fechas y usuario que actualizo.

La plantilla no contiene destinatarios.

### 2. Listas: `correo_listas`

Representa un conjunto reutilizable de destinatarios:

- `id`: identificador persistible.
- `nombre`: nombre administrativo.
- `proposito`: descripcion de uso.
- `activo`, fechas.

La lista no conoce la plantilla ni el modulo.

### 3. Destinatarios: `correo_lista_destinatarios`

Cada fila pertenece a una lista mediante `lista_id`:

- `id`.
- `lista_id`.
- `nombre`.
- `correo`.
- `tipo_sugerido`: `to`, `cc` o `bcc`.
- `activo`.

Un destinatario puede reutilizarse en distintas listas mediante filas distintas.

### 4. Reglas: `correo_configuracion`

Es la relacion actual entre proceso, plantilla y lista:

- `id`.
- `modulo`.
- `plantilla_id`.
- `lista_id`.
- `empresa_id`: opcional; `NULL` significa regla global.
- `prioridad`: menor valor se evalua primero.
- `activo`.

La aplicacion resuelve actualmente una configuracion priorizando:

1. Asignacion explicita del usuario.
2. Regla de la empresa activa.
3. Regla global.
4. Menor prioridad.

Luego obtiene los destinatarios de la lista asociada y renderiza la plantilla.

### 5. Asignaciones: `correo_usuario_asignacion`

Limita el uso de una regla o lista a un usuario:

- `usuario_id` obligatorio.
- `config_id` opcional.
- `lista_id` opcional.
- `activo`.

Si existen asignaciones para la regla/lista, el usuario debe estar asignado para que la configuracion sea utilizable.

### 6. Operacion y auditoria

- `correo_pendientes`: cola local para correos que deben quedar disponibles o esperar sincronizacion.
- `correo_eventos`: auditoria local y sincronizable de estados, usuario, empresa, modulo, plantilla, lista, asunto, adjunto y destinatarios.
- `correo_pendientes` no debe usarse como historico: puede eliminarse cuando el correo se prepara externamente.
- `correo_eventos` es la fuente historica para metricas.

## Como se crean actualmente

El panel administrativo usa servicios `upsert`:

1. Se crea o edita una plantilla.
2. Se crea o edita una lista.
3. Se agregan destinatarios a la lista usando `lista_id`.
4. Se crea una regla seleccionando modulo, plantilla, lista, empresa opcional y prioridad.
5. Opcionalmente se crea una asignacion para restringir regla o lista a usuarios.

Los identificadores se generan con UUID al crear y se conservan al editar. Las ediciones usan `ConflictAlgorithm.replace` en SQLite.

Al eliminar:

- Eliminar una lista elimina sus destinatarios.
- Tambien elimina reglas que la usan.
- Tambien elimina asignaciones relacionadas.
- Eliminar una plantilla elimina reglas que la usan y sus asignaciones.
- El historico de `correo_eventos` no debe eliminarse junto con la configuracion.

## Necesidad futura: inspecciones por area

Para inspecciones de buceo y embarcacion se necesitan dos fuentes de destinatarios:

1. **Lista obligatoria**: siempre se agrega.
2. **Lista del area**: se agrega segun el `area_id` de la inspeccion.

La lista del area no debe depender del usuario, empresa ni solamente del modulo. El area debe identificarse por ID persistible, no por el nombre mostrado.

El resultado final debe ser:

```text
destinatarios finales =
  lista obligatoria
  + lista correspondiente al area
  + destinatarios agregados manualmente
```

Se deben eliminar duplicados por correo conservando el tipo de destinatario de mayor prioridad definida por negocio.

## Extension recomendada, sin romper lo actual

No cambiar el significado de `correo_listas`, `correo_lista_destinatarios` ni de las reglas existentes. Agregar el alcance a `correo_configuracion`:

- `alcance_tipo`: `GLOBAL`, `EMPRESA`, `USUARIO`, `AREA`.
- `area_id`: nullable.
- `tipo_lista`: `OBLIGATORIA`, `AREA`, `NORMAL`.

Compatibilidad:

- Las reglas actuales se interpretan como `tipo_lista = NORMAL`.
- Las reglas actuales conservan su comportamiento por modulo, empresa, usuario y prioridad.
- Una nueva regla `OBLIGATORIA` se combina con la regla de area; no la reemplaza.
- Una nueva regla `AREA` requiere `area_id` y no debe tener usuario como criterio principal.
- `plantilla_id` puede ser la misma para ambas reglas si el contenido es igual.
- `lista_id` sigue apuntando a `correo_listas`; no se duplica la tabla de listas.

Alternativa mas limpia si el negocio crece: crear una tabla de reglas de destinatarios separada de la configuracion de plantilla. No es necesaria para la primera implementacion y agregaria complejidad prematura.

## Resolucion futura para buceo y embarcacion

El resolver debe aceptar un contexto explicito:

```text
modulo
empresa_id
usuario_id
area_id
```

Orden sugerido:

1. Resolver plantilla usando las reglas actuales.
2. Buscar todas las listas obligatorias activas aplicables al modulo.
3. Buscar la lista activa cuyo `area_id` coincida.
4. Aplicar permisos de usuario solo a reglas normales o cuando una regla obligatoria lo indique expresamente.
5. Combinar destinatarios y deduplicar.
6. Guardar en `correo_eventos` el snapshot de `area_id`, nombre del area, listas usadas y destinatarios finales.

Si el area no tiene lista configurada:

- No debe fallar la inspeccion ni el PDF.
- Se envia la lista obligatoria si existe.
- Se registra un evento de advertencia/configuracion faltante.

## Metricas que quedaran disponibles

La fuente historica debe ser `correo_eventos`. Cada evento debe guardar un
snapshot de los datos que tenia el sistema en ese momento. No se debe depender
de que la plantilla, lista o usuario sigan existiendo o sean iguales despues.

### Dimensiones que debe conservar cada evento

- `id`, `event_type`, `event_timestamp` y `resultado_evento`.
- `usuario_id`, `empresa_id`, `modulo_key` e `inspeccion_id`.
- `area_id` y `area_nombre` como snapshot del area.
- `template_id`, `template_nombre` y `template_version`.
- `config_id`, `lista_id`, `lista_nombre`, `tipo_lista` y `alcance_tipo`.
- `canal`: `APP_OUTLOOK`, `MAILTO`, `SHARE` u otro canal futuro.
- `asunto_generado`, `adjunto_nombre` y `adjunto_tipo`.
- `destinatarios_json` y `destinatarios_count`.
- `listas_utilizadas_json` para el caso de lista obligatoria mas lista de area.
- `duracion_resolucion_ms` para detectar configuraciones lentas.
- `error_code` y `error_message` para soporte y calidad.

Los campos `area_id`, `area_nombre`, `tipo_lista`, `alcance_tipo`,
`listas_utilizadas_json` y `duracion_resolucion_ms` deben incorporarse cuando
se implemente el alcance por area. Los demas ya existen o forman parte de la
base de eventos actual.

### Eventos que deben diferenciarse

- `PENDIENTE_ENCOLADO`: se creo una cola local.
- `CORREO_ABIERTO_PREVIEW`: se abrio la vista de preparacion.
- `CORREO_PREPARADO_EXTERNO`: la app abrio Outlook, Share o `mailto` y recibio el retorno externo.
- `PENDIENTE_PROMOVIDO`: un correo que esperaba sincronizacion quedo disponible.
- `PENDIENTE_ACTUALIZADO`: se edito asunto, cuerpo o destinatarios.
- `PENDIENTE_ESTADO`: cambio de estado de la cola.
- `PENDIENTE_ELIMINADO`: se retiro de la cola.
- `ERROR_RESOLVIENDO_DESTINATARIOS`: no se pudo construir la lista final.
- `CONFIGURACION_AREA_FALTANTE`: el area no tenia lista configurada.
- `CORREO_ENVIADO_CONFIRMADO`: reservado para un futuro backend que controle realmente el envio.

Con Outlook o `mailto` no se puede confirmar que la persona presiono
"Enviar". La metrica actual debe llamarse "correos preparados externamente" y
no "correos entregados".

### Metricas ejecutivas

1. Correos preparados en el periodo: contar `CORREO_PREPARADO_EXTERNO`.
2. Correos preparados por mes: agrupar por mes de `event_timestamp`.
3. Usuario con mas correos preparados: agrupar por `usuario_id`.
4. Correos por area: agrupar por `area_id` y mostrar `area_nombre`.
5. Correos por empresa: agrupar por `empresa_id`.
6. Correos por modulo: agrupar por `modulo_key`.
7. Correos por tipo de lista: comparar `OBLIGATORIA`, `AREA`, `NORMAL` y `MANUAL`.
8. Destinatarios mas frecuentes: expandir `destinatarios_json` por correo.
9. Promedio de destinatarios: promediar `destinatarios_count`.
10. Cobertura por area: comparar inspecciones con area contra listas de area resueltas.
11. Areas sin configuracion: contar `CONFIGURACION_AREA_FALTANTE`.
12. Tasa de errores: dividir errores de resolucion por intentos de preparacion.
13. Pendientes actuales: contar `correo_pendientes` por estado; es metrica operativa.
14. Tiempo de preparacion: promediar `duracion_resolucion_ms`.
15. Uso de plantillas: agrupar por `template_id` y `template_version`.
16. Uso de reglas y listas: agrupar por `config_id`, `lista_id` y listas combinadas.
17. Correos con adjunto: contar eventos con `adjunto_nombre`.
18. Uso de canales: agrupar por `canal`.

### Metricas de calidad administrativa

El dashboard debe poder detectar:

- plantillas activas sin reglas;
- reglas activas sin destinatarios;
- listas activas vacias;
- destinatarios inactivos en listas activas;
- reglas duplicadas para modulo, empresa, area y prioridad;
- varias listas `AREA` activas para la misma area y modulo;
- usuarios con permisos pero sin reglas aplicables;
- eventos sin `usuario_id` o `empresa_id`;
- eventos que quedaron locales y no sincronizaron;
- ultimos errores de sincronizacion;
- diferencia entre encolados, previews y preparados externamente;
- cantidad de destinatarios `to`, `cc` y `bcc`.

No calcular historicos leyendo solo las tablas administrativas actuales. Si
cambia una lista, plantilla, area o usuario, el evento debe conservar sus IDs y
snapshots legibles para seguir describiendo lo que ocurrio en ese momento.

La app externa debe llamar a `correo_eventos`. `correo_pendientes` sirve para la operacion local, no para el dashboard historico.

## Migracion futura

Cuando se implemente esta extension se debe crear una migracion nueva, separada de `supabase_migration_email_mvp.sql` y `supabase_migration_email_metrics_v1.sql`.

Antes de ejecutarla en Supabase SQL Editor, preparar siempre un SQL de solo lectura que confirme:

- si existe `area_id` en la tabla de areas;
- si las columnas nuevas ya existen;
- si hay reglas actuales que puedan verse afectadas;
- si existen listas o configuraciones duplicadas.

Los archivos SQL del repositorio no se aplican automaticamente. La migracion debera ejecutarse manualmente en Supabase SQL Editor y verificarse despues con consultas de lectura.

## Decision actual

Por ahora no se modifica el metodo actual de creacion. Se conserva porque sus relaciones estan claras y funcionan:

```text
plantilla -> regla -> lista -> destinatarios
usuario -> asignacion -> regla/lista
```

La extension por area debe agregarse como un nuevo alcance de regla, manteniendo esos IDs y relaciones. No se deben crear listas especiales codificadas por nombre ni duplicar plantillas por cada area.
