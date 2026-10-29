# PROSESSO — Lista de Tareas

> Checklist operativo. Marcar `[x]` cuando esté hecho.
> Documento maestro de contexto: `PROSESSO_MODULE.md`.

---

## FASE 1 — Base de Datos & Empresa

- [x] **1.1** SQL Supabase: crear empresa `PROSESSO SpA` en tabla `empresas`.
- [x] **1.2** SQL Supabase: insertar módulo `MANTENCION_PROSESSO` en `empresa_modulos` SOLO para empresa PROSESSO (habilitado=true).
- [x] **1.3** SQL Supabase: crear tabla `public.mantenciones_prosesso` (espejo de la SQLite).
- [x] **1.4** SQL Supabase: agregar columnas a `visitas_tecnicas` (`cert_numero`, `cert_anio`, `cert_correlativo`, `cliente_nombre`, `cliente_direccion`, `fecha_servicio`).
- [x] **1.5** SQL Supabase: secuencia/trigger para autoincrementar `cert_correlativo` por año (asignado al pasar de borrador → finalizado).
- [x] **1.6** SQL Supabase: insertar 9 `formulario_items` con `tipo_actividad = 'MANTENCION_PROSESSO'` (sello, señaletica, etiqueta, gabinete, pintura, seguro, manometro, soporte, manguera).
- [x] **1.7** Archivo `supabase_migration_prosesso.sql` creado con todo lo anterior.
- [x] **1.8** SQLite: bumpear `_dbVersion` y agregar tabla `mantenciones_prosesso_pendientes` + columnas nuevas en `visitas_tecnicas_pendientes` en `_onUpgrade`.
- [x] **1.9** SQLite: incluir nueva tabla en el `CREATE TABLE` inicial (instalación limpia).

## FASE 2 — Registro del Módulo

- [x] **2.1** Agregar `MANTENCION_PROSESSO` a `ModuleRegistry` con icono propio (ej: `Icons.build_circle`, color rojo PROSESSO).
- [x] **2.2** Verificar que `module_registry.dart` carga `ProsessoSetupScreen`.
- [ ] **2.3** Confirmar que el módulo respeta `empresa_modulos` y NO aparece para Mowi/Aquachile/JF Innova.

## FASE 3 — Modelos de Dominio

- [x] **3.1** `ProsessoExtintorState` — modelo equivalente a `ExtintorState` con campos: numero, planta, ubicacion, ubicacion_sector, ubicacion_2, certificado, anio, tipo, peso, kg, fecha_vencimiento, observaciones, fotoPaths, puntos.
- [x] **3.2** `ProsessoReportData` — datos para el PDF: cliente, dirección, fecha servicio, cert_numero, listado de extintores.
- [x] **3.3** `clonarEstados` para copiar respuestas entre extintores (UX rápida).

## FASE 4 — Repositorio

- [x] **4.1** `LocalProsessoRepository` — `saveServicio`, `getBorradores`, `getExtintoresPorVisita`, `eliminarBorrador`, `marcarSubida`, `siguienteCertNumero`.
- [x] **4.2** Integración con `LocalInspectionRepository.getItems('MANTENCION_PROSESSO')`.

## FASE 5 — UI

- [ ] **5.1** `ProsessoSetupScreen` — formulario inicial: Cliente, Dirección, Fecha servicio, Nº Certificado (precargado y editable).
- [x] **5.2** `ProsessoFormScreen` — lista expandible de extintores (calcado de `ExtintorFormScreen`).
- [x] **5.3** `ProsessoExtintorCard` — card colapsable con todos los metadatos del extintor + checklist.
- [x] **5.4** `ProsessoPuntoRow` — fila para cada pregunta C/NC/N/A.
- [x] **5.5** Botón duplicar/clonar extintor (mismo patrón existente).
- [x] **5.6** Botón "Finalizar y generar PDFs".

## FASE 6 — Generación de PDFs

- [ ] **6.1** Recibir/agregar assets: `assets/images/prosesso_logo.png` y `assets/images/firma_jose_miguel.png`. Declarar en `pubspec.yaml`.
- [x] **6.2** `ProsessoPdfService` — clase única que genera AMBOS PDFs reutilizando fuentes/imágenes en memoria.
- [x] **6.3** PDF 1 — Registro de Mantención (tabla con todas las columnas del Excel + columnas si/no/n/a por pregunta).
- [x] **6.4** PDF 2 — Certificado de Servicio (header logo + Nº, datos cliente, tabla resumen, normas, firma, nota validez).
- [x] **6.5** Generación en paralelo con `Future.wait`.
- [x] **6.6** Guardar paths locales en `visitas_tecnicas_pendientes.pdf_path_local` (registro) y `pdf_certificado_path_local` (certificado — nueva columna).
- [x] **6.7** UI: botones para abrir/compartir cada PDF por separado.

## FASE 7 — Sincronización

- [x] **7.1** Extender `SyncService` para subir filas de `mantenciones_prosesso_pendientes` → `mantenciones_prosesso` en Supabase.
- [x] **7.2** Subir ambos PDFs al storage de Supabase (bucket existente).

## FASE 8 — Borradores en Home

- [x] **8.1** `draft_card_mapper.dart` — mapear `tipo_actividad = 'MANTENCION_PROSESSO'` a label "Mantención PROSESSO".
- [x] **8.2** Verificar que aparece en `draft_list_widget`.

## FASE 9 — QA & Pulido

- [x] **9.1** `flutter analyze` sin errores nuevos.
- [ ] **9.2** Probar flujo completo: setup → agregar 3 extintores → finalizar → ver ambos PDFs.
- [ ] **9.3** Validar que el módulo no se ve para empresas distintas a PROSESSO.
- [ ] **9.4** Validar autoincremento de `cert_numero` (crear 2 servicios, ver 2025/N y 2025/N+1).
- [ ] **9.5** Validar offline-first: crear sin internet, sincronizar al volver.

---

## Pendientes / Bloqueos

- ⚠️ **Necesito del usuario:** archivos `prosesso_logo.png` y `firma_jose_miguel.png` (colocar en `assets/images/`).
- ⚠️ **Confirmar:** UUID/ID de la empresa PROSESSO una vez creada en Supabase (para los seeds).

