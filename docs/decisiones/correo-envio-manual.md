# Correo preparado, envío manual por el usuario

- **Fecha:** 2026-06-22
- **Estado:** vigente
- **Fuente:** [PLAN_CORREO_OUTLOOK_MVP.md](../planificacion/02_en_progreso/PLAN_CORREO_OUTLOOK_MVP.md)

## Qué se decidió

Al finalizar, la app prepara el correo (destinatarios, asunto, cuerpo, PDF) pero
el usuario siempre lo revisa y lo envía. Plantillas y listas se administran
primero desde la base y luego desde la app (Super Admin).

## Por qué

Evitar envíos automáticos erróneos a clientes y no depender de integración con
Microsoft Graph en la primera etapa.

## Alternativas

- Envío automático vía Microsoft Graph: postergado.
- Redirección a Outlook: elegida en el plan; pendiente de confirmar si el código
  usa Outlook o el selector de correo del sistema.
