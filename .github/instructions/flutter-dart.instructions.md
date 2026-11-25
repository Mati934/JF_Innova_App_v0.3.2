---
description: "Use when reading or changing Flutter or Dart code, widgets, state, services, data models, offline sync, or tests."
applyTo: "**/*.dart"
---

# Flutter y Dart

- Sigue el patrón del módulo más parecido; no impongas una arquitectura nueva ni muevas archivos como parte de un cambio funcional.
- Conserva compatibilidad entre plataformas y los comportamientos existentes de permisos, almacenamiento local, sincronización y errores.
- Para cambios de base de datos local o sincronización, revisa los lectores, escritores y pruebas relacionadas; cubre regresiones con pruebas dirigidas.
- Usa `flutter analyze` y ejecuta las pruebas relevantes con `flutter test`.
