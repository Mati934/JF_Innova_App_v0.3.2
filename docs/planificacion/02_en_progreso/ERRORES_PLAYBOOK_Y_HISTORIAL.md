# Playbook de Errores - JF Innova App

## Metodología de resolución

Cuando el usuario reporta un error, seguir este flujo:

### Fase 1: Diagnóstico
1. **Reproducir mentalmente** el flujo que causa el error (qué pantalla, qué acción, qué path: online vs offline)
2. **Trazar el dato** desde su origen hasta donde falla: Supabase → download → SQLite → query → modelo Dart → controller → pantalla/PDF
3. **Identificar TODOS los paths** por donde pasa el dato (ej: path online vs deferred, sync vs login, etc.)
4. **Buscar discrepancias** entre paths — si uno funciona y otro no, la diferencia es el bug
5. **Revisar modelos**: ¿el campo relevante existe en el modelo Dart o se pierde en `fromJson`?

### Fase 2: Plan de solución
1. **Fix directo**: corregir la causa raíz (ej: agregar ORDER BY faltante)
2. **Defensa en profundidad**: asegurar que el dato se preserve en toda la cadena (modelo, DTO, query)
3. **Eliminar fragilidad**: quitar hardcodes, asegurar consistencia entre paths paralelos
4. **Cerrar puertas traseras**: si el dato puede llegar desordenado/corrupto desde Supabase, agregar `.order()` o validación

### Fase 3: Tests (obligatorios)
Cada fix DEBE tener tests que cubran:
1. **Unit test del modelo**: parseo correcto del campo, valores default, nulls
2. **Unit test de la lógica**: la función/query produce el resultado esperado
3. **Test de consistencia entre paths**: path A y path B producen el mismo resultado
4. **Edge cases**: datos vacíos, nulls, gaps, duplicados, valores inesperados
5. **Test de regresión**: el escenario exacto del bug no vuelve a ocurrir
6. **Test de integración** (si aplica): generar el output final (PDF, pantalla) sin error

### Checklist pre-cierre
- [ ] Todos los tests pasan (nuevos + existentes)
- [ ] No se rompió nada existente (`flutter test` completo)
- [ ] El fix cubre TODOS los paths paralelos, no solo el que falló
- [ ] El modelo Dart tiene el campo relevante (no se pierde en fromJson)
- [ ] Las queries Supabase y SQLite son consistentes

---

## Errores resueltos

### BUG-001: Preguntas desordenadas en informes PDF

**Estado:** Resuelto | **Fecha:** 2026-04-08

#### Diagnóstico
Algunos informes PDF tenían las preguntas de inspección en orden incorrecto. Solo ocurría en PDFs generados por el path diferido (offline → sync → PDF posterior).

**Síntoma**: Preguntas mezcladas entre categorías o dentro de una categoría.
**Path afectado**: `DeferredPdfService` (offline). Path online (`InspectionFormController`) funcionaba bien.

#### Causa raíz
El dato `orden` se perdía o no se respetaba en múltiples puntos de la cadena:

| Punto de fallo | Archivo:línea | Impacto |
|---|---|---|
| Query sin ORDER BY | `deferred_pdf_service.dart:238` | CRÍTICO — items en orden arbitrario de SQLite |
| Modelo sin campo `orden` | `formulario_item.dart` | MEDIO — imposible re-ordenar después del query |
| DTO sin campo `orden` | `inspection_report_data.dart` | MEDIO — orden no viaja al PDF generator |
| Supabase download sin `.order()` | `sync_service.dart:37`, `login_screen.dart:70` | MEDIO — riesgo latente |
| categoryOrder hardcoded | `pdf_generator_service.dart:232` | BAJO — solo 3 categorías de buceo, embarcación desordenada |

#### Fixes aplicados
- [x] `deferred_pdf_service.dart` — agregado `orderBy: 'orden ASC'` a query de `formulario_items`
- [x] `formulario_item.dart` — campo `orden` agregado al modelo y `fromJson`
- [x] `inspection_report_data.dart` — campo `orden` agregado a `InspectionItemDto`
- [x] `inspection_form_controller.dart` — pasa `orden: item.orden` al DTO (path online)
- [x] `deferred_pdf_service.dart` — pasa `orden: item['orden']` al DTO (path diferido)
- [x] `sync_service.dart` — `.order('orden')` en descarga Supabase
- [x] `login_screen.dart` — `.order('orden')` en descarga inicial
- [x] `pdf_generator_service.dart` — `categoryOrder` ahora dinámico (basado en orden de aparición de items), eliminado hardcode de 3 categorías buceo

