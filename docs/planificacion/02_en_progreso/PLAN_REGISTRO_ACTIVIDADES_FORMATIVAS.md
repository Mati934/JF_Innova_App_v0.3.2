# Registro de Actividades Formativas

Estado: `IMPLEMENTACION EN PROGRESO / CORRELATIVO INDEPENDIENTE APLICADO EN SUPABASE`

Este documento reúne lo encontrado sobre el registro de actividades formativas
para continuar definiendo el producto antes de programarlo. En las notas también
se le llama "registro de actividad"; aquí se usa "actividades formativas" para
distinguirlo del módulo de vehículos livianos que ya existe.

## 1. Idea recopilada

Registrar charlas, servicios u otras actividades formativas realizadas por la
empresa. La persona relatora firma como responsable de la actividad y quienes
participan como asistentes/oyentes. Se quiere contabilizar tanto el número de
actividades como las horas-hombre (HH) generadas.

La minuta lo describe como un formulario parecido al AST, pero sin hallazgos.

## 2. Requisitos que aparecen en las fuentes

- Tipo de actividad: `Charla`, `Servicio`, `Capacitación` u `Otro`.
- Si se elige `Otro`, pedir el tipo y permitir una descripción opcional.
- Fecha de la actividad.
- Hora de inicio y hora de término.
- Número de participantes; por ahora no se guardará la nómina ni el RUT de cada
  asistente.
- Duración de la actividad.
- Relator y firma del relator. No se requieren firmas individuales de
  asistentes.
- El número de participantes lo informa quien completa el registro, según las
  personas que contó.
- Conteo de actividades: cinco charlas deben contabilizarse como cinco
  actividades formativas.
- Cálculo de HH a partir de la cantidad de participantes y la duración.
- No incluir hallazgos como los de un AST.
- Operación offline-first y sincronización posterior, siguiendo el patrón
  habitual de los módulos de la app.
- Guardado como borrador al salir y posibilidad de generar PDF.
- Se requiere correlativo siguiendo el patrón que ya funciona en inspecciones
  de buceo o embarcación.
- No se requiere envío por correo.
- En la primera versión, cada registro tendrá una sola actividad y un solo
  relator.
- Las actividades que crucen medianoche quedan fuera de la primera versión.

## 3. Regla de HH recogida

La conversación de producto formula la regla así:

`HH = cantidad de participantes x duración de la actividad`

La duración se redondea siempre hacia arriba a intervalos de 15 minutos, con
un mínimo de 15 minutos. Ejemplos indicados en la minuta:

| Duración real | Duración contabilizada |
| --- | --- |
| Menos de 15 minutos | 15 minutos (mínimo) |
| 15 minutos | 15 minutos |
| 16 minutos | 30 minutos |

Por tanto, se redondea la duración de la actividad una vez y se multiplica por
el número de personas considerado. En la pantalla de ingreso se muestra
únicamente el total de HH incluyendo a un relator; el campo de asistentes
continúa excluyéndolo. Se conservan ambas cifras en los datos para métricas;
el PDF muestra únicamente las HH incluyendo al relator.

## 4. Distinción respecto del módulo existente

En `lib/core/modules/module_registry.dart` ya hay un módulo llamado
`Registro de Actividades`, con clave `VISITA_ACTIVIDADES_VEHICULOS`. Este abre
un checklist de vehículos livianos (`VISITA_R008`) y no corresponde al registro
de charlas/servicios y sus HH.

La minuta también menciona habilitar el chequeo de vehículos livianos para una
nueva empresa como registro de actividad. Es un caso de uso distinto; no debe
mezclarse con este registro formativo ni renombrarse sin una decisión explícita.

## 5. Decisiones recogidas y puntos pendientes

### Decisiones recogidas

