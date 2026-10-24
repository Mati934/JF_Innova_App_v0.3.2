# AST – Análisis Seguro de Trabajo

> Clave: `AST` · Estado: en producción · Última revisión: 2026-10-22
> Empresas con el módulo (2026-10-22): AquaChile, JF Innova, Servimaf.

## Qué hace

Registra un **AST**: descripción del trabajo, **hallazgos** (cada uno con título,
detalle y foto), observaciones y galería general. Genera un PDF con correlativo propio.

## Reglas de negocio

- Configuración inicial: área, centro y contratista obligatorios.
- Hallazgos numerados 1, 2, 3… dentro del informe.
- Al finalizar pasa a `En Seguimiento`; Supabase asigna el correlativo AST
  (contador `ast_correlativo_counters`), se genera el PDF y se sincroniza.
- El PDF usa **siempre el logo de AquaChile**, sin importar la empresa.
- Las fotos se copian al almacenamiento permanente de la app antes de guardarse.
- Es independiente de visitas e inspecciones (tablas propias).

## Datos

`ast_informes`, `ast_hallazgos`, `ast_evidencias`, `ast_correlativo_counters`.

## Pantallas

`AstModuleScreen` → `AstSetupScreen` (datos iniciales) → `AstFormScreen`.

## Archivos principales

- `lib/features/ast/presentation/controllers/ast_form_controller.dart`
- `lib/features/ast/services/ast_pdf_generator_service.dart` (PDF v1.0.0)
- `lib/features/ast/services/ast_evidence_sync_plan.dart`

## Pendientes

- Tickets automáticos por hallazgo AST: [plan](../planificacion/03_por_realizar/PLAN_TICKETS_POR_HALLAZGO_AST.md) (no implementado).
- Pendiente de confirmar: si el logo fijo de AquaChile debe cambiar para otras empresas.
