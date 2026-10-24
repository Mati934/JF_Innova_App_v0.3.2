# Glosario y traductor de códigos

> Última revisión: 2026-10-22. Traduce entre lo que ve el usuario, lo que dice el
> código y lo que guarda la base. Columna "Fuente de verdad" = dónde se valida
> realmente el valor; si dos lugares no coinciden, manda esa.

## Empresas

| Nombre | Rol |
|---|---|
| **Servimaf** | Empresa propia (dueña de la app). Tiene todos los módulos habilitados y actúa como empresa administradora ("super admin" = admin de Servimaf). Que Servimaf tenga un módulo **no** significa que un cliente lo use. |
| **Hidroser** | Ex-cliente (dejó de trabajar con Servimaf en 2026). Su módulo `HIDROSER` queda solo en Servimaf, con su historial. |
| Demás empresas | Clientes: cada una ve solo sus módulos (ver [maestros](base-de-datos/maestros.md#módulos-habilitados-por-empresa-2026-10-22)). |

## Módulos: clave ↔ nombre en Inicio

| Clave (`modulo_key`) | Tarjeta en Inicio | Ficha |
|---|---|---|
| `INSPECCION` | Nueva Inspección – Barcos / Buceo | [ficha](modulos/inspeccion-buceo-embarcacion.md) |
| `VISITA_R003` | Registro de Visita – R-003 | [ficha](modulos/registro-visita.md) |
| `VISITA_ACTIVIDADES_VEHICULOS` | Registro de Actividades – Checklist Vehículos Livianos | [ficha](modulos/actividades-vehiculos.md) |
| `ACTIVIDADES_FORMATIVAS` | Registro de Actividad (charlas, capacitaciones) | [ficha](modulos/actividades-formativas.md) |
| `VISITA_R004` | Inspección Extintores | [ficha](modulos/inspeccion-extintores.md) |
| `MANTENCION_PROSESSO` | Mantención – Servicio de Extintores | [ficha](modulos/mantencion-prosesso.md) |
| `HIDROSER` | Hidroser – Listas de chequeo | [ficha](modulos/hidroser.md) |
| `MERIEUX_VISITAS` / `MERIEUX_EXTINTORES` | Merieux · Visitas / Merieux · Extintores | [ficha](modulos/merieux.md) |
| `AST` | AST – Análisis Seguro de Trabajo | [ficha](modulos/ast.md) |
| `BUCEO_EQUIPAMIENTO` | Eq. Buceo – SAL / SAM | [ficha](modulos/equipamiento-buceo.md) |
| `TICKETS` | Tickets | [ficha](modulos/tickets.md) |
| `HISTORY` | Historial | [ficha](modulos/historial.md) |
| `ADMIN` | Admin Maestros | [ficha](modulos/administracion.md) |
| `EMAIL_OUTBOX` / `EMAIL_ADMIN` / `EMAIL_TEST` | Bandeja correos / Admin Correos / Correo prueba | [ficha](modulos/correo.md) |
| `CRONOGRAMA_EMPRESAS` / `CRONOGRAMA_PLANTILLAS` | Cronograma / Plantillas Cronograma | [ficha](modulos/cronograma.md) |
| `RENDICIONES` | Rendiciones – Gastos (sin implementar) | [ficha](modulos/rendiciones.md) |

Ojo: "Registro de Actividad**es**" (vehículos) y "Registro de Actividad" (formativas) son módulos distintos.

## Checklists: código ↔ nombre

| Código(s) | Nombre | Estado |
|---|---|---|
| `INSPECCION_BUCEO` | Inspección de Buceo | Vigente |
| `INSPECCION_EMBARCACION` | Inspección de Embarcación | Vigente |
| `BITACORA` | Bitácora (puerto cerrado, sin checklist) | Vigente |
| `VISITA_R004` | Inspección Extintores | Vigente (módulo propio) |
| `VISITA_R005`, `VISITA_005`, `ELECTRICIDAD_R005` | Insp. Condiciones Eléctricas | Vigente (los dos últimos son alias antiguos) |
| `VISITA_R006`, `VISITA_006`, `PISOS_R006` | Insp. Pisos y Superficies | Vigente (alias antiguos) |
| `VISITA_R008`, `VEHICULOS_R008` | Chequeo Vehículos Livianos | Vigente |
| `VISITA_R011`, `SOLDADORA_R011` | Chequeo Máquina Soldadora | Vigente |
| `VISITA_R012` = lista Hidroser `GRUA_HORQUILLA_PFA` | Verificación Grúas Horquillas | Solo en módulo Hidroser |
| `VISITA_CHEQUEO_*` (= `VISITA_R013`–`R017` en etiquetas) | Herramientas (5) versión vieja | **Oculto** desde 2026-10-22; reemplazado por `chq_*` |
| `chq_herramientas_manuales`, `chq_soldadora_arco`, `chq_taladro_destornillador`, `chq_esmeril_angular`, `chq_extension_electrica` | Herramientas y Equipos (motor) | Vigente |
| `chq_equipo_critico`, `chq_paradas_emergencia_cintas`, `chq_transpaleta_manual` | Equipos Críticos (motor) | Vigente |
| `BUCEO_SAL_20M` / `BUCEO_SAM_36M` | Equipo SAL (20 m) / SAM (36 m) | Vigente |
| `MANTENCION_PROSESSO` | Mantención de extintores (9 puntos) | Vigente |

Las etiquetas visibles salen de `lib/features/visits/domain/visit_checklist_labels.dart`.

## Estados

| Entidad | Valores en la base | Etiqueta en la app | Fuente de verdad |
|---|---|---|---|
| Inspección / informe | `En Progreso`, `En Seguimiento` (+ `Habilitada`, `Suspendida`, `Rechazada`, `Finalizada`, `Eliminada`) | Borrador / Finalizado | Enum `estado_actividad` en `actividades.estado_final` |
| Ticket | `ABIERTO`, `TOMADO`, `PARCIAL`, `FINALIZADO_PENDIENTE_REVISION`, `CERRADO` | Abierto, Tomado, Parcial, Pendiente de revisión, Cerrado | Check `tickets_estado_check` (columna texto) + `TicketEstado` en código |
| Ticket (legado) | Enum `estado_ticket`: `Abierto, Tomado, En Progreso, Resuelto, Cerrado, Cancelado` | — | **Sin uso**: solo lo usa `ticket_historial` (vacía). No usar. |
| Origen de ticket | `INSPECCION`, `SOLICITUD` | — | Check `tickets_origen_check` |
| Tipo de ticket | `REVISION_OBSERVACIONES`, `SOLICITUD` | Revisión de observaciones, Solicitud | Check `tickets_tipo_ticket_check` |

## Respuestas y criticidad

| Base | App / PDF |
|---|---|
| `C` | Cumple (verde) |
| `NC` | No cumple (rojo, exige observación) |
| `N/A` (`NA` en PROSESSO) | No aplica |
| Motor configurable: Sí / No / No aplica | Cumple / No cumple / No aplica |

Criticidad: inspecciones `Tolerable / Moderado / Intolerable` ↔ tickets
`Bajo / Medio / Alto / Intolerable` ([decisión](decisiones/dos-escalas-criticidad.md)).

## Términos de negocio

| Término | Significado |
|---|---|
| AST | Análisis Seguro de Trabajo. |
| NC | No conformidad (respuesta "No cumple"). |
| Hallazgo | NC único por contexto (pregunta + embarcación) que se sigue con un ticket. |
| Ocurrencia | Cada vez que un hallazgo reaparece en un informe. |
| Subsanación | Corrección de un ítem del ticket, con foto de evidencia. |
| Faena | Trabajo de buceo en un centro; puede quedar habilitada o no según verificaciones. |
| Centro | Centro de cultivo o planta donde se inspecciona. |
| SAL / SAM | Sistemas de buceo para faenas de 20 m / 36 m. |
| HH | Horas-hombre (actividades formativas). |
| R-003, R-004… | Código de cada formulario/registro (ej. R-003 = Registro de Visita, R-004 = Extintores). Origen de la numeración: pendiente de confirmar. |
| N° de informe / correlativo | Número oficial asignado por Supabase al finalizar. |
| Borrador | Registro `En Progreso` guardado en el teléfono. |
| Módulo genérico | Tarjeta del motor de checklists configurables: misma pantalla y encabezado base, distinto checklist. Se crea con datos (skill `nuevo-checklist`). |
| Módulo normal | Módulo con código propio (pantalla, tablas, sync, PDF), registrado en `ModuleRegistry` (skill `nuevo-modulo`). |
| Tarjeta suelta / grupo | Las dos formas de mostrar módulos genéricos en Inicio: una tarjeta por checklist, o una tarjeta que agrupa varios. |
