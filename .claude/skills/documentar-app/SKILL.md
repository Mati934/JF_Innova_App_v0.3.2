---
name: documentar-app
description: Mantiene al día la documentación funcional de JF Innova App en docs/ (índice, arquitectura, base de datos, fichas de módulos, catálogo de checklists, decisiones y CHANGELOG). Usar SIEMPRE, sin esperar a que lo pidan, al terminar una tarea que agregue o cambie una funcionalidad, un módulo, una regla de negocio, una tabla o columna (SQLite o Supabase), un checklist o un PDF; y cuando el usuario diga "actualiza la documentación", "documenta esto", "revisa que la documentación esté al día" o similar (en ese caso, auditar docs/ contra el código y la base y corregir lo desactualizado).
---

# Documentar la app

La documentación en `docs/` explica **qué hace** la app y **por qué**, para el
usuario y para Claude. No es documentación de código: el **cómo** solo aparece
para ubicar algo (archivo principal, tabla).

## Reglas generales

- Escribir en español, frases cortas, sin relleno.
- Solo hechos verificados en código, Supabase (lectura) o docs. Lo que no se
  pueda verificar se escribe literalmente **"pendiente de confirmar"**.
- Nunca inventar fechas, motivos ni quién pidió algo.
- Fechas en formato `AAAA-MM-DD`. Actualizar "Última revisión" de cada archivo tocado.
- No duplicar: si algo ya está en una ficha, enlazarlo.
- No mover ni borrar `docs/planificacion/` ni los docs sueltos antiguos: están
  enlazados desde `CLAUDE.md` y `.github/copilot-instructions.md`.
- No incluir claves, datos personales (RUT, correos de personas) ni datos de clientes más allá del nombre de la empresa.
- Supabase: solo lectura (catálogos y conteos). Nunca escribir.
- **Servimaf es la empresa propia** y tiene todos los módulos: no deducir qué usa
  un cliente a partir de lo que tiene Servimaf.

## Verificar antes de afirmar

Antes de escribir que algo está desalineado, duplicado, sin uso u obsoleto,
comprobar la **fuente de verdad**, no solo que algo exista:

1. Qué columna usa realmente el valor (`information_schema.columns`, tipo y
   `udt_name`) y qué la valida (`pg_get_constraintdef` de los checks, enums).
2. Dónde lo lee/escribe el código (grep del valor y de la tabla).
3. Si hay datos (conteo por valor).

Un enum, tabla o script que existe no prueba que se use. Si no se puede
verificar, escribir "pendiente de confirmar" en vez de afirmar el problema.

## Qué va en cada lugar

| Ruta | Contenido | Cuándo se toca |
|---|---|---|
| `docs/README.md` | Resumen de la app, mapa de docs, tabla de módulos. | Módulo nuevo, renombrado o eliminado; carpeta nueva. |
| `docs/glosario.md` | Traductor: clave ↔ nombre visible ↔ valor en base, con su fuente de verdad (módulos, checklists, estados, respuestas, términos, empresas). | Cualquier código, estado, módulo, checklist o término nuevo o renombrado; cambio en la relación con una empresa. |
| `docs/arquitectura.md` | Stack, carpetas, flujo entre partes, comandos. | Cambia el stack, una dependencia importante, el flujo de sync/PDF o la estructura. |
| `docs/base-de-datos/README.md` | Relaciones generales, estados, tipos de respuesta, criticidad, convenciones. | Nuevo estado, enum, tipo de respuesta o convención. |
| `docs/base-de-datos/maestros.md` | Tablas maestras y módulos habilitados por empresa. | Cambia una tabla maestra o la habilitación de módulos. |
| `docs/base-de-datos/esquema-por-modulo.md` | Tablas de cada módulo (Supabase y local) con su contenido. | Tabla o columna nueva/cambiada. |
| `docs/modulos/<modulo>.md` | Ficha del módulo. | Cualquier cambio funcional del módulo. |
| `docs/modulos/README.md` | Lista de fichas con clave y estado. | Módulo nuevo o cambio de estado. |
| `docs/checklists/README.md` | Catálogo de checklists por fuente. | Checklist nuevo, modificado, nueva versión o retirado. |
| `docs/decisiones/<tema>.md` + `README.md` | Una decisión de diseño por archivo. | Se decide algo que cambia cómo se hacen las cosas o se descarta una alternativa. |
| `docs/CHANGELOG.md` | Cambios por fecha. | **Siempre** que haya un cambio funcional, de datos o de checklists. |

## Formatos

### Ficha de módulo (`docs/modulos/<nombre-en-kebab>.md`)

```markdown
# <Nombre visible>

> Clave: `<MODULE_KEY>` · Estado: <en producción | piloto | en desarrollo | sin implementar> · Última revisión: AAAA-MM-DD
> Empresas con el módulo (AAAA-MM-DD): <lista>.

## Qué hace
<2–4 frases para alguien que no conoce el código.>

## Reglas de negocio
- <Validaciones, obligatorios, estados, cálculos, permisos, qué pasa offline.>

## Datos
<Tablas Supabase y locales; enlace a base-de-datos/esquema-por-modulo.md.>

## Pantallas
<Pantallas y flujo entre ellas.>

## Archivos principales
- <3–5 rutas máximo: controller, reglas, PDF (con versión).>

## Pendientes
- <Backlog, dudas, "pendiente de confirmar", enlaces a planificacion/.>
```

