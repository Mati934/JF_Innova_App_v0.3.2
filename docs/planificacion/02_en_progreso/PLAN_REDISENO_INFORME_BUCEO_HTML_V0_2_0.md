# Plan de Rediseño Informe de Buceo HTML v0.2.0

Fecha: 2026-08-12
Estado: Definido para implementación
Prioridad: Alta

## 1) Objetivo

Rediseñar el informe PDF de Inspección de Buceo para que replique lo más fielmente posible la estructura, orden visual y bloques del HTML de referencia entregado por el usuario, con estas reglas cerradas:

1. La salida final debe parecerse al HTML al máximo dentro de las capacidades de la librería `pdf` de Flutter.
2. Las fotos del checklist ya no deben ir incrustadas dentro de la tabla de detalle; deben salir al final en un bloque de registro fotográfico por ítem, mostrando el número de la pregunta correspondiente.
3. Debe agregarse un nuevo bloque operativo de `Fotografías Obligatorias` para que el prevencionista cargue fotos con título fijo.
4. El nuevo bloque de `Fotografías Obligatorias` no debe afectar el porcentaje de cumplimiento.
5. Deben mantenerse también los bloques ya existentes de `Fotografías con Observación Detallada` y `Evidencia Fotográfica General`.
6. No deben aparecer placeholders vacíos en el PDF. Solo deben mostrarse fotos o bloques cuando existan datos reales.
7. La versión visible en el pie del PDF debe subir de `v0.1.0` a `v0.2.0`.

## 2) Alcance funcional cerrado

### Incluye

1. Rediseño visual del PDF de `INSPECCION_BUCEO`.
2. Nuevo bloque UI para capturar `Fotografías Obligatorias`.
3. Persistencia local de esas fotos reutilizando la infraestructura actual de `fotos_pendientes`.
4. Adaptación del armado de DTO online y diferido para que ambos caminos generen exactamente la misma salida.
5. Reordenamiento de las fotos por pregunta para construir un anexo final por ítem del checklist.
6. Mantención de los cálculos actuales de cumplimiento, criticidad y estado final de faena.

### No incluye

1. Cambios de diseño del PDF de `INSPECCION_EMBARCACION`.
2. Cambio de la versión global de la app en `pubspec.yaml`.
3. Nuevas tablas SQLite o migraciones SQL, salvo que aparezca un bloqueo real durante implementación.
4. Soporte para múltiples fotos por una misma pregunta del checklist. Se mantiene la lógica actual de una foto por pregunta.

## 3) Fuente de verdad visual

La referencia visual es el HTML entregado por el usuario para el informe AquaChile.

Regla operativa:

1. Copiar la estructura y jerarquía del HTML al máximo.
2. Cuando el HTML tenga placeholders visuales vacíos, en el PDF final esos placeholders no se renderizan si no existen datos reales.
3. Cuando un bloque del HTML dependa de datos que hoy no existen en el sistema, se debe crear el soporte mínimo necesario para que el prevencionista pueda alimentarlo desde la app.

## 4) Estado actual del sistema

### Generación actual

1. El PDF actual de inspección sale desde `lib/features/inspection/services/pdf_generator_service.dart`.
2. Los datos del PDF online se arman desde `lib/features/inspection/presentation/controllers/inspection_form_controller.dart`.
3. Los datos del PDF diferido se arman desde `lib/features/inspection/services/deferred_pdf_service.dart`.
4. El modelo transportado al PDF es `lib/features/inspection/domain/models/pdf/inspection_report_data.dart`.

### Captura y persistencia actual de fotos

1. `fotosPorPregunta`: una foto por item del checklist.
2. `fotosGenerales`: galería general.
3. `fotosConObservacion`: fotos adicionales con observación libre.
4. `verificacionesBuceo`: ya soporta foto + observación para los 5 checks críticos.
5. La persistencia local ya usa `fotos_pendientes` con `actividad_id`, `item_id`, `local_path` y `descripcion`.

### Diferencias principales contra el HTML

1. El header de buceo actual es legacy y no replica la composición AquaChile del HTML.
2. El bloque de verificaciones críticas hoy se representa como lista textual más una fila de fotos, no como cards individuales.
3. El equipo de trabajo y compresores hoy están en tablas simples, no en cards como el HTML.
4. La tabla de checklist hoy incrusta fotos dentro de las filas.
5. El registro fotográfico por ítem del checklist no existe.
6. El bloque de `Fotografías Obligatorias` no existe en UI, DTO ni PDF.
7. El pie del PDF sigue en `v0.1.0`.

## 5) Decisiones técnicas cerradas

