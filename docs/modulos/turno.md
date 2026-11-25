# Turno

> Clave: `TURNO` · Estado: en desarrollo (migración ejecutada 2026-11-24; falta probar en dispositivo y publicar) · Última revisión: 2026-11-25
> Empresas con el módulo (2026-11-24): AquaChile y Servimaf.

## Qué hace
El auditor registra desde su celular el ingreso a su turno (área y, si quiere, centro) y después confirma la salida.
Mientras el turno está activo ve qué día del turno va y cuándo termina. Abajo ve sus turnos anteriores.
Sirve para que el dashboard sepa quién está en turno y para la tabla "Turnos" de los informes. Plan y diseño:
[PLAN_TURNO](../planificacion/02_en_progreso/PLAN_TURNO.md).

## Reglas de negocio
- Turno estándar de 14 días: la salida estimada se llena sola con fecha de ingreso + 13, pero se puede acortar
  (ej. un turno extra más corto). Va entre el día de ingreso y ingreso + 13; nunca más de 14 días. Si se cambia
  el ingreso, la salida se mueve conservando el largo elegido. "Día X de N" usa el largo de ese turno.
- Fecha de ingreso: hoy por defecto, editable. No puede ser futura, ni de hace más de 13 días, ni del mismo día o
  antes de la salida del turno anterior.
- Área obligatoria; centro opcional ("Sin centro"). Se preseleccionan los del último turno.
- Sin "ingreso extraordinario" ni observación al ingresar (quitados 2026-11-25): un turno extra es simplemente
  un turno más corto. La columna `extraordinario` queda en la base, siempre en false.
- Un solo turno activo por usuario (también lo exige un índice único en Supabase).
- Activo: se puede editar (ingreso, salida estimada, área y centro) o eliminar si se registró por error. Un turno
  vencido se puede editar dejando la misma fecha de ingreso, aunque tenga más de 13 días.
- Confirmar salida: se elige la fecha real, entre el ingreso y hoy (puede ser días atrás si lo olvidó). Se propone
  hoy, o la salida estimada si hoy ya la pasó. Después el turno queda **solo lectura** (también en Supabase: el
  trigger ignora todo cambio a un turno `CERRADO`).
- "Vencido" (activo y hoy pasado la salida estimada) no es un estado guardado: se calcula y se muestra en ámbar.
- Offline: todo se guarda en el teléfono (`subido = 0`) y se sube al sincronizar. El sync también baja los turnos
  propios de los últimos 12 meses, sin pisar cambios locales sin subir. Los cierres suben antes que los ingresos.
  Si otro celular del mismo usuario ya subió un turno activo, el ingreso duplicado de este teléfono se descarta y
  queda el que está en Supabase. Los turnos sin subir cuentan en "pendientes de sincronizar" de Inicio.
- Sin número, firma, correo ni tickets propios. El único PDF es el del **cierre de turno** (abajo).
- Área preseleccionada: la del último turno; si no tiene turnos, la de su última inspección o AST guardada en el
  teléfono (2026-11-25). Siempre modificable.

