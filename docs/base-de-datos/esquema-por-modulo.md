# Esquema por módulo

> **Para qué es:** Qué tablas usa cada módulo, en SQLite y en Supabase, qué guarda cada una y su tamaño aproximado.

> Última revisión: 2026-11-18. Filas = conteo aproximado en Supabase al 2026-10-22.
> Local = tabla espejo en SQLite (normalmente `<tabla>_pendientes`).

## Numeración de informes (todos los módulos)

| Supabase | Local | Contenido | Filas |
|---|---|---|---:|
| `numeradores_informe` | — | Último número por empresa, tipo de informe y año (año 0 si no aplica). Solo lo escriben los triggers. Desde 2026-10-29; ver [decisión](../decisiones/numeracion-por-empresa.md). | 8 |

## Inspección de Buceo y Embarcación (`INSPECCION`)

| Supabase | Local | Contenido | Filas |
|---|---|---|---:|
| `actividades` | `actividades_pendientes` | Cabecera: tipo (`INSPECCION_BUCEO`, `INSPECCION_EMBARCACION`, `BITACORA`), centro, contratista, embarcación, fechas, horas, estado, `numero_informe`, `actividad_origen_id` (seguimiento), `formato_informe` (NULL = estándar, `SEAROV` = [Inspección Searov](../modulos/inspeccion-searov.md); desde v63), `inspector_nombre` y `recibe_nombre` (quién realiza y quién recibe, escritos en el formulario Searov; desde v64). Solo en SQLite: `firma_inspector_path`, `firma_recibe_path` (PNG en el dispositivo, no suben). | 844 |
| `verificaciones_buceo` | `verificaciones_buceo` | 1:1 con actividad. Checks críticos de faena, nivel y profundidad, compresores, supervisor. | 739 |
| `verificaciones_embarcacion` | `verificaciones_embarcacion` | 1:1 con actividad de embarcación. | 70 |
| `actividad_participantes` | `actividad_participantes` | Cuadrilla: personal y rol en la faena. `respuestas_personal` (jsonb, v63): respuestas por buzo de Inspección Searov. | 3170 |
| `inspeccion_respuestas` | `inspeccion_respuestas_pendientes` | Respuesta por pregunta (`C/NC/N/A`), observación, criticidad registrada. | 29162 |
| `registro_fotografico` | `fotos_pendientes` | Fotos por pregunta, generales y con observación. | 34852 |
| `formulario_items` | `formulario_items` | Banco de preguntas (catálogo). Desde v63: `potencialidad` (ALTA/MEDIA) y `aplica_por_buzo`, usados por Inspección Searov. | 406 |

## Registro de Visita, Extintores R-004, Vehículos y PROSESSO

| Supabase | Local | Contenido | Filas |
|---|---|---|---:|
| `visitas_tecnicas` | `visitas_tecnicas_pendientes` | Cabecera común. `tipo_actividad` distingue R-003, R-004, R-008 (vehículos), `MANTENCION_PROSESSO`. Sin `empresa_id` local (filtrar con JOIN a `usuarios`). | 401 |
| `visitas_checklists` | `visitas_checklists_pendientes` | Checklists anexos a una visita, respuestas en JSON. | 16 |
| `formulario_campos_extra` | `formulario_campos_extra` | Campos adicionales por checklist (ej. patente, kilometraje). | 6 |
| `extintores` | `extintores_pendientes` | Un registro por extintor inspeccionado (R-004). | 73 |
| `mantenciones_prosesso` | `mantenciones_prosesso_pendientes` | Extintores intervenidos en una mantención PROSESSO. | 25 |
| `visita_respuestas` | `visita_respuestas_pendientes` | Respuestas normalizadas de visitas. **0 filas**: pendiente de confirmar si está en uso. | 0 |

## Hidroser

| Supabase | Local | Contenido | Filas |
|---|---|---|---:|
| `hidroser_listas` | `hidroser_listas` | Listas disponibles (hoy: Grúas Horquillas, usa preguntas `VISITA_R012`). | 1 |
| `hidroser_inspecciones` | `hidroser_inspecciones_pendientes` | Cabecera, campos extra, dos firmas. | 1450 |
| `hidroser_respuestas` | `hidroser_respuestas_pendientes` | Respuestas por pregunta (`item_id` → `formulario_items`). | 31010 |