| Tema | Decisión |
| --- | --- |
| Tipos | `Charla`, `Servicio` y `Otro` son opciones fijas. |
| Tipo `Otro` | Campo para indicar el tipo; descripción adicional opcional. |
| Asistencia | Guardar solo el número de participantes, no la nómina individual. |
| Firmas | Firma del relator; no firmas individuales de asistentes. |
| Asistencia parcial | Quien llena el registro declara el total de personas que contó. No se ajustan HH por entradas/salidas individuales. |
| Empresa | Obligatoria y tomada automáticamente de la sesión del usuario; no es el contratista. |
| Centro | Seleccionable, con opción `Sin centro`. |
| Área | Propuesta: sugerir automáticamente la última área de una inspección del usuario en la empresa activa, pero permitir modificarla. Si no existe una sugerencia, permitir seleccionarla. Incluir opción `Otro` con texto libre. |
| Borrador | Sí: guardar el progreso localmente para poder salir y continuar después. |
| Entregables | Se requiere PDF y correlativo; no se requiere correo. |
| Correlativo | Propio desde 1, independiente de buceo y embarcación; asignado por Supabase al finalizar. |
| Unidad de registro | Una actividad y un relator por registro. |
| Cruce de medianoche | Fuera del alcance de la primera versión. |
| Conectividad | Offline-first, con sincronización posterior como los demás módulos. |

### Confirmaciones y alcance por cerrar

1. **Relator dentro del conteo:** en el formulario, mostrar solo las HH que
   incluyen al relator. El número ingresado de asistentes no lo incluye.
   El PDF muestra solo las HH incluyendo al relator; la persistencia conserva
   ambas cifras para métricas.
2. **Área sugerida:** validar que la última área usada en una inspección sea
   una buena sugerencia inicial. El usuario podrá cambiarla; si no hay historial,
   elegirá una opción o escribirá `Otro`. Como aún estamos definiendo el alcance,
   el campo `Otro` puede retirarse antes de desarrollar si no resulta necesario.
3. **Datos adicionales:** confirmar si hacen falta cliente, ubicación u orden
   de servicio además de empresa, centro y área.
4. **Correlativo (resuelto):** secuencia exclusiva desde 1. Los borradores no
   consumen número; al finalizar sin conexión queda pendiente hasta sincronizar.
   El PDF oficial se regenera con el número debajo del logo.
5. **Resumen de actividad/HH:** no quedó entendido qué agrupaciones se
   necesitan. Propuesta para la primera versión: guardar HH por registro y
   dejar reportes agrupados (por mes, empresa, usuario o tipo) fuera de alcance
   hasta que se soliciten explícitamente.
6. **Acceso:** no hace falta inventar roles nuevos ahora. El módulo debe seguir
   los permisos y habilitación por empresa que ya usa la app; solo si se
   necesita restringirlo de forma distinta habrá que definir perfiles.

## 6. Plan funcional

### Nombre y alcance

- Nombre visible propuesto: `Registro de Actividades Formativas`.
- Clave de módulo propuesta: `ACTIVIDADES_FORMATIVAS` (validar que no exista
  en datos remotos antes de habilitarlo).
- Es un módulo de registro de charla/servicio, no una inspección, checklist ni
  el módulo de vehículos livianos existente.
- Cada registro contiene una actividad, una fecha, un relator y su firma.
- No incluye hallazgos, lista nominal de asistentes, firma de asistentes ni
  envío por correo.
- El acceso usará la habilitación por empresa y permisos existentes; no se
  introducirán roles nuevos para la v1.

### Flujo propuesto

1. Abrir el módulo y crear un registro.
2. Tomar la empresa desde la sesión autenticada; no pedirla en el formulario.
3. Elegir centro o `Sin centro`.
4. Sugerir el área más reciente de una inspección del mismo usuario en la
   empresa activa; permitir cambiarla. Si no hay área previa, permitir
   elegirla. `Otro` con texto libre es una opción provisional que se puede
   retirar antes de implementar.
5. Seleccionar `Charla`, `Servicio` u `Otro`. Para `Otro`, ingresar el tipo y,
   opcionalmente, una descripción.
6. Completar fecha, horas de inicio y término, número de asistentes, datos del
   relator y firma del relator.
7. Calcular y mostrar la duración contabilizada y el total de HH con relator.
8. Guardar progreso como borrador local o finalizar. Al finalizar se asigna el
   correlativo oficial siguiendo el patrón de inspecciones centrales.