## Cierre de turno (en pruebas, 2026-11-25)
Reemplaza el PDF "Cierre de turnos" que se mandaba por correo. Detalle y decisiones en
[PLAN_TURNO §11](../planificacion/02_en_progreso/PLAN_TURNO.md#11-cierre-de-turno-parte-3-2026-11-25-en-pruebas).
- Se calcula con internet desde las inspecciones, AST y tickets del período del turno (ingreso → salida, o hoy si
  sigue activo). Todo se puede corregir; puertos cerrados, bitácora, notas de folios y EPP/Cil. son a mano.
- Observación = ítem de ticket (cerrada si está subsanada o el ticket cerrado). Hallazgo crítico = `Intolerable`.
- Tickets del turno: creados y cerrados por el profesional en el período y su estado actual (como "Tickets
  históricos por profesional" del dashboard).
- El directorio de servicios corregido se guarda en `contratista_contactos` y se le propone a cualquier usuario de
  la misma empresa.
- Estados: `BORRADOR` (guardado, offline también) y `GENERADO` (con PDF subido a `pdfs_visitas/turnos/...`).
  Se puede volver a generar. Sin número de informe. No sale en Historial (por ahora).
- PDF `turno_cierre_pdf_service.dart` v0.1.0: sin logo, pie "Generado por Servimaf".
- Sync: el borrador sube con el turno ya subido (FK). Si otro celular ya subió un cierre del mismo turno, el de este
  teléfono toma ese id y lo reemplaza (manda lo editado aquí); la descarga nunca pisa un borrador sin subir. Al abrir
  un turno sin cierre en el teléfono, primero se busca el de Supabase.

## Datos
Tabla `turnos` en Supabase y en SQLite (v67). Cierre: `turno_cierres` (SQLite v68) y, en Supabase,
`turno_cierres` + `contratista_contactos` (`supabase_migration_turno_v3.sql`, ejecutado 2026-11-25). Detalle en
[esquema por módulo](../base-de-datos/esquema-por-modulo.md#turno). RLS: el auditor lee y escribe los suyos; el
administrador lee los de sus empresas.

## Pantallas
- **Turno** (tarjeta en Inicio): sin turno → botón "Registrar ingreso". Con turno → tarjeta con cabecera de color
  (verde; ámbar si está vencido): "En turno"/"Sin cerrar", "Subido"/"Sin subir", "Día X de N", cuánto falta
  ("Faltan 9 días", "Hoy es tu último día") y una regla con un tramo por día. Abajo: área y centro, tarjetitas de
  Ingreso y Salida estimada, "Confirmar salida" y "Editar". El botón "⋯" abre "Opciones del turno" (Editar /
  Eliminar); eliminar pide confirmar mostrando área y fechas del turno. Debajo, "Mis turnos".
- **Registrar ingreso / Editar turno** (hoja inferior): dos tarjetas de fecha, Ingreso → Salida ("25 nov ·
  miércoles", con "Hoy"/"Automática"/"Ajustada"), el largo del turno ("Turno de 14 días" o "Turno corto de 5
  días" con "Volver a 14") y las listas de área y centro. Usa el selector nuevo `CampoSeleccion`
  (`lib/shared/widgets/campo_seleccion.dart`), pensado para reemplazar a `CustomDropdown` en los próximos módulos.
- **Confirmar salida** (diálogo): fecha de salida, días y diferencia con la estimada ("2 días antes"), observación.
- **Mis turnos**: cada turno tiene abajo el estado del cierre ("Sin cierre de turno" / "Cierre en borrador" /
  "Cierre con PDF") con "Hacer cierre", "Continuar" o "Ver PDF". En el activo, "⋯ → Cierre de turno".
- **Cierre de turno**: cabecera con el período y "Volver a calcular", tarjetas de resumen y tickets (números
  editables), una tarjeta por sección con sus filas editables ("Agregar fila", quitar), bitácora, y abajo
  "Guardar" y "Generar PDF". Al salir guarda el borrador solo.
- **Aviso en Inicio**: con turno activo, "En turno · día X de 14 · ÁREA"; vencido, "Confirma tu salida". Abre el módulo.

## Archivos principales
- `lib/features/turno/domain/turno.dart` (modelo y reglas de fechas)
- `lib/features/turno/presentation/controllers/turno_controller.dart`
- `lib/features/turno/presentation/screens/turno_module_screen.dart`
- `lib/features/turno/services/turno_sync.dart`
- `lib/features/turno/domain/turno_cierre_calculo.dart` (qué sale automático del cierre)
- `lib/features/turno/services/turno_cierre_pdf_service.dart` (PDF v0.1.0)
- `supabase_migration_turno_v1.sql`, `_v2`, `_v3`

## Pendientes
- Probar en dispositivo y publicar la versión (la migración v1 se ejecutó el 2026-11-24).
- Dashboard: tarjeta "En turno ahora" y tabla "Turnos" del informe leída desde `turnos` (PLAN_TURNO §6).
- Módulo siguiente: Jornada diaria (sin actividad, puerto cerrado, novedades). PLAN_TURNO §9.
