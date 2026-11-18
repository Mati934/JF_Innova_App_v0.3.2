# Changelog

> Registro de cambios funcionales por fecha (más reciente arriba). Reconstruido el
> 2026-10-22 desde el historial de git, `pubspec.yaml` y `docs/planificacion/`.
> Desde esa fecha se mantiene con la skill `documentar-app`.
> Formato: `## AAAA-MM-DD` + líneas `- [Módulo] qué cambió para el usuario`.

## 2026-11-08

- [Toda la app] Las cajas de texto se sueltan al tocar fuera de ellas o al
  desplazar la pantalla con el dedo (en Android/iOS antes no se soltaban). Ya no
  hay que cerrar una observación para salir de ella, y la pantalla deja de
  volver a la caja de más arriba cuando uno está más abajo.
- [Equipamiento de buceo] Los campos de compresores y buzos ya no pierden el
  cursor ni lo escrito cuando la pantalla se redibuja.

## 2026-10-29

- [Inspección Searov] Buceo sin "Estado final de faena", sin verificaciones
  críticas IV–VIII y sin registro fotográfico complementario (no están en el
  formato de Searov). PDF v0.1.1: el checklist muestra una sola columna
  "Estado" (Cumple / No cumple / N/A) en vez de tres columnas marcadas con X.
- [Inspección Searov] PDF v0.3.0: fotos de cada pregunta solo en el checklist y
  más grandes (el anexo final queda con fotos con observación y galería general);
  estado como píldora de color; firmas lado a lado con línea y nombre debajo;
  tabla de compresores en buceo.
- [Inspección Searov] PDF v0.2.0: checklist con la estructura del PDF estándar de
  buceo (observación bajo la pregunta, fotos a la derecha, estado) y diseño
  Searov; sin Inicial / Consecutiva. Nueva sección Firmas en el formulario:
  quién realiza (obligatorio) y quién recibe la inspección, con firma en
  pizarra. Base local v64; Supabase `actividades.inspector_nombre` y `recibe_nombre`.
- [Inspección Searov] Módulo nuevo `INSPECCION_SEAROV` para Searov SpA (en
  desarrollo, sin publicar): inspección de buceo con checklist por buzo e
  inspección de embarcación con potencialidad ALTA/MEDIA, cada una con PDF propio
  (v0.1.0). Inspección (AquaChile) no cambia.
- [Herramientas] Skill `nueva-empresa-demo`: SQL de alta de empresa + módulos y
  diagnóstico de qué le falta a una empresa para usar la app.
- [Todos los informes] El número de informe es propio de cada empresa y de cada
  tipo de informe (buceo, embarcación, formativa, AST, Hidroser, Merieux visitas y
  extintores, equipamiento de buceo, checklists). AquaChile sigue su numeración;
  una empresa nueva parte en 1. Un número ya no se reutiliza al borrar un informe.
- [AST, Hidroser y otros] Reintentar la sincronización ya no deja saltos en la numeración.
- [Inspección Buceo/Embarcación] El N° estimado antes de finalizar usa la empresa activa.

## 2026-10-28

- [Inspección Buceo/Embarcación] El PDF de embarcación generado en diferido
  (cuando el número de informe llega después de finalizar) vuelve a mostrar la
  dotación y el diseño de embarcación. Fallaba desde 2026-03-31. PDF v0.2.1.
- [Herramientas] Skill `diagnosticar-error` para reportes de errores
  (evidencia real, causa, alcance y plan antes de arreglar).
- [Herramientas] El agente `revisor-cambios` se lanza siempre antes de cerrar un
  cambio de código o SQL, compara caminos paralelos y corre analyze y tests.

## 2026-10-22

- [App] Versión `0.7.6+62` subida a producción.
- [Registro de Visita] Se ocultan del desplegable los 5 checklists de
  herramientas viejos (`VISITA_CHEQUEO_*`); se usan los del motor configurable.
- [Equipamiento de Buceo] El PDF muestra su versión (v0.1.0) en el pie.
- [Docs] Glosario/traductor de códigos (`docs/glosario.md`).
- [Checklists Configurables] MB Embajadores: permisos por rol PREVENCIONISTA en
  sus 3 checklists de Equipos Críticos (antes su usuario no veía las tarjetas).
- [Herramientas] MCP de Dart (`dart mcp-server`), hook de `dart format`, skill
  `migracion-supabase` y agente `revisor-cambios` para Claude Code.
- [Herramientas] Skills `nuevo-checklist` (con plantillas SQL de checklist y
  nueva versión, permisos por rol) y `nuevo-modulo`.
