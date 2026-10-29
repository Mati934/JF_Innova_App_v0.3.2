# Catalogo preliminar de checklists por hacer

**Estado:** propuesta para revision; todavia no implementar ni publicar.  
**Fuente revisada:** `LISTA_CHEQUEO_EQUIPOS_CRITICOS_Y_ROTACION_PUESTO.xlsx`, hoja "LISTA CHEQUEO EQUIPOS CRITICOS", "LISTA ROTACION PUESTO", "Control de Revisiones Rotacion" y "COVID-19".

## Propuesta de clasificacion

| Borrador | Que cubre | Propuesta de ubicacion |
|---|---|---|
| [Equipo critico (generico)](<01 - Equipo critico generico.md>) | Controles comunes a una maquina o equipo identificado en cada inspeccion | Motor configurable; candidato a hijo de "Herramientas y Equipos" |
| [Paradas de emergencia de cintas](<02 - Paradas de emergencia de cintas.md>) | Prueba y estado de las paradas de emergencia de cintas transportadoras | Motor configurable; mismo grupo, sujeto a validar si se usa de forma independiente |
| [Transpaleta manual](<03 - Transpaleta manual.md>) | Estado mecanico y uso seguro del transpaletero | Motor configurable; mismo grupo |
| [Rotacion de puestos](<04 - Registro de rotacion de puestos.md>) | Asignacion de personas a puestos por jornada | Registro operativo, no checklist de inspeccion; evaluar otro formulario/modulo |

La hoja "COVID-19" se registra en **Pendientes de validacion**, no como checklist listo: contiene sintomas y temperaturas asociadas a personas, y no incluye un catalogo de preguntas completo en la planilla. Antes de reutilizarla hay que confirmar que siga vigente y revisar su tratamiento de datos de salud.

## Encaje con el motor existente

La app ya tiene un motor de checklists configurables y el grupo "Herramientas y Equipos". Por eso, la recomendacion inicial es reutilizar el motor y **no crear un grupo nuevo todavia**. Los tres borradores de inspeccion pueden partir bajo ese grupo; la rotacion de puestos no deberia mezclarse con herramientas porque registra dotacion/jornadas, no condiciones de seguridad de un equipo.

El motor representa preguntas por checklist y admite campos dinamicos de encabezado. Cada checklist de inspeccion se plantea con respuesta **Si / No / No aplica**, observacion, criticidad y evidencia. La planilla tambien pide responsable y fecha de cumplimiento por cada hallazgo: confirmar si el motor puede guardar esos datos por respuesta; no convertirlos en campos generales de encabezado porque se pueden necesitar varias acciones en una misma inspeccion.

## Criterios comunes propuestos

- **Si:** el control cumple lo descrito.
- **No:** el control no cumple; requiere observacion y se recomienda evidencia fotografica.
- **No aplica:** permitir solo explicando el motivo.
- Toda respuesta debe quedar contestada antes de cerrar el checklist.
- Una respuesta "No" debe permitir marcar criticidad y registrar seguimiento/correccion.
- Reutilizar empresa, fecha/hora, autor y firma del motor si ya los proporciona; evitar pedirlos dos veces.
- Validar con Prevencion de Riesgos la criticidad, obligatoriedad de fotos, firmas y responsables antes de publicar.

## Pendientes de validacion

1. Confirmar que los tres checklists de inspeccion pertenecen al grupo existente "Herramientas y Equipos".
2. Definir si "Proteccion auditiva (PREXOR)" se mantiene como control del checklist generico o se gestiona en un control de area separado; no duplicarlo en cada equipo.
3. Confirmar soporte para asignar responsable y fecha de cumplimiento a cada respuesta "No".
4. Revisar el texto corregido de los controles de transpaleta, ya que en la fuente algunos items estan redactados como defecto en lugar de condicion conforme.
5. Confirmar vigencia y tratamiento autorizado de la hoja COVID-19 antes de rescatarla.
