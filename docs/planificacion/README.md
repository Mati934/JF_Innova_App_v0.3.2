# Planificacion del Proyecto

Indice operativo de planes, pendientes, decisiones y referencias. La carpeta
clasifica por estado de trabajo; este indice tambien aclara el estado real de
cada documento para que una ruta antigua no se confunda con una tarea vigente.

## Clasificaciones

- **En ejecucion:** trabajo funcional o tecnico que ya se esta implementando.
- **Listo para implementar:** alcance definido; requiere priorizacion y
  ejecucion.
- **Pendiente / backlog:** idea o mejora sin alcance aprobado para construir.
- **Cerrado:** implementado o validado; puede conservar seguimientos puntuales.
- **Referencia:** contexto, decisiones, historiales o disenos anteriores; no
  inicia trabajo por si solo.
- **Plantilla:** estructura reutilizable para nuevos trabajos.

Las rutas existentes se conservan para no romper enlaces. Si la clasificacion
de este indice difiere de la carpeta historica donde vive un archivo, prevalece
la clasificacion indicada aqui.

## En ejecucion

- [Registro de Actividades Formativas](02_en_progreso/PLAN_REGISTRO_ACTIVIDADES_FORMATIVAS.md) —
  implementacion en curso; migracion Supabase pendiente.
- [Seguimiento operativo de Tickets](02_en_progreso/ERRORES_PENDIENTES_TICKETS.md) —
  correcciones implementadas; quedan verificaciones y limpieza de datos
  historicos por confirmar.
- [Conversaciones y reuniones](02_en_progreso/CONVERSACION_REUNIONES_AGOSTO_2026.md) —
  documento vivo que deriva ideas a planes concretos.

## Listo para implementar

- [Motor de Checklists Configurables](02_en_progreso/PLAN_MOTOR_CHECKLISTS_CONFIGURABLES.md).
- [Correo Outlook MVP](02_en_progreso/PLAN_CORREO_OUTLOOK_MVP.md).
- [Rediseno del informe HTML de Buceo](02_en_progreso/PLAN_REDISENO_INFORME_BUCEO_HTML_V0_2_0.md).

## Pendiente / backlog

- [Tickets automaticos por hallazgo AST](03_por_realizar/PLAN_TICKETS_POR_HALLAZGO_AST.md) —
  un ticket por cada registro de hallazgo, con vinculo e idempotencia propios.
- [Cronograma por empresas](02_en_progreso/PLAN_CRONOGRAMA_EMPRESAS_MVP.md) —
  alcance en definicion, aun no implementado.
- [Boceto de Tickets por Area](03_por_realizar/BOCETO_TICKETS_POR_AREA.md).
- [Criticidad de hallazgos](03_por_realizar/CRITICIDAD_BACKLOG.md).
- [Variables pendientes del dashboard de hallazgos](03_por_realizar/DASHBOARD_HALLAZGOS_VARIABLES_PENDIENTES.md).
- [Cumplimiento real despues de subsanar](03_por_realizar/IDEA_CUMPLIMIENTO_REAL_SUBSANACIONES.md).

## Cerrado

- [Continuidad de informes y Tickets NC](01_realizados/PLAN_CONTINUIDAD_INFORMES_Y_TICKETS_NC.md) —
  base funcional implementada; revisar sus pendientes de gobernanza antes de
  ampliar el modelo.
- [Actualizacion de Tickets 2026-09-03](01_realizados/ACTUALIZACION_TICKETS_2026-09-03.md) —
  estado del flujo implementado y sus limitaciones conocidas.
- [Dashboard: contexto validado](01_realizados/DASHBOARD_CONTEXT_VALIDADO.md).

## Referencia

- [Plan original de Tickets MVP](02_en_progreso/PLAN_TICKETS_MVP.md) —
  documento historico de requisitos; algunas decisiones y fases quedaron
  superadas por la implementacion. Para el comportamiento vigente, consultar
  los documentos cerrados de Tickets y el codigo actual.
- [Errores, playbook e historial](02_en_progreso/ERRORES_PLAYBOOK_Y_HISTORIAL.md).
- [Contexto de diseno visual de Tickets](00_referencia/CONTEXTO_DISENO_TICKETS.md).
- [Arquitectura de correos y listas por area](00_referencia/ARQUITECTURA_CORREOS_Y_LISTAS_POR_AREA.md).
- [Contexto general del proyecto](00_referencia/CONTEXTO_GENERAL.md).

## Plantillas

- [Creacion de modulos de inspeccion](99_plantillas/PLANTILLA_CREACION_MODULOS_INSPECCION.md).

Antes de iniciar un modulo nuevo, completar la plantilla y revisar los patrones
de referencia que indica. Para actividades formativas, usar su plan especifico
y no asumir que es el mismo modulo que vehiculos.

## Convenciones de interfaz para modulos

- Los borradores se integran en la lista general de Home, debajo de los demas
  borradores. El acceso al modulo abre directamente un formulario nuevo; no se
  crea una segunda bandeja de borradores dentro de la pantalla del modulo.
- Reutilizar `CustomDropdown` de `lib/shared/widgets/custom_dropdown.dart` para
  los campos desplegables, en vez de introducir dropdowns distintos.
- Para fecha y horarios, preferir tarjetas de seleccion claras y consistentes
  con el patron del Registro de Visita.
- Para firmas, reutilizar el patron de pizarra modal del Registro de Visita:
  abrir el area de firma al tocar la tarjeta y ofrecer limpiar/confirmar.
- Los formularios con borrador deben guardar cambios automaticamente con
  debounce mientras se editan, tener un guardado periodico de respaldo y
  persistir al pasar la app a segundo plano/suspenderse.
- Interceptar tanto el boton superior como el boton/gesto Atras del sistema
  para completar el guardado local antes de salir. No depender de un boton
  manual "Guardar borrador" como unico mecanismo; ofrecer guardado manual solo
  si el flujo del modulo realmente lo requiere.
