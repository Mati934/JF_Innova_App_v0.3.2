# Documentación JF Innova App

> Índice general. Última revisión completa: **2026-10-22** (app `0.7.6+62`, DB local v`_dbVersion` en `database_helper.dart`).
> Mantenida con la skill `documentar-app` (`.claude/skills/documentar-app/SKILL.md`).

## Qué es la app

App móvil y web para **prevencionistas de riesgo** que trabajan en terreno, muchas
veces sin internet (centros de cultivo, embarcaciones, plantas). Permite:

- Hacer **inspecciones y listas de chequeo** (buceo, embarcaciones, extintores,
  vehículos, herramientas, equipos críticos, etc.) y generar su **informe PDF**.
- Registrar **AST**, **visitas técnicas** y **actividades formativas** (charlas,
  capacitaciones) con horas-hombre.
- Hacer **seguimiento de no conformidades** mediante **Tickets** hasta su cierre.
- Revisar el **historial de informes** y administrar datos maestros, módulos por
  empresa, correos y cronogramas.

Funciona **offline-first**: todo se guarda primero en el teléfono (SQLite) y se
sube a Supabase cuando hay conexión. Es **multiempresa**: cada empresa cliente ve
solo los módulos habilitados para ella. **Servimaf** es la empresa propia y
tiene todos los módulos.

## Mapa de la documentación

| Carpeta / archivo | Qué contiene |
|---|---|
| [glosario.md](glosario.md) | Traductor: claves de módulos, códigos de checklists, estados, respuestas y términos de negocio. Empresa propia vs clientes. |
| [arquitectura.md](arquitectura.md) | Stack, estructura de carpetas, cómo se conectan las partes y cómo ejecutar la app. |
| [base-de-datos/](base-de-datos/README.md) | Tablas por módulo, relaciones, estados y tipos de respuesta. |
| [modulos/](modulos/README.md) | Una ficha por módulo/funcionalidad: qué hace, reglas, tablas, pantallas, pendientes. |
| [checklists/](checklists/README.md) | Catálogo de todas las listas de chequeo cargadas. |
| [decisiones/](decisiones/README.md) | Decisiones de diseño importantes (qué, por qué, alternativas). |
| [CHANGELOG.md](CHANGELOG.md) | Registro de cambios por fecha. |

## Módulos (resumen)

| Módulo | Clave | Ficha |
|---|---|---|
| Inspección de Buceo y Embarcación | `INSPECCION` | [ficha](modulos/inspeccion-buceo-embarcacion.md) |
| Registro de Visita (R-003) | `VISITA_R003` | [ficha](modulos/registro-visita.md) |
| Registro de Actividades – Vehículos Livianos | `VISITA_ACTIVIDADES_VEHICULOS` | [ficha](modulos/actividades-vehiculos.md) |
| Inspección de Extintores (R-004) | `VISITA_R004` | [ficha](modulos/inspeccion-extintores.md) |
| Mantención de Extintores (PROSESSO) | `MANTENCION_PROSESSO` | [ficha](modulos/mantencion-prosesso.md) |
| Hidroser | `HIDROSER` | [ficha](modulos/hidroser.md) |
| Merieux (Visitas y Extintores) | `MERIEUX_VISITAS`, `MERIEUX_EXTINTORES` | [ficha](modulos/merieux.md) |
| AST – Análisis Seguro de Trabajo | `AST` | [ficha](modulos/ast.md) |
| Equipamiento de Buceo (SAL/SAM) | `BUCEO_EQUIPAMIENTO` | [ficha](modulos/equipamiento-buceo.md) |
| Actividades Formativas | `ACTIVIDADES_FORMATIVAS` | [ficha](modulos/actividades-formativas.md) |
| Checklists Configurables (motor) | nodos por empresa | [ficha](modulos/checklists-configurables.md) |
| Tickets | `TICKETS` | [ficha](modulos/tickets.md) |
| Historial | `HISTORY` | [ficha](modulos/historial.md) |
| Administración (maestros, módulos, checklists, usuarios) | `ADMIN` | [ficha](modulos/administracion.md) |
| Correo (bandeja y administración) | `EMAIL_OUTBOX`, `EMAIL_ADMIN`, `EMAIL_TEST` | [ficha](modulos/correo.md) |
| Cronograma | `CRONOGRAMA_EMPRESAS`, `CRONOGRAMA_PLANTILLAS` | [ficha](modulos/cronograma.md) |
| Rendiciones (sin implementar) | `RENDICIONES` | [ficha](modulos/rendiciones.md) |
| Inicio y borradores | — | [ficha](modulos/inicio-y-borradores.md) |
| Sincronización offline | — | [ficha](modulos/sincronizacion.md) |
| Acceso, sesión y multiempresa | — | [ficha](modulos/acceso-y-empresas.md) |

## Otra documentación existente (no reorganizada)

Se mantiene en su lugar para no romper enlaces desde `CLAUDE.md`,
`.github/copilot-instructions.md` y otros documentos.

- [planificacion/](planificacion/README.md): planes por estado (en progreso, por
  realizar, realizados, referencia, plantillas). Es la fuente de **qué se quiere
  hacer**; esta documentación describe **lo que existe hoy**.
- `1. Cosas/REUNIONES/`: minutas de reuniones (agosto–septiembre 2026).
- [ESTABILIZACION_Y_MANTENIMIENTO.md](ESTABILIZACION_Y_MANTENIMIENTO.md),
  [IOS_HANDOFF_MAC_CHECKLIST.md](IOS_HANDOFF_MAC_CHECKLIST.md),
  [RECORDATORIO_IPHONE_WEB.md](RECORDATORIO_IPHONE_WEB.md): operación y despliegue.
- [PROSESSO_MODULE.md](PROSESSO_MODULE.md), [PROSESSO_TASKS.md](PROSESSO_TASKS.md),
  [IMPLEMENTACION_HALLAZGO_UNICO_NC.md](IMPLEMENTACION_HALLAZGO_UNICO_NC.md),
  [MULTI_EMPRESA_DASHBOARD_HANDOFF.md](MULTI_EMPRESA_DASHBOARD_HANDOFF.md): documentos
  de detalle de módulos anteriores a esta estructura.
- `../documentos_checklists/`: documentos fuente (Word/markdown) de checklists
  hechos y por hacer.

## Convenciones de esta documentación

- Se basa **solo en código y datos reales**. Lo que no se pudo verificar está
  marcado como **"pendiente de confirmar"**.
- Prioriza **qué hace** la app y sus reglas de negocio sobre **cómo** está
  programada. El detalle técnico va solo donde ayuda a ubicar algo.
- Las cifras de la base (filas, empresas habilitadas) son una foto a la fecha
  indicada en cada archivo.
