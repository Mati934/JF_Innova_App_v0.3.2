# Plan de nuevos checklists

**Estado:** grupo aprobado; configuracion inicial preparada para MB Embajadores, pendiente de ejecutar SQL y validar piloto.  
**Alcance:** solo listas de inspeccion de equipos de la planilla de equipos criticos.  
**Separacion:** este plan es independiente de `Por Hacer` y `Hechos`; no reemplaza esos documentos ni cambia checklists existentes.

## Implementacion preparada

- Grupo: **Equipos Criticos**; icono `factory`.
- Tres entradas del mismo motor: equipo critico (`precision_manufacturing`), paradas de emergencia (`emergency`) y transpaleta (`pallet`).
- SQL: [supabase_seed_checklists_equipos_criticos_mb_v1.sql](../../supabase_seed_checklists_equipos_criticos_mb_v1.sql).
- Empresa inicial: **MB Embajadores**. El script exige una unica coincidencia de nombre, sin distinguir mayusculas.
- Incluye habilitacion del modulo **Historial** (`HISTORY`) solo para esa empresa.
- Los tres usan los ocho campos dinamicos comunes existentes, supervisor/correo fijos y dos campos adicionales: identificacion del equipo y operador. Estos dos ultimos son obligatorios al finalizar.
- Las preguntas iniciales son 7 / 4 / 7. Mantener su validacion operativa con Prevencion de Riesgos antes del uso general.
- Se corrigio que un fallo de subida de campos dinamicos dejara la inspeccion marcada como sincronizada. Tambien se agrego la subida de fotos generales/por pregunta con su vinculacion a respuestas.
- La persistencia completa contra Supabase, sus permisos y Storage requiere el piloto; no se ha ejecutado el SQL desde esta tarea.

## Recomendacion ejecutiva

Preparar **3 checklists de inspeccion**:

1. **Chequeo de equipo critico (generico):** controles generales aplicables a una maquina/equipo identificado.
2. **Chequeo de paradas de emergencia de cintas:** prueba y estado de los dispositivos de emergencia de una cinta transportadora.
3. **Chequeo de transpaleta manual:** estado mecanico y condiciones de uso de la transpaleta.

La planilla trae esos tres bloques de inspeccion diferenciables. La rotacion de puestos no es un checklist de inspeccion y queda fuera de este plan. La hoja COVID-19 tampoco se incorpora: requiere confirmar vigencia y tratamiento autorizado de datos de salud.

## Grupo de navegacion recomendado

Se recomienda proponer un grupo nuevo llamado **Equipos Criticos**, con los tres checklists anteriores. El grupo actual **Herramientas y Equipos** contiene listas de herramientas de uso mas acotado (por ejemplo, soldadora, esmeril y extension); separar maquinas, cintas y transpaletas evita mezclar flujos y facilita encontrar las listas. No es una necesidad tecnica del motor: se puede configurar un grupo o varios nodos sin cambiar el esquema de respuestas.

Antes de crearlo, confirmar que los usuarios esperan encontrar estas inspecciones separadas de las herramientas. No crear mas grupos por ahora.

## Campos a reutilizar

Los tres formularios deben mantener **el mismo encabezado comun** para que los informes sean consistentes. Ademas, cada uno tendra un campo propio para identificar el equipo inspeccionado.

| Campo comun | Como existe hoy en el motor | Propuesta |
|---|---|---|
| Fecha/hora y empresa | Datos propios de la inspeccion/sesion | Reutilizar; no duplicar como campo libre |
| Supervisor a cargo | Campo fijo del formulario, guardado como `quien_inspecciona` | Mantener, pero confirmar que el dato realmente representa al supervisor y no al inspector |
| Correo de supervisor | Campo fijo `supervisor_correo` | Mantener si se usa para notificaciones o envio |
| Obra o faena | Campo dinamico `obra_faena` | Compartir en los tres |
| Region | Campo dinamico `region` | Compartir en los tres |
| Area especifica | Campo dinamico `area_especifica` | Compartir en los tres |
| Jefatura a cargo | Campo dinamico `jefatura_a_cargo` | Compartir en los tres |
| Hora de inicio y termino | Campos dinamicos `hora_inicio` y `hora_termino` | Compartir solo si se registra el periodo de trabajo; confirmar utilidad para inspecciones puntuales |
| Correo empresa 1 y 2 | Campos dinamicos `correo_empresa_1` y `correo_empresa_2` | Compartir si siguen siendo destinatarios del informe |
| Equipo inspeccionado | No forma parte del encabezado comun actual | Agregar campo especifico por checklist: equipo/maquina, cinta o transpaleta; idealmente codigo interno + descripcion |

Los ocho campos dinamicos se encuentran en el catalogo del motor y fueron asignados a los cinco checklists existentes de herramientas. Se pueden asignar a los tres nuevos sin crear una tabla por checklist. **Hoy estan configurados como no requeridos** en esa migracion; cambiar la obligatoriedad requiere acordar reglas y publicar versiones nuevas. Los campos fijos de supervisor y correo tampoco deben considerarse obligatorios sin validar las reglas actuales del formulario.

No agregar como campos generales "responsable del hallazgo" y "fecha de cumplimiento": pertenecen a cada respuesta negativa, no al encabezado de toda la inspeccion.

## Contenido inicial

Usar en cada pregunta las respuestas **Si / No / No aplica**, expresadas en el PDF como cumple / no cumple / no aplica. Recomendar observacion para "No" y motivo para "No aplica"; acordar criticidad y evidencia con Prevencion de Riesgos.

