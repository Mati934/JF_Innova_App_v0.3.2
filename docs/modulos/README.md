# Módulos

> Última revisión: 2026-10-22. Fuente de la lista: `lib/core/modules/module_registry.dart`,
> `lib/features/*` y `checklist_navigation_nodes` en Supabase.

Cada ficha tiene: qué hace, quién lo usa, reglas de negocio, tablas, pantallas,
archivos principales y pendientes. **Antes de trabajar en un módulo, leer su ficha.**

## Módulos con tarjeta en Home

| Ficha | Clave(s) | Estado |
|---|---|---|
| [Inspección de Buceo y Embarcación](inspeccion-buceo-embarcacion.md) | `INSPECCION` | En producción |
| [Registro de Visita (R-003)](registro-visita.md) | `VISITA_R003` | En producción |
| [Actividades – Vehículos Livianos](actividades-vehiculos.md) | `VISITA_ACTIVIDADES_VEHICULOS` | En producción |
| [Inspección de Extintores (R-004)](inspeccion-extintores.md) | `VISITA_R004` | En producción |
| [Mantención de Extintores PROSESSO](mantencion-prosesso.md) | `MANTENCION_PROSESSO` | En producción |
| [Hidroser](hidroser.md) | `HIDROSER` | En producción |
| [Merieux](merieux.md) | `MERIEUX_VISITAS`, `MERIEUX_EXTINTORES` | Demo / bajo uso |
| [AST](ast.md) | `AST` | En producción |
| [Equipamiento de Buceo](equipamiento-buceo.md) | `BUCEO_EQUIPAMIENTO` | Implementado, bajo uso |
| [Actividades Formativas](actividades-formativas.md) | `ACTIVIDADES_FORMATIVAS` | En producción, en ajustes |
| [Checklists Configurables](checklists-configurables.md) | nodos por empresa | Piloto |
| [Tickets](tickets.md) | `TICKETS` | En producción |
| [Historial](historial.md) | `HISTORY` | En producción |
| [Administración](administracion.md) | `ADMIN` | En producción (solo admin) |
| [Correo](correo.md) | `EMAIL_OUTBOX`, `EMAIL_ADMIN`, `EMAIL_TEST` | Etapa inicial |
| [Cronograma](cronograma.md) | `CRONOGRAMA_EMPRESAS`, `CRONOGRAMA_PLANTILLAS` | Implementación parcial |
| [Rendiciones](rendiciones.md) | `RENDICIONES` | Solo tarjeta (sin implementar) |

## Funcionalidades transversales

| Ficha | Qué cubre |
|---|---|
| [Inicio y borradores](inicio-y-borradores.md) | Home, tarjetas, lista de borradores. |
| [Sincronización offline](sincronizacion.md) | Subida/bajada de datos, PDFs diferidos, tickets automáticos. |
| [Acceso y multiempresa](acceso-y-empresas.md) | Login, sesión, roles, empresas del usuario. |

## Formato de una ficha

Ver la skill `documentar-app` (`.claude/skills/documentar-app/SKILL.md`).
