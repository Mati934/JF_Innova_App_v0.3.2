# Backlog: Criticidad de Hallazgos

> Tema pendiente para retomar más adelante. **No implementar todavía.**

## Contexto / Problema observado

- En el **dashboard** aparecen demasiados hallazgos clasificados como **"Intolerable"**.
- Causa raíz sospechada: los **prevencionistas no están definiendo la criticidad** al responder las preguntas, y el sistema está usando un default (probablemente "Intolerable") cuando el usuario no la selecciona.
- Existe un documento/excel externo donde la criticidad **ya viene definida por pregunta**. (No se pudo descargar todavía — pendiente de revisar).

## Ideas / Hipótesis a evaluar

### 1. Criticidad fija por pregunta en la BD
- En la tabla `formulario_items` (o equivalente) ya existe el campo `criticidad`.
- **Regla nueva propuesta**: la criticidad solo se podría editar en el formulario **si la pregunta tiene `criticidad = NULL`** en la BD.
- Si la pregunta ya tiene criticidad maestra, el formulario la usa automáticamente y **bloquea la edición** al usuario.
- Beneficio: evita que el prevencionista olvide ponerla y elimina el sesgo a "Intolerable".

### 2. Migración masiva de hallazgos existentes
- ¿Hay una forma de **recalcular en masa** la criticidad de los hallazgos ya guardados (en SQLite y/o Supabase) cruzando con la criticidad maestra de cada pregunta?
- Posible script SQL único: `UPDATE hallazgos SET criticidad = fi.criticidad FROM formulario_items fi WHERE hallazgos.item_id = fi.id AND fi.criticidad IS NOT NULL`.
- Decidir: ¿se reemplazan **todas** o solo las que tengan criticidad por defecto/null?

### 3. Carga del documento maestro de criticidades
- Cuando el usuario consiga el archivo, hay que:
  - Mapear preguntas del excel ↔ `formulario_items.id`.
  - Generar un SQL/migración tipo `UPDATE formulario_items SET criticidad = ... WHERE id = ...`.
  - Idealmente, una sola migración Supabase reproducible (similar a las que ya existen en la raíz del repo).

## Excluido del alcance

- **PROSESSO no usa criticidad** y es un ejemplo válido del patrón: las preguntas de `MANTENCION_PROSESSO` deben tener `criticidad = NULL` en `formulario_items` (o el campo directamente ausente del cálculo de riesgo).
- Este patrón "sin criticidad" es precisamente lo que queremos generalizar: si una pregunta tiene `criticidad = NULL` en la BD → el módulo/formulario **no muestra ni calcula criticidad** para esa pregunta.
- Esto valida la idea de usar `formulario_items.criticidad IS NULL` como señal de "no aplica criticidad" (no solo como "el usuario aún no la definió").

## Tareas pendientes (cuando se retome)

- [ ] Conseguir el documento/excel con criticidades definidas.
- [ ] Investigar el campo `criticidad` actual en `formulario_items` (¿qué valores soporta? ¿hay default a "Intolerable" en algún lado?).
- [ ] Auditar el flujo: dónde se asigna la criticidad cuando el usuario no la elige.
- [ ] Decidir regla final (bloquear edición si maestra existe vs. solo sugerir).
- [ ] Diseñar migración para corregir hallazgos históricos.
- [ ] Crear migración Supabase para cargar criticidades maestras.
- [ ] Actualizar UI del formulario (deshabilitar selector cuando viene maestra).
- [ ] Verificar que **no aplica** al módulo PROSESSO.
- [ ] Validar impacto en el dashboard después del cambio.

## Notas

- Mantener **modo offline**: la criticidad maestra debe estar en SQLite también, no solo en Supabase.
- Considerar versionado: si una pregunta cambia de criticidad maestra, ¿se recalculan los hallazgos antiguos o solo los nuevos? Recomendado: **solo nuevos**, los históricos quedan como evidencia del momento.