#### Tests (`test/item_ordering_test.dart` — 16 tests)
| Test | Qué verifica |
|---|---|
| `fromJson parsea orden correctamente` | Campo `orden` se lee de JSON |
| `fromJson usa default 0 cuando orden es null` | Null safety |
| `fromJson usa default 0 cuando orden no existe` | Campo ausente |
| `fromJson preserva todos los campos junto con orden` | No rompe otros campos |
| `constructor asigna orden correctamente` | DTO acepta `orden` |
| `orden default es 0` | DTO sin `orden` explícito |
| `items dentro de categoria mantienen orden ASC` | Agrupamiento preserva secuencia |
| `categorias en orden del primer item` | Orden de categorías correcto |
| `una sola categoria mantiene orden interno` | Caso simple |
| `items con gaps en orden` | Gaps (1, 5, 10, 100) no rompen |
| `items con orden 0 (default)` | Orden 0 no causa problemas |
| `lista vacia no falla` | Edge case vacío |
| `datos ordenados = misma secuencia entre paths` | Path online == path diferido |
| `PDF con 3 categorias buceo` | Genera PDF válido con orden correcto |
| `PDF con categorias no-buceo` | Categorías nuevas no crashean |
| `PDF con items re-ordenados` | Sort por `orden` produce secuencia correcta |

#### Lección aprendida
> Cuando hay dos paths que producen el mismo output (online vs deferred), AMBOS deben hacer exactamente las mismas operaciones sobre los datos. Si uno tiene ORDER BY, el otro también. Si uno pasa un campo al DTO, el otro también. Discrepancia entre paths paralelos = bug latente.

---

## Plantilla para nuevos errores

```
### BUG-NNN: [Título corto]

**Estado:** Pendiente | En progreso | Resuelto | **Fecha:** YYYY-MM-DD

#### Diagnóstico
[Qué pasa, cuándo pasa, qué path está afectado]

#### Causa raíz
[Tabla con punto de fallo, archivo:línea, impacto]

#### Fixes aplicados
- [ ] Fix 1
- [ ] Fix 2

#### Tests
[Tabla con nombre del test y qué verifica]

#### Lección aprendida
> Cuando hay dos paths que producen el mismo output (online vs deferred), AMBOS deben hacer exactamente las mismas operaciones sobre los datos. Si uno tiene ORDER BY, el otro también. Si uno pasa un campo al DTO, el otro también. Discrepancia entre paths paralelos = bug latente.

---

### BUG-002: Inspección finalizada sin PDF

**Estado:** Resuelto | **Fecha:** 2026-04-08

#### Diagnóstico
Una inspección en el historial aparecía sin PDF. Solo había un caso, pero el flujo tenía múltiples formas de perder el PDF.

**Síntoma**: Inspección "En Seguimiento" en historial sin link a PDF.

#### Causa raíz
3 escenarios que podían dejar una inspección sin PDF:

| # | Escenario | Severidad | Auto-recuperable? |
|---|-----------|-----------|-------------------|
| A | `sincronizarTodo()` tenía try/catch global: si pasos 2-5 fallaban, `_generarPdfsDiferidos()` (paso 6) se saltaba completamente | **CRÍTICO** | No — requería que el próximo sync completo no fallara |
| B | Catch silencioso en controller (línea 743): si PDF generation falla, marca como finalizado sin PDF y retorna `true` al usuario | **ALTO** | Parcialmente — depende de escenario A no ocurrir |
| C | `numero_reporte` nunca asignado: si sync parcial dejó actividad con `subido=1` pero sin `numero_reporte`, `_generarPdfsDiferidos` la ignora (requiere `numero_reporte IS NOT NULL`) | **ALTO** | **No** — inspección stuck para siempre |

#### Fixes aplicados
- [x] `sync_service.dart:sincronizarTodo()` — `_generarPdfsDiferidos()` movido FUERA del try/catch principal, se ejecuta SIEMPRE
- [x] `sync_service.dart` — nuevo método `_recuperarNumeroReporteFaltante()`: busca inspecciones "En Seguimiento" sin `numero_reporte` y lo lee de Supabase. Se ejecuta antes de `_generarPdfsDiferidos()`
- [x] Flujo: `sincronizarTodo()` ahora es: try{pasos 1-5}catch → try{recuperar numero + generar PDFs}catch

#### Tests (`test/sync_and_draft_test.dart` — 11 tests nuevos)
| Test | Qué verifica |
|---|---|
| `Query detecta inspección sin PDF con numero_reporte` | Detección correcta de pendientes |
| `Query ignora inspección eliminada` | Soft-delete no genera PDF |
| `Query ignora inspección sin numero_reporte` | Sin número = sin PDF (correcto) |
| `Query trata pdf_path_local vacío como null` | String vacío == null para la detección |
| `Detecta inspecciones stuck sin numero_reporte` | `_recuperarNumeroReporteFaltante` las encuentra |
| `Inspección con numero_reporte no se toca` | No re-consulta innecesariamente |
| `Si sync falla, PDFs diferidos aún se ejecutan` | Fix principal: independencia de pasos |
| `Si sync tiene éxito, PDFs diferidos también` | No regresión en caso feliz |
| `PDF catch marca pdfDiferido = true` | Fallback silencioso funciona |
| `pdfDiferido=true queda detectable` | DeferredPdfService la encuentra |
| `Sin numero_reporte es recuperable` | `_recuperarNumeroReporteFaltante` la cubre |

#### Lección aprendida
> Nunca poner operaciones de recuperación (como generación de PDFs diferidos) dentro del mismo try/catch que las operaciones que pueden fallar independientemente. Si el paso 2 falla, el paso 6 no debería verse afectado. Cada fase de recuperación debe ser autónoma y ejecutarse SIEMPRE.

```
