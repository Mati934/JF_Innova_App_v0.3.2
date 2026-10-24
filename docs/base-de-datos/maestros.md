# Datos maestros

> Última revisión: 2026-10-22 (filas aproximadas en Supabase a esa fecha).

Datos de referencia que usan todos los módulos. Se descargan a SQLite en
`descargarDatosMaestros()` (cada tabla por separado; si una falla, se registra
en Crashlytics y se informa la lista de tablas fallidas). Se editan en
[Administración](../modulos/administracion.md).

| Tabla | Qué es | Relación | Filas | Notas |
|---|---|---|---:|---|
| `empresas` | Servimaf (empresa propia) y clientes: AquaChile, GNS, Hidroser (ex-cliente), JF Innova, Laboratorio CIBA, M&S, MB Embajadores, Merieux NutriSciences, PROSESSO, Vaxxinnova. | — | 11 | Servimaf es la empresa administradora. |
| `areas` | Áreas operativas. | `empresa_id` (legado) y N:N vía `empresa_areas`. | 5 | Se descargan todas; filtro por empresa con `empresa_areas`. Si da vacío, se muestran todas. |
| `empresa_areas` | Qué áreas ve cada empresa. | empresas ↔ areas | 15 | |
| `centros` | Centros de cultivo / plantas. | `area_id` | 185 | |
| `contratistas` | Empresas contratistas inspeccionadas. | — | 91 | **Compartidos** entre empresas (sin `empresa_id`). |
| `embarcaciones` | Embarcaciones de los contratistas. | `contratista_id` | 174 | Compartidas entre empresas. Clave para Tickets. |
| `personal_externo` | Buzos, tripulación y personal de contratistas. | `contratista_id` | 522 | RUT normalizado. Hay registros sin contratista (limpieza de datos pendiente de decidir). |
| `usuarios` | Usuarios de la app (vinculados a `auth.users`). | `rol_id`, `empresa_id` (legado) | 36 | |
| `usuario_empresas` | Empresas a las que pertenece cada usuario. | usuarios ↔ empresas | 36 | Fuente principal de multiempresa. |
| `roles` | Roles (admin / prevencionista). | — | 2 | Pendiente de confirmar nombres exactos. |
| `empresa_modulos` | Módulos habilitados por empresa y su orden. | `empresa_id`, `modulo_key` | 168 | Ver tabla de habilitación abajo. |
| `dashboard_permisos_catalogo`, `usuario_dashboard_permisos` | Permisos del dashboard (fuera de la app móvil). | — | 12 / 2 | Pendiente de confirmar: el dashboard no vive en este repo. |

## Módulos habilitados por empresa (2026-10-22)

| Empresa | Módulos habilitados |
|---|---|
| AquaChile | INSPECCION, RENDICIONES, HISTORY, AST, TICKETS, ACTIVIDADES_FORMATIVAS, BUCEO_EQUIPAMIENTO |
| GNS | VISITA_R003, VISITA_R004, HISTORY, ACTIVIDADES_FORMATIVAS, BUCEO_EQUIPAMIENTO |
| Hidroser | ACTIVIDADES_FORMATIVAS |
| JF Innova | INSPECCION, VISITA_R003, VISITA_R004, RENDICIONES, HISTORY, AST, TICKETS, ACTIVIDADES_FORMATIVAS, BUCEO_EQUIPAMIENTO |
| Laboratorio CIBA | VISITA_ACTIVIDADES_VEHICULOS, HISTORY, ACTIVIDADES_FORMATIVAS |
| M&S | HISTORY, ACTIVIDADES_FORMATIVAS (+ checklists configurables de herramientas) |
| MB Embajadores | ACTIVIDADES_FORMATIVAS, HISTORY (+ checklists configurables de equipos críticos) |
| Merieux NutriSciences | HISTORY, MERIEUX_VISITAS, MERIEUX_EXTINTORES, ACTIVIDADES_FORMATIVAS |
| PROSESSO | MANTENCION_PROSESSO, HISTORY, ACTIVIDADES_FORMATIVAS, BUCEO_EQUIPAMIENTO |
| Servimaf | Todos menos RENDICIONES (incluye ADMIN, HIDROSER, EMAIL_*, CRONOGRAMA_*) + checklists de herramientas |
| Vaxxinnova | VISITA_ACTIVIDADES_VEHICULOS, HISTORY, ACTIVIDADES_FORMATIVAS |

Si una empresa no tiene configuración, la app usa los módulos por defecto de
`ModuleRegistry.defaultModuleKeys`: INSPECCION, VISITA_R003,
VISITA_ACTIVIDADES_VEHICULOS, VISITA_R004, EMAIL_OUTBOX, RENDICIONES.

Cómo leer esta tabla:

- **Servimaf es la empresa propia**: tiene todos los módulos para operar y
  administrar. Que Servimaf tenga un módulo no indica que un cliente lo use.
- Cada cliente ve solo sus módulos; por eso usuarios de distintas empresas ven
  Inicios distintos.
- **Hidroser es ex-cliente** (dejó de trabajar con Servimaf en 2026): su módulo
  `HIDROSER` queda solo en Servimaf.

Traducción de claves a nombres: [glosario](../glosario.md).
