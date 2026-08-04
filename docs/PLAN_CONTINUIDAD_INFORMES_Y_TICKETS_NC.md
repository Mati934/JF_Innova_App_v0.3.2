# Plan de Continuidad de Informes y Tickets por No Cumple

Estado: V1 funcional cerrado (pendiente solo matriz de campos duros/informativos)
Fecha: 2026-07-23
Objetivo: evitar duplicados de No Cumple (NC) cuando se repiten en informes consecutivos, y generar tickets por hallazgo real (1 ticket por NC real), no por cada informe.

## 1) Problema real

Hoy un prevencionista puede registrar el mismo NC durante varios días (inicial + consecutivos). En base de datos eso queda como varios NC separados, aunque en terreno es el mismo hallazgo que sigue abierto.

Impacto:
- KPIs inflados (parece que hay más NC de los reales).
- Tickets duplicados del mismo problema.
- Dificultad para seguimiento y cierre real.

## 2) Resultado esperado (negocio)

Regla de negocio central:
- Un mismo NC persistente a través de informes consecutivos del mismo contexto debe ser 1 solo hallazgo vivo.

Regla para tickets:
- 1 ticket por cada hallazgo NC real (no por informe).
- Si en un informe nuevo aparece el mismo NC, se vincula al ticket existente y no se crea otro.
- Si aparece un NC nuevo distinto, se crea un ticket nuevo.

## 3) Definiciones operativas (propuestas)

- Informe inicial: primer informe de una secuencia de seguimiento para un contexto operativo.
- Informe consecutivo: informe posterior de la misma secuencia.
- Hallazgo NC real: entidad única que puede aparecer múltiples veces en informes distintos mientras no se cierre.
- Secuencia de continuidad: cadena de informes que pertenecen al mismo contexto de operación y seguimiento.

## 4) Clave técnica: separar "ocurrencia" de "hallazgo"

Propuesta de modelo:
- Ocurrencia NC: registro de que un NC se observó en un informe específico.
- Hallazgo NC: entidad maestra deduplicada (el problema real).

Relación:
- 1 hallazgo NC <-> N ocurrencias NC

Con esto:
- Los informes siguen guardando su evidencia diaria.
- Los dashboards y tickets consumen Hallazgo NC (deduplicado), no ocurrencias crudas.

## 5) Regla de deduplicación (versión inicial)

Unir ocurrencias al mismo hallazgo si coincide todo lo siguiente:
- Mismo módulo/tipo de actividad (ej. inspección buceo).
- Mismo item/pregunta de formulario (item_id).
- Misma embarcación (v1 para inspección embarcación y buceo).
- Mismo estado de hallazgo (abierto).

Notas:
- La observación de texto puede variar entre días. En v1 no debe romper la continuidad por sí sola.
- La criticidad no rompe continuidad en v1; se registra trazabilidad de quién la asignó.
- Fotos/evidencias nuevas se agregan como nuevas ocurrencias del mismo hallazgo.
- Un nuevo informe inicial por cambio de centro/embarcación no implica automáticamente nuevo hallazgo: eso lo define la regla de dedupe.

## 6) Cambios mínimos de datos (Supabase)

## 6.1 Nueva tabla maestra de hallazgos

Nombre sugerido: nc_hallazgos

Campos sugeridos:
- id (uuid)
- tipo_actividad
- item_id
- embarcacion_id nullable
- criticidad_inicial
- estado_hallazgo (ABIERTO, EN_SEGUIMIENTO, CERRADO)
- fecha_primera_deteccion
- fecha_ultima_deteccion
- informe_inicial_id
- informe_ultima_ocurrencia_id
- creado_por
- created_at
- updated_at

Índice sugerido (v1):
- Índice compuesto para búsqueda rápida por contexto:
  (tipo_actividad, embarcacion_id, item_id, estado_hallazgo)

## 6.2 Tabla puente de ocurrencias

Nombre sugerido: nc_hallazgo_ocurrencias

Campos sugeridos:
- id (uuid)
- hallazgo_id (fk nc_hallazgos.id)
- informe_id (actividad_id actual)
- inspeccion_respuesta_id (id de la respuesta NC actual)
- empresa_id (empresa vigente en el momento de la ocurrencia)
- contratista_id (contratista vigente en el momento de la ocurrencia)
- centro_id nullable
- fecha_ocurrencia
- observacion
- evidencia_foto_count
- creado_por
- created_at

Restricción sugerida:
- unique (inspeccion_respuesta_id) para no asociar dos veces la misma respuesta.

## 6.3 Enlace con tickets

