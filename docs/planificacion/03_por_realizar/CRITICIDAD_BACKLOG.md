# Backlog: Criticidad fija por pregunta (AquaChile)

> **Para qué es:** Análisis y plan para que la criticidad sea fija por pregunta en la inspección de AquaChile, sin perder el historial.

> Estado: **planificación, no implementar todavía** · Análisis con datos reales: 2026-11-08
> Alcance: inspección de **buceo o de embarcación de AquaChile** (falta confirmar cuál, ver 0).
> Relacionado: [decisión de dos escalas](../../decisiones/dos-escalas-criticidad.md) ·
> [pendientes del dashboard](PENDIENTES_DASHBOARD.md) · [glosario](../../glosario.md)

## 0. Alcance (lo que pidió AquaChile)

- AquaChile pidió que **una** de sus inspecciones tenga criticidad **fija por pregunta** (que el auditor no la elija).
  Puede ser la de **buceo** (`INSPECCION_BUCEO`) o la de **embarcación** (`INSPECCION_EMBARCACION`).
  **Falta confirmar cuál** (Mati no lo recuerda con seguridad). Este documento cubre las dos y separa los datos de cada una.
- La otra inspección y los demás módulos siguen como hoy.
- Las preguntas (`formulario_items`) **no tienen empresa**: se comparten por tipo. Hoy no es un problema porque esos tipos
  son prácticamente solo de AquaChile:

| Tipo | AquaChile | Sin empresa* | Servimaf | JF Innova |
|---|---:|---:|---:|---:|
| `INSPECCION_BUCEO` | 769 | 32 | 9 | 7 |
| `INSPECCION_EMBARCACION` | 72 | 6 | 1 | 3 |

\* Usuarios sin empresa asignada; casi seguro son de AquaChile. Servimaf y JF Innova son pruebas.
Searov tiene sus propias preguntas (`*_SEAROV`), así que no le afecta.

> **Si mañana otro cliente usa `INSPECCION_BUCEO`**, heredaría la criticidad fija. La regla se configura
> por tipo de inspección; si algún día hace falta por empresa, hay que agregar esa opción.

## Resumen

| | |
|---|---|
| **Pregunta** | La pregunta tiene una criticidad fija, pero el auditor la elige a mano. ¿Aplicamos la fija **desde ahora** o también **cambiamos todas las respuestas que ya existen**? |
| **Respuesta corta** | **Desde ahora: fija y bloqueada** en la inspección que pidió AquaChile (es un requisito del cliente). **Las respuestas antiguas no se sobrescriben**: se agrega la fija como dato aparte. |
| **Por qué no sobrescribir** | Los auditores bajaron la fija en el 73 % de los NC de buceo. Sobrescribir borraría esa decisión y la base dejaría de coincidir con los PDF y tickets ya emitidos. |
| **Hallazgo importante** | **El dashboard ya muestra la criticidad fija** y no la del auditor. Hoy el mismo hallazgo puede decir "Moderado" en el PDF y en el ticket, e "Intolerable" en el dashboard. Esto explica los "demasiados Intolerables". |
| **Avisar a AquaChile** | Al bloquear, los PDF y tickets nuevos van a tener **más Intolerables** que antes (en buceo, 3 de cada 4 NC hoy se registran más bajos). |

---

## 1. Cómo funciona hoy

### App (inspección de buceo y embarcación)

1. La pregunta (`formulario_items.criticidad`) trae una criticidad fija.
2. El selector **solo aparece si la respuesta es NC**
   ([question_card.dart](../../../lib/features/inspection/presentation/widgets/question_card.dart)) y parte con la fija marcada.