### 5.1 Nuevo bloque de Fotografías Obligatorias

Se implementará como un nuevo bloque operativo dentro del formulario de inspección de buceo.

Cada slot tendrá:

1. Título fijo.
2. Una foto asociada.
3. Sin placeholder forzado en el PDF si la foto no existe.

Los 8 títulos base definidos desde el HTML son:

1. Compresor General
2. Estado de Aceite Vegetal Compresor Principal
3. Estado Aceite Vegetal Compresor Back Up
4. Matrículas de Buceo
5. Bitácora de Compresores
6. Bitácora de Buceo Supervisor
7. Registro Aplicación Oxígeno Normobárico
8. Certificado de Inspección de Compresores

### 5.2 Persistencia del nuevo bloque

No se abrirá una tabla nueva en esta etapa.

Se reutilizará `fotos_pendientes` con una convención de identificadores para distinguir categorías de foto:

1. `item_id = <uuid real de pregunta>` para foto de checklist.
2. `item_id = null` para galería general.
3. `item_id = <uuid auxiliar no perteneciente a formulario_items>` para foto con observación.
4. `item_id = mandatory::<clave>` para fotografía obligatoria.

La `descripcion` guardará el título fijo del slot obligatorio cuando sea necesario para reconstrucción o trazabilidad.

### 5.3 Registro fotográfico por ítem

Se creará un anexo nuevo al final del informe:

1. Agrupado por categoría del checklist.
2. Mostrando número de ítem global, nombre de la pregunta y foto centrada.
3. Mostrando solo preguntas que realmente tengan foto.
4. Sin impactar conteos ni porcentajes.

### 5.4 Fidelidad HTML vs PDF

Objetivo: máxima fidelidad posible.

Limitación aceptada:

1. La librería `pdf` no replica CSS/HTML 1:1.
2. Se copiará la composición visual, colorimetría, distribución de bloques y jerarquía tipográfica lo más cercano posible.
3. Si alguna microinteracción o curvatura exacta del HTML no es viable en `pdf`, se priorizará equivalencia visual antes que exactitud de implementación.

### 5.5 Placeholders

Por instrucción del usuario:

1. No mostrar cajas vacías de fotos en PDF cuando falten imágenes.
2. Sí mantener el orden del HTML en la medida de lo posible.
3. Si un bloque queda completamente vacío, evaluar ocultarlo en vez de mostrar contenedor sin contenido.

## 6) Diseño objetivo del PDF v0.2.0

### Página principal

Debe acercarse a este orden:

1. Header superior con branding AquaChile.
2. Identificación del informe: número, tipo de inspección y fecha.
3. Barra de estado final de faena.
4. Resumen de cumplimiento con 3 tarjetas: Cumple, No Cumple, No Aplica.
5. Verificaciones críticas de seguridad en formato de cards con foto y comentario por check.
6. Equipo de trabajo / personal en cards.
7. Equipamiento / compresores en cards.
8. Observaciones generales.
9. Hallazgos `No Cumple`.

### Página(s) de detalle

1. Detalle de verificaciones por categoría.
2. Tabla del checklist sin fotos embebidas.
3. Mantener número correlativo global visible.
4. Mantener observaciones y estado C / NC / N/A.

### Anexos fotográficos finales

1. Registro Fotográfico por Ítem del Checklist.
2. Fotografías con Observación Detallada.
3. Fotografías Obligatorias.
4. Evidencia Fotográfica General.

## 7) Cambios de datos requeridos

### DTO del PDF

Extender `InspectionReportData` para incluir al menos:

1. Colección de fotos obligatorias con clave, título y path.
2. Colección de anexos fotográficos del checklist con número global de ítem, categoría, pregunta y path.
3. Si hace falta, metadatos visuales auxiliares para el render del bloque final.

### Controlador online

Extender `InspectionFormController` para:

1. Mantener estado local de fotografías obligatorias.
2. Cargar fotos obligatorias desde SQLite al abrir borrador.
3. Persistirlas al guardar borrador/finalización.
4. Inyectarlas al DTO final de PDF.

### Path diferido

Extender `DeferredPdfService` para:

1. Reconstruir fotos obligatorias desde `fotos_pendientes`.
2. Reconstruir anexo fotográfico por ítem.
3. Mantener equivalencia exacta con el path online.

## 8) Estrategia de implementación

### Fase 1: Datos y persistencia

1. Definir constantes/estructura de slots obligatorios.
2. Agregar estado en controlador.
3. Cargar y clasificar fotos obligatorias en `_init()`.
4. Persistirlas en `_persistirDatos()`.
5. Llevarlas al DTO online.
6. Llevarlas al DTO diferido.

