# Merieux (Visitas y Extintores)

> Claves: `MERIEUX_VISITAS`, `MERIEUX_EXTINTORES` · Estado: demo / bajo uso (2 visitas, 1 mantención) · Última revisión: 2026-10-29
> Empresas con el módulo (2026-10-22): Merieux NutriSciences, Servimaf.

## Qué hace

Dos submódulos para el cliente **Merieux NutriSciences**, con el mismo encabezado:

- **Registro de Visita**: visita con checklist opcional (sin checklist o con
  Vehículos Livianos, mismo banco que `VISITA_R008`).
- **Mantención de Extintores**: grilla de N extintores con el checklist de 9
  puntos de PROSESSO.

## Reglas de negocio

- Profesional, fono y correo se autocompletan desde la sesión pero son
  editables (una misma cuenta la usan varias personas).
- El nombre de quien firma se autocompleta pero puede ser otra persona.
- Al guardar definitivo se asigna correlativo (trigger) y se sincroniza.
  Desde 2026-10-29 visitas y extintores tienen numeración propia por empresa
  (antes compartían la secuencia).
- El PDF reutiliza el generador de Hidroser; cada extintor se muestra como una
  categoría del checklist.

## Datos

`merieux_visitas`, `merieux_visita_respuestas`, `merieux_extintores`.

## Pantallas

`MerieuxVisitaModuleScreen` / `MerieuxVisitaFormScreen`,
`MerieuxExtintoresModuleScreen` / `MerieuxExtintoresFormScreen`.

## Archivos principales

- `lib/features/merieux/presentation/controllers/merieux_visita_form_controller.dart`
- `lib/features/merieux/presentation/controllers/merieux_extintores_form_controller.dart`

## Pendientes

- Pendiente de confirmar: si el módulo está en uso real o quedó como demo (commit "demo merieux", 2026-07-08).
