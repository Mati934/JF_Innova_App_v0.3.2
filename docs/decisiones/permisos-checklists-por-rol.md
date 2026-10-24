# Permisos de checklists configurables por rol, no por usuario

- **Fecha:** 2026-10-22
- **Estado:** vigente (aplicado en MB Embajadores; pendiente en M&S y Servimaf)
- **Fuente:** decisión del usuario en conversación (2026-10-22)

## Qué se decidió

Los permisos de los checklists del motor (`checklist_permission_grants`) se dan
al **rol PREVENCIONISTA dentro de cada empresa**, con las capacidades `ver`,
`crear`, `editar_borrador` y `finalizar`. No se dan al rol ADMINISTRADOR (no lo
necesita) ni a cada usuario por separado.

## Por qué

Supabase decide con RLS (`checklist_user_can`) si un usuario ve una tarjeta y
puede subir inspecciones: debe pertenecer a la empresa y tener el permiso por
usuario **o por su rol**. Los scripts antiguos daban permisos a los usuarios
que existían al ejecutarlos; el prevencionista de MB Embajadores se creó
después y quedó sin ver sus 3 checklists. Con permisos por rol, todo
prevencionista que se agregue a la empresa los hereda solo.

Los administradores no necesitan permisos: las reglas `is_admin_user()` ya les
dan acceso a tarjetas e inspecciones.

## Alternativas

- Permisos por usuario (como Herramientas y Equipos): obliga a repetir el paso
  por cada usuario nuevo; fue la causa del problema.
- Permisos al rol ADMINISTRADOR: innecesario.

## Consecuencias

- Al crear un usuario o asignarlo a una empresa basta con el rol y la empresa
  correctos (ver [acceso y multiempresa](../modulos/acceso-y-empresas.md#al-crear-usuarios-o-asignarlos-a-empresas)).
- Un prevencionista de la empresa ve **todos** los checklists con permiso por
  rol. Para restringir uno a ciertas personas habría que usar permisos por usuario.
- Las plantillas de la skill `nuevo-checklist` crean los permisos por rol
  PREVENCIONISTA.
