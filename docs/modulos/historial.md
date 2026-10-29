# Historial

> Clave: `HISTORY` · Estado: en producción · Solo online · Última revisión: 2026-10-22
> Empresas con el módulo (2026-10-22): todas menos Hidroser.

## Qué hace

Lista los **informes finalizados** de todos los módulos para consultarlos y abrir
o compartir su PDF. Filtros por usuario, centro y módulo.

## Reglas de negocio

- Usa la RPC `historial_autorizado`, que **valida en Supabase** rol y pertenencia
  a la empresa. La app solo indica el alcance pedido:
  - Super admin: todas las empresas.
  - Admin: su empresa, puede filtrar por usuario.
  - Usuario normal: sus propios informes.
- Solo funciona con conexión.
- Habilitar Historial no da acceso a informes de otras empresas.

## Datos

RPC `historial_autorizado` (+ vista `historial_unificado` según comentarios;
pendiente de confirmar). Catálogos de filtros: `centros`, `usuarios`, `embarcaciones`, `areas`.

## Pantallas

`HistoryScreen` con `HistoryCard` y filtros (`CustomFilterSheet`).

## Archivos principales

- `lib/features/history/controllers/history_controller.dart`
- `lib/features/history/data/repositories/supabase_history_repository.dart`

## Pendientes

- Ninguno conocido.
