# Instrucciones del proyecto

- Es una app Flutter/Dart para operaciones e inspecciones, con funciones offline/online, SQLite local y Supabase. Conserva el comportamiento de Android, web e iOS.
- Antes de cambiar código, busca implementaciones y patrones existentes en `lib/core` y `lib/features`; inspecciona el módulo vecino más parecido y reutiliza lo que ya funciona. No dupliques lógica ni reescribas módulos estables.
- Lee `README.md` y `docs/ESTABILIZACION_Y_MANTENIMIENTO.md` antes de cambios amplios; consulta la documentación específica del módulo cuando exista.
- Mantén los cambios acotados al objetivo. No agregues dependencias, funciones nuevas, refactors amplios ni cambios de infraestructura sin necesidad justificada.
- Protege credenciales y datos sensibles: no abras, imprimas ni incluyas en respuestas archivos de claves, secretos, firmas o configuración local. Nunca expongas credenciales en código, logs o documentación.
- La inspección de metadatos de Supabase está autorizada en modo de solo lectura, sin pedir permiso en cada consulta: tablas, columnas, funciones, triggers, secuencias, restricciones, índices, permisos y políticas RLS del proyecto relacionado con la tarea. Usa el acceso autenticado disponible y confirma el proyecto y entorno antes de consultar; no leas credenciales ni datos personales.
- Antes de cambiar persistencia, sincronización o correlativos, consulta los objetos relacionados en la base real; los scripts locales no prueban qué está desplegado. Consulta catálogos con SELECT y, cuando el acceso lo permita, una transacción READ ONLY; no invoques funciones de negocio ni nextval/setval para inspeccionar secuencias.
- No ejecutes escrituras, DDL, migraciones, cambios de permisos, reinicios de secuencias ni comandos destructivos en entornos remotos sin autorización explícita para el cambio y el entorno. Si falta acceso de lectura, informa el bloqueo y solicita habilitarlo; modificar instrucciones no concede permisos técnicos ni justifica eludirlos.
- Valida los cambios Dart con `flutter analyze` y pruebas dirigidas con `flutter test`; escala a la suite completa si el alcance lo requiere. La compilación y validación iOS final se hace en Mac.
- No reviertas ni sobrescribas cambios preexistentes del usuario. Resume qué cambió, qué validaste y cualquier limitación.

## Requisitos de PDF independientes del diseño

- Antes de crear un nuevo PDF, pregunta si debe incluir el pie de buceo/embarcación: `Generado por Servimaf`, contacto y versión. No lo omitas ni lo agregues por suposición; respeta una decisión ya confirmada para ese PDF.
- Para Actividades Formativas ya está confirmado: incluir ese pie; mostrar `N° Informe` debajo del logo en vez de `Correlativo`; mostrar únicamente las HH incluyendo al relator. Conservar ambas cifras de HH en persistencia para métricas.
- Estos requisitos son de contenido y deben mantenerse aunque el usuario rediseñe el PDF. No cambies el resto del diseño sin que lo solicite.

## Delegación y contexto

- El Agent principal puede elegir los agentes especializados disponibles sin que el usuario cambie de agente. Resuelve directamente consultas, cambios pequeños y un único flujo continuo; delega solo trabajo sustancial, acotado y separable que justifique contexto propio.
- Usa `Module Planner` cuando un cambio amplio necesite investigar patrones y límites antes de implementar; `Flutter Implementer` para una implementación delimitada y aprobada; `Change Reviewer` para una revisión separada de un cambio con riesgo significativo de regresión, permisos o pérdida de datos. No ejecutes los tres por defecto ni crees cadenas de subagentes.
- Cada delegación debe incluir objetivo, archivos conocidos, restricciones y resultado esperado. Evita que dos agentes editen los mismos archivos; utiliza sus resultados sin repetir su investigación, y valida mediante pruebas.
- Las skills aportan procedimientos, no trabajadores adicionales. Si una skill y un agente cubren la misma necesidad, aplica el procedimiento una sola vez, en el agente que realiza la tarea.
- Usa automáticamente la skill [Ponytail](skills/ponytail/SKILL.md), en nivel `full` por defecto, al escribir, corregir, refactorizar o revisar código y al elegir dependencias, sin esperar que el usuario la solicite. Cárgala una sola vez por contexto y no para consultas ajenas al código; respeta si el usuario cambia el nivel o la desactiva. Si no está disponible como skill, lee el archivo enlazado y aplica su procedimiento. No reemplaza las reglas de seguridad, arquitectura ni validación del proyecto.

## graphify

For any question about this repo's architecture, structure, components, or how to add/modify/find
code, your first action should be `graphify query "<question>"` when `graphify-out/graph.json`
exists. Use `graphify path "<A>" "<B>"` for relationship questions and `graphify explain "<concept>"`
for focused-concept questions. These return a scoped subgraph, usually much smaller than the full
report or raw grep output.

Triggers: "how do I…", "where is…", "what does … do", "add/modify a <component>",
"explain the architecture", or anything that depends on how files or classes relate.

If `graphify-out/wiki/index.md` exists, use it for broad navigation. Read `graphify-out/GRAPH_REPORT.md`
only for broad architecture review or when query/path/explain do not surface enough context. Only read
source files when (a) modifying/debugging specific code, (b) the graph lacks the needed detail, or
(c) the graph is missing or stale.

Type `/graphify` in Copilot Chat to build or update the graph.
