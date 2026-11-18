# Plan: demo Searov SpA (inspección de buceo y embarcación)

> **Para qué es:** Plan y avance de la demo para Searov SpA (inspección de buceo y embarcación con formato propio).

**Estado:** en ejecución (iniciado 2026-10-29).
**Pedido:** Tío Jorge, 2026-10-21. Searov SpA es un servicio de buceo con varios
buzos; quiere un demo que haga inspección de buceo y de embarcaciones.
**Fuentes:** `documentos_checklists/Hechos/`
- `LISTA CHEQUEO FAENAS BUCEO 20 y 36 metros searov spa.pdf` (lista propia de Searov).
- `Formato Inspeccion Barcos-Barcazas_V10_Mayo-2026 (1).xlsx` (formato de Cermaq, mandante de Searov).

## Decisiones (Mati, 2026-10-29)

| Tema | Decisión |
|---|---|
| Empresa | "Searov SpA", sin RUT ni logo. Mati crea empresas y usuarios en la base (skill `nueva-empresa-demo` genera el SQL y dice qué falta). |
| Tipo de módulo | **Módulo propio** `INSPECCION_SEAROV` (no checklist del motor: pide ítems por buzo y PDF propio). Reusa las pantallas de Inspección; el PDF y las preguntas van atados al módulo. Los módulos existentes no cambian de comportamiento. |
| Nombre visible | Igual que Inspección ("Nueva Inspección"); la clave `INSPECCION_SEAROV` y el formato `SEAROV` no se muestran. |
| Formato | Cada actividad guarda `formato_informe = 'SEAROV'`; `tipo_actividad` sigue siendo `INSPECCION_BUCEO` / `INSPECCION_EMBARCACION` (numeración por empresa, Historial). |
| Logo | Sin logo: el PDF escribe el nombre de la empresa. |
| Preguntas | `formulario_items` con claves `INSPECCION_BUCEO_SEAROV` (68) e `INSPECCION_EMBARCACION_SEAROV` (75). |
| Ítems por buzo (buceo) | Al agregar un buzo, sus 11 ítems de "Personal" parten en Cumple; el usuario cambia los que fallan. Un NC de un buzo deja la pregunta en NC. |
| Potencialidad ALTA/MEDIA (embarcación) | Medición **separada** de la criticidad. Resultado: Faena autorizada / Autorizada condicional / Rechazada; se guarda en `estado_faena`. |
| Numeración | Por empresa y tipo de informe: Searov parte en 1. |
| PDF | `searov_pdf_service.dart` (hoy v0.3.0), estilo técnico tipo planilla con el checklist estructurado como el PDF estándar de buceo. |

## Etapas

1. **Numeración por empresa** — **Hecho 2026-10-29** ([decisión](../../decisiones/numeracion-por-empresa.md)).
2. **Módulo `INSPECCION_SEAROV`** (app): registro, formato por actividad, preguntas
   por buzo, potencialidad, PDF propio, PDF diferido, SQLite v63, sync. — **Hecho en código 2026-10-29**, sin publicar.
3. **Supabase**: `supabase_migration_inspeccion_searov_module.sql` (columnas,
   empresa, módulos, preguntas). — **Hecho 2026-10-29** (68 + 75 preguntas,
   módulo habilitado). Firmas: `supabase_migration_inspeccion_firmas_v1.sql` — **Hecho 2026-10-29**.
4. Usuario de Searov asociado a la empresa — **Hecho 2026-10-29**. Falta publicar la app.
5. Ajustes de la demo (sin estado final ni verificaciones IV–VIII, firmas con
   pizarra, PDF v0.3.0) — **Hecho 2026-10-29**. Dashboard: anotado como
   observación en la [ficha del módulo](../../modulos/inspeccion-searov.md).

## Preguntas para la reunión con el tío Jorge

Campos de encabezado que piden los formatos y que la inspección actual no tiene:

- Buceo: **tipo de faena Interna / Contratista**, **matrícula del compresor**
  (hoy hay compresores, sin matrícula). Centro, fecha, contratista, supervisor y
  buzos con RUT ya existen.
- Embarcación: **nombre del servicio**, **persona que recibe la inspección**,
  **N° de trabajadores**, **motivo (Validación / Rutinario)**. Área, fecha,
  embarcación y matrícula ya existen.
- Embarcación: ¿quieren el **resumen de acciones correctivas** con responsable,
  fecha de cumplimiento y fecha de control (como el xlsx)?
- ¿El PDF debe decir que el formato es el de Cermaq, o solo Searov?
- Buceo: ¿máximo 7 buzos como la hoja, o sin límite?
- Buceo: el PDF de Searov junta 20 y 36 m. ¿Se responden ambas secciones siempre,
  o se elige la profundidad y se muestra solo una?
