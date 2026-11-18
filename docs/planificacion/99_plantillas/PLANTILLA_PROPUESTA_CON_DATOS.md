# Plantilla: propuesta o análisis con datos

> Para ideas que cambian **cómo se guardan los datos** o **una regla de negocio** y que conviene analizar con datos
> reales antes de decidir (ejemplos: [compresores](../03_por_realizar/PROPUESTA_COMPRESORES.md),
> [criticidad fija](../03_por_realizar/CRITICIDAD_BACKLOG.md)).
> Copiar a `03_por_realizar/PROPUESTA_<TEMA>.md` y agregar una línea en el [índice](../README.md).
> Si el tema ya tiene un backlog, **actualizar ese archivo** en lugar de crear otro.

```markdown
# Propuesta: <tema>

> **Para qué es:** <una frase con el tema del archivo>

> Estado: idea / backlog · Creado: AAAA-MM-DD · Origen: <quién o qué reunión>
> Alcance: <empresa(s), módulo(s)> · Relacionado: <enlaces>

## Resumen
| | |
|---|---|
| **Idea / pregunta** | ... |
| **¿Es factible?** | ... |
| **¿Se pierde información?** | ... |
| **Recomendación** | ... |

## 1. Cómo funciona hoy
Tablas y columnas reales (verificadas en Supabase), archivos de la app y del dashboard que lo usan.

## 2. Lo que dicen los datos (Supabase, AAAA-MM-DD)
Tabla de cifras + qué significa cada una. Indicar el período y si hay datos basura o de prueba.

## 3. Opciones
Tabla de pros y contras, con una recomendada.

## 4. Plan por fases
Primero lo que no toca la app (tablas, copia de datos), después la app, al final la limpieza (opcional).
Cada fase: qué se hace, dónde (Supabase / app / dashboard) y si es reversible.

## 5. Excluido del alcance

## 6. Preguntas abiertas
```

## Reglas

- Las cifras se sacan de la base real con consultas de **solo lectura** y llevan fecha.
- Nunca proponer sobrescribir datos históricos sin una alternativa que los conserve.
- Si el cambio también afecta al dashboard, agregar una sección en
  [PENDIENTES_DASHBOARD.md](../03_por_realizar/PENDIENTES_DASHBOARD.md).
- Cuando la propuesta se apruebe y se implemente, el detalle técnico pasa a `docs/` (módulo, base de datos,
  decisión) con la skill `documentar-app`, y este archivo se mueve a cerrado en el índice.
