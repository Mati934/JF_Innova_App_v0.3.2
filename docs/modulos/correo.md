# Correo

> Claves: `EMAIL_OUTBOX` (Bandeja), `EMAIL_ADMIN` (admin), `EMAIL_TEST` (solo en modo debug)
> Estado: etapa inicial · Última revisión: 2026-10-22
> Empresas con el módulo (2026-10-22): Servimaf.
> Plan: [PLAN_CORREO_OUTLOOK_MVP.md](../planificacion/02_en_progreso/PLAN_CORREO_OUTLOOK_MVP.md).

## Qué hace

Al finalizar una inspección, prepara un **correo sugerido** (destinatarios,
asunto y cuerpo con variables, PDF adjunto) que el usuario revisa y envía él
mismo. Los correos que no se pudieron enviar quedan en la **Bandeja de correos**.

## Reglas de negocio

- **Nunca se envía automáticamente**: el usuario revisa y envía (decisión del MVP).
- Prioridad de configuración: asignada al usuario → empresa → global.
- Plantillas con variables, listas de destinatarios por área, asignaciones por usuario.
- Cada paso queda registrado como evento (`correo_eventos`) para trazabilidad.
- Hoy está integrado en el flujo de [Hidroser](hidroser.md).
- Administración (plantillas, listas, destinatarios, configuraciones,
  asignaciones) solo para admin.

## Datos

`correo_plantillas`, `correo_listas`, `correo_lista_destinatarios`,
`correo_configuracion`, `correo_usuario_asignacion`, `correo_pendientes`, `correo_eventos`.

## Pantallas

`EmailOutboxScreen`, `EmailAdminScreen`, `EmailPreviewScreen`, `EmailSetupScreen` (prueba).

## Archivos principales

- `lib/features/email/services/email_dispatch_service.dart` (resolver configuración)
- `lib/features/email/services/email_flow_service.dart` (abrir vista previa)
- `lib/features/email/services/email_pending_service.dart` (bandeja y eventos)

## Pendientes

- Pendiente de confirmar: si el envío final usa Outlook (según el plan) o el
  selector de correo del sistema; no se encontró referencia explícita a Outlook en el código.
- Extender a otros módulos además de Hidroser.
