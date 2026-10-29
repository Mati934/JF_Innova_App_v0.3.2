# Hidroser

> Clave: `HIDROSER` · Estado: **sin cliente activo** (Hidroser es ex-cliente desde 2026) · Última revisión: 2026-10-29
> Empresas con el módulo (2026-10-22): Servimaf (empresa propia).

## Qué hace

Listas de chequeo para el cliente **Hidroser**. Hoy tiene una lista:
**Grúas Horquillas** (`GRUA_HORQUILLA_PFA`, usa las 21 preguntas de
`VISITA_R012`). Es el módulo con más inspecciones registradas (1450).

## Reglas de negocio

- El usuario elige la lista; el formulario carga sus preguntas y sus campos
  extra (N° de grúa, hora inicio/horómetro, hora término/horómetro).
- **Dos firmas**: supervisor y operador.
- Foto por pregunta y galería general.
- Al guardar definitivo pasa a `En Seguimiento` (correlativo por trigger, propio por empresa y lista desde 2026-10-29) y se
  sincroniza **en segundo plano**: desde 2026-08-21 el sync no bloquea el guardado.
- Integrado con [Correo](correo.md): al finalizar puede abrir la vista previa
  del correo con el PDF.
- Desde junio 2026 es un módulo propio (antes era una variante del Registro de Visita).

## Datos

`hidroser_listas`, `hidroser_inspecciones`, `hidroser_respuestas`, `formulario_items`.

## Pantallas

`HidroserModuleScreen` (elegir lista / borradores) → `HidroserFormScreen`.

## Archivos principales

- `lib/features/hidroser/presentation/controllers/hidroser_form_controller.dart`
- `lib/features/hidroser/services/hidroser_pdf_generator_service.dart` (PDF v0.1.0, reutilizado por Merieux)

## Pendientes

- Hidroser dejó de ser cliente. Pendiente de decidir: mantener el módulo como
  está (historial) o retirarlo de Servimaf.
