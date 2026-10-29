# Offline-first con SQLite y sincronización

- **Fecha:** 2026-01 (arquitectura desde el inicio del repo)
- **Estado:** vigente

## Qué se decidió

La app siempre lee y escribe en SQLite local. La subida a Supabase es un proceso
aparte (`SyncService`) que corre cuando hay conexión. Los registros locales
llevan `subido = 0/1`.

## Por qué

Los usuarios trabajan en centros de cultivo, embarcaciones y plantas sin señal.
Deben poder completar todo el flujo (incluido finalizar) sin internet.

## Alternativas

- App solo online: descartada por falta de conectividad en terreno.
- Pendiente de confirmar si se evaluó otra base local (Hive aparece mencionada en
  `CONTEXTO_GENERAL.md`).

## Consecuencias

- Cada módulo necesita tablas espejo `*_pendientes` y su rama en el sync.
- El número de informe y el PDF pueden quedar diferidos.
- Excepciones: Tickets, Historial y Cronograma funcionan solo online.