En tabla de tickets (o tabla relación):
- agregar hallazgo_id nullable + unique parcial cuando tipo_ticket = AUTOMATICO_NC y eliminado = false.

Regla:
- un ticket automático activo por hallazgo.
- si el ticket sigue abierto y reaparece el mismo NC, se reutiliza el mismo ticket.
- si el ticket ya está cerrado y reaparece el mismo NC, se crea ticket nuevo.

## 7) Algoritmo de creación/actualización de ticket automático

Entrada: informe finalizado con respuestas NC.

Para cada respuesta NC:
1. Construir clave de continuidad (tipo_actividad, embarcación, item_id).
2. Buscar hallazgo abierto más reciente que cumpla la clave.
3. Si existe:
   - asociar ocurrencia al hallazgo existente.
   - actualizar fecha_ultima_deteccion.
   - buscar ticket del hallazgo:
     - si existe y activo: no crear ticket nuevo.
     - si no existe: crear ticket para ese hallazgo.
4. Si no existe hallazgo:
   - crear hallazgo nuevo.
   - crear ocurrencia inicial.
   - crear ticket nuevo.

Salida esperada:
- Persistencia histórica intacta (todas las ocurrencias).
- Tickets deduplicados por hallazgo.

## 8) Reglas de cierre/reapertura de hallazgo

Propuesta inicial:
- Cierre manual: usuario marca hallazgo como cerrado (con evidencia).
- Cierre automático opcional (fase 2): cerrar cuando X informes consecutivos ya no reportan ese NC.
- Reapertura de hallazgo: se puede reabrir para trazabilidad técnica.
- Ticket asociado a reaparición: si el ticket previo está cerrado, crear ticket nuevo.

Recomendación para v1:
- cierre manual y reapertura del mismo hallazgo para trazabilidad simple.

## 9) Preguntas clave para resolver con jefatura

## 9.1 Sobre inicial/consecutivo
- ¿Existe exactamente 1 informe inicial por turno?
- ¿Puede haber más de un inicial para el mismo contexto y período?
- ¿Qué condición formal convierte un informe en inicial?

## 9.2 Sobre continuidad
- Entre inicial y consecutivos, ¿pueden cambiar empresa, centro o embarcación?
- Si cambia alguno de esos campos, ¿se considera nueva secuencia?
- ¿La continuidad se corta al cambio de prevencionista (contraturno) o debe mantenerse?

## 9.3 Sobre ticket
- Si el hallazgo ya tiene ticket cerrado y reaparece, ¿se reabre ese ticket o se crea uno nuevo?
- ¿El dueño del ticket se mantiene al cambiar de turno o se reasigna?

## 9.4 Sobre criticidad
- Si cambia criticidad del mismo item (ej. Moderado -> Intolerable), ¿es mismo hallazgo o hallazgo nuevo?

## 9.5 Decisiones ya acordadas (usuario)

Estas decisiones ya fueron definidas y no deben re-discutirse en la implementación MVP:

- Continuidad: se busca identificar hallazgos reales (no solo ocurrencias).
- Informe inicial/consecutivo por turno: se asume 1 informe inicial por turno.
- Regla de reinicio en el mismo turno: si cambia centro o embarcación, pasa a ser un nuevo inicial.
- Área: se considera prácticamente estable dentro del turno (probabilidad de cambio cercana a 0), no usar como gatillo principal en v1.
- Distinción por tipo de inspección:
  - INSPECCION_EMBARCACION: la continuidad se evalúa sobre la embarcación.
  - INSPECCION_BUCEO: la continuidad se evalúa sobre el equipo de buceo; para v1 se asume que depende de la embarcación.
- Cambio de empresa contratista para la misma embarcación: no corta continuidad del problema técnico observado por sí solo.
- Criticidad: no usar criticidad para romper continuidad en v1.
- Historial de criticidad: conservar quién asignó criticidad y cuándo, aunque el hallazgo sea el mismo.
- Ticket re-detectado tras cierre: si un ticket ya se cerró y aparece nuevamente la misma observación después, crear ticket nuevo (no reabrir el ticket antiguo).
- Ticket re-detectado mientras sigue abierto: se mantiene el mismo ticket (no crear duplicado).
- Cierre de ticket: criterio operativo del administrador responsable (jefatura).
- Responsable del ticket: uno solo, el usuario que toma el ticket.
- Empresa en inspección: se asume obligatoria en el flujo normal; no diseñar el flujo principal en torno a falta de empresa.
- Estabilidad de reglas: se acepta partir con estas reglas y ajustar en iteraciones si aparece un caso real no cubierto.

## 10) Casos borde y reglas propuestas

