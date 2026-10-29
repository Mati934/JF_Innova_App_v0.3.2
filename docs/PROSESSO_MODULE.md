# Módulo PROSESSO — Mantención y Recarga de Extintores

> **Documento maestro** para el módulo de PROSESSO.
> Todo lo relacionado a esta empresa y este flujo se documenta acá.
> El checklist operativo de tareas vive en `PROSESSO_TASKS.md`.

---

## 1. Contexto del Negocio

**Empresa:** PROSESSO SpA
**Tipo de servicio:** Mantención y recarga de extintores (más operativo que una inspección).
**Cliente final típico:** Mowi Chile S.A., Centro Huelmo (entre otros).
**Salidas requeridas tras un servicio:**
1. **PDF Registro de Mantención** — listado completo de los extintores intervenidos con sus chequeos.
2. **PDF Certificado de Servicio de Mantenimiento y Recarga de Extintores** — formato oficial PROSESSO con firma de José Miguel Muñoz (Gerente técnico).

---

## 2. Decisiones Técnicas (acordadas)

| Tema | Decisión |
|---|---|
| ¿Tabla por empresa? | **NO**. Multi-tenant. Nuevo módulo `MANTENCION_PROSESSO` registrado en `module_registry.dart` y habilitado vía `empresa_modulos` SOLO para PROSESSO. |
| Tabla SQLite nueva | `mantenciones_prosesso_pendientes` (espejo en Supabase: `mantenciones_prosesso`). Cabecera reutiliza `visitas_tecnicas_pendientes` con `tipo_actividad = 'MANTENCION_PROSESSO'`. |
| Preguntas / Checklist | **Configurables** vía `formulario_items` con `tipo_actividad = 'MANTENCION_PROSESSO'`. Seed inicial: 9 preguntas (sello, señaletica, etiqueta, gabinete, pintura, seguro, manometro, soporte, manguera). |
| Estados respuestas | `C` / `NC` / `NA` (mismo enum existente). |
| `certificado` (columna del extintor) | **TEXT** (no INTEGER) — algunos registros llevan prefijo "CN". |
| Nº de Certificado del PDF | **Autoincremental por año + editable** (formato `2025/NN`). Se guarda en la cabecera de la mantención. |
| Datos del Certificado PDF | Formulario al inicio: **Cliente, Dirección, Fecha de servicio**. Resto fijo: D.S y O.M. Ordinario Nº 12600/06/208/Vrs, Tipo de Servicio, Normas, Firma José Miguel Muñoz - Gerente técnico. |
| PDFs | Generados en una sola pasada por `ProsessoPdfService` reutilizando fuentes/logo en memoria. |

---

## 3. Esquema de Datos

### 3.1 Tabla SQLite: `mantenciones_prosesso_pendientes`

Cada fila = un extintor intervenido (relacionado a una visita/servicio).

```sql
CREATE TABLE mantenciones_prosesso_pendientes (
  id TEXT PRIMARY KEY,                      -- uuid
  visita_id TEXT NOT NULL,                  -- FK a visitas_tecnicas_pendientes
  numero INTEGER NOT NULL,                  -- correlativo dentro del servicio (1,2,3..)
  planta TEXT,                              -- ej: BRIGADA DE EMERGENCIA
  ubicacion_sector TEXT,                    -- ej: PASILLO
  ubicacion_2 TEXT,                         -- ej: LADO SUBIDA ESCALERA VAP
  ubicacion TEXT,                           -- "ubicación" original (ej: LOCKERS N°2)
  certificado TEXT,                         -- alfanumérico (ej: 4322636 o "CN-..")
  anio INTEGER,                             -- ej: 2015
  tipo TEXT,                                -- ej: PQS, CO2, K
  peso TEXT,                                -- ej: "50"
  kg TEXT,                                  -- usualmente "KG"
  fecha_vencimiento TEXT,                   -- ej: ago-26 / 2026-08
  observaciones TEXT,
  respuestas_json TEXT,                     -- {item_id: {estado, observacion}}
  fotos_json TEXT,                          -- list<string> rutas locales
  subido INTEGER DEFAULT 0,
  created_at TEXT
);
CREATE INDEX idx_mantenciones_prosesso_visita ON mantenciones_prosesso_pendientes(visita_id);
```