### Fila del catálogo de checklists

Agregar la fila en la sección de su fuente (banco clásico `formulario_items`,
Equipamiento de Buceo, o motor configurable). Columnas: código/clave, nombre,
módulo o grupo, categorías (cantidad y nombres), cantidad de preguntas, fecha
en que se agregó, **dirigido a** (clientes que tienen el módulo o la tarjeta;
sin contar Servimaf) y estado (vigente, oculto, sin uso). Un checklist que se
deja de ofrecer se marca **Oculto** con fecha, no se borra la fila. Agregar
también su código al glosario. Obtener los números con una consulta de solo
lectura, por ejemplo:

```sql
select tipo_actividad, count(*), count(distinct categoria)
from formulario_items where activo group by 1;
-- motor configurable
select c.checklist_key, c.nombre, v.version,
       jsonb_array_length(v.snapshot_preguntas) as preguntas
from checklists c join checklist_versions v
  on v.checklist_key = c.checklist_key and v.version = c.published_version;
```

Si no hay acceso a Supabase, contar en el script SQL de carga y anotar
"según script, pendiente de confirmar en la base".

### Decisión (`docs/decisiones/<tema-en-kebab>.md`)

```markdown
# <Decisión en una línea>

- **Fecha:** AAAA-MM-DD
- **Estado:** vigente | reemplazada por [otra](otra.md) | en revisión
- **Fuente:** <doc, conversación o commit>

## Qué se decidió
## Por qué
## Alternativas
<Qué otras opciones había y por qué no se eligieron.>
## Consecuencias
```

Agregar una fila en `docs/decisiones/README.md`. Si una decisión cambia, no
borrar la antigua: marcarla "reemplazada por" y crear la nueva.

### Entrada del CHANGELOG

Bajo `## AAAA-MM-DD` (crear el encabezado si no existe, más reciente arriba):

```markdown
- [Módulo] Qué cambió, dicho para el usuario de la app.
```

Si se sube versión en `pubspec.yaml`, agregar `- [App] Versión X.Y.Z+N ...`.

## Procedimiento A: después de un cambio

1. Identificar qué cambió: módulo(s), tablas, checklists, PDF, decisiones.
2. Leer la ficha del módulo y actualizar solo las secciones afectadas.
3. Si hubo cambio de tablas: actualizar `esquema-por-modulo.md` (y `maestros.md` o `base-de-datos/README.md` si aplica).
4. Si hubo checklist: actualizar `docs/checklists/README.md`.
5. Si cambió un PDF: anotar la nueva versión en la ficha y en `decisiones/version-por-pdf.md`.
6. Si se tomó una decisión de diseño: crear su archivo en `decisiones/`.
7. Si es un módulo nuevo: crear la ficha, agregarlo a `modulos/README.md` y a la tabla de `docs/README.md`.
8. Si hay un código, estado o término nuevo: agregarlo a `docs/glosario.md` con
   su valor en la base, en el código y la etiqueta visible. Si los tres no
   coinciden, avisar al usuario antes de cerrar la tarea.
9. Agregar la entrada al `CHANGELOG.md`.
10. En la respuesta al usuario, listar en una línea qué archivos de docs se tocaron.

## Procedimiento B: "revisa que la documentación esté al día"

1. **Módulos**: comparar `ModuleRegistry` (`lib/core/modules/module_registry.dart`),
   las carpetas `lib/features/*` y `checklist_navigation_nodes` con
   `docs/modulos/README.md`. Señalar módulos sin ficha o fichas sin módulo.
2. **Tablas**: comparar las tablas de Supabase (`list_tables`) y las de SQLite
   (`CREATE TABLE` en `database_helper.dart`) con `esquema-por-modulo.md` y `maestros.md`.
3. **Checklists**: rehacer los conteos del catálogo con las consultas de arriba.
4. **PDFs**: buscar `_pdfVersion` / `pdfVersion` en `lib/` y comparar con `decisiones/version-por-pdf.md`.
5. **Empresas**: consultar `empresa_modulos` y actualizar la tabla de `maestros.md` y la línea "Empresas con el módulo" de cada ficha.
6. **Changelog**: revisar `git log` desde la última fecha del CHANGELOG y agregar lo que falte.
7. **Glosario**: comparar estados y códigos con los checks/enums de Supabase y
   los enums del código (aplicando "Verificar antes de afirmar").
8. Revisar los "pendiente de confirmar": si ya se puede confirmar, resolverlo.
9. Corregir lo desactualizado y entregar un resumen: qué estaba mal, qué se
   corrigió y qué sigue pendiente de confirmar (pregunta concreta al usuario).