Objetivo: definir cómo se comporta continuidad/hallazgo/ticket cuando cambia el contexto operativo.

Caso 1 - Misma embarcación, mismo centro, mismo item NC, días consecutivos
- Decisión sugerida: mismo hallazgo.
- Ticket: se mantiene el ticket existente.

Caso 2 - Misma embarcación se mueve a otro centro, mismo item NC
- Opción A (recomendada v1): mismo hallazgo si embarcación + item coinciden.
- Opción B (más estricta): hallazgo nuevo porque cambió centro.
- Recomendación: usar Opción A para no duplicar tickets por logística de traslado.
- Ticket: mantener ticket y registrar ocurrencia con nuevo centro para trazabilidad.

Caso 3 - Misma embarcación, mismo centro, item distinto NC
- Decisión sugerida: hallazgo nuevo.
- Ticket: ticket nuevo.

Caso 4 - Embarcación distinta, mismo centro, mismo item NC
- Decisión sugerida: hallazgo nuevo.
- Ticket: ticket nuevo (el contexto físico cambió).

Caso 5 - Cambio de prevencionista por contraturno, mismo contexto e item
- Decisión sugerida: mismo hallazgo.
- Ticket: se mantiene el ticket; cambia trazabilidad de autor de ocurrencia.

Caso 6 - Misma clave operativa pero pasa mucho tiempo sin aparecer el NC
- Regla sugerida: usar ventana de continuidad (ej. 30/45/60 días, definir con jefatura).
- Si está fuera de ventana y/o hallazgo cerrado: crear hallazgo nuevo o reabrir según política.

Caso 7 - Mismo item, misma embarcación, cambia criticidad
- Opción A: mismo hallazgo con historial de cambio de criticidad.
- Opción B: hallazgo nuevo por severidad distinta.
- Recomendación v1: Opción A (evita fragmentación), guardando criticidad actual e histórica.

Caso 8 - Se corrige NC y luego reaparece semanas después
- Hallazgo: puede reabrirse el mismo para trazabilidad técnica.
- Ticket: se crea ticket nuevo si el anterior está cerrado.

Caso 9 - Empresa cambia (multiempresa)
- Hallazgo técnico: puede mantenerse si coincide tipo + embarcación + item.
- Ticket: no se hereda entre empresas; queda histórico en la empresa anterior y se gestiona ticket nuevo en la empresa vigente.

Caso 10 - NC igual en texto, pero pertenece a pregunta/item distinto
- Decisión sugerida: hallazgo nuevo (item_id manda sobre texto libre).
- Ticket: ticket nuevo.

Caso 11 - La embarcación cambia de empresa contratista
- Política ajustada para validación con jefatura: la continuidad del problema técnico puede mantenerse aunque cambie la empresa contratista de la embarcación.
- Regla tentativa: mantener mismo hallazgo si coincide contexto técnico (tipo + embarcación + item), pero registrar explícitamente empresa/contratista por cada ocurrencia para trazabilidad temporal.
- Ticket: si el ticket anterior ya está cerrado, crear ticket nuevo cuando reaparezca la observación; si sigue abierto, evaluar continuidad según estado operativo.
- Nota: este caso requiere confirmación final de gobernanza multiempresa antes de producción.

Caso 12 - Embarcación sin contratista vigente (brecha temporal)
- Decisión sugerida: no intentar continuidad automática hasta que exista empresa vigente definida.
- Ticket: no generar ticket automático si la empresa no está resuelta de forma confiable; dejar en cola de validación.
- Recomendación: registrar estado de validación para evitar tickets mal asignados.

Regla de precedencia sugerida para dedupe:
1. Tipo de actividad debe coincidir.
2. item_id debe coincidir.
3. embarcacion_id debe coincidir (v1).
4. Luego aplicar contexto operacional según política acordada:
  - Política Embarcacion-Centrada (recomendada): embarcación manda, centro informativo.
  - Política Centro-Embarcacion Estricta: embarcación + centro deben coincidir.
5. Validar estado (hallazgo abierto/reabrible) y ventana temporal.

Regla multiempresa V1:
- Se permite continuidad técnica del hallazgo aunque cambie contratista/empresa.
- La responsabilidad operativa y el ticket siempre respetan la empresa vigente de la ocurrencia.

## 10.1 Preguntas pendientes mínimas para cierre final

Solo falta una definición formal:
- Matriz de campos duros vs informativos por tipo de inspección.
- Sugerencia base v1:
  - Duros: tipo_actividad, item_id, embarcacion_id.
  - Informativos: centro_id, contratista_id, area_id, criticidad.

## 10.2 Qué está resuelto y qué falta cerrar

