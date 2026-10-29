# Registro de Actividades – Vehículos Livianos

> Clave: `VISITA_ACTIVIDADES_VEHICULOS` · Estado: en producción · Última revisión: 2026-10-22
> Empresas con el módulo (2026-10-22): Laboratorio CIBA, Servimaf, Vaxxinnova.

## Qué hace

Chequeo de **vehículos livianos** (checklist `VISITA_R008`, 20 preguntas) con
patente, kilometraje y conductor. Genera un "INFORME DE ACTIVIDAD".

## Reglas de negocio

- No es un módulo propio: abre el [Registro de Visita](registro-visita.md)
  restringido al checklist `VISITA_R008`, con título "Registro de Actividades",
  campo "Origen de la actividad" y colores índigo.
- Campos extra (de `formulario_campos_extra`): Patente del vehículo, Kilometraje, Conductor.
- No confundir con [Actividades Formativas](actividades-formativas.md), que
  también se llama "Registro de Actividad" en Home.

## Datos

Los mismos del Registro de Visita: `visitas_tecnicas`, `visitas_checklists`.

## Archivos principales

- `lib/core/modules/module_registry.dart` (configuración de la tarjeta)
- `lib/features/visits/` (toda la lógica)

## Pendientes

- Ninguno conocido.
