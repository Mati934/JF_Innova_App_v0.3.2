# Versión independiente por cada PDF

- **Fecha:** pendiente de confirmar
- **Estado:** vigente (regla en `.github/copilot-instructions.md`)

## Qué se decidió

Cada generador de PDF tiene su propia versión, independiente de la app. Todo
cambio de contenido o diseño de ese PDF sube su patch (`0.1.0` → `0.1.1`).
Antes de crear un PDF nuevo se pregunta si lleva el pie "Generado por Servimaf".

## Por qué

Saber con qué diseño se generó cada informe entregado a clientes, aunque la app
cambie de versión por otros motivos.

## Alternativas

- Usar la versión de la app: descartada (cambia por motivos ajenos al PDF).

## Versiones actuales (2026-10-22)

| PDF | Versión |
|---|---|
| Inspección buceo/embarcación | 0.2.0 |
| Registro de Visita | 0.1.0 |
| Extintores R-004 | 0.4.0 |
| PROSESSO | 1.0 |
| Hidroser (también Merieux) | 0.1.0 |
| AST | 1.0.0 |
| Checklists configurables | 0.1.0 |
| Actividades formativas | 0.1.4 |
| Equipamiento de buceo | 0.1.0 (versión agregada 2026-10-22, visible en el pie) |