### Fase 2: UI de captura

1. Crear widget nuevo para `Fotografías Obligatorias`.
2. Mostrar lista de slots con su título.
3. Permitir tomar o reemplazar una foto por slot.
4. Permitir eliminar la foto de un slot.
5. Ubicar el bloque dentro del formulario de buceo en una posición coherente con el flujo del prevencionista.

### Fase 3: Rediseño del generador PDF

1. Rehacer el header de buceo para acercarlo al HTML.
2. Rediseñar resumen de cumplimiento.
3. Rediseñar verificaciones críticas en cards.
4. Rediseñar equipo de trabajo en cards.
5. Rediseñar compresores en cards.
6. Rediseñar hallazgos y observaciones.
7. Mantener checklist en tabla, pero sin fotos incrustadas.
8. Crear anexo de registro fotográfico por ítem.
9. Crear bloque de fotografías obligatorias.
10. Mantener y adaptar los bloques de observaciones detalladas y galería general.
11. Cambiar pie del PDF a `v0.2.0`.

### Fase 4: Validación

1. Generar previsualización desde el flujo online.
2. Validar que no reviente con datos completos y parciales.
3. Validar que no aparezcan placeholders vacíos.
4. Validar que los porcentajes no cambien por fotos obligatorias.
5. Validar que el path diferido produzca el mismo layout y datos.

## 9) Propuesta de estructura de código

### Archivos que deben cambiar

1. `lib/features/inspection/domain/models/pdf/inspection_report_data.dart`
2. `lib/features/inspection/presentation/controllers/inspection_form_controller.dart`
3. `lib/features/inspection/presentation/screens/inspection_form_screen.dart`
4. `lib/features/inspection/services/deferred_pdf_service.dart`
5. `lib/features/inspection/services/pdf_generator_service.dart`
6. `lib/features/inspection/presentation/widgets/...` para el nuevo widget de fotos obligatorias

### Archivos nuevos probables

1. Widget para captura de fotografías obligatorias.
2. Archivo de constantes o modelo liviano para definir slots obligatorios, si mejora legibilidad.

## 10) Criterios de aceptación

La tarea se considerará bien implementada si se cumplen todos estos puntos:

1. El PDF de `INSPECCION_BUCEO` refleja el HTML de referencia en estructura y apariencia general.
2. Las fotos del checklist salen al final bajo un bloque de registro fotográfico por ítem.
3. El número mostrado en cada tarjeta/ítem del anexo coincide con el número del checklist.
4. Existe un bloque operativo para capturar `Fotografías Obligatorias` en la app.
5. Las fotografías obligatorias se renderizan en el PDF solo cuando existan.
6. El bloque obligatorio no altera el porcentaje de cumplimiento.
7. Se mantienen `Fotografías con Observación Detallada` y `Evidencia Fotográfica General`.
8. No se rompen borradores existentes.
9. El generador online y diferido entregan una salida consistente.
10. El pie del PDF muestra `v0.2.0`.

## 11) Riesgos y controles

### Riesgo 1: Divergencia entre path online y diferido

Control:

1. Implementar el mismo criterio de clasificación de fotos en ambos caminos.
2. Validar ambos antes de cerrar.

### Riesgo 2: PDF demasiado cargado o con saltos de página defectuosos

Control:

1. Construir bloques pequeños que puedan partir página sin romper layout.
2. Evitar tablas gigantes con fotos embebidas.

### Riesgo 3: Borradores antiguos sin nuevo bloque

Control:

1. Tratar el bloque como opcional.
2. Si no hay fotos obligatorias, el PDF sigue siendo válido.

### Riesgo 4: Exceso de fidelidad imposible respecto del HTML

Control:

1. Priorizar equivalencia visual por bloques.
2. Ajustar solo cuando la librería `pdf` limite formas o composición exacta.

## 12) Orden recomendado de ejecución

1. Extender modelo DTO.
2. Agregar clasificación de `Fotografías Obligatorias` en controlador y servicio diferido.
3. Crear widget de captura en formulario.
4. Sacar fotos del checklist desde la tabla de detalle.
5. Crear anexo final de registro fotográfico por ítem.
6. Rehacer layout principal del PDF.
7. Agregar bloque final de fotografías obligatorias.
8. Cambiar versión a `v0.2.0`.
9. Validar previsualización y path diferido.

## 13) Resultado esperado

El informe de buceo debe pasar de un PDF funcional pero legacy a un PDF v0.2.0 visualmente cercano al HTML AquaChile, con anexos fotográficos ordenados, nuevo bloque real de fotografías obligatorias y sin ruido visual de placeholders vacíos.
