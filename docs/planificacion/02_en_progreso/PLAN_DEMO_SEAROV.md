# Plan: demo Searov SpA (inspección de buceo y embarcación)

**Estado:** en ejecución (iniciado 2026-10-29).
**Pedido:** Tío Jorge, 2026-10-21. Searov SpA es un servicio de buceo con varios
buzos; quiere un demo que haga inspección de buceo y de embarcaciones.
**Fuentes:** `documentos_checklists/Por Hacer/`
- `LISTA CHEQUEO FAENAS BUCEO 20 y 36 metros searov spa.pdf` (lista propia de Searov).
- `Formato Inspeccion Barcos-Barcazas_V10_Mayo-2026 (1).xlsx` (formato de Cermaq, mandante de Searov).

## Decisiones (Mati, 2026-10-29)

| Tema | Decisión |
|---|---|
| Empresa | Crear "Searov SpA", sin RUT ni logo. Mati crea los usuarios. |
| Logo | Sin logo: el PDF muestra el nombre de la empresa. Hoy el respaldo es el logo de AquaChile (hay que corregirlo). |
| Flujo | Mismo módulo `INSPECCION` (mismas pantallas). La variante se distingue con un código interno `formato_informe` (`ESTANDAR` / `SEAROV`) que el usuario no ve. `tipo_actividad` sigue siendo `INSPECCION_BUCEO` / `INSPECCION_EMBARCACION`. |
| Preguntas | Propias de Searov en `formulario_items` con claves `INSPECCION_BUCEO_SEAROV` e `INSPECCION_EMBARCACION_SEAROV`. |
| Ítems por buzo (buceo) | Al agregar un buzo a la cuadrilla, sus ítems de "Personal" quedan en Cumple; el usuario cambia los que fallan. |
| Potencialidad ALTA/MEDIA (embarcación) | Medición **separada** de la criticidad: columna propia por pregunta y cálculo propio del resultado (Aprobada / Autorizada condicional / Rechazada). No se mapea a Tolerable/Moderado/Intolerable. |
| Numeración | Por empresa y módulo. AquaChile continúa su número; empresa nueva parte en 1. |
| PDF | Generador nuevo, estilo técnico profesional, versión propia. El de AquaChile no cambia. |

## Etapas

1. **Numeración por empresa** (actividades: buceo, embarcación, formativa; AST).
   Script `supabase_migration_numeracion_por_empresa_v1.sql` (incluye además
   Hidroser, Merieux, Equipamiento de Buceo y motor de checklists) + estimador
   de número en la app filtrado por empresa. — **Hecho 2026-10-29** (aplicado y
   verificado; [decisión](../../decisiones/numeracion-por-empresa.md)).
2. **Empresa Searov + módulo INSPECCION + `formato_informe`** (Supabase `empresas`,
   `actividades`; SQLite y sync).
3. **Preguntas Searov** (buceo y embarcación) con potencialidad en embarcación.
4. **Carga de preguntas según formato** en el formulario y en el PDF diferido.
5. **Ítems por buzo** (tabla de respuestas por participante, SQLite + Supabase + sync).
6. **Logo de respaldo**: nombre de la empresa en vez del logo de AquaChile.
7. **PDF Searov** (buceo y embarcación) + resultado Cermaq en embarcación.
8. Revisión (`revisor-cambios`), tests y documentación.

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
