---
name: diagnosticar-error
description: Diagnostica errores reportados en JF Innova App (algo que no sale, no se guarda, sale mal o falla) encontrando la causa con evidencia real antes de tocar código, y entrega causa, alcance y plan de arreglo esperando OK. Usar SIEMPRE, sin esperar a que lo pidan, cuando el usuario reporte un problema: "me comentaron que…", "me dijeron que…", "no sale…", "no aparece…", "no funciona…", "no se guarda…", "falla…", "error en…", "sale mal…", "está raro…", o pida "diagnostica", "revisa por qué…", "encuentra el error". No usar para features nuevas.
---

# Diagnosticar error

Regla de oro: **no editar código ni datos hasta que el usuario dé OK al plan.**
Reglas de base del proyecto: `CLAUDE.md` y `.github/copilot-instructions.md`.

## Paso 1: fijar un caso concreto

Necesito un caso real para comprobar, no una descripción general:
número de informe, fecha, empresa, usuario, módulo; qué se esperaba y qué salió;
si se finalizó con o sin internet; dispositivo/plataforma.

- Si el usuario no lo dio, buscarlo yo en Supabase (solo lectura): los registros
  más recientes del módulo afectado. Solo preguntar si no hay forma de encontrarlo.

## Paso 2: evidencia real primero

Antes de leer mucho código, mirar qué pasó de verdad:

- **Datos**: MCP `supabase` (solo lectura). ¿El dato está guardado? ¿En qué tabla
  y columna? Contrastar el caso malo con uno bueno del mismo módulo.
- **Artefacto generado**: si es un PDF, bajarlo desde `pdf_url` a una carpeta propia
  en el scratchpad y extraer el texto (`pdftotext -layout`). Compararlo con lo que
  el código debería dibujar (títulos, secciones, etiquetas): eso dice qué rama del
  código se ejecutó.
- **Logs/errores**: Crashlytics si el usuario lo comparte; `query_logs` de Supabase
  para errores del backend.

Resultado de este paso: "el dato está / no está" y "se ejecutó la rama X".

## Paso 3: ubicar la causa

1. graphify primero (`graphify query/explain/path`), según `CLAUDE.md`.
2. Seguir el dato desde el formulario → SQLite → sync → Supabase → generador.
3. **Comparar caminos paralelos**, donde nacen la mayoría de estos errores:
   online vs. diferido (`DeferredPdfService`), borrador vs. final, buceo vs.
   embarcación, local vs. Supabase, primera carga vs. reabrir un borrador.
   Si dos caminos construyen el mismo objeto, revisar que llenen lo mismo con los
   mismos valores (textos, tildes, claves, nulls).
4. Revisar condiciones que deciden por un texto mostrado (`contains('…')`,
   comparaciones de strings con tilde/mayúsculas): son frágiles.
5. `git log -S"<línea sospechosa>"` para saber desde cuándo existe el error.

No dar una causa por buena hasta que explique **todo** lo observado en el paso 2.

## Paso 4: alcance

- Cuántos registros quedaron afectados y desde qué fecha (consulta de solo lectura).
- Si hay datos o PDFs ya emitidos que el arreglo de código no corrige.
- Si afecta a otras empresas o módulos que usan el mismo código.

## Paso 5: informe y esperar OK

Entregar, corto:

- **Causa** con archivo:línea y la evidencia que la prueba.
- **Alcance** (cifras).
- **Plan de arreglo**: preferir corregir la causa de fondo (una sola fuente de verdad)
  sobre parchar el síntoma; decir si hace falta subir versión de PDF, migración
  SQLite/Supabase o regenerar datos.
- Qué queda pendiente de decidir por el usuario (ej. regenerar PDFs ya enviados).

Luego **detenerse** hasta el OK.

## Paso 6: después del OK

1. Arreglo mínimo que cubra la causa (ponytail).
2. Test de regresión que falle sin el arreglo (`test/<tema>_test.dart`).
3. `flutter analyze` y el test dirigido (MCP `dart`).
4. Si toca PDF: subir el patch de su `_pdfVersion`.
5. Lanzar el agente `revisor-cambios` (siempre, sin preguntar) y atender sus hallazgos.
6. Skill `documentar-app` si cambió comportamiento (al menos CHANGELOG).
7. Nunca escribir en Supabase ni regenerar datos sin un OK explícito aparte.
