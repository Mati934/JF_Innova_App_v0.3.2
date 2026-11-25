# Plan: Turno (ingreso y egreso del auditor)

> **Para qué es:** Definición del módulo Turno: el auditor registra desde su celular cuándo entra y sale de su turno
> (área y centro), ve su turno activo y sus turnos anteriores, y el dashboard sabe quién está en turno ahora.

> Estado: **app implementada (2026-11-24), migración Supabase ejecutada 2026-11-24** (`supabase_migration_turno_v1.sql`) ·
> Ficha: [turno](../../modulos/turno.md) · Creado: 2026-11-24 ·
> Origen: pedido de la tía ("Reporte JF", [Por Hacer](../../1.%20Cosas/Por%20Hacer)) + definición de Mati (2026-11-24) ·
> Alcance: AquaChile y Servimaf · Relacionado: módulo **Jornada diaria** (siguiente, ver §9) ·
> pendiente n°1 de `jf_innova_web/PENDIENTES_FLUTTER.md` · tabla "Turnos" del informe semanal del dashboard
> (`dashboard-jfinnova/src/modules/informes/semanal/semanal.model.ts`, `TurnoAuditor` / `armarTurnos`)

## Resumen

| | |
|---|---|
| **Qué es** | Un registro por turno: área, centro (opcional), fecha de ingreso, salida estimada (ingreso + 13 días) y fecha de salida confirmada por el auditor. |
| **Quién** | El propio auditor, en su celular. Cada uno ve solo sus turnos. |
| **Flujo** | Registrar ingreso → aparece como **turno activo** con su información → al terminar, **confirmar salida** eligiendo la fecha real (puede ser anterior a hoy, si se le olvidó). |
| **Qué reemplaza** | Los turnos que hoy se anotan a mano en el editor del informe semanal del dashboard (`localStorage` del navegador, se pierden al cambiar de PC). |
| **Para el dashboard** | Tarjeta "En turno ahora" (quién está, en qué área y centro, qué día del turno) y tabla "Turnos" del informe semanal/mensual, leídas de la base. |
| **Sin** | PDF, número de informe, firma, correo, tickets ni checklist. |
| **Por qué no es un checklist del motor** | No son preguntas: es un registro con estado (activo → cerrado), fechas calculadas y una vista propia de turnos. El motor no alcanza. |

El registro de los días sin actividad, puerto cerrado, novedades y observaciones **no va acá**: va en el módulo
Jornada diaria (§9).

---

## 1. Definición (plantilla §1)

| Campo | Valor |
|---|---|
| Nombre visible | **Turno** (tarjeta en Inicio) |
| `moduleKey` | `TURNO` |
| Tabla | `turnos` (Supabase y SQLite, mismas columnas) |
| Feature en código | `lib/features/turno/` |
| Empresas | AquaChile (`88f539a7-…`) y Servimaf (`5535b965-…`, para revisar desde la cuenta de Mati), vía `empresa_modulos` |
| Variantes | No |
| Entregables | Ninguno: no hay PDF, firma ni correlativo |
| Tickets | No |

---

## 2. Reglas del turno

| Regla | Detalle |
|---|---|
| Largo estándar | **14 días**: salida estimada = fecha de ingreso **+ 13** (ej. ingreso 24/11 → salida estimada 07/12). Es el mismo largo que ya usa el dashboard (`DIAS_TURNO_ESTANDAR = 14`). |
| Fecha de ingreso | Se llena sola con **hoy**, y se puede cambiar. No puede ser futura. Hacia atrás, máximo 13 días (si no, ya habría terminado el turno). |
| Un turno activo a la vez | Mientras haya uno activo no se puede registrar otro ingreso: primero se confirma la salida. |
| Sin superponer | La fecha de ingreso de un turno nuevo debe ser **posterior** a la salida del turno anterior. |
| Fecha de salida | Al confirmar salida se elige la fecha. Por defecto es **hoy**, o la salida estimada si hoy ya la pasó. Puede ser anterior a hoy (se olvidó de marcar) y debe ser ≥ ingreso y ≤ hoy. No hace falta que coincida con la estimada: sale antes o después, y eso queda registrado. |
| Ingreso extraordinario | **Quitado 2026-11-25** (decisión del usuario): un turno extra es un turno con la salida estimada acortada. Antes: interruptor opcional "Ingreso extraordinario" (fuera de su turno normal). El dashboard ya lo marca en el informe (`extra`, pedido de la tía 2026-11-20). La salida estimada se calcula igual. |
| Corregir | Mientras está activo, el auditor puede editar fecha de ingreso, área, centro, extraordinario y observación. Cuando lo cierra queda en **solo lectura**. Si hay que corregir un turno cerrado, lo hace un administrador (ver §8, decisión 1). |
| Borrar | Solo un turno activo y aún no subido (registrado por error). Usa soft delete (`eliminado = 1, subido = 0`), como el resto de la app. |
| Fechas | `date` en hora de Chile (la del celular). El turno se cuenta por días, no por horas. Además se guarda **cuándo** se marcó cada cosa (`timestamptz`) para auditoría y para saber si la fecha se corrigió. |

