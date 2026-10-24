# Inspección de Extintores (R-004)

> Clave: `VISITA_R004` · Estado: en producción · Última revisión: 2026-10-22
> Empresas con el módulo (2026-10-22): GNS, JF Innova, Servimaf.

## Qué hace

Inspección de los extintores de un lugar. Por cada extintor se registra número,
matrícula, tipo, peso, fecha de última y próxima mantención, fotos y un
checklist de **17 puntos** ("Condiciones del Extintor"). Genera un PDF.

## Reglas de negocio

- Obligatorio ingresar el **lugar de inspección** (registros antiguos usaban
  `lugar_visita`; se mantiene compatibilidad).
- Se pueden agregar varios extintores; al copiar un extintor se copian los
  estados de los puntos, **no** matrícula, fotos ni observaciones.
- Autoguardado del borrador.

## Datos

Cabecera en `visitas_tecnicas` (`tipo_actividad = VISITA_R004`), extintores en
`extintores`, preguntas en `formulario_items` (`VISITA_R004`).

## Pantallas

`ExtintorFormScreen` con tarjetas por extintor (`ExtintorCard`, `PuntoExtintorRow`).

## Archivos principales

- `lib/features/extintores/presentation/controllers/extintor_form_controller.dart`
- `lib/features/extintores/services/extintor_pdf_generator_service.dart` (PDF v0.4.0)

## Pendientes

- Ninguno conocido.
