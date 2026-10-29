# Borrador: chequeo de transpaleta manual

**Estado:** propuesta para revision de Prevencion de Riesgos.  
**Origen:** bloque de equipo que aparece despues de las paradas de emergencia en la hoja "LISTA CHEQUEO EQUIPOS CRITICOS". El encabezado no identifica el equipo claramente; confirmar que corresponde a una transpaleta manual.

## Campos del checklist

| Campo | Requerido | Tipo/criterio propuesto |
|---|---:|---|
| Empresa | Si | Usar empresa activa, si el motor la completa |
| Fecha y hora de inspeccion | Si | Fecha/hora del informe |
| Area o ubicacion | Si | Texto/seleccion |
| Identificador de transpaleta | Si | Codigo interno o descripcion |
| Operador | Si | Persona que la utilizara |
| Inspector / realizado por | Si | Usuario autenticado |
| Supervisor / aprobado por | No | Nombre y cargo; firma por definir |

La fuente pide observacion, responsable y fecha de cumplimiento por item; confirmar soporte del motor para gestionar acciones a nivel de cada respuesta.

## Respuestas por pregunta

Opciones: **Si / No / No aplica**. "No" requiere observacion y se recomienda foto; "No aplica" requiere motivo. "Si" siempre significa que la condicion esta conforme.

## Preguntas propuestas

| N° | Pregunta | Categoria | Nota |
|---:|---|---|---|
| 1 | ¿La empunadura esta integra, sin fisuras ni bordes danados? | Estructura | Reescrita en positivo: la fuente describe una empunadura con fisuras/bordes romos |
| 2 | ¿El freno de mano funciona correctamente, si este modelo dispone de freno? | Freno | Confirmar si aplica a los modelos utilizados |
| 3 | ¿El conjunto hidraulico esta limpio y lubricado, sin pernos sueltos ni fugas visibles? | Sistema hidraulico | Texto normalizado desde la fuente |
| 4 | ¿Las ruedas delanteras y traseras estan en buen estado, sin roturas y con desgaste uniforme? | Ruedas | Basada en la fuente |
| 5 | ¿La transpaleta opera sin ruidos extranos? | Funcionamiento | Reescrita en positivo |
| 6 | ¿La barra y las horquillas de elevacion estan integras, sin roturas ni deformaciones? | Estructura de carga | Confirmar que "barra de elevacion" identifica el componente esperado |
| 7 | ¿El operador cuenta con capacitacion para utilizar esta transpaleta? | Competencia | Basada en la fuente |

## Reglas y cierre por definir

- Confirmar denominacion, tipo y componentes: transpaleta manual, electrica u otro modelo.
- Confirmar criterios de retiro de servicio ante defectos de freno, sistema hidraulico, ruedas u horquillas.
- La fila siguiente a la pregunta 7 en la fuente repite el numero 7 y evalua PREXOR; se omite aqui porque no es una condicion propia de la transpaleta. Revisar ese control en el checklist generico/de area.
- Definir evidencia, criticidad, responsable y fecha objetivo para cada hallazgo.
