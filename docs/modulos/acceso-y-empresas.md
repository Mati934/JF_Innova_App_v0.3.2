# Acceso, sesión y multiempresa

> Transversal · Última revisión: 2026-10-22

## Qué hace

Login con Supabase Auth, carga del perfil del usuario y de la empresa activa,
y control de qué ve cada usuario según rol y empresa.

## Reglas de negocio

- Login con correo y contraseña (Supabase Auth). `AuthGate` decide entre login y Home.
- `UserSession` (singleton) guarda usuario, rol, empresa activa y permisos.
- Un usuario puede pertenecer a **varias empresas** (`usuario_empresas`);
  `usuarios.empresa_id` es legado y sirve de respaldo.
- Home muestra la empresa fija, **sin selector** (decisión del usuario).
- Roles: admin y prevencionista (pendiente de confirmar nombres exactos en `roles`).
  "Super admin" = admin de la empresa administradora (Servimaf).
- Logo por empresa para los PDF (`EmpresaLogoService`), salvo AST (siempre AquaChile).
- Áreas filtradas por empresa vía `empresa_areas`; contratistas y embarcaciones compartidos.

## Al crear usuarios o asignarlos a empresas

Lo que necesita un usuario para ver y usar lo de su empresa:

1. **Rol** en `usuarios.rol_id`: `PREVENCIONISTA` para usuarios de terreno;
   `ADMINISTRADOR` solo para quien administra (si además pertenece a una empresa
   administradora, como Servimaf, es super admin y ve todo).
2. **Empresa**: fila en `usuario_empresas` (una por empresa). `usuarios.empresa_id`
   es legado; se usa como respaldo.
3. **Módulos normales**: los ve si están habilitados para su empresa en
   `empresa_modulos` (Administración > Módulos). No hay que hacer nada por usuario.
4. **Checklists del motor**: si la empresa tiene permisos por rol (MB
   Embajadores), no hay que hacer nada. Si tiene permisos por usuario (M&S,
   Servimaf en Herramientas y Equipos), hay que agregar los permisos de ese
   usuario, o mejor pasar esa empresa a permisos por rol
   ([decisión](../decisiones/permisos-checklists-por-rol.md)).
5. El usuario debe **sincronizar** en la app para que le lleguen las tarjetas nuevas.

## Archivos principales

- `lib/features/auth/presentation/screens/login_screen.dart`
- `lib/core/services/user_session.dart`
- `lib/core/services/empresa_logo_service.dart`
- `lib/main.dart` (`AuthGate`)

## Pendientes

- Pendiente de confirmar: cómo se elige la empresa activa cuando el usuario tiene varias.