9. Generar/actualizar el PDF con todos los datos del registro, las HH y el
   correlativo oficial. El registro se sincroniza cuando haya conexión.

### Contenido del PDF

El PDF debe reflejar todos los datos capturados y derivados: empresa, centro o
`Sin centro`, área (incluyendo texto si se elige `Otro`), tipo y descripción,
fecha, horas de inicio y término, asistentes, relator, firma y las HH incluyendo
al relator. No debe mostrar las duraciones real ni contabilizada; ambas se
mantienen en la captura, persistencia y cálculo de HH. También debe mostrar el
número oficial como `N° Informe` debajo del logo y la identidad visual
correspondiente a la empresa, junto al pie `Generado por Servimaf` en cada
página. No debe mostrar la fecha de emisión.
Desde la versión PDF `0.1.4`, el nombre sobre el título corresponde a la empresa
del registro, tomada de la empresa activa de la sesión mediante
`usuario_empresas` y `empresas`, no de `usuarios.empresa_id`. El pie sigue
identificando a Servimaf como generador.
No se enviará automáticamente por correo.

## 7. Reglas y modelo de datos propuestos

### Cálculo HH

- `duracion_real_minutos = hora_termino - hora_inicio`; la v1 rechaza una hora
  de término igual o anterior a la de inicio. Cruce de medianoche queda fuera.
- `duracion_contabilizada_minutos = max(15, ceil(duracion_real_minutos / 15) * 15)`.
- Capturar explícitamente la cantidad de asistentes/oyentes **sin incluir al
  relator**. El cálculo del total mostrado suma un relator a esa cantidad.
- `HH sin relator = asistentes * duracion_contabilizada_minutos / 60`.
- `HH con relator = (asistentes + 1) * duracion_contabilizada_minutos / 60`.
- Mostrar solo las HH con relator en pantalla, como horas decimales a dos
  decimales. Mantener ambas cifras en los datos, pero mostrar solo las HH con
  relator en el PDF; la duración guardada en minutos evita errores de redondeo
  acumulado.
- El usuario ingresa la cantidad observada; no se ajusta por llegadas/salidas
  parciales.

El campo de asistentes excluye al relator; este se agrega únicamente al
cálculo de las HH con relator.

### Campos mínimos de cabecera

| Campo | Tipo / regla |
| --- | --- |
| `id` | UUID generado localmente y estable al sincronizar. |
| `usuario_id` | Usuario autenticado, asignado desde sesión. |
| `empresa_id` | Obligatorio, empresa activa de la sesión; no contratista. |
| `centro_id` | Opcional; nulo representa `Sin centro`. |
| `area_id` | Opcional si se usa `Otro`; guardar la selección final, no solo la sugerencia. |
| `area_otro` | Texto opcional, solo cuando esté habilitado y seleccionado `Otro`. |
| `tipo_actividad` | `CHARLA`, `SERVICIO` u `OTRO` (claves estables; etiquetas visibles localizadas). |
| `tipo_otro` | Obligatorio si tipo `OTRO`. |
| `descripcion` | Texto opcional; incluye descripción libre cuando corresponda. |
| `fecha_realizacion` | Fecha de actividad. |
| `hora_inicio`, `hora_termino` | Horas locales; término debe ser posterior a inicio. |
| `asistentes` | Entero >= 0, asistentes/oyentes sin incluir al relator. |
| `duracion_real_minutos` | Derivado y persistido para que el registro histórico sea reproducible. |
| `duracion_contabilizada_minutos` | Derivado con regla de mínimo 15 y techo de 15 minutos. |
| `hh_sin_relator`, `hh_con_relator` | Derivados; recalculables desde valores base. |
| `relator_nombre` | Nombre requerido para completar. |
| `firma_relator` | Captura requerida al finalizar; almacenamiento remoto/local por definir según política común de firmas. |
| `estado_final` | `Borrador` / estado final alineado con los módulos actuales. |
| `numero_informe` / `correlativo` | Número oficial asignado al finalizar en servidor; nulo en borrador/offline pendiente. |
| `pdf_path_local`, `pdf_url` | Local-only path y URL sincronizada. |
| `subido`, `eliminado`, `created_at`, `updated_at` | Estado local/sync siguiendo convenciones existentes. |

