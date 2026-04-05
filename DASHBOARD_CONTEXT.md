# Dashboard JF Innova App - Contexto Técnico VALIDADO

**Fecha:** 2026-04-01
**Proyecto:** JF Innova App (Flutter + SQLite + Supabase)
**Módulo:** Dashboard & Reportería
**Status:** ✅ Estructura de datos validada

---

## 🎨 UI/Navegación - DECISIONES

### Integración en HomeScreen
- **Ubicación:** Tarjeta en `ModuleSelectorGrid` (grilla de módulos)
- **Nombre:** "Dashboard de Reportes"
- **Icono:** `Icons.dashboard` (tablero)
- **Posición:** Reemplaza "Rendiciones" (que estaba deshabilitado)
- **Color:** `AppTheme.primaryBlue` (consistente con inspecciones)
- **Estado:** Habilitado siempre (no necesita validaciones)

### Estructura Visual
```
┌─────────────────────────────────────┐
│ [Nueva Inspección] [Visita Técnica] │
│                                     │
│ [Extintores]   [Dashboard Reportes]│ ← NUEVA
│                                     │
│ [... otros módulos si futuros]     │
└─────────────────────────────────────┘
```

### Código cambios mínimos
1. Modificar `module_selector_grid.dart`: agregar callback `onDashboardTap`
2. Modificar `home_screen.dart`: pasar callback y navegar a `DashboardScreen`
3. Crear `DashboardScreen` en `lib/features/dashboard/presentation/screens/`

---

## 🎯 Requerimientos

**Usuario final:** Administrador de empresa

**Funcionalidades:**
1. **Dashboard KPIs:**
   - Total de inspecciones realizadas (período configurable)
   - Porcentaje de cumplimiento por inspección/pregunta
   - Análisis de "no cumples" (hallazgos no conformes)
   - Top de "no cumples" más frecuentes
   - Reportería semanal (base, luego extendible)

2. **Sistema Modular de Reportes:**
   - Usuario selecciona qué módulos incluir (inspecciones, visitas, tickets, extintores)
   - Usuario arrastra/ordena módulos dentro del PDF
   - PDF se genera con secciones modulares (cada módulo = sección)
   - Innovación: reportes personalizados sin código

3. **Exportación:**
   - PDFs con gráficos
   - Visualización en-app
   - Descarga de reportes generados

---

## 🗄️ Datos Necesarios - ESTRUCTURA VALIDADA

### Tablas SQLite Clave (v35)

**Para KPIs & "No Cumples":**

1. **`actividades_pendientes`** (tabla principal de inspecciones/actividades)
   ```sql
   id TEXT PRIMARY KEY
   usuario_id TEXT
   centro_id TEXT, contratista_id TEXT, embarcacion_id TEXT
   tipo_actividad TEXT  -- INSPECCION_BUCEO, INSPECCION_EMBARCACION, VISITA_R*, VISITA_R004
   fecha_realizacion TEXT  -- YYYY-MM-DD HH:MM:SS
   estado_final TEXT  -- Borrador, Incomplete, Completada, En Seguimiento
   numero_reporte TEXT  -- NULL hasta cambiar a "En Seguimiento" (asignado por trigger)
   observaciones_generales TEXT
   pdf_url TEXT, pdf_path_local TEXT
   eliminado INTEGER (0/1), subido INTEGER (0/1)
   puerto_abierto INTEGER (0/1)
   ```
   - ⚠️ **NO TIENE `empresa_id` directo** → obtener vía `usuarios.empresa_id`

2. **`inspeccion_respuestas_pendientes`** (las respuestas = "No Cumple", "Cumple", "N/A")
   ```sql
   id INTEGER PRIMARY KEY AUTOINCREMENT
   actividad_id TEXT  -- FK a actividades_pendientes
   item_id TEXT  -- FK a formulario_items
   estado TEXT  -- 'C' (Cumple), 'NC' (No Cumple), 'NA' (No Aplica)
   observacion TEXT  -- Detalle/hallazgo (especialmente en NC)
   criticidad_registrada TEXT  -- Tolerable, Moderado, Intolerable
   subido INTEGER
   ```
   - **AQUÍ ESTÁN LOS "NO CUMPLES"** → `WHERE estado = 'NC'`

