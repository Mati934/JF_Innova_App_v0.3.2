# jf_innova_app

Aplicacion Flutter de operaciones e inspecciones para despliegue Android, web e iOS.

## Estado del proyecto

El proyecto esta orientado a mantenimiento y estabilizacion. La prioridad es corregir incidencias reales, evitar cambios de alcance y mantener el flujo listo para iPhone con el menor trabajo posible en el Mac.

## Documentacion clave

- [Preparacion iPhone: handoff a Mac](docs/IOS_HANDOFF_MAC_CHECKLIST.md)
- [Estrategia de estabilizacion y mantenimiento](docs/ESTABILIZACION_Y_MANTENIMIENTO.md)
- [Recordatorio: iPhone y acceso por navegador](docs/RECORDATORIO_IPHONE_WEB.md)

## Flujo recomendado

1. Desarrollar y revisar en Windows.
2. Subir cambios con Git.
3. En Mac, compilar iOS, firmar y validar en iPhone.
4. Publicar solo builds de correccion o versionado planificado.

## Comando util

```bash
flutter build apk --target-platform android-arm64
```