### 3.2 Cabecera: `visitas_tecnicas_pendientes`

Se reutiliza tal cual, con campos extra (vía columnas existentes o nuevas):

- `tipo_actividad = 'MANTENCION_PROSESSO'`
- `empresa = 'PROSESSO SpA'`
- `lugar_visita` / `lugar_inspeccion` = nombre del cliente (ej: "Mowi Chile S.A. - Centro Huelmo")
- Nuevas columnas a agregar (si no existen):
  - `cert_numero TEXT` — ej "2025/30"
  - `cert_anio INTEGER`
  - `cert_correlativo INTEGER`
  - `cliente_nombre TEXT`
  - `cliente_direccion TEXT`
  - `fecha_servicio TEXT`

### 3.3 Supabase

- Espejo `public.mantenciones_prosesso` con misma estructura + `created_at timestamptz default now()`.
- Migración SQL en `supabase_migration_prosesso.sql`.
- Trigger/secuencia para `cert_correlativo` por año (similar a `numero_informe`).

---

## 4. Flujo de Usuario

1. Usuario PROSESSO entra → ve módulo "Mantención Extintores PROSESSO" en el grid.
2. **Pantalla setup** — completa: Cliente, Dirección, Fecha de servicio. Sistema sugiere `cert_numero` autoincremental (editable).
3. **Pantalla formulario** — agrega N extintores. Por cada uno:
   - Datos: número, planta, ubicación, sector, ubicación 2, certificado, año, tipo, peso, kg, fecha venc.
   - Checklist 9 preguntas (C/NC/N/A).
   - Observaciones.
4. Guardar borrador / Finalizar → genera **DOS PDFs**:
   - `mantencion_prosesso_<id>.pdf` (Registro)
   - `certificado_prosesso_<cert_numero>.pdf` (Certificado oficial firmado)

---

## 5. Generación de PDFs

### 5.1 PDF Registro de Mantención
- Tabla principal con todas las columnas del Excel.
- Una columna por cada pregunta (sello, señaletica, etc.) mostrando "si"/"no"/"n/a" según estado (matchea formato Excel).
- Sección de observaciones.
- Footer: fecha, realizado por.

### 5.2 PDF Certificado de Servicio
- Encabezado: logo PROSESSO + "Certificado de Servicio de Mantenimiento y Recarga de Extintores" + Nº.
- "PROSESSO SpA" + "D.S Y O.M. ORDINARIO N.º 12600/06/208/Vrs" centrados.
- Fecha de Servicio.
- Información del Cliente (Nombre, Dirección).
- Información del Servicio: Tipo de Servicio + tabla de extintores (UNIDAD/CENTRO | AGENTE | PESO KG/LITROS | CERTIFICADO).
- Normas Cumplidas + Normas Marítimas.
- Certificación + firma José Miguel Muñoz - Gerente técnico (asset existente).
- Nota de validez 1 año.

### 5.3 Eficiencia
- Carga única de fuentes Roboto / logo PROSESSO / firma → reutilizadas en ambos PDFs.
- Usar `pw.MultiPage` con `header`/`footer` reutilizables.
- Generar ambos PDFs en paralelo (`Future.wait`) cuando finaliza.

---

## 6. Assets necesarios

- `assets/images/prosesso_logo.png` (logo cuadrado rojo del header) — **PENDIENTE de proporcionar por el usuario**.
- `assets/images/firma_jose_miguel.png` (firma escaneada) — **PENDIENTE de proporcionar por el usuario**.
- Declarar en `pubspec.yaml`.

---

## 7. Archivos esperados (nuevos)

```
lib/features/prosesso/
├── data/repositories/local_prosesso_repository.dart
├── domain/models/
│   ├── prosesso_extintor_state.dart
│   └── prosesso_report_data.dart
├── presentation/
│   ├── controllers/prosesso_form_controller.dart
│   ├── screens/
│   │   ├── prosesso_setup_screen.dart
│   │   └── prosesso_form_screen.dart
│   └── widgets/
│       ├── prosesso_extintor_card.dart
│       └── prosesso_punto_row.dart
└── services/prosesso_pdf_service.dart

supabase_migration_prosesso.sql
docs/PROSESSO_MODULE.md       (este archivo)
docs/PROSESSO_TASKS.md        (checklist)
```