3. **`formulario_items`** (catálogo de preguntas/items)
   ```sql
   id TEXT PRIMARY KEY
   tipo_actividad TEXT  -- Filtra por tipo de inspección
   categoria TEXT  -- Agrupa preguntas
   pregunta TEXT  -- Texto de la pregunta
   criticidad TEXT  -- Tolerable, Moderado, Intolerable
   orden INTEGER
   activo INTEGER (0/1)
   info_adicional TEXT
   url_imagen_referencia TEXT
   ```

4. **`visitas_tecnicas_pendientes`** (visitas técnicas)
   ```sql
   id TEXT PRIMARY KEY
   usuario_id TEXT
   fecha_realizacion TEXT
   estado_final TEXT  -- similar a actividades
   tipo_actividad TEXT  -- VISITA_R*, VISITA_R004 (extintor), etc
   empresa TEXT  -- nombre empresa (NO empresa_id)
   lugar_inspeccion TEXT
   pdf_url TEXT, pdf_path_local TEXT
   ```
   - ⚠️ **TAMBIÉN SIN `empresa_id`** → obtener vía usuario

5. **`usuarios`** (vinculación con empresa)
   ```sql
   id TEXT PRIMARY KEY
   empresa_id TEXT  -- ⭐ CLAVE PARA FILTRAR
   nombre_completo TEXT
   email TEXT, telefono TEXT
   rol_id TEXT, nombre_rol TEXT
   ```

### Multi-tenancy (v35) - IMPLEMENTADO
- `usuarios.empresa_id` → **ÚNICA FUENTE DESDE v35**
- Todas las inspecciones/visitas se filtran por `usuarios.empresa_id`
- Las tablas `actividades_pendientes` y `visitas_tecnicas_pendientes` NO tienen column `empresa_id`
- **Pattern Query:**
  ```sql
  SELECT ap.*, f.pregunta, f.criticidad, ir.estado, ir.observacion
  FROM actividades_pendientes ap
  JOIN usuarios u ON ap.usuario_id = u.id
  JOIN inspeccion_respuestas_pendientes ir ON ap.id = ir.actividad_id
  JOIN formulario_items f ON ir.item_id = f.id
  WHERE u.empresa_id = ?
    AND ir.estado = 'NC'
    AND ap.fecha_realizacion BETWEEN ? AND ?
  ORDER BY ap.fecha_realizacion DESC
  ```

---

## 📊 Query Examples for Dashboard

### KPI 1: Total Inspeccionadas (período)
```sql
SELECT COUNT(DISTINCT ap.id) as total
FROM actividades_pendientes ap
JOIN usuarios u ON ap.usuario_id = u.id
WHERE u.empresa_id = ?
  AND ap.estado_final IN ('Completada', 'En Seguimiento')
  AND ap.fecha_realizacion BETWEEN ? AND ?
```

### KPI 2: Cumplimiento % (C vs NC)
```sql
SELECT
  COUNT(DISTINCT CASE WHEN ir.estado = 'C' THEN ir.id END) as cumples,
  COUNT(DISTINCT CASE WHEN ir.estado = 'NC' THEN ir.id END) as no_cumples,
  ROUND(
    COUNT(DISTINCT CASE WHEN ir.estado = 'C' THEN ir.id END) * 100.0 /
    NULLIF(
      COUNT(DISTINCT ir.id) - COUNT(DISTINCT CASE WHEN ir.estado = 'NA' THEN ir.id END),
      0
    ),
    2
  ) as porcentaje_cumplimiento
FROM inspeccion_respuestas_pendientes ir
JOIN actividades_pendientes ap ON ir.actividad_id = ap.id
JOIN usuarios u ON ap.usuario_id = u.id
WHERE u.empresa_id = ?
  AND ap.estado_final IN ('Completada', 'En Seguimiento')
  AND ap.fecha_realizacion BETWEEN ? AND ?
```

