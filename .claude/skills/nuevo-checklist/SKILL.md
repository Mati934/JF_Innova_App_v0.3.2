---
name: nuevo-checklist
description: Crea checklists nuevos en el motor de checklists configurables de JF Innova App (tarjetas que abren la pantalla genérica con distinto checklist), publica nuevas versiones de un checklist existente o lo habilita para otra empresa, generando el SQL desde plantillas probadas y registrándolo en docs. Usar cuando el usuario diga "nuevo checklist", "me pidieron un checklist", "agrega/carga este checklist", "cambia las preguntas de X", "nueva versión del checklist", "habilita el checklist X para la empresa Y", o comparta un Word/Excel/foto/lista de preguntas de inspección. Si el pedido no cabe en el motor, deriva a la skill nuevo-modulo.
---

# Nuevo checklist (motor configurable)

## Modelo mental

El motor sirve para crear **módulos genéricos** sin programar: todos comparten
el encabezado base (supervisor, correo de supervisor y campos del catálogo) y
la misma pantalla (`GenericChecklistFormScreen`) y PDF; lo único que cambia es
el checklist. Cada checklist aparece en Inicio de la empresa como **tarjeta
suelta** o dentro de una **tarjeta de grupo**. Los módulos que no caben en este
molde se hacen como módulo normal (skill `nuevo-modulo`).

Detalle: `docs/modulos/checklists-configurables.md`. Catálogo actual:
`docs/checklists/README.md`. Códigos y nombres: `docs/glosario.md`.

## Modos

| Modo | Cuándo | Plantilla |
|---|---|---|
| **A. Checklist nuevo** (uno o un lote) | Pedido de un checklist que no existe. | `plantilla_checklist.sql` |
| **B. Nueva versión** | Cambian preguntas, categorías o criticidad de un checklist existente. | `plantilla_nueva_version.sql` |
| **C. Otra empresa** | Un checklist que ya existe se habilita para otra empresa. | `plantilla_checklist.sql` con los datos actuales del checklist (ficha y preguntas de la versión publicada, leídas con la sección 0 de `plantilla_nueva_version.sql`); solo cambia `cfg_empresas`. Ficha y versión ya existen y no se tocan; se agregan tarjetas y permisos. |

## Paso 1: ¿cabe en el motor?

Cabe si **todas** se cumplen:

- Cada pregunta se responde con **Sí / No / No aplica** (+ observación y foto opcionales).
- El encabezado se arma con campos de tipo texto, texto_largo, numero, fecha,
  hora, email, telefono, booleano, seleccion_unica o seleccion_multiple.
- Un formulario = una cosa inspeccionada (no una grilla de N equipos dentro del mismo informe).
- Basta el PDF estándar del motor y una firma.

**No** cabe (requiere código; avisar y ofrecer `nuevo-modulo` o una mejora del motor) si pide:

- Respuestas numéricas o de texto por pregunta, o preguntas repetidas por persona/equipo (como "por buzo").
- Varios equipos en el mismo informe (como la grilla de extintores).
- Responsable y fecha de cumplimiento por hallazgo.
- Reglas obligatorias: observación o foto obligatoria en "No cumple". Las marcas
  del form type (`requiere_observacion_nc`, `requiere_foto_nc`, etc.) y
  `snapshot_reglas` **se guardan pero la app no las aplica**.
- Tickets automáticos desde sus "No cumple".
- Un PDF con diseño propio.
- Un ícono fuera de la lista soportada (abajo); eso requiere publicar la app.

Si solo una parte no cabe, decirlo y proponer: (a) cargar sin esa parte, (b) mejorar el motor, (c) módulo normal. Recomendar una.

## Paso 2: reunir y normalizar (antes de cualquier SQL)

1. Leer la fuente (Word, Excel, PDF, foto o texto). Los documentos fuente se
   guardan en `documentos_checklists/` (`Por Hacer/` mientras se trabaja,
   `Hechos/` al terminar, `En Pausa/` si queda postergado o descartado).
2. Preguntar lo que falte, en una sola tanda:
   - Empresa(s) cliente a la que va dirigido (nombre exacto en `empresas`).
     Servimaf es la empresa propia: incluirla solo si el usuario lo pide.
   - Navegación: **tarjetas sueltas** o **grupo** (nombre del grupo). Si ya existe un grupo afín, proponer reutilizarlo.
   - Si los informes se verán en Historial (habilitar `HISTORY` si la empresa no lo tiene).
