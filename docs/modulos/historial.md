# Historial

> **Para qué es:** Ficha del módulo Historial: qué hace hoy, reglas de negocio, tablas, pantallas y pendientes.

> Clave: `HISTORY` · Estado: en producción · Solo online · Última revisión: 2026-11-23
> Empresas con el módulo (2026-10-22): todas menos Hidroser.

## Qué hace

Lista los **informes finalizados** de todos los módulos para consultarlos y abrir
o compartir su PDF. Filtros por tipo, centro, área, usuario, embarcación y contratista.

## Reglas de negocio

- Usa la RPC `historial_autorizado`, que **valida en Supabase** rol y pertenencia
  a la empresa. La app solo indica el alcance pedido:
  - Super admin: todas las empresas.
  - Admin: su empresa, puede filtrar por usuario.
  - Usuario normal: sus propios informes.
- Solo funciona con conexión.
- Habilitar Historial no da acceso a informes de otras empresas.
- Filtros (2026-11-23): centro y usuario van a la RPC; el resto se aplica en la
  app, igual para registros de la nube y del teléfono. **Tipo** es un solo
  filtro (inspección de buceo, de embarcación, registro de actividad, AST,
  Hidroser, cada checklist…) armado con los tipos que el usuario tiene. Las
  opciones de cada filtro muestran solo valores con registros.
- La RPC **no devuelve** `area_id` ni `contratista_id`: el área se deduce del
  centro (`centros.area_id`) y el contratista de la embarcación
  (`embarcaciones.contratista_id`). Un registro sin embarcación (ej. registro de
  actividad con contratista) no aparece al filtrar por contratista.
- Los registros locales eliminados (`eliminado = 1`) ya no se muestran.

## Datos

RPC `historial_autorizado` (+ vista `historial_unificado` según comentarios;
pendiente de confirmar). Catálogos de filtros: `centros`, `usuarios`, `embarcaciones`, `areas`.

## Pantallas

`HistoryScreen` con `HistoryCard` y filtros (`CustomFilterSheet`).

## Archivos principales

- `lib/features/history/controllers/history_controller.dart`
- `lib/features/history/data/repositories/supabase_history_repository.dart`

## Pendientes

- Agregar `area_id` y `contratista_id` a `historial_unificado` / `historial_autorizado`
  para filtrar por el contratista real del registro (requiere migración en Supabase).