## Merieux

| Supabase | Local | Contenido | Filas |
|---|---|---|---:|
| `merieux_visitas` | `merieux_visitas_pendientes` | Cabecera común de visitas y extintores Merieux. | 2 |
| `merieux_visita_respuestas` | `merieux_visita_respuestas_pendientes` | Checklist opcional (Vehículos Livianos). | 0 |
| `merieux_extintores` | `merieux_extintores_pendientes` | Extintores de una mantención Merieux. | 1 |

## AST

| Supabase | Local | Contenido | Filas |
|---|---|---|---:|
| `ast_informes` | `ast_informes_pendientes` | Cabecera (área, centro, contratista, descripción). Correlativo propio. | 306 |
| `ast_hallazgos` | `ast_hallazgos_pendientes` | Hallazgos numerados con título, detalle y foto. | 114 |
| `ast_evidencias` | — | Fotos de hallazgos y galería. | 1159 |
| `ast_correlativo_counters` | — | Contador global AST por año. Desde 2026-10-29 solo respaldo (filas sin empresa); se usa `numeradores_informe`. | 1 |

## Equipamiento de Buceo (SAL/SAM)

| Supabase | Local | Contenido | Filas |
|---|---|---|---:|
| `buceo_equipamiento_listas` | `buceo_equipamiento_listas` | Listas `BUCEO_SAL_20M` y `BUCEO_SAM_36M`. | 2 |
| `buceo_equipamiento_items` | `buceo_equipamiento_items` | Preguntas por lista; `aplica_por_buzo` repite la pregunta por buzo. | 136 |
| `buceo_equipamiento_inspecciones` | `buceo_equipamiento_inspecciones_pendientes` | Cabecera. | 2 |
| `buceo_equipamiento_respuestas` | `buceo_equipamiento_respuestas_pendientes` | Respuestas. | 12 |
| `buceo_equipamiento_numeradores` | — | Numerador global por lista. Desde 2026-10-29 solo respaldo; se usa `numeradores_informe`. | 0 |

## Registro de inmersiones

Desde 2026-11-18 (app v65 local). Tablas de Supabase creadas por `supabase_migration_registro_inmersiones_v1.sql`
(**ejecutada el 2026-11-18**: las tablas ya existen en Supabase, vacías). Ficha: [registro-inmersiones](../modulos/registro-inmersiones.md).

| Supabase | Local | Contenido | Filas |
|---|---|---|---:|
| `registros_inmersion` | `registros_inmersion_pendientes` | Cabecera: 1 vigente por `actividad_id` (inspección de buceo), copias del día (centro, contratista, N° inspección, profundidad autorizada), `origen`, `estado_final`, `numero`/`correlativo` (RI-NNNN, trigger), `pdf_url`, `pdf_version`. Local: `pdf_path_local`, `subido`, `eliminado`. | 0 |
| `registro_inmersion_buzos` | `registro_inmersion_buzos_pendientes` | Una fila por persona: `personal_id` (nulo si es nueva), nombre, RUT, cargo, `realizo_inmersion`, resumen (`profundidad_maxima_m`, `tiempo_total_min`, `cantidad_inmersiones`, `excede_autorizada`), `marcado_rojo`, equipo (series normalizadas), nota. | 0 |
| `registro_inmersion_inmersiones` | `registro_inmersion_inmersiones_pendientes` | Una fila por bajada: `orden`, profundidad, `hora_inicio` (+ `hora_inicio_editada`), `hora_termino`, `tiempo_min`, `excede_autorizada`. | 0 |
| `registro_inmersion_fotos` | `registro_inmersion_fotos_pendientes` | Fotos con `tipo` y `buzo_id` (nulo = galería general). Bucket `evidencias`, carpeta `inmersiones/<registro>/`. Local: `local_path`. | 0 |

Trigger `trg_registro_inmersion_numero` (número al pasar a `Finalizado`, no gasta números en reintentos) y
`trg_actividades_baja_registro_inmersion` (si la inspección pasa a `Eliminada`, el registro también).
Rama `Registro de inmersiones` en `historial_unificado`.

