# Numeración de informes por empresa y tipo de informe, sin reutilizar números

- **Fecha:** 2026-10-29
- **Estado:** vigente
- **Fuente:** pedido de Mati (conversación 2026-10-29); script `supabase_migration_numeracion_por_empresa_v1.sql`, aplicado ese día.

## Qué se decidió

Cada tipo de informe de cada módulo tiene su propia numeración continua,
**separada por empresa**, y un número **nunca se reutiliza** (un informe borrado
deja su número sin usar). Los contadores viven en `numeradores_informe`
(empresa, módulo, año) y los usa la función `next_numero_informe`, llamada desde
los triggers de cada módulo. Sigue vigente que el número se asigna en Supabase
al finalizar ([decisión anterior](numero-informe-por-trigger.md)).

| Informe | Contador (`modulo`) | Formato |
|---|---|---|
| Inspección de buceo | `INSPECCION_BUCEO` | N° |
| Inspección de embarcación | `INSPECCION_EMBARCACION` | N° |
| Actividad formativa | `ACTIVIDAD_FORMATIVA` | N° |
| AST | `AST` (por año) | `AST-AAAA-NNNN` |
| Hidroser | `HIDROSER:<lista>` | `HIDROSER-GH-AAAA-NNNN` |
| Merieux visitas / extintores | `MERIEUX_VISITAS` / `MERIEUX_EXTINTORES` | `MERIEUX-VIS/EXT-AAAA-NNNN` |
| Equipamiento de Buceo | `BUCEO_EQ:<lista>` | `BUCEO-EQ-SAL20-AAAA-NNNN` |
| Checklists del motor | `CHECKLIST:<checklist_key>` | `<PREFIJO>-NNNN` |

## Por qué

Con una empresa nueva (Searov SpA) los informes iban a seguir la numeración de
AquaChile. Además, al borrar el último informe de buceo/embarcación el número
se volvía a usar: dejó números repetidos en buceo de AquaChile (etapa de
pruebas). Un folio repetido es ambiguo si el PDF ya se envió.

## Alternativas

- Mantener secuencias globales: descartado, mezcla empresas.
- Reiniciar el contador al borrar (comportamiento anterior): descartado.
- Índice único por empresa en buceo/embarcación: no se agregó; los números
  repetidos de pruebas lo impiden y se prefirió no bloquear subidas.

## Consecuencias

- Al aplicar, cada contador partió en el máximo de su empresa: AquaChile siguió
  sin saltos (buceo 716, embarcación 78, formativa 3, AST-2026-0655); una empresa
  nueva parte en 1. Merieux visitas y extintores dejaron de compartir número.
- Si una fila llega sin `empresa_id`, el trigger la completa desde el usuario
  (`resolver_empresa_usuario`); solo si no se resuelve usa el generador global anterior.
- Un upsert del sync sobre una fila existente ya no gasta un número (antes
  dejaba huecos en AST e Hidroser).
- El mismo texto de correlativo puede existir en dos empresas. Storage y la app
  identifican informes por `id`, no por número.
- Se eliminó el trigger `trg_resetear_secuencia`. Las tablas
  `ast_correlativo_counters`, `buceo_equipamiento_numeradores`,
  `checklist_correlativo_counters` y las secuencias `seq_inf_*` quedan solo como respaldo.
- La app estima el próximo número con el máximo de la empresa activa.
