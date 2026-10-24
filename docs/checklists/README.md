# Catálogo de checklists

> Última revisión: 2026-10-22, consultando Supabase (`formulario_items`,
> `buceo_equipamiento_items`, `hidroser_listas`, `checklists`, `checklist_versions`,
> `empresa_modulos`, `checklist_navigation_nodes`).
> **Fecha** = primer commit del script SQL que lo carga (no prueba la fecha de
> ejecución en la base). **Dirigido a** = clientes que tienen habilitado el
> módulo o la tarjeta donde se usa. No se lista Servimaf (empresa propia, tiene todo).
> Traducción de códigos: [glosario](../glosario.md#checklists-código--nombre).

Hay **tres fuentes** de checklists:

1. **Banco clásico** `formulario_items` (por `tipo_actividad`): inspecciones,
   visitas, extintores, PROSESSO, Hidroser.
2. **Equipamiento de Buceo** `buceo_equipamiento_items` (por `lista_codigo`).
3. **Motor configurable** `checklists` + `checklist_versions` (preguntas en snapshot por versión).

## 1. Banco clásico (`formulario_items`)

| Código | Nombre | Dónde se usa | Categorías | Preguntas | Fecha | Dirigido a | Estado |
|---|---|---|---|---:|---|---|---|
| `INSPECCION_BUCEO` | Inspección de Buceo | [Inspección](../modulos/inspeccion-buceo-embarcacion.md) | 3: Equipo de buceo, Equipo personal, Seguridad y apoyo | 39 | 2026-01 (origen de la app) | AquaChile, JF Innova | Vigente |
| `INSPECCION_EMBARCACION` | Inspección de Embarcación | [Inspección](../modulos/inspeccion-buceo-embarcacion.md) | 6: Administrativo, Brazo hidráulico, Conductas, Infraestructura, Sala máquinas, Seguridad | 54 | 2026-02-26 (habilitada 2026-03-09) | AquaChile, JF Innova | Vigente |
| `VISITA_R004` | Inspección Extintores | [Extintores R-004](../modulos/inspeccion-extintores.md) | 1: Condiciones del extintor | 17 | 2026-03-26 | GNS, JF Innova | Vigente |
| `VISITA_R005` | Insp. Condiciones Eléctricas | [Registro de Visita](../modulos/registro-visita.md) | 1: Condiciones eléctricas generales | 12 | ≤ 2026-04-22 | GNS, JF Innova | Vigente |
| `VISITA_R006` | Insp. Pisos y Superficies | [Registro de Visita](../modulos/registro-visita.md) | 5: Superficies, Iluminación y tránsito, Orden y limpieza, Prevención de caídas, Señalización | 10 | ≤ 2026-04-22 | GNS, JF Innova | Vigente |
| `VISITA_R008` | Chequeo Vehículos Livianos | [Vehículos](../modulos/actividades-vehiculos.md), Registro de Visita, [Merieux](../modulos/merieux.md) | 1 | 20 | 2026-05-20 | Laboratorio CIBA, Vaxxinnova, Merieux NutriSciences, GNS, JF Innova | Vigente |
| `VISITA_R011` | Chequeo Máquina Soldadora | [Registro de Visita](../modulos/registro-visita.md) | 1 | 16 | 2026-05-20 | GNS, JF Innova | Vigente |
| `VISITA_R012` | Verificación Grúas Horquillas | [Hidroser](../modulos/hidroser.md) (lista `GRUA_HORQUILLA_PFA`) | 1 | 21 | 2026-05-26 | Hidroser (ex-cliente) | Sin cliente activo |
| `MANTENCION_PROSESSO` | Mantención de extintores | [PROSESSO](../modulos/mantencion-prosesso.md), [Merieux Extintores](../modulos/merieux.md) | 1: Inspección | 9 | ≤ 2026-06-09 | PROSESSO, Merieux NutriSciences | Vigente |
| `VISITA_CHEQUEO_HERRAMIENTAS_MANUALES` | Herramientas Manuales (versión vieja) | — | 1 | 20 | 2026-09-04 | — | **Oculto** 2026-10-22 |
| `VISITA_CHEQUEO_SOLDADORA_AL_ARCO` | Soldadora al Arco (versión vieja) | — | 1 | 13 | 2026-09-04 | — | **Oculto** 2026-10-22 |
| `VISITA_CHEQUEO_TALADRO_DESTORNILLADOR` | Taladro Destornillador (versión vieja) | — (2 visitas históricas) | 1 | 13 | 2026-09-04 | — | **Oculto** 2026-10-22 |
| `VISITA_CHEQUEO_ESMERIL_ANGULAR` | Esmeril Angular (versión vieja) | — | 1 | 16 | 2026-09-04 | — | **Oculto** 2026-10-22 |
| `VISITA_CHEQUEO_EXTENSION_ELECTRICA` | Extensión Eléctrica (versión vieja) | — | 1 | 10 | 2026-09-04 | — | **Oculto** 2026-10-22 |
| `BUCEO_SAL_20M`, `BUCEO_SAM_36M` | Copia de Equipamiento de Buceo | Ninguno (el módulo usa su tabla propia) | — | 84 / 52 | 2026-06-26 | — | Sin uso |

Los `VISITA_CHEQUEO_*` siguen en la base pero no se ofrecen en el Registro de
Visita: los reemplazan los `chq_*` del motor ([decisión](../decisiones/ocultar-checklists-herramientas-viejos.md)).
Fecha 2026-09-04 = primer uso registrado (el script tiene commit del 2026-09-14).

Campos extra (`formulario_campos_extra`): `VISITA_R008` → Patente, Kilometraje,
Conductor. `VISITA_R012` → N° de grúa, Hora inicio/horómetro, Hora término/horómetro.

## 2. Equipamiento de Buceo (`buceo_equipamiento_items`)

| Código | Nombre | Categorías | Preguntas | Fecha | Dirigido a |
|---|---|---|---:|---|---|
| `BUCEO_SAL_20M` | Inspección de equipo SAL – faena 20 m | 5: Checklist por buzo, Documentos, Emergencia, Equipos de apoyo 20 m, Manguera de buceo | 84 | 2026-06-26 | AquaChile, GNS, JF Innova, PROSESSO |
| `BUCEO_SAM_36M` | Inspección de equipo SAM – faena 36 m | 5: Documentos, Emergencia, Equipos de apoyo 36 m, Manguera de buceo, Unión compresora/manguera | 52 | 2026-06-26 | AquaChile, GNS, JF Innova, PROSESSO |

## 3. Motor configurable (`checklists`)

Tipo de formulario: `generic_standard_form` (PDF `standard_checklist_pdf`).
Todos en versión 1 publicada.

| Clave | Nombre | Grupo | Prefijo | Categorías | Preguntas | Campos dinámicos | Fecha | Dirigido a |
|---|---|---|---|---:|---:|---:|---|---|
| `chq_herramientas_manuales` | Herramientas Manuales | Herramientas y Equipos | HM | 1 | 20 | 8 | 2026-09-14 | M&S |
| `chq_soldadora_arco` | Soldadora al Arco | Herramientas y Equipos | SA | 1 | 13 | 8 | 2026-09-14 | M&S |
| `chq_taladro_destornillador` | Taladro Destornillador | Herramientas y Equipos | TD | 1 | 13 | 8 | 2026-09-14 | M&S |
| `chq_esmeril_angular` | Esmeril Angular | Herramientas y Equipos | EA | 1 | 16 | 8 | 2026-09-14 | M&S |
| `chq_extension_electrica` | Extensión Eléctrica | Herramientas y Equipos | EE | 1 | 10 | 8 | 2026-09-14 | M&S |
| `chq_equipo_critico` | Equipo Crítico | Equipos Críticos | MEC | 7 | 7 | 10 | 2026-10-03 | MB Embajadores |
| `chq_paradas_emergencia_cintas` | Paradas de Emergencia de Cintas | Equipos Críticos | MPE | 4 | 4 | 10 | 2026-10-03 | MB Embajadores |
| `chq_transpaleta_manual` | Transpaleta Manual | Equipos Críticos | MTP | 7 | 7 | 10 | 2026-10-03 | MB Embajadores |

Notas:

- Las preguntas de herramientas se copiaron de los `VISITA_CHEQUEO_*`. Documentos
  fuente en `documentos_checklists/Hechos/`.
- Equipos Críticos: preguntas iniciales pendientes de validar con Prevención de
  Riesgos (ver `documentos_checklists/Plan Nuevos Checklist/`).

## Por hacer (documentos fuente)

En `documentos_checklists/Por Hacer/`: catálogo preliminar y "Registro de
rotación de puestos" (no es checklist de inspección; fuera de alcance por ahora).

## Cómo agregar una fila

Ver la skill `documentar-app`. Al cargar un checklist nuevo, agregar una fila en
la sección de su fuente con fecha real y a qué cliente va dirigido.