### 1. Equipo critico generico

Partir de las siete preguntas del borrador existente: senalizacion, funcionamiento, paradas/sensores cuando aplican, protecciones contra atrapamiento, conexiones electricas, capacitacion/EPP y proteccion auditiva PREXOR. Antes de publicarlo, decidir si PREXOR corresponde a un control de area aparte para evitar repetirlo por cada equipo; definir que maquinas califican como criticas.

### 2. Paradas de emergencia de cintas

Partir de las cuatro preguntas del borrador existente: detencion al accionar, estado fisico, estado del cableado y accesibilidad/ubicacion. Prevencion de Riesgos debe aprobar el procedimiento seguro de prueba y los criterios para retirar una cinta de servicio.

### 3. Transpaleta manual

Partir de las siete preguntas del borrador existente: empunadura, freno cuando corresponda, sistema hidraulico, ruedas, ruidos, barra/horquillas de elevacion y capacitacion del operador. Confirmar primero si el equipo es manual o electrico y corregir los componentes/terminos segun los modelos reales.

Los textos detallados y sus observaciones estan en los borradores de `Por Hacer`; esta carpeta contiene el plan de organizacion, campos, riesgos tecnicos y secuencia de trabajo, no una segunda copia de las preguntas.

## Persistencia y escalabilidad: estado real

### Lo que el codigo/schema indican

- El borrador se guarda primero en SQLite local, dentro de una transaccion que guarda inspeccion, respuestas y valores de campos dinamicos. Esto permite conservarlo en el dispositivo antes de sincronizar.
- La sincronizacion usa tablas relacionales de Supabase para inspecciones, respuestas, evidencias y valores de campos; tambien hay indices por empresa/estado, checklist/fecha e inspeccion.
- Las versiones publicadas guardan una copia (snapshot) de preguntas y campos. Esto permite que informes historicos mantengan la definicion con que fueron contestados.
- Agregar tres definiciones de checklist y preguntas no requiere crear una tabla nueva por formulario. Para tres checklists, el diseno existente parece adecuado; la carga futura dependera mas del volumen de inspecciones, consultas y fotos/PDF que del numero de formularios.

### Lo que no se debe dar por garantizado

- Leer el codigo no comprueba que las migraciones esten aplicadas correctamente en cada ambiente, que Storage/RLS esten configurados, ni que una inspeccion especifica haya llegado y pueda recuperarse desde produccion.
- El flujo actualizado propaga un fallo de subida de campos dinamicos al manejador de error de la inspeccion y la mantiene pendiente. Verificar el reintento real con Supabase en el piloto.
- `checklist_respuestas` guarda estado, observacion y criticidad, pero no responsable ni fecha de cumplimiento por pregunta. Si esos datos son requeridos, hay que ampliar el modelo y sincronizacion o enlazar el hallazgo con un flujo de seguimiento; no prometerlos en el primer lanzamiento.
- Las fotos y PDFs dependen de la subida a Storage y de su seguimiento de pendientes; deben probarse por separado, especialmente con mala conectividad.
- No se puede afirmar que no haya problemas de escalabilidad sin medir volumen, tamanos de archivos, politicas de retencion y tiempos de las consultas de historial. No se aprecia que tres formularios por si solos exijan redisenar la base de datos.

## Secuencia propuesta

1. **Acordar alcance:** validar que son tres listas; confirmar grupo `Equipos Criticos`, poblacion usuaria y equipos incluidos.
2. **Aprobar encabezado comun:** decidir si supervisor significa inspector o supervisor; definir obligatoriedad de correo, obra/faena, region, area, jefatura y horas. Mantener un identificador especifico del equipo en cada lista.
3. **Cerrar preguntas y reglas:** Prevencion de Riesgos aprueba redaccion, respuesta N/A, criticidad, fotos, observaciones y criterios de bloqueo/retiro de servicio.
4. **Resolver seguimiento por hallazgo:** decidir si se necesita responsable/fecha de cumplimiento en cada respuesta y disenar ese dato antes de publicar.
5. **Cerrar el riesgo de sincronizacion:** cambiar el flujo para que un error al subir un valor dinamico mantenga la inspeccion pendiente de sincronizacion; cubrir reintentos e idempotencia con pruebas.
6. **Configurar y validar:** crear las definiciones/versiones de los tres checklists, asignar los campos comunes acordados y ubicar los nodos en el grupo decidido. No duplicar campos ni migraciones de datos por checklist.
7. **Piloto acotado:** probar borrador offline, cierre, fotos, firma, PDF, sincronizacion, reintento y lectura del historial en una empresa y dispositivos representativos.
8. **Publicar gradualmente:** habilitar el grupo/listas a usuarios definidos, revisar pendientes/errores de sincronizacion y acordar revision periodica de preguntas.

## Criterios minimos para dar por listo

- Encabezado comun identico en los tres formularios, con las diferencias marcadas como especificas y justificadas.
- Pruebas que demuestren persistencia offline y sincronizacion completa de cabecera, respuestas, campos dinamicos, fotos, firma y PDF; un fallo debe quedar visible y reintentable.
- Verificacion del informe PDF y de la consulta en historial con las preguntas/campos de la version contestada.
- Confirmacion de que un valor dinamico fallido no deja la inspeccion falsamente marcada como sincronizada.
- Si se aprueba el seguimiento por hallazgo, prueba de que cada respuesta "No" conserva su responsable, plazo y estado sin sobrescribir otros hallazgos.
