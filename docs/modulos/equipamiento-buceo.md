# Equipamiento de Buceo (SAL / SAM)

> Clave: `BUCEO_EQUIPAMIENTO` · Estado: implementado, bajo uso (2 inspecciones) · Última revisión: 2026-10-22
> Empresas con el módulo (2026-10-22): AquaChile, GNS, JF Innova, PROSESSO, Servimaf.

## Qué hace

Lista de chequeo del **equipo de buceo** antes de una faena, en dos variantes:

- **SAL** – faena de 20 metros (`BUCEO_SAL_20M`, 84 preguntas).
- **SAM** – faena de 36 metros (`BUCEO_SAM_36M`, 52 preguntas).

## Reglas de negocio

- Algunas preguntas aplican **por buzo** (`aplica_por_buzo`, categoría
  "Checklist por buzo"): se responden una vez por cada buzo de la cuadrilla.
- Preguntas con criticidad y peso.
- Si falla la lectura local del usuario, el formulario no se bloquea.

## Datos

`buceo_equipamiento_listas`, `buceo_equipamiento_items`,
`buceo_equipamiento_inspecciones`, `buceo_equipamiento_respuestas`,
`buceo_equipamiento_numeradores`. La app lee las preguntas de
`buceo_equipamiento_items`. Las mismas preguntas también siguen en
`formulario_items` (tipos `BUCEO_SAL_20M` / `BUCEO_SAM_36M`), sin uso en este módulo.

## Pantallas

`BuceoEquipmentModuleScreen` → `BuceoEquipmentFormScreen`.

## Archivos principales

- `lib/features/buceo_equipment/presentation/controllers/buceo_equipment_form_controller.dart`
- `lib/features/buceo_equipment/services/buceo_equipment_pdf_service.dart` (PDF v0.1.0, desde 2026-10-22)

## Pendientes

- Copia sobrante de las preguntas en `formulario_items`: pendiente de confirmar si se puede retirar.