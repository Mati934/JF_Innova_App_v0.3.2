# Minibase Hallazgos Unicos (AquaChile)

## Archivo base

- `hallazgos_unicos_aquachile_snapshot_2026-08-03.json`

Este snapshot guarda evidencia de validacion de la teoria:
- comparacion inicial vs consecutiva por usuario,
- interseccion de `item_id`,
- pares de inspecciones comparados,
- calidad de contexto (`embarcacion_id` nulo vs presente),
- estado de implementacion en codigo.

## Uso

1. Tomar este archivo como baseline de evidencia.
2. Regenerar un nuevo snapshot con fecha cuando se cambie logica de dedupe.
3. Comparar metricas clave:
- `inter_item_id`
- `jaccard_item_id`
- `inter_clave_tipo_embarc_item`
- porcentaje de inspecciones con `embarcacion_id` nulo

## Regla operacional

La evaluacion oficial de continuidad NC debe pasar por el panel de control, no por rescates manuales aislados, para mantener consistencia de datos y de KPI.
