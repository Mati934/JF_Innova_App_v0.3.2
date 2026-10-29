# Número de informe asignado por trigger en Supabase

- **Fecha:** 2026-03-29 (refactor de número de informe)
- **Estado:** vigente. Desde 2026-10-29 el número es por empresa y no se reutiliza: ver [numeración por empresa](numeracion-por-empresa.md).

## Qué se decidió

El número de informe lo asigna Supabase (trigger `trg_asignar_numero_informe`;
hasta 2026-10-29 con las secuencias `seq_inf_buceo`, `seq_inf_embarcacion`) **solo** cuando el registro
pasa a `En Seguimiento`. Los borradores no tienen número. El PDF se genera solo
con número real; si se finaliza offline, se genera en el siguiente sync.
AST, formativas, Hidroser, Merieux y el motor configurable siguen la misma idea
con sus propios correlativos.

## Por qué

Varios dispositivos offline no pueden coordinar un correlativo sin choques ni saltos.

## Alternativas

- Números provisorios `PROV-*` en el dispositivo: se usaron y se **abandonaron**;
  el código solo filtra registros antiguos con ese prefijo. No volver a crearlos.
- Otras alternativas evaluadas: pendiente de confirmar.

## Consecuencias

- La app nunca envía `numero_informe` en el upsert.
- Existe `DeferredPdfService` y `_generarPdfsDiferidos()`.
- Detalle técnico: `supabase_migration_numero_informe.sql`.
