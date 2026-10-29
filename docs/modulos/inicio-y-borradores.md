# Inicio y borradores

> Transversal · Última revisión: 2026-10-22

## Qué hace

Pantalla principal tras el login: muestra la **empresa activa** (fija, sin
selector), las **tarjetas de módulos** habilitados y los **borradores**
pendientes de todos los módulos.

## Reglas de negocio

- Tarjetas: módulos de `ModuleRegistry` habilitados en `empresa_modulos` para la
  empresa, en su orden; más las tarjetas/grupos de checklists configurables. Los
  módulos `requiresAdmin` solo para admin.
- Sin configuración para la empresa → módulos por defecto.
- Los borradores de todos los módulos se muestran juntos en Home; los módulos no
  tienen bandeja de borradores propia (al entrar se abre un formulario nuevo).
- Formularios: autoguardado con debounce, guardado periódico, al salir (botón o
  gesto Atrás) y al pasar a segundo plano.
- Antes de finalizar se pide confirmación (`confirm_finalize_dialog`).

## Archivos principales

- `lib/features/home/presentation/screens/home_screen.dart`
- `lib/features/home/presentation/controllers/home_controller.dart`
- `lib/features/home/domain/draft_card_mapper.dart` (cómo se muestra cada borrador)
- `lib/core/modules/module_registry.dart`

## Pendientes

- Ninguno conocido.
