# Registro de Visita (R-003)

> Clave: `VISITA_R003` · Estado: en producción · Última revisión: 2026-10-22
> Empresas con el módulo (2026-10-22): GNS, JF Innova, Servimaf.

## Qué hace

Registra una **visita técnica** de prevención a un lugar o cliente: datos de la
visita, actividades realizadas (bloque opcional), observaciones, fotos, firma y,
opcionalmente, uno o más **checklists anexos** (eléctrico, pisos, vehículos,
soldadora, grúas, herramientas…). Genera un PDF de visita.

## Reglas de negocio

- El checklist se elige de una lista de tipos disponibles; cada tipo carga sus
  preguntas desde `formulario_items` y sus campos propios desde
  `formulario_campos_extra` (ej. patente y kilometraje en vehículos).
- El bloque "Actividades Realizadas" es opcional; al desactivarlo se limpian sus
  checks para que no aparezcan en el PDF.
- La firma se captura en una pizarra modal (patrón reutilizado por otros módulos).
- Las fotos por pregunta no se mezclan con la galería general.
- Autoguardado del borrador.
- La misma pantalla se reutiliza, con filtros, para
  [Vehículos Livianos](actividades-vehiculos.md).
- Pendiente de confirmar: si el Registro de Visita recibe número de informe por
  trigger como las inspecciones.

## Checklists anexos disponibles

Ver [catálogo](../checklists/README.md): `VISITA_R005` (eléctrico), `VISITA_R006`
(pisos y superficies), `VISITA_R008` (vehículos), `VISITA_R011` (soldadora).

Ocultos en el desplegable (siguen en la base): `VISITA_R004` (módulo propio),
`VISITA_R012` (módulo Hidroser) y los 5 `VISITA_CHEQUEO_*` de herramientas,
reemplazados por los checklists del motor configurable desde 2026-10-22
([decisión](../decisiones/ocultar-checklists-herramientas-viejos.md)). Un
borrador antiguo que ya usaba uno oculto lo sigue mostrando.

## Datos

`visitas_tecnicas`, `visitas_checklists` (respuestas en JSON),
`formulario_items`, `formulario_campos_extra`, fotos en Storage `pdfs_visitas` / `evidencias`.

## Pantallas

`VisitFormScreen` (formulario único con encabezado, checklist, fotos y firma).

## Archivos principales

- `lib/features/visits/presentation/controllers/visit_form_controller.dart`
- `lib/features/visits/services/visit_pdf_generator_service.dart` (PDF v0.1.0)
- `lib/features/visits/domain/visit_checklist_labels.dart` (nombres de cada tipo)

## Pendientes

- Ninguno conocido.