### Estados

| Estado | Cuándo | Se ve como |
|---|---|---|
| `ACTIVO` | Registró ingreso y no ha confirmado salida | Tarjeta "Turno activo" |
| `ACTIVO` + hoy > salida estimada | Pasó el día 14 y no confirmó salida | Tarjeta en **ámbar**: "Tu turno terminaba el 07/12. Confirma tu salida." |
| `CERRADO` | Confirmó salida | Fila en "Mis turnos" |

"Vencido" **no es un estado guardado**: se calcula (hoy > `egreso_estimado` y estado `ACTIVO`). Así no hay que tener un
proceso que lo cambie y se ve igual en la app y en el dashboard.

`ACTIVO` y `CERRADO` van al glosario y al check de Supabase con el mismo valor.

---

## 3. Pantallas

Todo en una sola pantalla del módulo (`turno_module_screen.dart`), con tres estados. Es la parte que tiene que quedar
"bacán": registrar debe tomar 2 toques, y el turno activo tiene que mostrar de una lo importante.

### 3.1 Sin turno activo

```
┌──────────────────────────────────────┐
│  Turno                               │
├──────────────────────────────────────┤
│   No tienes un turno activo          │
│   [  Registrar ingreso  ]            │
├──────────────────────────────────────┤
│  Mis turnos                          │
│  10/11 → 23/11 · CISNES · Puerto…    │
│  14 días · salida a tiempo       ✓   │
│  ...                                 │
└──────────────────────────────────────┘
```

### 3.2 Registrar ingreso (hoja inferior o pantalla corta)

| Campo | Obligatorio | Detalle |
|---|---|---|
| Fecha de ingreso | Sí | Hoy por defecto; selector de fecha (máximo 13 días atrás, no futura) |
| Área | Sí | Áreas de la empresa activa (`getAreasByEmpresa`, respaldo `getAreas()`). Se preselecciona el área del **último turno**. |
| Centro | No | Centros del área elegida, o "Sin centro". Se preselecciona el del último turno si es de la misma área. |
| Ingreso extraordinario | No | Interruptor, apagado por defecto |
| Observación | No | Texto libre corto |

Debajo de los campos, en vivo: **"Tu turno: lun 24/11 → dom 07/12 (14 días)"**. Botón "Registrar ingreso".

Si el auditor ya tiene la fecha de hoy y su área de siempre, son 2 toques: abrir y registrar.

### 3.3 Turno activo

```
┌──────────────────────────────────────┐
│  TURNO ACTIVO            Día 5 de 14 │
│  ████████░░░░░░░░░░░░░░              │
│  CISNES · Centro Puerto Cisnes       │
│  Ingreso     lun 24/11               │
│  Salida est. dom 07/12 (faltan 9 d)  │
│  ⟳ Pendiente de subir  /  ✓ Subido   │
│                                      │
│  [ Confirmar salida ]   [ Editar ]   │
└──────────────────────────────────────┘
```

- Barra de avance por días. Pasado el día 14 se pone en ámbar y dice "Día 16 · terminaba el 07/12".
- Se muestra el estado de sync para que el auditor sepa si la oficina ya lo ve.
- Debajo, "Mis turnos" igual que en 3.1.

### 3.4 Confirmar salida (diálogo)

- "¿Qué día terminaste tu turno?" con la fecha propuesta (hoy, o la salida estimada si hoy ya la pasó) y un selector
  (rango: ingreso … hoy).