3. El auditor la puede cambiar sin justificación.
4. Se guarda en `inspeccion_respuestas.criticidad_registrada`
   ([inspection_form_controller.dart:1185](../../../lib/features/inspection/presentation/controllers/inspection_form_controller.dart#L1185)).
5. **PDF**, **tickets** y **`nc_hallazgos`** usan `criticidad_registrada` (lo que eligió el auditor).

### Dashboard (`jf_innova_web/dashboard-jfinnova`)

**Usa la criticidad fija** (`formulario_items.criticidad`), no la registrada, en:

- `src/services/dashboard.service.ts` (consultas de respuestas NC, detalle por inspección y top de NC).
- `src/services/metrics.calc.ts` (top 5 de No Cumple).
- La función de Supabase `get_reporte_resumen` (informes semanal y mensual): `fi.criticidad`. Confirmado en la base real.

Detalle con líneas y cambios: [PENDIENTES_DASHBOARD.md](PENDIENTES_DASHBOARD.md#1-criticidad-usar-la-registrada-y-no-la-fija).

---

## 2. Lo que dicen los datos (Supabase, 2026-11-08)

### 2.1 Los auditores cambian la criticidad, casi siempre hacia abajo

No Cumple desde 2026-06-01 (después de corregir el error de guardado):

| Inspección | NC | Igual a la fija | **Bajaron** la fija | Subieron la fija | Auditores | Auditores que la cambian |
|---|---:|---:|---:|---:|---:|---:|
| Buceo | 474 | 111 (23 %) | **348 (73 %)** | 15 | 15 | 14 |
| Embarcación | 235 | 130 (55 %) | 78 (33 %) | 27 | 12 | 10 |

Lo más común: pregunta fija **Intolerable** registrada como **Moderado** (460 desde marzo) o **Tolerable** (299).
Casi todos los auditores lo hacen, así que no es un error de una persona: en terreno consideran que la fija
es alta. Si la inspección que se bloquea es la de **buceo**, el cambio va a ser muy visible; si es la de
**embarcación**, bastante menos.

### 2.2 Las respuestas C y N/A arrastran el error antiguo hasta mayo

| Mes | Respuestas C | C con criticidad = fija |
|---|---:|---:|
| 2026-02 a 2026-05 | 8.405 | 2.008 (24 %) |
| 2026-06 en adelante | 23.217 | 22.862 (98–100 %) |

Hasta mayo, lo que el auditor no tocaba se guardaba como "Tolerable". **En C y N/A la criticidad no afecta
nada** (el selector ni aparece), así que no tiene impacto.

### 2.3 Problemas del catálogo de preguntas

| Hallazgo | Detalle | Impacto |
|---|---|---|
| **El default de la columna es de la escala de tickets** | `formulario_items.criticidad` tiene `DEFAULT 'Bajo'`. Una pregunta nueva sin criticidad queda en "Bajo", que la inspección muestra como "Tolerable". | Error latente para preguntas nuevas. |
| Mucha criticidad alta | Buceo: 22 de 39 preguntas Intolerable (10 Moderado, 7 Tolerable). Embarcación: 29 de 54 (13 Moderado, 12 Tolerable). | Con bloqueo, más de la mitad de los NC salen Intolerable. |
| ¿Los valores están al día? | No se sabe si la criticidad cargada hoy es la que definió AquaChile (backlog original: "existe un Excel con la criticidad por pregunta"). | **Comparar con el Excel antes de bloquear.** |
| Searov: todo "Tolerable" | 143 preguntas iguales. | Fuera de alcance; anotado para cuando Searov la use. |
| Escalas mezcladas en visitas | `VISITA_R008/R011/R012` y `VISITA_CHEQUEO_*` usan `Alto/Medio/Bajo`. | Fuera de alcance; anotado. |

### 2.4 Diferencia entre PDF y dashboard (hoy)

NC con criticidad registrada ≠ fija (es decir, el PDF y el dashboard muestran cosas distintas):
**852 de 1.123 desde el 2026-03-29**. Esto pasa hoy, antes de cualquier cambio.

---

## 3. Las dos preguntas

### 3.1 Inspecciones nuevas (la que pidió AquaChile)

**Bloquear con la fija** (requisito del cliente):

- El selector se reemplaza por una etiqueta de solo lectura con la criticidad de la pregunta.
- `criticidad_registrada` = la fija, siempre.
- La regla se activa **por tipo de inspección** con una bandera, no en código suelto. El motor de checklists ya
  tiene ese patrón (`checklist_form_types.usa_criticidad` / `requiere_criticidad_nc`).
- **Offline:** la criticidad ya viaja en SQLite con las preguntas, no hace falta nada nuevo para leerla. La bandera sí
  tiene que estar en SQLite.
- La otra inspección (la que no pidió el cambio) sigue igual: selector libre.

Opcional, pero recomendado: si AquaChile acepta, dejar una vía para **subir** la criticidad (nunca bajarla) con motivo
escrito. Si no, bloqueo total.

### 3.2 Respuestas que ya existen

| Opción | Pros | Contras |
|---|---|---|
| Sobrescribir `criticidad_registrada` con la fija | Una sola columna. | **Se pierde** la decisión del auditor, sin vuelta atrás. La base deja de coincidir con los PDF y tickets emitidos. |
| **Agregar `criticidad_base` y llenarla con la fija** (recomendada) | No se pierde nada. Permite mostrar tanto "como se registró" como "con la regla nueva". | Una columna más y un script de copia. |
| No hacer nada | Sin trabajo. | Mezcla de criterios en las métricas. |

**Recomendación: `criticidad_base`.** Guarda lo que valía la pregunta el día de la inspección (la fija también
puede cambiar con el tiempo). Antes del 2026-03-29, `criticidad_registrada` no es confiable, así que ahí
`criticidad_base` es la mejor estimación.

### 3.3 ¿Qué muestra el dashboard?

Hay que decidir **una** fuente y usarla en todas partes:

- **Recomendado:** `criticidad_registrada`. Es la del PDF y la del ticket, y desde el bloqueo coincide con la fija.
- Si AquaChile quiere ver el pasado "con la regla nueva": se muestra `criticidad_base`, **con un rótulo claro**.
  Es exactamente lo que el dashboard ya hace hoy sin decirlo.

---

## 4. Plan por fases

| Fase | Qué se hace | Dónde | Reversible |
|---|---|---|:---:|
| **0. Confirmar** | ¿Buceo o embarcación? ¿La criticidad cargada coincide con el Excel de AquaChile? ¿Qué debe mostrar el dashboard para el pasado? | Reunión | — |
| **1. Catálogo** | Corregir las criticidades según el Excel (si difieren). Cambiar el `DEFAULT 'Bajo'` de `formulario_items.criticidad`. | Supabase | Sí |
| **2. `criticidad_base`** | Columna en `inspeccion_respuestas` (Supabase y SQLite) y copia de la fija actual. **No se toca `criticidad_registrada`.** | Supabase + app | Sí |
| **3. Bloqueo** | Bandera por tipo de inspección y selector de solo lectura en la inspección elegida. Guardar `criticidad_base` en las respuestas nuevas. Subir el patch del PDF si cambia lo que muestra. | App | Sí (apagando la bandera) |
| **4. Dashboard** | Usar una sola fuente (3.3) en servicio, métricas y `get_reporte_resumen`. Ver [PENDIENTES_DASHBOARD.md](PENDIENTES_DASHBOARD.md). | Dashboard + Supabase | Sí |

Orden sugerido: **4 puede ir antes que 3**. Corregir el dashboard para que use `criticidad_registrada` arregla hoy la
diferencia entre PDF y dashboard, aunque todavía no se bloquee nada.

### Puntos a cuidar

- **Tickets:** ya usan `criticidad_registrada`. Con el bloqueo van a subir de prioridad en la inspección elegida.
- **Versión de la DB local:** `criticidad_base` y la bandera requieren una migración nueva (`_dbVersion`).
- **Versiones viejas de la app:** mientras haya teléfonos sin actualizar, seguirán dejando elegir. Conviene que el
  servidor no dependa de eso: el dashboard puede usar `criticidad_base` para esa inspección si hace falta.

---

## 5. Excluido del alcance

- **Searov, visitas, checklists configurables, Hidroser, Equipamiento de buceo:** tienen su propia criticidad. Los
  problemas encontrados quedan anotados en 2.3.
- **PROSESSO** no usa criticidad (`NULL`): es el patrón "NULL = no aplica".

## 6. Preguntas abiertas

1. ¿La criticidad fija es para **buceo** o para **embarcación**? (o las dos más adelante)
2. ¿Dónde está el Excel de AquaChile con la criticidad por pregunta? ¿Coincide con lo cargado?
3. ¿El auditor puede **subir** la criticidad con un motivo, o bloqueo total?
4. ¿El dashboard muestra el pasado "como se registró" o "con la regla nueva"?

## Pendientes heredados (del backlog original)

- [ ] Conseguir el Excel con las criticidades definidas.
- [x] Revisar el campo `criticidad` de `formulario_items`: enum `nivel_criticidad` con las dos escalas, default `'Bajo'`.
- [x] Revisar el flujo cuando el usuario no elige: se usa la fija. No hay default a "Intolerable".
- [x] Causa de "demasiados Intolerables" en el dashboard: lee la fija, no la registrada (2026-11-08).
- [ ] Decidir la regla final (bloqueo total o permitir subir con motivo).
- [ ] Copia del pasado con `criticidad_base`, sin sobrescribir.
- [ ] Actualizar el formulario (solo la inspección elegida).
- [ ] Verificar que no aplica a PROSESSO.
- [ ] Revisar el impacto en el dashboard después del cambio.