## Actividades Formativas

| Supabase | Local | Contenido | Filas |
|---|---|---|---:|
| `actividades` (`tipo_actividad` formativa) | `actividades_pendientes` | Cabecera con correlativo propio. Aquí sí se llena `empresa_id`. | — |
| `actividad_formativa_registros` | `actividades_formativas_pendientes` | Detalle: tipo, horario, asistentes, relator, HH con y sin relator. | 15 |
| — | `formativa_fotos_eliminadas` | Fotos borradas pendientes de eliminar en Storage. | — |

## Checklists Configurables (motor)

| Supabase | Local | Contenido | Filas |
|---|---|---|---:|
| `checklist_form_types` | igual | Tipos de formulario (hoy `generic_standard_form`). | 1 |
| `checklists` | igual | Definición: clave, nombre, prefijo de informe, versión publicada. | 8 |
| `checklist_versions` | igual | Versiones con snapshot de preguntas, campos y reglas. | 8 |
| `checklist_navigation_nodes` | igual | Tarjetas y grupos en Home por empresa. | 29 |
| `checklist_permission_grants` | igual | Quién puede usar cada checklist (empresa/rol/usuario). | 80 |
| `checklist_campo_definiciones` / `checklist_campo_asignaciones` | — | Catálogo de campos dinámicos y asignación a checklists. | 10 / 70 |
| `checklist_inspecciones` | `checklist_inspecciones_pendientes` | Cabecera de cada inspección. | 15 |
| `checklist_respuestas` | `checklist_respuestas_pendientes` | Respuestas. | 245 |
| `checklist_campo_valores` | `checklist_campo_valores_pendientes` | Valores de campos dinámicos. | 104 |
| `checklist_evidencias` | `checklist_evidencias_pendientes` | Fotos. | 0 |
| `checklist_correlativo_counters` | — | Correlativo global por checklist. Desde 2026-10-29 solo respaldo; se usa `numeradores_informe`. | 0 |

## Tickets y hallazgos (solo online)

| Supabase | Contenido | Filas |
|---|---|---:|
| `nc_hallazgos` | Hallazgo único por contexto (empresa + tipo + pregunta + embarcación, abierto). | 189 |
| `nc_hallazgo_ocurrencias` | Cada vez que el hallazgo aparece en un informe. | 326 |
| `tickets` | Expediente de seguimiento (origen, tipo, estado, quién lo tomó). | 323 |
| `ticket_items` | Observaciones a subsanar. | 524 |
| `ticket_item_subsanaciones` | Evidencias de subsanación. | 140 |
| `ticket_historial_tomas` | Quién tomó/soltó el ticket. | 463 |
| `ticket_notificaciones` | Notificaciones del módulo. | 128 |
| `ticket_categorias` (local) | Categorías de ticket. | — |

## Correo

`correo_plantillas`, `correo_listas`, `correo_lista_destinatarios`,
`correo_configuracion`, `correo_usuario_asignacion`, `correo_pendientes`,
`correo_eventos` (trazabilidad). Todas con espejo local. Pocas filas (1 o 0) al
2026-10-22: el módulo está en etapa inicial.

## Cronograma (solo online)

`cronograma_clientes_empresas` (empresas cliente, independiente de `empresas`),
`cronograma_tipos_tarea`, `cronograma_plantillas`, `cronograma_plantilla_tareas`,
`cronograma_plantilla_asignaciones`, `cronograma_planes`, `cronograma_plan_tareas`,
`cronograma_tareas_programadas`, `cronograma_tareas_historial`,
`cronograma_tareas_evidencias`, `cronograma_tarea_inspecciones`,
`cronograma_grupos_usuarios`, `cronograma_grupo_usuarios`,
`cronograma_grupo_planes`, `cronograma_usuario_planes`, `cronograma_permisos`.
Casi todas con 0–1 filas al 2026-10-22.

## Historial

No tiene tablas propias: usa la RPC `historial_autorizado` (y la vista
`historial_unificado` según comentarios del código; pendiente de confirmar
definición actual en Supabase).