- En vivo: "14 días · a tiempo", "12 días · 2 días antes" o "16 días · 2 días después".
- Observación de salida opcional (ej. motivo de salida anticipada).
- Botón "Confirmar salida". Después el turno pasa a "Mis turnos" y la pantalla vuelve a 3.1.

### 3.5 Mis turnos

- Lista de los turnos cerrados, del más reciente al más antiguo: fechas, área · centro, días reales, diferencia con
  la estimada (a tiempo / N días antes / N días después) y la marca "Extraordinario".
- Sale de SQLite. Para que el historial no se pierda al cambiar de celular, el sync **descarga los turnos propios**
  (§5).
- Sin filtros en v1, porque son pocos (unos 2 al mes).

### 3.6 Inicio (opcional v1, recomendado)

En la tarjeta del módulo o arriba de los módulos: "En turno · día 5 de 14 · CISNES". Si está vencido: "Confirma tu
salida". Es lo que más ayuda a que no se olviden de cerrar.

---

## 4. Base de datos

Una sola tabla. Las mismas columnas en SQLite y Supabase (upsert directo). Solo locales: `subido`, `eliminado`.

| Columna | Tipo (Supabase) | Notas |
|---|---|---|
| `id` | `uuid` PK | Se genera en el celular (offline) |
| `usuario_id` | `uuid` → `usuarios` | El auditor (= `auth.uid()`) |
| `empresa_id` | `uuid` → `empresas` | Empresa activa al registrar (multiempresa) |
| `area_id` | `uuid` → `areas` | Obligatorio |
| `centro_id` | `uuid` → `centros` null | Opcional (decisión 2026-11-24). `ON DELETE SET NULL`. |
| `estado` | `text` check `('ACTIVO','CERRADO')` | |
| `ingreso_fecha` | `date` | Fecha del turno (editable) |
| `egreso_estimado` | `date` | `ingreso_fecha + 13`. Se guarda (no se calcula al leer) para que el dashboard no repita la regla. Se recalcula si se edita el ingreso. |
| `egreso_fecha` | `date` null | Salida confirmada. Null mientras está activo. |
| `extraordinario` | `boolean` default false | |
| `observacion_ingreso` | `text` null | |
| `observacion_egreso` | `text` null | |
| `ingreso_registrado_at` | `timestamptz` | Cuándo tocó "Registrar ingreso" |
| `egreso_registrado_at` | `timestamptz` null | Cuándo tocó "Confirmar salida". Junto con `egreso_fecha` muestra si cerró tarde (ej. salida 07/12 confirmada el 09/12). |
| `app_version` | `text` | Como el resto de los módulos |
| `created_at` / `updated_at` | `timestamptz` | |

Supabase:

- **Índice único parcial** `(usuario_id) where estado = 'ACTIVO'`: un solo turno activo por usuario, aunque use dos
  celulares. Si el sync choca con él, se muestra un error claro ("ya tienes un turno activo en otro equipo") y no se
  pierde el local.
- Check `egreso_fecha >= ingreso_fecha` y `egreso_estimado = ingreso_fecha + 13`.
- Índices: `(empresa_id, estado)` para la tarjeta del dashboard y `(empresa_id, ingreso_fecha)` para informes.
- **RLS**, igual que `registros_inmersion`: `turnos_owner_all` (`usuario_id = auth.uid()`) y `turnos_admin_select`
  (`is_superadmin_user() OR (is_admin_user() AND user_has_empresa(empresa_id))`). El dashboard lee con la sesión del
  administrador.

SQLite: tabla `turnos` en `_createDB`, en un bloque `if (oldVersion < N)` de `onUpgrade` y en `_repairCriticalSchema`.
Se sube `_dbVersion`.

---

## 5. Sync

- **Subida:** `SyncService` sube las filas con `subido = 0` (upsert por `id`) y hace delete real si `eliminado = 1`.
  Se quitan `subido` y `eliminado` antes del upsert.
- **Descarga:** al sincronizar se bajan **los turnos del usuario** (`usuario_id = auth.uid()`, últimos 12 meses), sin
  pisar filas locales con `subido = 0`. Así "Mis turnos" y el turno activo aparecen en un celular nuevo.
- Offline: todo funciona sin señal. El dashboard lo ve recién cuando el celular sincroniza (se dice en §6).

---

## 6. Dashboard (pensado desde ahora)

### Tarjeta "En turno ahora"

`turnos` con `estado = 'ACTIVO'` de la empresa, agrupados por área:

| Auditor | Área | Centro | Ingreso | Día | Salida est. |
|---|---|---|---|---|---|
| Juan Pérez | CISNES | Puerto Cisnes | 24/11 | 5/14 | 07/12 |
| Ana Soto | AYSEN | … | 10/11 | **16/14 · vencido** | 23/11 |

- Conteo por área arriba ("CISNES 2 · AYSEN 1 · …") y áreas sin nadie en turno.
- Vencidos (hoy > `egreso_estimado`) resaltados: es casi siempre un auditor que olvidó confirmar la salida.
- Aviso: un ingreso hecho sin señal aparece cuando el celular sincroniza.

### Informe semanal/mensual (tabla "Turnos")

Reemplaza la carga a mano del editor. Se mapea a lo que `armarTurnos` ya recibe:

| `TurnoAuditor` (dashboard) | Columna |
|---|---|
| `auditor` | `usuarios.nombre_completo` |
| `zona` | nombre del área (mismo mapeo que hoy: `AYSEN` → "Puerto Aysén", etc.) |
| `ingreso` | `ingreso_fecha` |
| `egreso` | `egreso_fecha` (activo → vacío; el dashboard ya estima + 13) |
| `extra` | `extraordinario` |

Con eso las jornadas sin actividad se siguen calculando igual (días del turno sin inspecciones, AST ni registro de
actividad), hasta que llegue Jornada diaria. Estos cambios van en el repo del dashboard: se anotan en
`PENDIENTES_FLUTTER.md` / `PENDIENTES_DASHBOARD.md` cuando la tabla exista.

**Otras métricas posibles con estos datos:** salidas anticipadas o extendidas por auditor, cobertura por área por día
(cuántos auditores había en cada área cada día), turnos extraordinarios del mes, novedades automáticas ("entra X a
CISNES", "sale Y").

---

## 7. Alcance

**Incluye (v1):** tabla, sync de subida y descarga, pantalla con los tres estados (sin turno, activo, vencido),
registrar ingreso, editar mientras está activo, confirmar salida con fecha, Mis turnos, aviso en Inicio, módulo
habilitado para AquaChile y Servimaf, tests de reglas de fechas.

**No incluye (v1):**
- Días sin actividad, puerto cerrado, novedades y observaciones de la jornada: módulo Jornada diaria.
- Cambio de centro dentro del turno: se registra el centro de ingreso. El centro de cada día lo pondrá Jornada diaria.
- Notificaciones push ("tu turno termina mañana"). El aviso va dentro de la app.
- Edición de turnos cerrados por un administrador desde la app o el dashboard.
- Historial unificado (`historial_unificado`): el módulo tiene su propia lista.
- PDF, firma, correo, tickets.

**Riesgos:**
- **Que no cierren el turno.** Se mitiga con el aviso ámbar en la app, en Inicio y en el dashboard (vencido) y con que
  no se pueda abrir otro sin cerrarlo.
- **Celular con la fecha mal puesta:** `ingreso_registrado_at` se guarda; se puede comparar con `created_at` de
  Supabase.
- **Auditor con dos empresas:** el turno queda en la empresa activa al registrar. Para AquaChile y Servimaf en la cuenta
  de Mati no es problema (solo es para revisar).

---

## 8. Decisiones (confirmadas por Mati, 2026-11-24)

1. **Turno cerrado:** solo lectura para el auditor después de confirmar la salida. Mientras está activo se puede
   editar o eliminar.
2. **Área obligatoria, centro opcional.** El módulo se usa al ingresar al turno. El centro de cada día irá en
   Jornada diaria.
3. **Ingreso con más de 13 días de atraso:** no se permite en la app. Carga por administrador: no se hará por ahora.

---

## 9. Siguiente: módulo Jornada diaria (otro plan)

Este plan lo deja preparado, pero no lo incluye. Idea: cada día **dentro de un turno activo**, el auditor registra cómo
fue su jornada (con actividad / puerto cerrado / sin actividades), sus novedades y sus observaciones y
recomendaciones, más el centro del día. Depende de `turnos`: sabe qué días tienen que tener jornada (días entre
`ingreso_fecha` y `egreso_fecha`, o hoy). Pendiente de definir en ese plan: la relación con la `BITACORA` actual
(puerto cerrado con otra actividad) y el pedido "Puerto Cerrado en vez de habilitada/suspendida".

---

## 10. Implementación (cuando se apruebe)

Skill `nuevo-modulo`, pasos 3–5, copiando el patrón de **Registro de inmersiones** (el módulo más reciente, con RLS
dueño + admin):

1. SQL `supabase_migration_turno_v1.sql` (skill `migracion-supabase`, ejecutado 2026-11-24): tabla, checks, índice
   único parcial, RLS, `empresa_modulos` para AquaChile y Servimaf.
2. SQLite: `_dbVersion`, `_createDB`, `onUpgrade`, `_repairCriticalSchema`.
3. `ModuleRegistry`: `TURNO`.
4. `lib/features/turno/`: modelo, repositorio local, controlador (`_disposed` + `_safeNotify`), pantalla.
5. `SyncService`: subida y descarga de los turnos propios.
6. Tests: `test/turno_test.dart` (fechas: + 13, límites de ingreso y salida, un activo, superposición, vencido).
7. `revisor-cambios`, `documentar-app` (ficha `docs/modulos/turno.md`, glosario `TURNO`/`ACTIVO`/`CERRADO`, esquema,
   CHANGELOG) y aviso al dashboard.

---

## 11. Cierre de turno (parte 3, 2026-11-25, en pruebas)

**Qué reemplaza:** el formulario PDF "Cierre de turnos" que cada auditor llenaba a mano y mandaba por correo (muestra
analizada: 3 páginas, 10 secciones). Cruzado con los datos reales del mismo auditor y período, la app ya tiene ~60 %:
indicadores y desglose por centro calzan exacto; folios y observaciones salían mal a mano (faltaba el informe 745 y
el AST 664; las observaciones no calzaban con nada).

**Decisiones del usuario (2026-11-25):** todo automático pero modificable; observación = ítem de ticket (cerrada si
está subsanada o el ticket está cerrado); hallazgo crítico = `Intolerable`; EPP y Cil. manuales pero guardados;
puertos cerrados manuales (hasta que exista Jornada diaria); el directorio se guarda por empresa y lo reutilizan los
colegas; generar el PDF requiere internet, el borrador no; PDF propio con versión, sin logo, pie "Generado por
Servimaf"; sin número de informe; solo desde el turno (no en Historial por ahora). Datos: **híbrido** (indicadores y
tickets en columnas; secciones con filas en JSONB) mientras se pule el PDF; pasar a tablas hijas cuando quede fijo.