### KPI 3: Top "No Cumples" más frecuentes
```sql
SELECT
  f.pregunta,
  f.categoria,
  f.criticidad,
  COUNT(*) as cantidad_nc,
  GROUP_CONCAT(DISTINCT ir.observacion, '; ') as observaciones_ejemplo
FROM inspeccion_respuestas_pendientes ir
JOIN formulario_items f ON ir.item_id = f.id
JOIN actividades_pendientes ap ON ir.actividad_id = ap.id
JOIN usuarios u ON ap.usuario_id = u.id
WHERE u.empresa_id = ?
  AND ir.estado = 'NC'
  AND ap.estado_final IN ('Completada', 'En Seguimiento')
  AND ap.fecha_realizacion BETWEEN ? AND ?
GROUP BY ir.item_id
ORDER BY cantidad_nc DESC
LIMIT 5
```

### KPI 4: Tendencia de cumplimiento (diaria/semanal)
```sql
SELECT
  DATE(ap.fecha_realizacion) as fecha,
  COUNT(DISTINCT CASE WHEN ir.estado = 'C' THEN ir.id END) as cumples,
  COUNT(DISTINCT CASE WHEN ir.estado = 'NC' THEN ir.id END) as no_cumples,
  ROUND(
    COUNT(DISTINCT CASE WHEN ir.estado = 'C' THEN ir.id END) * 100.0 /
    NULLIF(
      COUNT(DISTINCT ir.id) - COUNT(DISTINCT CASE WHEN ir.estado = 'NA' THEN ir.id END),
      0
    ),
    2
  ) as porcentaje
FROM inspeccion_respuestas_pendientes ir
JOIN actividades_pendientes ap ON ir.actividad_id = ap.id
JOIN usuarios u ON ap.usuario_id = u.id
WHERE u.empresa_id = ?
  AND ap.estado_final IN ('Completada', 'En Seguimiento')
  AND ap.fecha_realizacion BETWEEN ? AND ?
GROUP BY DATE(ap.fecha_realizacion)
ORDER BY fecha ASC
```

---

## 🏗️ Arquitectura Existente

### Controllers
- Sin Provider global
- Cada screen crea su propio `ChangeNotifier` controller
- Patrón: `_disposed` flag + `_safeNotify()` para async

### Base de Datos
- **DatabaseHelper** (singleton) → acceso SQLite
- v35: `empresa_id` en usuarios (FINAL: no habrá más migraciones de schema para multi-tenancy)
- Versión actual: 35

### Sincronización
- **SyncService** → `descargarDatosMaestros()`, `sincronizarTodo()`
- Auto-save con Debouncer(2000ms)
- PDFs diferidos: `DeferredPdfService`

### PDF Generation
- Ubicación: `lib/features/inspection/services/deferred_pdf_service.dart`
- Patrón: genera PDFs cuando inspección obtiene `numero_informe`
- Soporta múltiples módulos (inspecciones, visitas, extintores)

---

## 📁 Estructura del Proyecto

```
lib/features/
├── auth/              # Login/AuthGate
├── home/              # HomeScreen
├── inspection/        # Inspecciones buceo + embarcación
├── visits/            # Visitas Técnicas
├── tickets/           # Tickets de Requerimientos
├── extintores/        # Módulo extintores (VISITA_R004)
├── admin/             # Master Data Management
├── history/           # Historial (solo online)
├── sync/              # SyncService
├── dashboard/         # ⬅️ NUEVO: Dashboard + Reportería
└── core/
    ├── database/      # DatabaseHelper
    ├── utils/         # RUT, formatters, etc
    └── ...
```

---

## ✅ Decisiones Técnicas - VALIDADAS

