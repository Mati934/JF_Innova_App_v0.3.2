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

## Mapa local del código para Copilot

Graphify es una herramienta opcional de desarrollo; no forma parte de la app. Su mapa se genera localmente y `graphify-out/` está excluido de Git porque puede contener fragmentos y rutas del código.

Para crear o actualizar un mapa solo del código, sin análisis de documentos ni llamadas a modelos:

```bash
graphify extract . --code-only --no-cluster
graphify cluster-only . --no-label
```

Después se puede consultar con `graphify query "pregunta sobre el proyecto"` o desde Copilot Chat con la skill `/graphify`. El mapa no sustituye revisar los archivos fuente antes de modificar código.

Para refrescar el mapa después de cambios de código, usa `graphify update .`.

## Agentes y skill Ponytail

El Agent predeterminado puede delegar según los criterios de [las instrucciones del proyecto](.github/copilot-instructions.md); no es necesario seleccionar un agente manualmente ni ejecutar todos para cada cambio.

La [skill Ponytail](.github/skills/ponytail/SKILL.md) procede de [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail), con [licencia MIT](.github/skills/ponytail/LICENSE). Se incorporó el 17-10-2026 como skill del proyecto, no como plugin completo de Claude: no instala hooks, paneles ni los demás comandos del plugin.

Las instrucciones del proyecto requieren usar Ponytail automáticamente en tareas de código, en nivel `full` por defecto; no es necesario pedirlo en cada chat. Puedes cambiar el nivel o desactivarlo explícitamente. Su descubrimiento depende del soporte de skills de la sesión; si no aparece en `/skills`, abre un chat nuevo o recarga VS Code. No actualiza automáticamente su contenido desde el repositorio original.

Las instrucciones, los tres agentes y la skill Ponytail están guardados en este repositorio y su alcance es este proyecto. El programa Graphify y su skill se instalaron en el perfil del usuario de Windows, por lo que pueden estar disponibles en otros proyectos; el mapa generado y las reglas para usarlo pertenecen a este repositorio.