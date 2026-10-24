# Borrador: chequeo de equipo critico (generico)

**Estado:** propuesta para revision de Prevencion de Riesgos.  
**Origen:** hoja "LISTA CHEQUEO EQUIPOS CRITICOS" del libro fuente.  
**Uso propuesto:** una inspeccion por maquina/equipo identificado. La planilla repite este bloque para varios equipos; no define tipos concretos.

## Campos del checklist

| Campo | Requerido | Tipo/criterio propuesto |
|---|---:|---|
| Empresa | Si | Usar la empresa activa de la sesion, si el motor la completa |
| Fecha y hora de inspeccion | Si | Fecha/hora de creacion del informe |
| Maquina/equipo inspeccionado | Si | Texto o seleccion de equipo |
| Area o ubicacion | Si | Texto/seleccion; validar catalogo disponible |
| Operador | Si | Persona que opera o tiene asignado el equipo |
| Inspector / realizado por | Si | Usuario autenticado; nombre y cargo en el informe |
| Supervisor / aprobado por | No | Nombre y cargo; firma solo si el flujo requiere aprobacion |
| Codigo, patente o identificador interno del equipo | No | Texto |

La planilla fuente solicita observacion, responsable y fecha de cumplimiento **por cada item**. Confirmar el soporte del motor para responsable y fecha por hallazgo antes de dar esos dos datos por incluidos.

## Respuestas por pregunta

Opciones: **Si / No / No aplica**. "No" requiere observacion y se recomienda foto; "No aplica" requiere motivo. Criticidad por respuesta "No", conforme a la matriz aprobada por Prevencion de Riesgos.

## Preguntas propuestas

| N° | Pregunta | Categoria | Nota |
|---:|---|---|---|
| 1 | ¿La maquina o equipo cuenta con señalizacion de seguridad visible y legible? | Senalizacion | Basada en la fuente |
| 2 | ¿Se comprobo que la maquina o equipo funciona correctamente? | Funcionamiento | Definir prueba segura aplicable por equipo |
| 3 | ¿Las paradas de emergencia y los sensores, cuando corresponden, funcionan correctamente? | Controles de seguridad | No reemplaza el checklist especifico de cintas |
| 4 | ¿Las partes moviles y accesorios tienen protecciones que evitan el atrapamiento? | Guardas y atrapamiento | Basada en la fuente |
| 5 | ¿Las conexiones electricas estan en buen estado y sin conductores expuestos? | Electricidad | Basada en la fuente |
| 6 | ¿El personal esta capacitado y cuenta con el equipo de proteccion personal requerido? | Personal y EPP | Confirmar si se evalua al operador o al personal del area |
| 7 | ¿Las personas del area utilizan correctamente la proteccion auditiva exigida por PREXOR? | Salud ocupacional | En la fuente aparece como control de area; validar si corresponde aqui o en un control separado |

## Reglas y cierre por definir

- Definir que equipos califican como "criticos" y quien mantiene ese catalogo.
- Definir quien puede inspeccionar y quien aprueba/cierra acciones correctivas.
- Acordar si una respuesta "No" en preguntas 2, 3, 4 o 5 bloquea el uso del equipo o solo genera hallazgo.
- Validar si las preguntas 3 y 7 aplican a todos los equipos; permitir "No aplica" con justificacion.