Guardar también el snapshot necesario para que los informes históricos no
cambien si se renombran empresa, centro o área (por ejemplo, IDs y nombres
visibles usados al finalizar).

## 8. Plan técnico de implementación

### Decisión arquitectónica tomada

El registro formativo usa `actividades` / `actividades_pendientes` como
cabecera, para reutilizar el flujo de asignación al finalizar, con una secuencia
propia para `ACTIVIDAD_FORMATIVA`. Sus datos
específicos se guardan en `actividad_formativa_registros` en Supabase y
`actividades_formativas_pendientes` en SQLite. `Capacitación` es un tipo de
actividad, no una tabla ni un módulo separado. No se modifican
`capacitaciones_registros` / `capacitaciones_asistentes`, cuyo contrato externo
sigue pendiente de confirmación.

La tabla de detalle de
[`supabase_migration_actividades_formativas.sql`](../../../supabase_migration_actividades_formativas.sql)
se verificó desplegada en Supabase. El 17-10-2026 se aplicó, con autorización,
[`supabase_migration_actividades_formativas_correlativo.sql`](../../../supabase_migration_actividades_formativas_correlativo.sql)
en `AppJFInnova`: secuencia `seq_inf_actividad_formativa`, índice único parcial
para números positivos de este tipo y extensión de la función activa.
Se fijó su `search_path` y se conservaron las ramas de buceo y embarcación.
No se reiniciaron secuencias ni se numeraron registros eliminados.

### Convenciones de interfaz confirmadas

- Los borradores se muestran únicamente en la lista común de Home, junto a los
  demás módulos; al pulsar Actividades Formativas se abre un formulario nuevo.
- Los desplegables usan el componente compartido `CustomDropdown`.
- La fecha y las horas se presentan en tarjetas de selección visuales.
- La firma se captura en una pizarra modal con acciones para limpiar y confirmar,
  reutilizando el patrón existente en Registro de Visita.
- Los borradores se guardan automáticamente al editar (debounce), cada 30
  segundos si hay cambios y al suspender/enviar la app a segundo plano. El
  botón o gesto Atrás superior/sistema fuerza un guardado SQLite antes de salir;
  no hay botón manual "Guardar borrador".
- La pantalla tiene previsualización PDF. Empresa, área y centro se mantienen,
  sin el título `Contexto` ni el botón de ayuda del cálculo de HH.
  Áreas aparecen antes que centros; los centros se consultan mediante la
  relación empresa-área `empresa_areas`.
- La pantalla muestra solo el total de HH incluyendo al relator, sin alterar
  el conteo ingresado de asistentes. No se muestra el identificador interno del
  borrador; se mantienen el autoguardado y sus avisos de progreso o error.
- La tarjeta de participación ordena el ingreso de asistentes, las duraciones
  real y contabilizada en dos columnas, y el total de HH destacado al final.

### Persistencia local y modelo

- Feature sugerido: `lib/features/formative_activities/` (nombre final según
  convenciones del repositorio).
- Modelo tipado para cabecera/datos del reporte; no reutilizar
  `InspectionResponse`, criticidades ni hallazgos.
- Repositorio SQLite con guardar/actualizar en transacción, cargar borradores,
  recuperar registro, actualizar PDF y borrado lógico.
- Añadir esquema a `_createDB`, una migración nueva de `_onUpgrade` y
  `_repairCriticalSchema`; subir `_dbVersion` una vez.
- Revisar cómo obtener áreas/centros para la empresa activa y el área más
  reciente del usuario en esa misma empresa desde SQLite. La sugerencia será
  solo un valor inicial, nunca una selección bloqueada.
- Firma guardada en SQLite como bytes; se excluye del payload tabular remoto y
  se sube a Storage. Las rutas de archivos y estados locales tampoco se envían.

### Correlativo, finalización y PDF offline

