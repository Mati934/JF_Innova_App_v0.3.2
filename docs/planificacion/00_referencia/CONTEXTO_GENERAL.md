sigamos con la app, # CONTEXTO DEL PROYECTO: APP JF INNOVA (Inspecciones & Prevención)

## 1. Resumen del Proyecto
* **Objetivo:** App para prevencionistas que permite realizar inspecciones, verificaciones de buceo y AST en zonas sin internet (Offline-First).

* **Stack:** Flutter + Supabase (Backend) + SQLite (`sqflite` para local).
* **Gestión de Estado:** `ChangeNotifier` (Provider Pattern).
* **Stack Tecnológico:** Flutter (Dart) + Supabase (PostgreSQL).
* **Estado:** Desarrollo activo (Sprint de ajustes finales/producción).

**Regla de Oro:** La app SIEMPRE lee y escribe en la base de datos local (SQLite). La sincronización es un proceso en segundo plano.

1.  **Lectura:** La UI consume datos desde `LocalInspectionRepository`.
2.  **Escritura:** `InspectionFormController` guarda borradores en tablas `_pendientes` en SQLite.
3.  **Sync:** `SyncService` detecta conexión, sube los datos de SQLite a Supabase y luego limpia/marca lo local como 'subido'.


## 2. Arquitectura Técnica
* **Patrón:** Feature-First + Clean Architecture (Data, Domain, Presentation) + Repository Pattern.
* **Gestión de Datos:** * `SupabaseClient` para conexión remota.
    * `LocalRepository` (SQLite/Hive) para persistencia offline (Prioridad Offline-First).
    * Sincronización manual/automática cuando hay red.
* **Estructura de Directorios Clave (`lib/`):**
    * `core/`: Config (`supabase_config`, `theme`), Utils (`spanish_delegates`).
    * `features/`:
        * `auth/`: Login.
        * `home/`: Pantalla principal, lista de borradores (`draft_list_widget`).
        * `inspection/`: 
            * `data/`: `inspection_repository`, `local_...`, `supabase_...`.
            * `domain/models/`: `buceo_verificacion`, `formulario_item`, `pdf/`.
            * `presentation/`: `controllers` (Lógica de UI), `screens`, `widgets`.
    * `shared/`: Widgets reutilizables (`camera`, `form_inputs`), Servicios (`image_service`).

## 3. Esquema de Base de Datos (Supabase/PostgreSQL)
**Nota:** Uso de UUIDs (`gen_random_uuid()`) para todas las Primary Keys.

### Enums (Tipos Personalizados)
* `nivel_criticidad`: 'Bajo', 'Medio', 'Alto', 'Intolerable', 'Tolerable', 'Moderado'.
* `estado_actividad`: 'Habilitada', 'Suspendida', 'Rechazada', 'En Seguimiento', 'En Progreso'.
* `estado_respuesta`: 'C' (Cumple), 'NC' (No Cumple), 'N/A'.

### Tablas Principales
1.  **Maestras:** * `empresas` (id, nombre, rut) -> `areas` -> `centros`.
    * `contratistas` -> `embarcaciones`, `personal_externo` (buzos, tripulación).
    * `usuarios` (vinculado a `auth.users`, roles).

2.  **Operativas (Core):**
    * `actividades`: Cabecera principal. (FKs: usuario, centro, embarcación). Campos: `fecha_realizacion`, `estado_final`, `tipo_actividad`, `hora_inicio`, `hora_termino`.
    * `verificaciones_buceo`: Detalle 1:1 con `actividades`. Checkbox booleanos críticos (autoridad marítima, plan contingencia, etc.), `profundidad_maxima`, datos de compresores.
    * `actividad_participantes`: M:N (Quién estuvo en la faena y su rol).
    * `registro_fotografico`: Evidencia visual vinculada a la actividad.

3.  **Formularios Dinámicos:**
    * `formulario_items`: Preguntas maestras (categoría, pregunta, criticidad base).
    * `inspeccion_respuestas`: Respuestas de una inspección. Campos: `estado` (C/NC), `observacion`, `criticidad_registrada` (snapshot del momento).

4.  **Módulos Adicionales:**
    * `ast_registros` / `ast_detalles`: Análisis Seguro de Trabajo (Pasos, peligros, controles).
    * `capacitaciones_registros` / `capacitaciones_asistentes`: Registro de charlas y firmas.

## 4. Reglas de Negocio Críticas
1.  **Offline-First:** El usuario debe poder completar todo el flujo sin internet. Los datos se guardan en local y se suben al detectar conexión.
2.  **Validación de Roles:** Ciertas acciones (como borrar o aprobar) dependen del rol del usuario (`admin` vs `prevencionista`).
3.  **Integridad de Datos:** Al sincronizar, se debe respetar la relación `actividad` -> `respuestas` -> `fotos`.
4.  **Generación de PDF:** Se genera reporte localmente (`pdf_generator_service`) para compartir inmediato.

## 5. Convenciones de Código (Estilo Estudiante/Clean Code)
* Variables y funciones en `camelCase`. Clases en `PascalCase`.
* Archivos en `snake_case`.
* **Estricto:** Tipado fuerte (evitar `dynamic`).
* **Seguridad:** Validar inputs de texto (SQL injection prevention handled by ORM/Supabase), manejo de errores con `try/catch` en repositorios.

