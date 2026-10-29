# Controller por pantalla, sin estado global

- **Fecha:** 2026-01-13 (refactor a arquitectura por features)
- **Estado:** vigente

## Qué se decidió

Sin Provider ni estado global: cada pantalla crea y libera su propio Controller
(`ChangeNotifier`). Lo único global es `UserSession` (singleton) y
`DatabaseHelper`. Los controllers async usan `_disposed` + `_safeNotify()`.

## Por qué

Pendiente de confirmar. Efecto práctico: cada módulo es independiente y se puede
cambiar sin afectar a otros.

## Alternativas

- Provider: mencionado en `CONTEXTO_GENERAL.md`, pero no se usa en el código actual.

## Consecuencias

- Los datos compartidos se leen de SQLite, no de memoria.