| Sección del PDF | Fuente | Cómo |
|---|---|---|
| Profesional, área, desde/hasta | Turno | Automático |
| Control de folios (inicial, final, cantidad) | `actividades.numero_informe`, `ast_informes.correlativo` | Automático; notas a mano |
| Resumen (centros, insp. buceo/emb, AST, reg. actividad, obs., faenas suspendidas) | `actividades`, `ast_informes`, ítems de `tickets` | Automático |
| Tickets del turno | `tickets` (creados) + `ticket_historial_tomas` FINALIZADO (cerrados) | Automático, como "Tickets históricos por profesional" del dashboard acotado al período |
| Faenas suspendidas | `actividades.estado_faena = 'SUSPENDIDA'` | Automático; motivo a mano; se agregan las que se habilitaron el mismo día |
| Actividades por centro (+ obs. tot/cerr/pend) | `actividades`, `ast_informes`, tickets | Automático; EPP y Cil. a mano |
| Informes con observaciones | Tickets por inspección | Automático |
| Hallazgos críticos | `nc_hallazgo_ocurrencias` del turno con `nc_hallazgos.criticidad_actual = 'Intolerable'` | Automático |
| Directorio de servicios | Contratistas del turno + `contratista_contactos` (o supervisor de buceo / correo de embarcación) | Semi; lo corregido se guarda para la empresa |
| Puertos cerrados | — | Manual |
| Bitácora | — | Manual |

**Pantalla:** "Cierre de turno" se abre desde cada turno de "Mis turnos" ("Hacer cierre" / "Continuar" / "Ver PDF")
y desde "⋯ → Opciones del turno" en el turno activo. "Volver a calcular" relee todo y conserva puertos, bitácora,
notas de folios y EPP/Cil.

**Pendiente de confirmar:** si los hallazgos de AST deben contar como observaciones (hoy no: no generan tickets);
cuándo pasar el PDF al Historial; tablas hijas para el dashboard.
