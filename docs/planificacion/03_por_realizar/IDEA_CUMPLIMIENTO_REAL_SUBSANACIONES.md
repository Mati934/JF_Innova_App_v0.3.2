# Idea: porcentaje de cumplimiento real despues de subsanar

**Estado:** Idea pendiente de diseno  
**Fecha:** 2026-09-03

## 1. Idea general

Actualmente una inspeccion puede comenzar con varios `NC` (No Cumple), por lo que su porcentaje de cumplimiento inicial queda bajo. Si posteriormente esos hallazgos se corrigen mediante tickets y la subsanacion es validada, el resultado operativo real deberia mejorar.

La propuesta es mostrar dos porcentajes distintos:

1. **Cumplimiento de la inspeccion:** resultado original registrado al terminar la inspeccion.
2. **Cumplimiento real o actualizado:** estado actual de los hallazgos, considerando cuales fueron subsanados y cerrados correctamente.

Ejemplo:

- La inspeccion tenia 10 puntos evaluables.
- 6 Cumple y 4 No Cumple.
- Cumplimiento inicial: `60%`.
- Se subsanan y aprueban 3 de los 4 hallazgos.
- Cumplimiento actualizado: `90%`.
- Queda 1 hallazgo pendiente o no validado.

El porcentaje inicial no se reemplaza: se conserva como fotografia de la inspeccion. El porcentaje actualizado representa la situacion vigente y debe mostrar la fecha de su ultima actualizacion.

## 2. Regla de calculo propuesta

### Cumplimiento inicial

Usar la fuente oficial del panel de control y la misma regla actual de cumplimiento:

```text
cumplimiento_inicial = respuestas_C / (respuestas_C + respuestas_NC) * 100
```

Las respuestas `N/A` no entran en el denominador, salvo que la regla actual del panel indique expresamente lo contrario.

### Cumplimiento real actualizado

Para evitar mezclar observaciones duplicadas entre informes, el calculo deberia basarse en **hallazgos unicos**, no en la cantidad bruta de tickets ni en la cantidad de ocurrencias.

Una primera formula posible seria:

```text
cumplimiento_actualizado =
  (hallazgos_cerrados_aprobados /
   (hallazgos_cerrados_aprobados + hallazgos_abiertos + hallazgos_en_seguimiento)) * 100
```

Otra vista complementaria, mas orientada a la inspeccion original, seria:

```text
recuperacion_de_NC =
  hallazgos_originales_subsanados_y_aprobados /
  hallazgos_originales_totales * 100
```

La primera mide el estado vivo actual. La segunda mide cuanto se recupero de una inspeccion especifica.

## 3. Fuentes de datos

La fuente de los indicadores debe pasar por el **panel de control**, para mantener una unica regla de calculo y evitar rescates o conteos duplicados.

Fuentes que el panel podria utilizar:

- `inspeccion_respuestas`: resultado original `C`, `NC` o `N/A`.
- `nc_hallazgos`: hallazgo unico y estado vivo.
- `nc_hallazgo_ocurrencias`: relacion del hallazgo con cada informe, sin contar cada ocurrencia como un problema nuevo.
- `tickets`: expediente operativo asociado al hallazgo.
- `ticket_items`: observaciones y estado de subsanacion.
- `ticket_item_subsanaciones`: evidencia e historial de subsanaciones.

La fuente oficial debe quedar definida en un diccionario de metricas antes de implementar el dashboard.

## 4. Reglas necesarias para que el porcentaje sea confiable

- [ ] No contar tickets como si fueran hallazgos: un hallazgo puede tener varios tickets historicos.
- [ ] No contar ocurrencias repetidas de un mismo hallazgo como problemas independientes.
- [ ] Una subsanacion solo mejora el porcentaje cuando la evidencia fue aprobada, no solo cuando alguien marco el item.
- [ ] Definir si `FINALIZADO_PENDIENTE_REVISION` cuenta como subsanado provisional o como pendiente hasta `CERRADO`.
- [ ] Definir que ocurre cuando un admin rechaza una subsanacion.
- [ ] Definir si un hallazgo reabierto vuelve a bajar el porcentaje.
- [ ] Excluir tickets eliminados logicamente.
- [ ] Excluir tickets historicos desactivados por la politica de lanzamiento.
- [ ] Mostrar fecha de corte y ultima actualizacion del porcentaje.
- [ ] Separar inspecciones de distintos tipos de checklist si sus preguntas o reglas no son comparables.

## 5. Vistas que podria mostrar el panel

### Por inspeccion

- Cumplimiento inicial.
- Cumplimiento actualizado.
- Cantidad de NC iniciales.
- Hallazgos cerrados y aprobados.
- Hallazgos pendientes.
- Hallazgos rechazados o reabiertos.
- Fecha de ultima actualizacion.

### Por embarcacion o centro

- Cumplimiento promedio inicial del periodo.
- Cumplimiento real actual de hallazgos.
- Cantidad de hallazgos abiertos.
- Tiempo promedio de subsanacion.
- Reincidencia de hallazgos.

### Evolucion temporal

Mostrar el cambio entre el resultado de la inspeccion y el estado actual, por ejemplo:

```text
60% inicial -> 90% actualizado
4 NC iniciales -> 1 pendiente
3 hallazgos cerrados y aprobados
```

## 6. Riesgos de interpretacion

El porcentaje actualizado no debe presentarse como si la inspeccion original hubiese sido mejor de lo que fue. La inspeccion tuvo el resultado que tuvo; lo que cambia es el estado posterior de sus hallazgos.

Por eso la interfaz deberia usar nombres diferentes, por ejemplo:

- `Cumplimiento de inspeccion`
- `Cumplimiento actual de hallazgos`
- `Recuperacion posterior`

Evitar mostrar solo un numero sin indicar si es inicial o actualizado.

## 7. Decisiones de negocio pendientes

- [ ] Confirmar si una subsanacion requiere aprobacion administrativa para influir en el porcentaje.
- [ ] Confirmar si el porcentaje actualizado se calcula por inspeccion, por embarcacion, por centro, por empresa o por periodo.
- [ ] Confirmar si los hallazgos persistentes entre varias inspecciones se cuentan una sola vez.
- [ ] Confirmar como se ponderan inspecciones con distinta cantidad de preguntas.
- [ ] Confirmar si fotos con observacion sin respuesta `NC` entran en el indicador y con que peso.
- [ ] Confirmar si el cierre de un ticket implica automaticamente cierre del hallazgo.
- [ ] Confirmar si un hallazgo desactivado o historico queda fuera del porcentaje vigente.

## 8. Siguiente paso recomendado

Antes de programar, construir una consulta de solo lectura desde la logica del panel que entregue, para una inspeccion elegida:

- respuestas `C`, `NC` y `N/A`;
- hallazgos unicos relacionados;
- estado actual de cada hallazgo;
- ticket e items asociados;
- subsanaciones aprobadas, rechazadas y pendientes;
- ambos porcentajes y sus denominadores.

Luego validar manualmente el resultado con dos o tres inspecciones reales, incluyendo una con varios `NC`, una con subsanaciones parciales y una con un hallazgo repetido en informes posteriores.

No implementar el indicador hasta cerrar las decisiones de negocio y confirmar que el panel usa la misma fuente para todos los reportes.