# CONTEXTO CÓDIGO FUENTE (FLUTTER/DART)

## 1. Gestión de Estado (Controllers)

### `InspectionFormController` (Core Logic)
Es el cerebro de la inspección. Gestiona el estado en memoria antes de persistir en SQLite.
* **Mapas de Estado (Acceso O(1)):**
    * `respuestas`: Map<String, String> (Key: `item_id`, Value: `'C'|'NC'|'N/A'`).
    * `observaciones`: Map<String, String>.
    * `criticidades`: Map<String, String> (Snapshot del momento, ej: `'Intolerable'`).
    * `fotosPorPregunta`: Map<String, File> (Maneja archivos locales temporales).
    * `fotosGenerales`: List<File>.
* **Datos Específicos (Buceo):**
    * `verificacionesBuceo`: Instancia de `BuceoVerificacionModel`.
    * `participantes`: Lista de `ParticipanteModel`.
* **Flujo de Carga (`_init`):**
    1.  Carga metadata de actividad (`actividades_pendientes`).
    2.  Carga items del formulario (`formulario_items`).
    3.  Rellena los mapas con respuestas previas desde SQLite (`inspeccion_respuestas_pendientes`).
    4.  Si es buceo, carga verificaciones y participantes.
* **Persistencia (`guardarBorrador` / `finalizarInspeccion`):**
    * `guardarBorrador()`: Guarda todo en SQLite sin validar completitud.
    * `finalizarInspeccion()`:
        * **Validación 1:** Cuadrilla >= 2 participantes (si es buceo).
        * **Validación 2:** Nivel de buceo seleccionado y profundidad > 0 (si aplica).
        * **Acción:** Cambia estado a `'En Seguimiento'`, guarda en SQLite y dispara `_syncService.sincronizarTodo()`.

### `InspectionSetupController`
Maneja la configuración previa a la inspección.
* **Lógica de Negocio:**
    * Determina si es una "Inspección Completa" o solo "Bitácora" basándose en si el puerto está `ABIERTO` o `CERRADO` (y la actividad seleccionada).
    * Genera el ID único (`uuid.v4()`) que se usará tanto en local como en la nube.
    * Guarda la cabecera en `actividades_pendientes` con `subido = 0`.

## 2. Capa de Datos (Repositories & DB)

### `LocalInspectionRepository` (SQLite)
Implementación concreta de `InspectionRepository` para modo Offline.
* **CRUD Actividades:** `saveActividad` (Upsert), `getActividad`, `eliminarBorrador` (Cascade manual: borra respuestas y fotos asociadas).
* **CRUD Respuestas:** `saveRespuestasBatch` (Usa transacción `batch` para eficiencia).
* **CRUD Fotos:** `saveFoto` (Guarda ruta local en `fotos_pendientes`, NO bytes).
* **CRUD Buceo:**
    * `guardarVerificacionesBuceo`: Upsert en tabla `verificaciones_buceo`.
    * `guardarParticipantes`: **Transacción Crítica**. Primero hace `DELETE` de todos los participantes de esa actividad y luego `INSERT` de la lista nueva (para manejar borrados en la UI).

### `DatabaseHelper` (Infraestructura)
* **Tablas Espejo:** Crea tablas locales (`_pendientes`) que replican la estructura de Supabase.
* **Maestros:** Tablas `areas`, `centros`, `contratistas`, `personal_externo` se sincronizan para consulta offline.

## 3. Modelos de Dominio (Domain Layer)

### `BuceoVerificacionModel`
* **Lógica de Seguridad (`faenaHabilitada`):**
    * Retorna `true` si: `estadoManual == 'APROBADO'` O (todos los checks booleanos son true).
    * Checks: `autorizacionAutoridadMaritima`, `induccionCentroCultivo`, `permisoBuceoCentroCorrecto`, `planContingenciasCentroOk`, `examenesOcupacionalesVigentes`.
* **Campos Técnicos:** `nivelBuceo`, `profundidadMaxima`, `supervisorRut`, datos de compresores.

### `ParticipanteModel`
* Representa la relación M:N entre Actividad y Personal.
* Campos clave: `personalId` (FK), `rolEnFaena` (Cargo del momento), `condicionesOptimas` (Bool).

## 4. UI Estructural

### `InspectionFormScreen`
* **Manejo de "Atrás":** Usa `PopScope`. Si el usuario intenta salir, intercepta la acción, muestra "Guardando borrador...", ejecuta `_controller.guardarBorrador(silent: true)` y luego cierra la pantalla.
* **Estructura del ListView:**
    1.  Header (Fábrica según tipo de inspección).
    2.  Parámetros de Faena (Profundidad/Nivel - Inyectado dinámicamente).
    3.  Lista de preguntas (Agrupadas por `Categoria`).
    4.  Verificaciones de Seguridad (Checks críticos).
    5.  Footer (Fotos generales + Botón Finalizar).

### `QuestionCard`
* Widget con estado interno (`AutomaticKeepAliveClientMixin`) para no perder la data al hacer scroll.
* Maneja visualmente los estados `C` (Verde), `NC` (Rojo + Observación obligatoria), `N/A` (Gris).
necesitas mas contexto?