- [Docs] Nueva estructura de documentación en `docs/` (índice, arquitectura,
  base de datos, módulos, checklists, decisiones, changelog) y skill `documentar-app`.

## 2026-10-21

- [Actividades Formativas] El PDF incluye galería de fotos (PDF 0.1.4).

## 2026-10-18

- [Actividades Formativas] Incorporación del módulo con correlativo independiente.

## 2026-10-08

- [App] Versión `0.7.6+61` subida a producción.

## 2026-10-07

- [App] Versión `0.7.6+60` subida a producción.

## 2026-10-06

- [App] Versión `0.7.6+59` subida a producción.
- [Checklists Configurables] Grupo **Equipos Críticos** para MB Embajadores:
  Equipo Crítico, Paradas de Emergencia de Cintas, Transpaleta Manual.
- [iOS] Bundle id `com.jfInnova.app`.

## 2026-09-21

- [AST] Ajuste en la verificación del correlativo.

## 2026-09-16

- [Checklists Configurables] Corrección de permisos de checklists por empresa.

## 2026-09-14

- [Checklists Configurables] Motor de checklists configurables con 5 checklists
  de Herramientas y Equipos (manuales, soldadora al arco, taladro, esmeril,
  extensión eléctrica) y campos dinámicos.

## 2026-09-03

- [Tickets] Hallazgo único por embarcación, un ticket por observación
  fotográfica, sin tickets vacíos, corte de reprocesamiento 2026-08-31.

## 2026-09-02

- [AST, Tickets] Mejor sincronización y persistencia de evidencias.

## 2026-08-24

- [iOS] Preparación de build para TestFlight.
- [Correo, Hidroser, Tickets] Ajustes varios.

## 2026-08-19

- [Correo] Correcciones. [Inspección] Diseño del PDF de buceo. [Tickets] Finalización de tickets.

## 2026-08-17

- [Cronograma] Mejoras del módulo.

## 2026-08-13 – 2026-08-14

- [Inspección] Rediseño del informe de buceo; mejora al finalizar y al guardar el estado de faena.

## 2026-08-11

- [Correo] Creación de plantillas de correo.

## 2026-08-09

- [Seguridad] Se elimina la service role de Supabase del cliente.

## 2026-08-03

- [Tickets] Versión 0.3.0. [Sync] Corrección de subida de PDF.

## 2026-07-20 – 2026-07-26

- [Seguridad] Medidas de seguridad (RLS y permisos; detalle pendiente de confirmar).

## 2026-07-04 – 2026-07-08

- [Tickets] Primera versión del módulo (v0.1.1).
- [Merieux] Demo de Visitas y Extintores.

## 2026-06-26

- [Equipamiento de Buceo] Nuevo módulo SAL (20 m) y SAM (36 m).

## 2026-06-22

- [Correo] Plan MVP aprobado (correo preparado, envío manual).

## 2026-06-09

- [AST] Módulo AST terminado.

## 2026-06-02

- [Hidroser] Módulo propio (antes variante del Registro de Visita).

## 2026-05-26

- [Checklists] Verificación de Grúas Horquillas (`VISITA_R012`).

## 2026-05-20

- [Checklists] Vehículos Livianos (`VISITA_R008`) y Máquina Soldadora (`VISITA_R011`).

## 2026-05-12

- [App] Confirmación de seguridad al finalizar un módulo.

## 2026-04-17 – 2026-04-22

- [Multiempresa] Configuración de módulos por empresa, rediseño de borradores y
  de la app, mejora del Historial.
- [Extintores] Mejora del PDF.

## 2026-04-05 – 2026-04-09

- [Multiempresa] Primera versión multiempresa. "App lista" el 2026-04-09.

## 2026-03-29 – 2026-03-31

- [Inspección] Número de informe por trigger, autoguardado de borradores, refactor Supabase.
- [Historial] Corrección de configuración.

## 2026-03-26

- [Extintores] Chequeo de extintores (R-004). [Criticidad] Corrección de escala.
- [Registro de Visita] Tipos de actividad.

## 2026-03-15

- [Tickets] Primera versión (app 0.6.4).

## 2026-03-09

- [Inspección] Inspección de Embarcación habilitada; firma mejorada.

## 2026-02-20 – 2026-02-26

- [Registro de Visita] Módulo completado con borradores.
- [Inspección] Inspección de Embarcación con rediseño visual.

## 2026-01-12 – 2026-01-30

- [Inspección] Inicio del proyecto: inspección de buceo (DPR24), cuadrilla,
  verificaciones, PDF y número de informe.
