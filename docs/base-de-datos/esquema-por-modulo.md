# Esquema por módulo

> Última revisión: 2026-10-22. Filas = conteo aproximado en Supabase a esa fecha.
> Local = tabla espejo en SQLite (normalmente `<tabla>_pendientes`).

## Inspección de Buceo y Embarcación (`INSPECCION`)

| Supabase | Local | Contenido | Filas |
|---|---|---|---:|
| `actividades` | `actividades_pendientes` | Cabecera: tipo (`INSPECCION_BUCEO`, `INSPECCION_EMBARCACION`, `BITACORA`), centro, contratista, embarcación, fechas, horas, estado, `numero_informe`, `actividad_origen_id` (seguimiento). | 844 |
| `verificaciones_buceo` | `verificaciones_buceo` | 1:1 con actividad. Checks críticos de faena, nivel y profundidad, compresores, supervisor. | 739 |
| `verificaciones_embarcacion` | `verificaciones_embarcacion` | 1:1 con actividad de embarcación. | 70 |
| `actividad_participantes` | `actividad_participantes` | Cuadrilla: personal y rol en la faena. | 3170 |
| `inspeccion_respuestas` | `inspeccion_respuestas_pendientes` | Respuesta por pregunta (`C/NC/N/A`), observación, criticidad registrada. | 29162 |
| `registro_fotografico` | `fotos_pendientes` | Fotos por pregunta, generales y con observación. | 34852 |
| `formulario_items` | `formulario_items` | Banco de preguntas (catálogo). | 406 |

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
| `ast_correlativo_counters` | — | Contador del correlativo AST. | 1 |

## Equipamiento de Buceo (SAL/SAM)

| Supabase | Local | Contenido | Filas |
|---|---|---|---:|
| `buceo_equipamiento_listas` | `buceo_equipamiento_listas` | Listas `BUCEO_SAL_20M` y `BUCEO_SAM_36M`. | 2 |
| `buceo_equipamiento_items` | `buceo_equipamiento_items` | Preguntas por lista; `aplica_por_buzo` repite la pregunta por buzo. | 136 |
| `buceo_equipamiento_inspecciones` | `buceo_equipamiento_inspecciones_pendientes` | Cabecera. | 2 |
| `buceo_equipamiento_respuestas` | `buceo_equipamiento_respuestas_pendientes` | Respuestas. | 12 |
| `buceo_equipamiento_numeradores` | — | Numerador por lista. | 0 |

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
| `checklist_correlativo_counters` | — | Correlativo por checklist. | 0 |

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
