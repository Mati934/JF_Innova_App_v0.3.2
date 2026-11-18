# Plan: Registro de inmersiones (AquaChile)

> **Para qué es:** Diseño del registro de inmersiones de buceo: qué datos guarda, cómo se vincula a la inspección de buceo, numeración, PDF y métricas para el dashboard.

> Estado: **app implementada (2026-11-18), migración Supabase sin ejecutar** · Creado: 2026-11-08 · Actualizado: 2026-11-18 (aviso de exceso, varias inmersiones, hora "desde") ·
> Origen: reuniones 24-08 y 29-10-2026, explicación de Mati
> Alcance: AquaChile, inspección de buceo (`INSPECCION_BUCEO`) · Relacionado:
> [reunión 29-10](../../1.%20Cosas/REUNIONES/REUNION-29-10-2026.md) ·
> [conversación agosto §4](CONVERSACION_REUNIONES_AGOSTO_2026.md#4-registro-de-inmersiones-de-buceo) ·
> [pendientes del dashboard](../03_por_realizar/PENDIENTES_DASHBOARD.md)

## Resumen

| | |
|---|---|
| **Qué es** | Informe con una fila por buzo de la faena: cargo, si buceó, profundidad máxima, desde–hasta (una inmersión por defecto, se pueden agregar más), nota y fotos (profundímetro, registrador Sensus Ultra, general del buzo y galería general). Es la evidencia de cuánto bajó cada buzo. |
| **Quién y cuándo** | El auditor en terreno, al terminar la inspección de buceo, con los datos de la bitácora. La app se lo ofrece al finalizar la inspección. |
| **Qué reemplaza** | Los datos de inmersión que hoy los auditores escriben en el cuerpo del correo (y el registro que Paola arma aparte). |
| **Reglas** | 1 registro por inspección de buceo · **solo se crea vinculado a una inspección**, y lo hace el auditor que hizo la inspección · se anota la profundidad máxima del día · **ninguna foto obligatoria** · sin firma · sin envío por correo · correlativo propio. |
| **Recomendación** | Módulo propio (tarjeta "Registro de inmersiones"), no checklist del motor: no son preguntas C/NC/N/A sino datos por buzo con fotos. |

El PDF de la inspección de buceo (DPR24) no cambia.

---

## 1. Cómo es hoy

### El papel (ejemplo real, Punta Ganso, 31/07/2026)

| N° | Nombre del buzo | RUT | Profundidad máxima (m) | Foto del profundímetro | Foto del dispositivo |
|---|---|---|---|---|---|
| 1 | Leonidas A. Montecinos V. | 13.167.780-4 | 21 m | Scubapro con lectura | Sensus Ultra `U-18659` |
| 2 | César B. Ayancán R. | 13.739.338-7 | 18,8 m | Scubapro con lectura | Sensus Ultra `U-18496` |
| 3 | Juan C. Barrientos T. | 13.825.639-1 | **Buzo de emergencia** | — | — |

Encabezado: centro y fecha. Pie: "Datos extraídos desde bitácoras".

### Flujo en terreno

1. El auditor hace la **inspección de buceo** en la app (cuadrilla, verificaciones, checklist).
2. Con la bitácora, anota la profundidad máxima de cada buzo y fotografía el profundímetro y el registrador.
3. Hoy esos datos van **escritos en el correo**. Con este registro quedan en la app y en un PDF.

### Lo que la app ya tiene y se reutiliza

| Dato | Dónde está hoy | Uso en el registro |
|---|---|---|
| Buzos de la faena | `actividad_participantes` (rol `Buzo`, `Supervisor`, `Asistente`…) + `personal_externo` (nombre, RUT, matrícula) | Se cargan solos al elegir la inspección, con su cargo. |
| Centro, fecha, contratista | `actividades` | Encabezado del registro. |
| Profundidad máxima **planificada** | **No se captura.** `verificaciones_buceo.profundidad_maxima` existe en Supabase pero vale 0 en las 833 filas (revisado 2026-11-18) y no existe en SQLite. | El auditor la ingresa en el encabezado del registro. Vacía o 0 = sin dato (nunca cuenta como exceso). Si supera, **aviso** y el auditor decide si lo marca en rojo. |
| Numeración por empresa | `numeradores_informe` + `next_numero_informe` | Contador propio del registro. |

---

## 2. ¿Es más trabajo para el auditor?

**Debería ser igual o menos:**

1. **Los buzos vienen cargados** de la inspección: no se escriben de nuevo nombre, RUT ni cargo. Solo se ingresa la
   profundidad (y lo demás que quiera agregar).
2. **Ninguna foto es obligatoria.** Ninguna nota de las reuniones lo exige. El dashboard puede mostrar el % de buzos con
   evidencia para ver si se están sacando.
3. **La app lo ofrece al finalizar la inspección** y abre el registro ya vinculado, sin buscar nada.
4. Se puede llenar **offline** y en partes (borrador), como el resto de la app.

Los datos de la bitácora se siguen pasando a mano, pero ahora a la app en vez del correo, y el correo queda más corto.

---

## 3. Diseño propuesto

### Cómo se llega al registro

**A. Al finalizar la inspección de buceo (camino principal).** Cuando la inspección se guarda como finalizada sin
errores, sale un aviso: *"¿Quieres hacer el registro de inmersiones ahora?"* → **Sí** abre el formulario ya vinculado a
esa inspección · **Más tarde** cierra el aviso.

- El aviso sale solo si la empresa tiene el módulo habilitado y la inspección no tiene ya un registro.
- **No espera a que la inspección esté subida.** El vínculo es local (`actividad_id`), así que funciona sin señal; si
  se esperara al sync, en terreno sin internet el aviso no saldría nunca. El número y el PDF se resuelven en el sync,
  como en el resto de la app.

**B. Desde la tarjeta "Registro de inmersiones" en Inicio (para "Más tarde").** Abre la lista de **mis inspecciones de
buceo** del dispositivo, las más recientes primero, marcando cuáles ya tienen registro. Solo aparecen las del propio
auditor (las que están en su teléfono).

### El formulario

1. Encabezado: centro, fecha, contratista, N° de inspección (si ya lo tiene) y profundidad autorizada.
2. **Una fila (tarjeta) por buzo**, cargada desde la cuadrilla con los de rol `Buzo`; los demás de la cuadrilla se
   pueden agregar con un botón, y también un buzo que no estaba en la cuadrilla.

   | Campo | Tipo | Notas |
   |---|---|---|
   | Cargo | Lista, viene de la cuadrilla y se puede cambiar | Buzo, Supervisor, Asistente… y **Buzo de emergencia**. |
   | ¿Buceó? | Sí / No | Si es "No", no se piden profundidad ni tiempo. |
   | Profundidad máxima | Número en metros, con decimales | Si supera la autorizada, sale un aviso (ver "Exceso de profundidad"). |
   | Desde | Hora, **se llena sola** y se puede cambiar | Ver "Tiempo" abajo. |
   | Hasta | Hora | El tiempo de inmersión se calcula solo. |
   | + Agregar otra inmersión | Botón discreto | Ver "Varias inmersiones" abajo. |
   | Fotos | Profundímetro · dispositivo · general del buzo | Todas opcionales. |
   | Equipo (opcional) | Marca y serie del profundímetro, serie del registrador | Para una futura tabla de equipos. |
   | Nota adicional | Texto libre | Cualquier comentario sobre ese buzo. |

3. Galería general del informe y observación general.
4. **Finalizar** → número y PDF, como en los demás módulos (en Supabase, con PDF diferido si se finaliza offline).

### Exceso de profundidad (decidido 2026-11-18)

- Al ingresar una profundidad mayor que la autorizada, sale un mensaje: *"El buzo bajó más de la profundidad
  permitida (20 m). ¿Desea marcarlo en rojo?"* → **Sí** / **No**.
- **Sí:** se resalta en rojo en el formulario y en el PDF (`marcado_rojo = true`). **No:** se ve normal.
- `excede_autorizada` se calcula y guarda **siempre**, sin depender de la respuesta. Así el dashboard cuenta todos los
  excesos y además sabe cuáles el auditor quiso destacar.

### Varias inmersiones por buzo (decidido 2026-11-18)

- La pantalla está pensada para **una inmersión**: cada buzo muestra un solo bloque de profundidad y desde–hasta,
  como hoy en el papel.
- Un botón discreto **"+ Agregar otra inmersión"** abre un segundo bloque, por si un buzo bajó más de una vez.
- En la base, cada inmersión es su propia fila. En el buzo se guarda el resumen: profundidad máxima del día (la mayor),
  tiempo total y cantidad de inmersiones.
- El PDF muestra una línea por buzo si bajó una vez (lo normal) y sub-líneas si bajó más veces.

### Tiempo: desde–hasta (decidido)

- **Desde se llena solo** con la **hora en que se crea el registro** (en la práctica, cuando se finaliza la
  inspección y se acepta el aviso), y el auditor la puede corregir.
  Ojo: si el registro se hace "más tarde" desde Inicio, esa hora puede quedar horas después de la inmersión; por eso
  queda editable y se guarda si se cambió.
- En una segunda inmersión, "desde" se deja vacío (no hay una hora razonable para proponer).
- **Hasta** lo pone el auditor con la bitácora.
- El **tiempo de inmersión en minutos** se calcula solo al guardar (si "hasta" es menor que "desde", se asume que cruzó
  la medianoche).
- Se guarda si el "desde" quedó como vino o el auditor lo cambió, para saber en el dashboard qué tan confiable es.

### Datos (todo estructurado, pensado para el dashboard)

```mermaid
erDiagram
    actividades ||--o| registros_inmersion : "1 por inspección de buceo"
    registros_inmersion ||--o{ registro_inmersion_buzos : "una fila por buzo"
    registros_inmersion ||--o{ registro_inmersion_fotos : "fotos"
    registro_inmersion_buzos ||--|{ registro_inmersion_inmersiones : "1 o más inmersiones"
    registro_inmersion_buzos ||--o{ registro_inmersion_fotos : "fotos del buzo"
    personal_externo ||--o{ registro_inmersion_buzos : "buzo"

    registros_inmersion {
        uuid id PK
        uuid actividad_id FK "UNIQUE: la inspección de buceo"
        uuid empresa_id FK
        uuid usuario_id FK "auditor"
        uuid centro_id FK "copia de la inspección"
        date fecha
        numeric profundidad_autorizada_m "la ingresa el auditor"
        text observacion_general
        text origen "AVISO_FINALIZAR / TARJETA_INICIO"
        text estado_final "Borrador / Finalizado / Eliminada"
        int numero "lo asigna el trigger"
        text correlativo "RI-NNNN, lo asigna el trigger"
        text pdf_url
        text pdf_version
        timestamptz created_at
        timestamptz updated_at
    }

    registro_inmersion_buzos {
        uuid id PK
        uuid registro_id FK
        uuid personal_id FK "nullable si es buzo nuevo"
        text nombre "copia del día"
        text rut "copia normalizada"
        text cargo "copia de la cuadrilla, editable (incluye Buzo de emergencia)"
        boolean realizo_inmersion
        numeric profundidad_maxima_m "resumen: la mayor del día"
        boolean excede_autorizada "resumen: alguna inmersión excede"
        boolean marcado_rojo "el auditor aceptó marcarlo"
        int tiempo_total_min "resumen: suma de inmersiones"
        int cantidad_inmersiones "resumen"
        text profundimetro_marca "opcional"
        text profundimetro_serie "opcional"
        text dispositivo_tipo "ej. SENSUS_ULTRA"
        text dispositivo_serie "ej. U-18659, normalizada"
        text nota "nota adicional del buzo"
        int orden
    }

    registro_inmersion_inmersiones {
        uuid id PK
        uuid buzo_id FK
        uuid registro_id FK "para consultas directas"
        int orden "1 = primera inmersión"
        numeric profundidad_maxima_m "ej. 18.8"
        boolean excede_autorizada "calculado al guardar"
        text hora_inicio "HH:mm, la primera se llena sola"
        boolean hora_inicio_editada "el auditor la cambió"
        text hora_termino "HH:mm"
        int tiempo_min "calculado al guardar"
    }

    registro_inmersion_fotos {
        uuid id PK
        uuid registro_id FK
        uuid buzo_id FK "NULL = foto general del informe"
        text tipo "PROFUNDIMETRO / DISPOSITIVO / BUZO_GENERAL / GENERAL"
        text foto_url
        text descripcion
        timestamptz created_at
    }
```

Por qué así:

- **Copias del día** (nombre, RUT, cargo, profundidad autorizada): el informe no cambia si después se edita la ficha del
  buzo o la cuadrilla.
- **Cargo + ¿buceó?** en vez de un "motivo": "Buzo de emergencia" es un cargo, y un buzo de emergencia que sí tuvo que
  bajar queda bien registrado (cargo de emergencia, buceó = sí).
- **Tiempo:** las horas tal cual (`hora_inicio`, `hora_termino`, formato `HH:mm` como en `verificaciones_buceo`) y el
  valor en minutos (`tiempo_min`, para métricas sin recalcular).
- **Inmersiones en tabla aparte + resumen en el buzo:** soporta varias bajadas sin complicar la pantalla, y el dashboard
  lee el resumen por buzo sin sumar filas (las filas sirven para "cuántas veces bajó").
- **`marcado_rojo` separado de `excede_autorizada`:** el rojo es decisión del auditor; el exceso es un hecho.
- **Fotos con `tipo`**: cubre "foto por buzo" y "galería general" a la vez, y permite contar la evidencia faltante.
- **Serie del dispositivo normalizada** (`U18659`): si después se quiere una tabla de equipos (como la de compresores),
  los datos ya están listos para juntarse.
- `excede_autorizada` se guarda calculado para que el dashboard no tenga que recalcular.
- `origen` dice si el registro se hizo desde el aviso o desde Inicio, para medir si el aviso sirve.
- En SQLite: las mismas tablas con `subido` / `eliminado` y rutas locales de fotos, como el resto de los módulos.

### Numeración (correlativo propio)

| Opción | Ejemplo | Pros | Contras |
|---|---|---|---|
| Mismo número que la inspección | Registro N° 1234 = Inspección N° 1234 | Simple de leer. | No es un correlativo propio. Dos documentos distintos con el mismo número generan confusión. |
| Compuesto | `1234-1` | Se ve la inspección de un vistazo. | Con 1 registro por inspección, el sufijo siempre es "-1". Si la inspección todavía no tiene número (finalizada offline), el registro tampoco puede tenerlo. |
| **Propio + referencia** (recomendado) | `RI-0057` · "Inspección de buceo N° 1234" en el encabezado | Sigue la [decisión de numeración por empresa](../../decisiones/numeracion-por-empresa.md) (contador `REGISTRO_INMERSIONES` en `numeradores_informe`). El vínculo queda en el PDF y en la base (`actividad_id`). | Hay que mostrar los dos números en el PDF. |

Si la inspección todavía no tiene número cuando se finaliza el registro, el PDF se genera después del sync (como los
PDF diferidos de hoy) para que salgan los dos números.

### PDF

- Encabezado: "Registro de inmersiones", N° propio, **N° de la inspección de buceo vinculada**, centro, fecha,
  contratista y profundidad autorizada.
- Tabla como la del papel: N°, buzo, RUT, cargo, profundidad máxima (en rojo solo si el auditor lo marcó), desde–hasta y tiempo (sub-líneas si bajó más de una vez), foto del
  profundímetro y foto del dispositivo. "No buceó" en lugar de la profundidad cuando corresponde.
- Notas por buzo (si hay), foto general de cada buzo (si hay), galería general y observación general.
- Pie: "Datos extraídos desde bitácoras". **Sin firmas.**
- Versión propia del generador, como todos los PDF (v0.1.0).

---

## 4. Datos para el dashboard (qué permite medir)

| Métrica | Cómo sale |
|---|---|
| Profundidad máxima por buzo, centro, contratista y mes | `profundidad_maxima_m` + centro y contratista de la inspección |
| **Inmersiones que superan la profundidad autorizada** | `excede_autorizada = true` (y cuántas marcó el auditor: `marcado_rojo`) |
| Inmersiones por buzo (frecuencia y exposición) | conteo por `personal_id` / `rut` con `realizo_inmersion = true`; bajadas: filas de `registro_inmersion_inmersiones` |
| Tiempo de inmersión por buzo y faena, y a qué hora se bucea | `tiempo_total_min`, `tiempo_min`, `hora_inicio` |
| Faenas con buzo de emergencia, y cuántas veces tuvo que bajar | `cargo = 'Buzo de emergencia'` + `realizo_inmersion` |
| Evidencia (% de buzos que bucearon con foto de profundímetro y dispositivo) | fotos por `tipo` |
| Inspecciones de buceo **sin** registro de inmersiones | `actividades` sin fila en `registros_inmersion` |
| Uso del aviso al finalizar | `origen` |
| Uso de registradores (qué Sensus usó cada buzo) | `dispositivo_serie` |

Anotado en [PENDIENTES_DASHBOARD.md §5](../03_por_realizar/PENDIENTES_DASHBOARD.md).

---

## 5. Plan por fases

| Fase | Qué se hace | Dónde |
|---|---|---|
| 0. Confirmar | Preguntas abiertas (abajo). | Reunión |
| 1. Base | Tablas en Supabase (RLS como los módulos vecinos), contador `REGISTRO_INMERSIONES`, trigger de número, bucket de fotos. | Supabase (skill `migracion-supabase`) |
| 2. App | Tablas SQLite y migración (`_dbVersion`), módulo en `ModuleRegistry`, lista de inspecciones, formulario, borrador, sync y PDF. Aviso al finalizar la inspección de buceo. | App (skill `nuevo-modulo`) |
| 3. Habilitar | Módulo para AquaChile en `empresa_modulos`, para todos sus auditores. | Supabase |
| 4. Dashboard | Métricas de la sección 4. | Dashboard |

Módulo de referencia para copiar el patrón: el que tenga formulario con fotos y PDF diferido más parecido; a definir
con la skill `nuevo-modulo`, que revisa primero si basta con un checklist del motor (aquí no basta: hay datos por buzo).

---

## 6. Excluido del alcance

- Envío por correo (descartado para todo hasta nuevo aviso).
- Firmas.
- Fotos obligatorias.
- Registro sin inspección de buceo vinculada, o de una inspección hecha por otro auditor u otro teléfono.
- Cambios al PDF de la inspección de buceo (DPR24).
- Inspecciones de otras empresas o Searov (se puede habilitar después).

## 7. Decisiones tomadas

**2026-11-18:**

- Exceso de profundidad: aviso opcional "¿Desea marcarlo en rojo?"; el exceso se guarda siempre.
- Varias inmersiones por buzo permitidas, pero la pantalla está pensada para una.
- "Desde" automático = hora en que se crea el registro, editable.

**2026-11-08:**

- 1 registro por inspección; se anota solo la profundidad máxima.
- Fotos: profundímetro, dispositivo, general del buzo y galería general; ninguna obligatoria.
- Sin firma ni correo; correlativo propio, vinculado a la inspección.
- Solo se crea vinculado a una inspección del propio auditor; la app lo ofrece al finalizar la inspección.
- Por buzo: cargo, ¿buceó?, nota adicional y tiempo **desde–hasta**, con el "desde" automático.
- Numeración: correlativo propio `RI-NNNN` + N° de la inspección de buceo en el encabezado.
- Lo usan **todos los auditores** de AquaChile desde el inicio (no solo Paola).
- Guardar todos los datos posibles, estructurados, para el dashboard.

## 8. Lo que lleva todo módulo (según skill `nuevo-modulo` y su plantilla)

| Pieza | En este módulo |
|---|---|
| Borradores en Inicio | Sí: si se sale sin finalizar, aparece en borradores y se reabre. |
| Sync | Subida de registro, buzos, inmersiones y fotos (`subido = 0/1`); soft delete con `eliminado = 1`. |
| PDF diferido | Si se finaliza offline o la inspección aún no tiene número, se genera al final del sync. |
| Historial | Rama nueva en `historial_unificado`. |
| RLS y permisos | Como los módulos vecinos: el auditor ve y edita lo suyo, por empresa. |
| Glosario | `moduleKey`, estados, tipos de foto y contador `REGISTRO_INMERSIONES`. |
| Pruebas | `test/registro_inmersiones_test.dart` + `upgrade_data_integrity_test.dart`. |
| Orden | El SQL se escribe al principio pero **se ejecuta al final**, con la app ya conectada a las tablas nuevas (lección de Equipamiento de Buceo). |

## 9. Respuestas (2026-11-18)

1. El PDF lleva el pie "Generado por Servimaf".
2. Si se elimina la inspección de buceo, se elimina también su registro. Lo ideal es no eliminar inspecciones;
   a futuro se quiere una columna de "activo" (`isActive`) en todas las tablas, para verlo aparte.
3. No genera tickets.

## 10. Implementación (2026-11-18)

| Parte | Estado |
|---|---|
| App: tablas SQLite (v65), formulario, aviso al finalizar, tarjeta, borradores, sync, PDF v0.1.0, Historial | Hecho, `flutter analyze` y tests OK |
| Supabase: [`supabase_migration_registro_inmersiones_v1.sql`](../../../supabase_migration_registro_inmersiones_v1.sql) (tablas, número RI-NNNN, baja en cascada, RLS, historial, habilitar AquaChile) | **Ejecutada 2026-11-18**: verificación OK (RLS y 2 políticas por tabla, 2 triggers, historial con los mismos conteos por módulo, módulo habilitado solo para Aquachile, sin alertas RLS en advisors) |
| Prueba en dispositivo (crear, borrador, finalizar offline, sync, número, PDF, Historial) | Pendiente |
| Publicar versión de la app | Pendiente |

Detalles que se resolvieron al implementar:

- Estados: `Borrador`, `Finalizado`, `Eliminada`. Los borradores **no suben** a Supabase: solo los finalizados.
- Para finalizar, cada persona que buceó debe tener la profundidad máxima de su primera inmersión. Las horas,
  fotos y equipo son opcionales.
- Un buzo de emergencia agregado a mano parte con "¿Buceó? = No"; si bajó, se cambia.
- El PDF se genera en el sync, cuando ya existen el RI-NNNN y el N° de la inspección. Si la inspección aún no
  tiene número, el registro queda pendiente y se reintenta en el siguiente sync.
- Una foto cuyo archivo ya no está en el teléfono se omite al subir (no bloquea el registro).
- Profundidad autorizada: la ingresa el auditor en el encabezado (la inspección no la captura; ver §1).
- El registro nuevo se guarda apenas se abre y se autoguarda cada 20 s y al agregar cada foto.
- Los borradores no cuentan como "pendientes de sincronizar".
- Supabase: una baja (`Eliminada`) no se revierte con un reintento del sync, y un registro de una inspección ya
  eliminada nace de baja sin consumir número. Si al subir vuelve `Eliminada`, el teléfono lo borra.
- Pendiente de decidir: la lista del módulo muestra las inspecciones de buceo del auditor sin filtrar por empresa
  (las inspecciones dejan `empresa_id` vacío). Solo importa si un auditor trabaja para varias empresas con buceo.
- Ficha del módulo: [registro-inmersiones.md](../../modulos/registro-inmersiones.md).
