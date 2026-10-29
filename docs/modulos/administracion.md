# Administración

> Clave: `ADMIN` (requiere rol admin) · Estado: en producción · Última revisión: 2026-10-22
> Empresas con el módulo (2026-10-22): Servimaf.

## Qué hace

Pantalla "Administración" con pestañas:

1. **Datos Maestros**: crear/editar centros (con área), contratistas y
   embarcaciones (con contratista).
2. **Módulos**: habilitar/deshabilitar y ordenar los módulos de cada empresa (`empresa_modulos`).
3. **Checklists**: administrar nodos de navegación y permisos de los
   [checklists configurables](checklists-configurables.md).
4. **Usuarios**: gestión de usuarios y sus empresas (visible según permisos).

## Reglas de negocio

- Solo usuarios admin ven la tarjeta.
- Los cambios se guardan online y se reflejan en los dispositivos en el siguiente sync.
- Contratistas y embarcaciones son compartidos entre empresas.
- Pendiente de confirmar: qué distingue la pestaña Usuarios (se muestra condicionalmente).

## Datos

`centros`, `areas`, `contratistas`, `embarcaciones`, `personal_externo`,
`usuarios`, `usuario_empresas`, `empresas`, `empresa_modulos`,
`checklist_navigation_nodes`, `checklist_permission_grants`.

## Archivos principales

- `lib/features/admin/presentation/screens/master_data_admin_screen.dart`
- `lib/features/admin/presentation/screens/empresa_modulos_screen.dart`
- `lib/features/admin/presentation/screens/checklist_nodes_admin_screen.dart`
- `lib/features/admin/presentation/controllers/admin_crud_controller.dart`

## Pendientes

- Código muerto conocido (no extender): `BatchDraftController`,
  `MasterDataBatchService`, `DependencyGraph`, `presentation/examples/`.