Resuelto a nivel funcional (ya definido):
- El objetivo principal es resolver NC como hallazgos generales (no por ocurrencia), y de ahí derivar tickets más limpios.
- La regla de ticket está definida:
  - si reaparece mientras está abierto, se usa el mismo ticket;
  - si reaparece después de cerrado, se crea ticket nuevo.
- Responsable de ticket: único (quien toma).
- Inicial por turno con reinicio a inicial si cambia centro o embarcación.
- En buceo v1, la continuidad depende de embarcación + item NC.
- Cambio de contratista confirmado: no corta continuidad técnica por sí solo.

Pendiente de cierre final con jefatura (antes de migrar a producción):
- Matriz final de campos duros/informativos por tipo de inspección.

Pendiente técnico (después de cerrar negocio):
- Crear tablas de hallazgos y ocurrencias.
- Ajustar generación automática de tickets para que use hallazgo.
- Ajustar dashboard para que la métrica principal de NC consuma hallazgos.

## 11) Riesgos y mitigaciones

Riesgos:
- Dedupe demasiado agresivo (une cosas que no son iguales).
- Dedupe demasiado estricto (sigue duplicando).
- Ruptura de reportes históricos existentes.

Mitigaciones:
- Activar la lógica nueva detrás de feature flag por empresa.
- Ejecutar en paralelo: guardar ocurrencias completas + construir hallazgos.
- Métrica de control: ratio ocurrencias/hallazgos por semana para validar calibración.
- Logging auditable de cada decisión de merge (por qué se unió o por qué se creó nuevo).

## 12) Plan por fases

Fase 0 - Definición funcional (1 reunión)
- Cerrar la matriz de campos duros/informativos definida en sección 10.1.
- Aprobar definición de continuidad y reapertura.

Fase 1 - Base de datos
- Crear tablas nc_hallazgos y nc_hallazgo_ocurrencias.
- Agregar enlace de hallazgo en tickets.
- Índices y restricciones.

Fase 2 - Servicio de deduplicación
- Implementar servicio: dado un NC, resolver hallazgo objetivo.
- Registrar ocurrencia siempre.
- Ajustar creación automática de tickets por hallazgo.

Fase 3 - Reportería y dashboard
- Fuente oficial de KPIs de NC: hallazgos deduplicados.
- Mantener ocurrencias para trazabilidad y detalle diario.
- Importante: la fuente de datos debe pasar por panel de control para consistencia y evitar rescates duplicados.

Fase 4 - Migración histórica (opcional)
- Backfill para agrupar NC históricos en hallazgos.
- Marcar confiabilidad del backfill y tolerar excepciones manuales.

## 13) Criterios de éxito

- Disminuye la duplicación de tickets para el mismo NC.
- Cada hallazgo tiene una trazabilidad clara de ocurrencias por informe.
- Dashboard muestra tanto:
  - hallazgos únicos (visión real de problemas), y
  - ocurrencias (persistencia/recurrencia del problema).
- No se pierde compatibilidad con flujos actuales de inspección.

## 14) Decisión recomendada para partir (MVP)

Para arrancar sin frenar operación:
- Deduplicar por (tipo_actividad, embarcación, item_id, estado_hallazgo_abierto).
- No usar observación textual como llave en v1.
- Mantener continuidad entre turnos mientras coincida la llave de dedupe.
- 1 ticket automático activo por hallazgo.
- Cierre manual de hallazgo en v1.
- Si reaparece con ticket abierto: mantener ticket.
- Si reaparece con ticket cerrado: ticket nuevo.
- Si cambia empresa/contratista: no heredar ticket anterior; registrar nueva responsabilidad en la empresa vigente.

## 15) Verificación de aplicación real (2026-08-03)

Estado verificado en código y migraciones del repo:
- La estrategia de hallazgo único está definida en este documento, pero NO está implementada aún en producción.
- No existen tablas `nc_hallazgos` ni `nc_hallazgo_ocurrencias` en migraciones SQL aplicables.
- No hay enlace operativo `hallazgo_id` en la creación automática de tickets actual.
- El flujo actual de tickets sigue siendo por inspección (`inspeccion_id`) y no por hallazgo deduplicado.

Evidencia guardada en repo (minibase de validación):
- `docs/data/hallazgos_unicos_aquachile_snapshot_2026-08-03.json`

Diseño técnico completo para implementación:
- `docs/IMPLEMENTACION_HALLAZGO_UNICO_NC.md`
- `supabase_migration_nc_hallazgos_unicos_v1.sql`

---

Documento vivo.
Se debe ajustar tras reunión con jefatura y antes de ejecutar migraciones en producción.