1. ✅ **"No cumples" están en `inspeccion_respuestas_pendientes.estado = 'NC'`**
   - Con detalles en `observacion`
   - Criticidad en `criticidad_registrada`

2. ✅ **Multi-tenancy via `usuarios.empresa_id`**
   - Todas las queries deben filtrar por empresa vía usuario
   - Las tablas de inspecciones NO tienen empresa_id column

3. ✅ **Período configurable:**
   - Usar `fecha_realizacion` en actividades_pendientes
   - Semanal base, luego extender a custom range

4. ✅ **PDFs modulares:**
   - `DeferredPdfService` ya existe y es extensible
   - Cada módulo (inspección, visita, extintor) = 1 generador PDF
   - Ordenamiento por selector UI

5. ✅ **Estados:**
   - Inspecciones filtradas por `estado_final IN ('Completada', 'En Seguimiento')`
   - Los borradores (estado='Borrador') se excluyen del dashboard

---

## 📚 Referencias

- **Memory:** `C:\Users\matip\.claude\projects\c--src-Proyectos-jf-innova-app\memory\MEMORY.md`
- **DatabaseHelper:** `lib/core/database/database_helper.dart` (v35 schema completo)
- **InspectionFormController:** `lib/features/inspection/presentation/controllers/inspection_form_controller.dart` (cómo se guardan respuestas)
- **PDF Service:** `lib/features/inspection/services/deferred_pdf_service.dart`
- **SyncService:** `lib/features/sync/services/sync_service.dart`
- **Criticidad scales:** `memory/criticidad.md`

---

## 📊 Gráficos Soportados

### Fase 1: Gráficos Iniciales (Fijos)
| KPI | Tipo | Librería | Descripción |
|-----|------|----------|-------------|
| Total Inspecciones | Número grande | Texto + card | Solo número con ícono |
| % Cumplimiento | Circular (gauge) | `fl_chart` | Indicador de progreso circular |
| Top "No Cumples" | Barras horizontal | `fl_chart` | 5 items más frecuentes |
| Tendencia (diaria/semanal) | Línea | `fl_chart` | Cumplimiento a lo largo del período |

### Fase 2: Gráficos Intercambiables (Futuro)
- Soporte para cambiar tipo de gráfico dentro del Dashboard (selector UI)
- Opciones por métrica: barras ↔ línea, circular ↔ porcentaje texto, etc.
- Persistencia: guardar preferencias de usuario en Preferencias locales

---

## ✅ Checklist Implementación

### FASE 0: Integración UI (necesario primero)
- [ ] Modificar `module_selector_grid.dart` para agregar parámetro `onDashboardTap`
- [ ] Agregar tarjeta dashboard a la grilla (ícono dashboard, color blue)
- [ ] Modificar `home_screen.dart` para pasar callback de navegación
- [ ] Crear pantalla base `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- [ ] Navegar correctamente desde HomeScreen al DashboardScreen

### FASE 1: Dashboard KPIs (necesario primero)
- [ ] Crear DashboardController (ChangeNotifier)
- [ ] Implementar queries SQL para KPIs (copiar de Query Examples)
- [ ] Crear DashboardScreen con visualización KPIs
- [ ] Agregar filtro período (semanal + date range)
- [ ] Gráficos: tendencia, "no cumples" top 5

### FASE 2: Generador Modular de Reportes
- [ ] Crear ReportGeneratorController
- [ ] Diseñar modal selector de módulos (checkboxes)
- [ ] Implementar drag-drop para reordenar
- [ ] Crear interface para cada módulo PDF (builder pattern)
- [ ] Generar PDF modular (pieza por pieza)
- [ ] Vista previa antes de descargar

### FASE 3: Persistencia de Reportes
- [ ] Crear tabla `reportes_generados` (historial)
- [ ] Guardar PDF generados localmente
- [ ] Sync de reportes a Supabase
- [ ] Pantalla historial de reportes

---

**Status:** ✅ Contexto validado, listo para implementación
**Próximo paso:** Crear DashboardController e implementar KPIs