- Seguir el comportamiento de `actividades`: borradores no consumen número;
  el número se asigna al finalizar en Supabase mediante
  `seq_inf_actividad_formativa`, desde 1 e independiente de las inspecciones.
  Reintentar el mismo ID conserva el número; un finalizado sin número puede
  recuperarlo al actualizarse. El borrado no reinicia esta secuencia.
- El número oficial no se calcula con `MAX + 1` en el cliente. Sin red, guardar
  el formulario finalizado como pendiente de sincronización sin inventar un
  correlativo definitivo.
- Usar la generación diferida del PDF oficial después de que el sync recupere
  el número asignado. La UI debe indicar claramente `PDF pendiente de
  sincronización` si todavía no puede generarlo con correlativo oficial.
- El PDF no debe bloquear el guardado offline. Al sincronizar, subir PDF a
  Storage, guardar `pdf_url` y marcar sincronización completa solo tras el
  resultado confirmado. Conservar/reintentar si falla la subida.
- El PDF local sin conexión muestra `N° Informe: Pendiente` debajo del logo.
  El flujo diferido reemplaza ese archivo y sube el PDF oficial cuando tiene un
  número positivo y el detalle está sincronizado. Muestra solo las HH incluyendo
  al relator; ambas cifras siguen guardadas para métricas.
- Requisitos de contenido confirmados, independientes del diseño: `N° Informe`
  debajo del logo y pie en cada página con `Generado por Servimaf`, contacto y
  versión, siguiendo buceo/embarcación. El resto del diseño lo define el usuario.
- Garantizar que una edición/reintento del mismo ID no asigne otro número ni
  cree un segundo registro; el sync será idempotente.

### Módulo, borradores e historial

- Registrar `ACTIVIDADES_FORMATIVAS` (clave provisional) en
  `ModuleRegistry`; habilitar por empresa con `empresa_modulos`, sin
  comprobaciones hardcodeadas por nombre.
- Incluir tarjeta propia en Home, borradores recuperables/eliminables y
  navegación de regreso al formulario.
- Agregar la actividad al historial unificado si la arquitectura de datos lo
  requiere; evitar duplicarla si queda representada por la cabecera común
  `actividades`.
- No añadir tickets ni bandeja de correos.

### Migración remota y control de acceso

- Aplicar la migración SQL idempotente ya preparada. Incluye FK, índice, RLS y
  habilitación del módulo por empresa; el correlativo reutiliza el trigger de
  `actividades`. Storage reutiliza el bucket `reportes` y sus políticas
  autenticadas existentes.
- `usuario_id` y `empresa_id` salen de la sesión, no de campos editables.
- RLS debe coincidir con las reglas multiempresa existentes; no copiar una
  política amplia de tablas antiguas sin revisar su acceso efectivo.
- Documentar la dependencia del panel externo antes de cambiar tablas
  `capacitaciones_*`.

## 9. Fases y tareas

1. **Contrato funcional:** confirmar que el conteo de asistentes excluye al
   relator, formato visible del correlativo y si se conserva `Otro` para área.
   Empresa automática, centro opcional y PDF con todos los datos/HH ya están
   definidos. La HH mostrada en formulario y PDF incluye al relator; las dos
   variantes se conservan en persistencia.
2. **Implementado localmente:** feature, formulario, validación, cálculo HH,
   firma, PDF local, borradores, selección de empresa/centro/área y migración
   SQLite v61.
3. **Integración en curso:** Home, historial, sincronización de detalle,
   reutilización de correlativo y regeneración/subida diferida del PDF.
4. **Validado el 17-10-2026:** análisis Dart dirigido sin incidencias y 48
   pruebas dirigidas aprobadas. El sync se probó con SQLite y HTTP simulado:
   borrador sin número, finalización offline→online, correlativo 1, PDF oficial,
   reintento sin renumerar y fallo/reintento de Storage. Se verificó el número
   debajo del logo en un PDF generado. La migración incluye autopruebas del
   trigger con tablas/secuencias temporales, sin consumir números reales.
   Sigue pendiente la validación en dispositivo y la compilación final iOS.