3. Normalizar las preguntas:
   - Una idea por pregunta, redactada como pregunta de Sí/No ("¿El equipo cuenta con…?").
   - Agrupar en categorías cortas.
   - Criticidad `Tolerable / Moderado / Intolerable` (preguntar si el cliente no la define; por defecto Tolerable).
   - Sacar del cuestionario lo que en realidad es encabezado (equipo, operador, patente, horómetro…) y llevarlo a campos.
4. Campos del encabezado: reutilizar el catálogo (`checklist_campo_definiciones`)
   antes de crear uno nuevo. Hoy existen: obra_faena, region, area_especifica,
   jefatura_a_cargo, hora_inicio, hora_termino, correo_empresa_1,
   correo_empresa_2, equipo_identificacion, operador_equipo. Confirmar con una
   consulta de solo lectura porque puede haber más.
5. Clave `chq_<nombre_corto>` (minúsculas, `_`), prefijo de informe de 2–4
   letras MAYÚSCULAS no usado por otro checklist activo, ícono de la lista.

**Mostrar al usuario una tabla de aprobación** con: checklist, clave, prefijo,
ícono, empresas, modo de navegación, campos (reutilizados / nuevos, obligatorios)
y las preguntas por categoría con su criticidad. No generar SQL hasta que apruebe.

### Íconos soportados

`handyman, hardware, construction, build, build_circle, local_fire_department,
electrical_services, bolt, power, electric_bolt, precision_manufacturing,
factory, emergency, pallet, directions_car, fire_extinguisher, plumbing,
category, checklist` (fuente: `lib/features/configurable_checklists/presentation/checklist_icons.dart`;
verificar ahí si cambió).

## Paso 3: generar el SQL

1. Copiar la plantilla del modo a la raíz como
   `supabase_seed_checklist_<nombre>_v1.sql` (modo A/C) o
   `supabase_checklist_<clave>_v<N>.sql` (modo B).
2. Reemplazar **todos** los `<<...>>` y las filas de ejemplo de cada tabla
   `cfg_*`. Al terminar, buscar `<<` en el archivo: no debe quedar ninguno.
3. No cambiar la lógica de la plantilla. Si hace falta algo distinto, explicarlo y pedir OK.
4. Modo B: conservar el `id` de cada pregunta que no cambia de sentido. La app
   reabre los borradores con la última versión publicada y une las respuestas
   por `id`: cambiar ids hace que un borrador abierto pierda respuestas y rompe
   métricas entre versiones.

## Paso 4: ejecutar y verificar

1. Ejecutar la **sección 0** con el MCP de solo lectura (`supabase`) y revisar
   cada "esperado". Si algo no calza, corregir antes de seguir.
2. El bloque `BEGIN…COMMIT` **escribe en producción**: mostrar el resumen y pedir
   OK explícito. Con OK, ejecutarlo con `supabase-write` (o el usuario lo pega en
   el SQL Editor). Nunca ejecutar escrituras sin ese OK.
3. Ejecutar la **sección 2** y comparar con lo esperado.
4. Decirle al usuario cómo probar: sincronizar en la app con un usuario de la
   empresa, ver la tarjeta, completar y **finalizar** una inspección de prueba,
   y revisar el PDF y el correlativo (`<PREFIJO>-0001`). Ofrecer después
   eliminar esa inspección de prueba.

## Paso 5: documentar

Usar la skill `documentar-app`:

- `docs/checklists/README.md`: fila en "Motor configurable" (o actualizar
  versión/empresas), con fecha y "dirigido a".
- `docs/glosario.md`: clave ↔ nombre.
- `docs/modulos/checklists-configurables.md`: lista de checklists si cambió.
- `docs/CHANGELOG.md`.
- Mover el documento fuente de `documentos_checklists/Por Hacer/` a `Hechos/`.
- Lanzar el agente `revisor-cambios` (siempre, sin preguntar) sobre el SQL generado.

## Errores conocidos que esta skill evita

- **Permisos por usuario**: los scripts antiguos daban permiso solo a los
  usuarios existentes al ejecutar; los nuevos quedaban sin ver las tarjetas
  (RLS `checklist_user_can`). Las plantillas dan permisos **por rol**.
- Prefijo repetido entre checklists activos (índice único `uq_checklists_active_report_prefix`).
- Orden repetido de tarjetas (índice único por empresa + padre + orden): la plantilla calcula el orden.
- Sobrescribir una versión publicada: nunca; se publica una versión nueva.
