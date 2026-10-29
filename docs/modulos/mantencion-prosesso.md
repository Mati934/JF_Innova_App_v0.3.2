# Mantención de Extintores (PROSESSO)

> Clave: `MANTENCION_PROSESSO` · Estado: en producción · Última revisión: 2026-10-22
> Empresas con el módulo (2026-10-22): PROSESSO, Servimaf.
> Documento maestro anterior: [PROSESSO_MODULE.md](../PROSESSO_MODULE.md).

## Qué hace

Para la empresa **PROSESSO SpA**, que hace mantención y recarga de extintores a
sus clientes (ej. Mowi Chile). Registra los extintores intervenidos con un
checklist de 9 puntos y genera el **Registro de Mantención** y el **Certificado
de Servicio de Mantenimiento y Recarga de Extintores**.

## Reglas de negocio

- Obligatorio ingresar el **cliente**. El certificado pide cliente, dirección y
  fecha de servicio; el resto del certificado es fijo (normas, firma del gerente técnico).
- N° de certificado autoincremental por año y editable (formato `AAAA/NN`); se
  sugiere si está vacío.
- El número de certificado del extintor es texto (algunos llevan prefijo "CN").
- Preguntas configurables en `formulario_items` (`MANTENCION_PROSESSO`): sello,
  señalética, etiqueta, gabinete, pintura, seguro, manómetro, soporte, manguera.
- Una vez finalizado se bloquea el autoguardado para no revertir el estado ni
  borrar el PDF; si falla, se puede reintentar.
- Decisión: no se creó una tabla por empresa; es un módulo habilitado por
  empresa (ver [decisión](../decisiones/modulo-por-empresa-no-tabla.md)).

## Datos

Cabecera en `visitas_tecnicas` (`tipo_actividad = MANTENCION_PROSESSO`),
extintores en `mantenciones_prosesso`.

## Pantallas

`ProsessoFormScreen` con tarjetas por extintor (`ProsessoExtintorCard`, reutilizada por Merieux).

## Archivos principales

- `lib/features/prosesso/presentation/controllers/prosesso_form_controller.dart`
- `lib/features/prosesso/services/prosesso_pdf_service.dart` (PDF v1.0)

## Pendientes

- Ver [PROSESSO_TASKS.md](../PROSESSO_TASKS.md).
