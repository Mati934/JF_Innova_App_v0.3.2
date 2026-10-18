---
description: "Use when reviewing or editing SQL, Supabase scripts, schema changes, migrations, permissions, or row-level security."
applyTo: "**/*.sql"
---

# SQL y Supabase

- Distingue scripts de diagnóstico, corrección puntual, seed y migraciones; conserva el propósito y estilo del archivo existente.
- Revisa permisos, RLS, índices, restricciones y compatibilidad con el acceso desde Flutter antes de cambiar el esquema.
- Haz los cambios idempotentes cuando corresponda y evita operaciones destructivas o pérdida de datos.
- Está autorizada la consulta de metadatos de Supabase en solo lectura para la tarea, sin confirmación por consulta: funciones y sus definiciones, triggers, secuencias, defaults, restricciones, índices, permisos y RLS. Confirma el proyecto y entorno usando el acceso autenticado disponible; consulta pg_catalog e information_schema con SELECT y usa una transacción READ ONLY cuando sea posible.
- Para correlativos, revisa la columna y sus defaults/identity, todas las funciones y triggers relacionados, las secuencias (incluidas las no asociadas a la columna) y las restricciones e índices únicos. No supongas que el SQL local coincide con lo desplegado.
- SELECT no garantiza ausencia de efectos secundarios: no invoques RPC ni funciones de negocio, nextval, setval ni funciones con escrituras durante el diagnóstico. No ejecutes scripts mixtos de diagnóstico y corrección como si fueran de solo lectura.
- Toda escritura, DDL, migración, cambio de permisos o reinicio de secuencias remoto requiere autorización explícita del cambio y confirmación del entorno. Si no hay conexión de lectura disponible, informa el bloqueo sin abrir archivos de credenciales ni eludir permisos.
- No incluyas claves, tokens ni datos reales en scripts, salidas o documentación.
