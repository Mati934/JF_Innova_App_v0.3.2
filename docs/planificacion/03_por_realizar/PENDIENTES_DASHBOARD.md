# Pendientes del dashboard (jf_innova_web)

> Cambios que hay que hacer en el **dashboard web** a raíz de decisiones o hallazgos de la app.
> Proyecto: `C:\src\Proyectos\jf_innova_web\dashboard-jfinnova` (React + Vite + Supabase, repo aparte).
> El dashboard tiene su propio plan (`dashboard-jfinnova/TASKS.md`) y su propia lista de pendientes hacia la app
> (`jf_innova_web/PENDIENTES_FLUTTER.md`). Este archivo es lo contrario: **lo que la app le pide al dashboard**.

## Cómo usar este archivo

- Un pendiente por sección: **por qué**, **dónde** (archivo y línea del dashboard), **qué cambiar**, **estado**.
- El análisis largo vive en su documento de planificación; aquí solo va el enlace.
- Al terminar un cambio en el dashboard: marcar `[x]`, anotar la fecha y el commit del repo `jf_innova_web`.

| # | Pendiente | Origen | Estado |
|---|---|---|---|
| 1 | [Criticidad: usar la registrada y no la fija](#1-criticidad-usar-la-registrada-y-no-la-fija) | [CRITICIDAD_BACKLOG.md](CRITICIDAD_BACKLOG.md) | Por decidir |
| 2 | [Filtro de criticidad con un nivel que no existe](#2-filtro-de-criticidad-con-un-nivel-que-no-existe) | Revisión 2026-11-08 | Listo para hacer |
| 3 | [Informes semanal y mensual (reunión 29-10)](#3-informes-semanal-y-mensual-reunión-29-10) | [Reunión 29-10-2026](../../1.%20Cosas/REUNIONES/REUNION-29-10-2026.md) | En lista |
| 4 | [Compresores (si se implementa la propuesta)](#4-compresores-si-se-implementa-la-propuesta) | [PROPUESTA_COMPRESORES.md](PROPUESTA_COMPRESORES.md) | Depende de la propuesta |

---

## 1. Criticidad: usar la registrada y no la fija

**Por qué:** el dashboard muestra `formulario_items.criticidad` (la fija de la pregunta), pero el PDF, los tickets y
`nc_hallazgos` usan `inspeccion_respuestas.criticidad_registrada` (la que quedó en la inspección). En 852 de 1.123 NC
desde el 2026-03-29 son distintas: el mismo hallazgo dice "Moderado" en el PDF e "Intolerable" en el dashboard.
Esto explica los "demasiados Intolerables".

**Dónde (revisado el 2026-11-08, commit `4930d6c` de `jf_innova_web`):**

| Archivo | Línea aprox. | Qué hace hoy |
|---|---:|---|
| `src/services/dashboard.service.ts` | 322 | `select` de respuestas trae `formulario_items(criticidad)` y no `criticidad_registrada`. |
| `src/services/dashboard.service.ts` | 513 / 573 | Lista de NC por pregunta: `criticidad: fi?.criticidad`. |
| `src/services/dashboard.service.ts` | 648 / 746 | Detalle por inspección: criticidad de la pregunta. |
| `src/services/dashboard.service.ts` | 685 | Los 5 checks críticos de buceo (`BUCEO_VERIFICATION_ITEMS`) van fijos como "Intolerable". Correcto por negocio; solo dejarlo documentado. |
| `src/services/metrics.calc.ts` | 82 | Top 5 de No Cumple: `fi?.criticidad`. |
| `supabase/migrations/20260713_fix_reporte_resumen_end_date_inclusive.sql` | 356 | Función `get_reporte_resumen` (informes): `fi.criticidad::text`. **Está así en la base real.** |

**Qué cambiar (cuando se decida):**

- [ ] Traer `criticidad_registrada` en los `select` de respuestas y usarla en lugar de `fi.criticidad`.
- [ ] Si `criticidad_registrada` es NULL o la respuesta es anterior al 2026-03-29, usar la fija como respaldo
      (o `criticidad_base`, cuando exista).
- [ ] Nueva versión de `get_reporte_resumen` con el mismo criterio (migración nueva, no editar la existente).
- [ ] Top de NC agrupado por pregunta: decidir si muestra la criticidad de la pregunta (sirve para ordenar) o la
      más frecuente registrada. Sugerencia: mostrar la de la pregunta con el rótulo "criticidad de la pregunta".

**Decisión pendiente:** qué mostrar para el pasado, "como se registró" o "con la regla nueva". Ver
[CRITICIDAD_BACKLOG.md §3.3](CRITICIDAD_BACKLOG.md#33-qué-muestra-el-dashboard).

## 2. Filtro de criticidad con un nivel que no existe

- **Dónde:** `src/modules/dashboard/components/NcDetallePanel.tsx:14`:
  `['Tolerable', 'Moderado', 'Importante', 'Intolerable']`.
- "Importante" no existe en el enum `nivel_criticidad` de Supabase. Por eso el filtro nunca devuelve resultados.
- [ ] Quitar "Importante". Si se mezclan módulos con la escala de tickets, mapear con la equivalencia del
      [glosario](../../glosario.md) (Tolerable↔Bajo, Moderado↔Medio, Intolerable↔Alto).

## 3. Informes semanal y mensual (reunión 29-10)

Los puntos de formato, estructura, nombres (Puerto Cisnes, Puerto Natales, Auditor), tarjetas y gráficos están en la
[Parte 2 de la reunión 29-10-2026](../../1.%20Cosas/REUNIONES/REUNION-29-10-2026.md#1-dashboard-e-informes-ejecutivos-1).
No se copian aquí para no duplicar: al empezar ese trabajo, pasarlos a `dashboard-jfinnova/TASKS.md`.

## 4. Compresores (si se implementa la propuesta)

- Hoy el dashboard no usa compresores: no aparecen en `src/` ni en vistas o funciones de Supabase (revisado el 2026-11-08).
- Si se implementa [PROPUESTA_COMPRESORES.md](PROPUESTA_COMPRESORES.md): buscar `compresor_` en `src/` antes de la
  fase 5 (borrar columnas), y evaluar un indicador "faenas con compresor vencido".