5. **Revisión de publicación 17-10-2026:** se confirmaron en producción las
   tablas, políticas RLS, índices, permisos de secuencias y trigger de
   correlativos, sin escrituras remotas. El bucket `reportes` es público y
   permite operaciones amplias a usuarios autenticados: los PDF y las imágenes
   de firma no tienen aislamiento privado de Storage. El responsable aceptó
   expresamente conservar este comportamiento para esta publicación; no se
   considera corregido. Privatizarlo requiere un cambio coordinado compatible
   con las versiones instaladas.
6. La finalización espera el autoguardado en curso, bloquea la edición durante
   el guardado y no puede ejecutarse simultáneamente con la vista previa del
   PDF. Se agregó cobertura de este bloqueo y de migración SQLite v60 a v61 con
   inspecciones, respuestas y firmas existentes.

## 10. Pruebas y definición de terminado

- HH para 0/1/varios asistentes, relator incluido/excluido, mínimo 15 min,
  15 min exactos, 16 min y duraciones mayores.
- Validaciones: término posterior a inicio; un formulario = una actividad/un
  relator; tipo `Otro` requiere tipo; descripción puede quedar vacía.
- Crear/guardar/reabrir/eliminar borrador offline; sincronizar sin duplicados.
- Empresa desde sesión, centro opcional, sugerencia del área reciente,
  modificación manual, estado sin sugerencia y opción `Otro` si se mantiene.
- Correlativo no consumido por borrador; asignación única al finalizar online y
  offline→online; PDF oficial contiene `N° Informe`, las HH con relator y el
  pie `Generado por Servimaf` en cada página.
- PDF reintenta tras fallo de Storage; datos siguen visibles localmente.
- RLS prueba acceso permitido/denegado y políticas no exponen firmas ni
  registros entre usuarios/empresas fuera de reglas autorizadas.
- Upgrade SQLite conserva datos existentes y crea el esquema nuevo.
- Módulo aparece solo para empresas habilitadas y sus borradores se recuperan
  desde Home.

La plantilla de creación de módulos se considera completada para este caso con
este plan adaptado: no aplican listas ni respuestas de checklist; sí aplican
persistencia offline, PDF, correlativo, firma, permisos, sync, borradores e
historial según la decisión arquitectónica.

## 11. Fuentes revisadas

- `docs/1. Cosas/REUNIONES/REUNION-24-08-2026.md`: nota original sobre
  actividades formativas, relator, oyentes, tipos, participantes y HH.
- `docs/planificacion/02_en_progreso/CONVERSACION_REUNIONES_AGOSTO_2026.md`,
  sección 5: consolida el cálculo de HH y lista preguntas de producto.
- `docs/planificacion/02_en_progreso/PLAN_MOTOR_CHECKLISTS_CONFIGURABLES.md`:
  señala que las actividades formativas probablemente requieren su propio tipo
  de formulario, en vez de forzarlas en el motor de checklists.
- `lib/core/modules/module_registry.dart`: define el módulo ya existente de
  actividades para vehículos livianos.
- `supabase_migration_numero_informe.sql` y `lib/features/sync/services/sync_service.dart`:
  correlativo asignado al finalizar y sincronización del informe.
- `lib/features/inspection/services/deferred_pdf_service.dart`:
  patrón de PDF diferido hasta recuperar el correlativo oficial.
- `supabase_migration_buceo_equipamiento_module.sql`:
  patrón alternativo de numeración por variante, no reutilizable tal cual si el
  registro formativo no tiene variantes.
- `supabase_migration_rls_visitas_emergency.sql`: evidencia de tablas
  `capacitaciones_registros` / `capacitaciones_asistentes`; su esquema y dueño
  funcional aún deben confirmarse y no se usan en esta implementación.

## 12. Siguiente paso

Validar el recorrido completo en dispositivo con la nueva versión de la app:
finalizar offline, sincronizar y abrir el PDF oficial con correlativo bajo el
logo. La primera asignación real parte de 1; las autopruebas no la consumieron.
El contrato externo de `capacitaciones_*` sigue fuera de este cambio.
