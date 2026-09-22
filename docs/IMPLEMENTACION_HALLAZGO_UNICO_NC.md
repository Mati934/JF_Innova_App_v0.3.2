# Implementacion Hallazgo Unico NC (V1)

Fecha: 2026-08-03
Estado: Diseno listo para implementar

## 1. Diagnostico actual

Confirmado en repo y codigo actual:
- La teoria de hallazgo unico NO esta aplicada en flujo productivo.
- Hoy el ticket automatico se genera por `inspeccion_id` (1 ticket por inspeccion), no por hallazgo persistente.
- No existen tablas de hallazgos/ocurrencias en SQL del repo.

Referencia de evidencia:
- `docs/data/hallazgos_unicos_aquachile_snapshot_2026-08-03.json`

## 2. Objetivo funcional

Para cada respuesta NC:
- Resolver si corresponde a un hallazgo activo existente.
- Registrar siempre la ocurrencia de ese dia.
- Reusar ticket activo del hallazgo si existe.
- Crear ticket nuevo solo cuando no exista ticket activo para ese hallazgo.

Regla V1 (acordada):
- Clave dura: `empresa_id + tipo_actividad + item_id + contexto tecnico`.
- Contexto tecnico:
  - Si hay `embarcacion_id`: usar embarcacion.
  - Si NO hay `embarcacion_id`: fallback a `centro_id`.
- No romper continuidad por cambios de observacion textual ni criticidad.

## 3. Modelo de datos propuesto

### 3.1 Tabla `nc_hallazgos`

Representa el hallazgo real deduplicado.

Campos clave:
- `id` uuid pk
- `empresa_id` uuid not null
- `tipo_actividad` text not null
- `item_id` uuid not null
- `dedupe_mode` text not null (`EMBARCACION` | `CENTRO_FALLBACK`)
- `embarcacion_id` uuid null
- `centro_id` uuid null
- `estado_hallazgo` text not null (`ABIERTO` | `EN_SEGUIMIENTO` | `CERRADO`)
- `criticidad_inicial` text null
- `criticidad_actual` text null
- `fecha_primera_deteccion` timestamptz
- `fecha_ultima_deteccion` timestamptz
- `informe_inicial_id` uuid
- `informe_ultima_ocurrencia_id` uuid
- `creado_por` uuid
- `created_at`, `updated_at`

Indices:
- Unico parcial para evitar dos hallazgos activos iguales en misma clave dura.
- Indices de consulta por estado, empresa, item y contexto.

### 3.2 Tabla `nc_hallazgo_ocurrencias`

Representa cada aparicion diaria del NC.

Campos clave:
- `id` uuid pk
- `hallazgo_id` uuid fk -> `nc_hallazgos.id`
- `inspeccion_respuesta_id` uuid unique
- `informe_id` uuid
- `empresa_id` uuid
- `contratista_id` uuid null
- `centro_id` uuid null
- `embarcacion_id` uuid null
- `fecha_ocurrencia` timestamptz
- `observacion` text null
- `criticidad_registrada` text null
- `evidencia_foto_count` int default 0
- `creado_por` uuid
- `created_at`

### 3.3 Tabla `tickets` (extension)

Agregar columnas:
- `hallazgo_id` uuid null
- `hallazgo_ocurrencia_id` uuid null

Indice unico parcial:
- Solo 1 ticket activo por hallazgo (`eliminado=false` y `estado <> 'CERRADO'`).

Esto permite:
- Reusar ticket mientras este abierto.
- Crear ticket nuevo cuando el anterior ya esta cerrado.

## 4. Flujo de negocio (en finalizacion de inspeccion)

Para cada respuesta NC de una inspeccion finalizada:
1. Construir clave de dedupe.
2. Buscar hallazgo activo por clave.
3. Si existe:
- Actualizar `fecha_ultima_deteccion`, `criticidad_actual`, `informe_ultima_ocurrencia_id`.
- Insertar ocurrencia.
4. Si no existe:
- Crear hallazgo.
- Insertar ocurrencia inicial.
5. Ticket:
- Buscar ticket activo por `hallazgo_id`.
- Si existe: NO crear otro.
- Si no existe: crear ticket automatico nuevo, linkeado al hallazgo.

## 5. Integracion en codigo (app)

Punto de integracion recomendado:
- `lib/features/tickets/data/repositories/ticket_repository.dart`

Cambios sugeridos:
- Nuevo metodo de orquestacion, por ejemplo `procesarNcHallazgosDesdeInspeccion(...)`.
- Reemplazar el enfoque actual de "ticket por inspeccion" en generacion automatica por "ticket por hallazgo".
- Mantener compatibilidad temporal con `inspeccion_id` durante migracion.

## 6. KPI y panel de control

Fuente oficial de KPIs (obligatorio):
- Conteos principales desde `nc_hallazgos` (no desde ocurrencias crudas).
- Trazabilidad y detalle desde `nc_hallazgo_ocurrencias`.

Indicadores minimos:
- Hallazgos activos unicos por empresa/tipo.
- Ocurrencias semanales por hallazgo.
- Ratio `ocurrencias / hallazgos` por semana.

## 7. Plan de despliegue seguro

Fase A:
- Ejecutar migracion SQL.
- No activar aun creacion por hallazgo (feature flag off).

Fase B:
- Activar escritura dual (crear ocurrencias/hallazgos + mantener flujo actual).
- Validar no regresion de tickets.

Fase C:
- Encender dedupe real para ticket automatico por hallazgo.
- Dashboard pasa a consumir `nc_hallazgos`.

Fase D:
- Limpieza de logica vieja por inspeccion cuando KPI confirme estabilidad.

## 8. Criterios de aceptacion

- Misma observacion NC en inicial/consecutiva no crea tickets duplicados si el hallazgo sigue abierto.
- Reaparicion tras cierre crea ticket nuevo.
- Observacion textual distinta, pero mismo item/contexto, conserva hallazgo.
- Dashboard reporta hallazgos unicos y ocurrencias por separado.
- No se rompe el flujo offline/online existente.
