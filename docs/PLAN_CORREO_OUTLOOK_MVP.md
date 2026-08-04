# Plan MVP de Envio de Inspecciones por Correo (Outlook)

Fecha: 2026-06-22
Estado: Aprobado para etapa inicial (sin envio automatico)

## 1) Objetivo

Implementar un flujo donde, al finalizar una inspeccion, la app prepare automaticamente un correo con destinatarios sugeridos, asunto/cuerpo predefinidos con variables y adjunto PDF (o ZIP), pero el envio final siempre lo hace el usuario en Outlook.

## 2) Decisiones cerradas de esta etapa

1. Integracion: redireccion a Outlook (no Graph en esta etapa).
2. Envio: NO automatico. El usuario revisa/edita y presiona enviar.
3. Administracion de bancos de correo y plantillas:
   - Inicialmente desde base de datos (administrado por ti).
   - Evolucion recomendada: interfaz en app para Super Admin.
4. Rol de administracion:
   - Super Admin = usuario con permisos admin y perteneciente a empresa admin.
   - Empresa admin actual esperada: Servimaf (validar nombre exacto en BD).

## 3) Prerrequisitos operativos

1. Usuario con Outlook instalado y configurado en el dispositivo.
2. Cuenta de correo iniciada en Outlook.
3. Si Outlook no esta disponible, mostrar alternativa:
   - Copiar correo preparado (para/cc/asunto/cuerpo) y descargar adjunto para envio manual.

## 4) Flujo funcional MVP

1. Usuario finaliza inspeccion.
2. Modal de confirmacion: "Deseas preparar correo de envio?"
3. Si confirma, abrir vista previa de correo con:
   - Para, CC, CCO sugeridos (editables).
   - Asunto prellenado (editable).
   - Cuerpo prellenado con variables (editable).
   - Adjuntos sugeridos: PDF o ZIP (si aplica).
4. Accion principal: "Abrir en Outlook".
5. Outlook abre redaccion con datos prellenados.
6. Usuario revisa, modifica y envia manualmente.
7. App guarda trazabilidad del proceso (ver seccion 9).

## 5) Definicion formal de campos de plantilla (punto 3)

En este plan, "campos" significa la estructura de datos obligatoria para que una plantilla de correo se pueda usar sin errores.

### 5.1 Esquema minimo obligatorio de plantilla

1. template_id: identificador unico.
2. template_nombre: nombre legible para administracion.
3. asunto_template: texto con placeholders permitidos.
4. cuerpo_template: texto con placeholders permitidos.
5. variables_permitidas: lista cerrada de variables admitidas.
6. estado: activo o inactivo.
7. version: numero de version incremental.
8. updated_at: fecha/hora de ultima actualizacion.
9. updated_by: usuario que hizo el ultimo cambio.

### 5.2 Metadatos recomendados

1. modulo_inspeccion: modulo o tipo de inspeccion objetivo.
2. empresa_id: null para plantilla global o valor para sobreescritura por empresa.
3. idioma: para futuro soporte multilenguaje.
4. prioridad: para desempate cuando aplican varias plantillas.

### 5.3 Variables base estandar

1. empresa_nombre
2. centro_nombre
3. numero_informe
4. fecha_inspeccion
5. inspector_nombre
6. tipo_inspeccion
7. resultado_inspeccion

### 5.4 Validaciones obligatorias antes de usar una plantilla

1. Validar que la plantilla este activa.
2. Validar que asunto_template y cuerpo_template no esten vacios.
3. Validar que todos los placeholders usados existan en variables_permitidas.
4. Validar que todas las variables obligatorias tengan valor al renderizar.
5. Si falta una variable obligatoria, bloquear apertura de Outlook y mostrar detalle.

### 5.5 Politica de fallback de plantilla

1. Buscar plantilla especifica por empresa + modulo.
2. Si no existe, usar plantilla global del modulo.
3. Si no existe plantilla global, bloquear proceso y mostrar error de configuracion.

### 5.6 Reglas de administracion

1. Solo Super Admin puede crear/editar/desactivar plantillas.
2. Toda edicion incrementa version.
3. No se elimina historico: se recomienda desactivar en lugar de borrar.
4. Registrar en auditoria: template_id, version, usuario y timestamp.

## 6) Banco de correos y modelo de base de datos recomendado

Para este MVP, la idea no es crear una tabla generica de "correos" que guarde cada mensaje como si fuera un registro maestro. Eso generaria ruido y complicaria el diseño. En su lugar, lo recomendable es separar tres cosas:

1. La plantilla que define el contenido del correo.
2. Las listas de destinatarios que sugieren a quien enviar.
3. La configuracion que decide, para cada empresa y modulo, que plantilla y que lista usar.

### 6.1 Tabla 1: correo_plantillas
Esta tabla contiene el "correo tipo" o plantilla base.

Campos recomendados:
- id
- nombre: nombre legible para administracion
- asunto_template: texto con placeholders
- cuerpo_template: texto con placeholders
- variables_permitidas: lista cerrada de variables validas
- modulo_inspeccion: modulo o tipo de inspeccion al que aplica
- empresa_id: null si es global; valor si aplica solo a una empresa
- estado: activo/inactivo
- version: numero incremental
- created_at / updated_at
- updated_by

Objetivo:
- Aqui se escribe el asunto y el cuerpo base del correo.
- La app toma esta plantilla, reemplaza variables como empresa, numero de informe, fecha, inspector, etc., y arma el correo final.

### 6.2 Tabla 2: correo_listas
Esta tabla agrupa destinatarios por finalidad.

Campos recomendados:
- id
- nombre_lista
- proposito
- activo

Ejemplo:
- Lista "Clientes Servimaf"
- Lista "Responsables de inspeccion"
- Lista "Copias internas"

### 6.3 Tabla 3: correo_lista_destinatarios
Relaciona una lista con los destinatarios concretos.

Campos recomendados:
- id
- lista_id
- nombre
- correo
- tipo_sugerido: to / cc / cco
- activo

Objetivo:
- Evita repetir manualmente los correos en cada plantilla.
- Si varias plantillas usan la misma lista, se reutiliza.

### 6.4 Tabla 4: correo_configuracion_empresa_modulo
Esta tabla resuelve el problema de empresas y modulos sin dejarlo ambiguo.

Campos recomendados:
- id
- empresa_id
- modulo_inspeccion
- plantilla_id
- lista_id
- prioridad
- activo

Objetivo:
- Decidir que plantilla y que lista usar para una empresa y un modulo especifico.
- Si no existe una configuracion especifica, se puede usar una global o un fallback.

### 6.5 Tabla 5: correo_eventos (trazabilidad)
No es la tabla del correo en si, sino la tabla de auditoria del proceso.

Campos recomendados:
- id
- inspeccion_id
- empresa_id
- usuario_id
- event_type
- event_timestamp
- resultado_evento
- canal
- template_id
- template_version
- asunto_generado
- adjunto_nombre
- adjunto_tipo
- error_code
- error_message

Objetivo:
- Registrar si se preparo el correo, si se abrio en Outlook, si el usuario confirmo el envio, etc.

### 6.6 Por que no necesitamos una tabla general llamada "correos"
Para este MVP, no conviene tener una tabla llamada "correos" porque:
- el correo no es un dato maestro, sino un resultado temporal de una plantilla + datos de inspeccion + destinatarios;
- se duplicaria logica y haria mas dificil mantener consistencia;
- el historial real se resuelve mejor con la tabla de eventos.

En otras palabras:
- la plantilla vive en correo_plantillas;
- los destinatarios viven en correo_listas y correo_lista_destinatarios;
- la decision empresa/modulo vive en correo_configuracion_empresa_modulo;
- la trazabilidad vive en correo_eventos.

### 6.7 Regla de fallback para empresas y modulos
La app debe resolver la plantilla y la lista en este orden:

1. Buscar configuracion exacta para empresa + modulo.
2. Si no existe, buscar una configuracion global del modulo.
3. Si no existe, mostrar error de configuracion y no abrir Outlook.

Esto cubre el problema que comentaste: no se va a depender de un solo modelo rigido ni se va a dejar algo ambiguo.

### 6.8 Apartado para escribir el correo tipo / plantilla inicial
Aqui es donde se define el contenido base del correo que la app usara.

Campo principal a completar:
- asunto_template
- cuerpo_template

Ejemplo inicial para usar como base:

Asunto template:
- Informe {{numero_informe}} - {{tipo_inspeccion}} - {{empresa_nombre}}

Cuerpo template:
- Estimado(a):
- Se adjunta el informe correspondiente a la inspeccion de {{tipo_inspeccion}}.
- Empresa: {{empresa_nombre}}
- Centro: {{centro_nombre}}
- Numero de informe: {{numero_informe}}
- Fecha de inspeccion: {{fecha_inspeccion}}
- Inspector: {{inspector_nombre}}
- Resultado: {{resultado_inspeccion}}
- 
- Saludos,
- {{inspector_nombre}}

Nota importante:
- El campo de observaciones adicionales no debe ir dentro de la plantilla base como una variable fija, sino como un campo editable en la pantalla anterior al envio.
- Ese texto se puede concatenar al cuerpo al momento de abrir Outlook, sin modificar la plantilla maestra.

### 6.9 Recomendacion de implementacion inicial
Para no complicar la primera etapa, se recomienda:
- crear las tablas anteriores con campos basicos;
- cargar una plantilla inicial por defecto;
- dejar la administracion de plantillas para un Super Admin en una etapa posterior si se desea.

### 6.10 Implementacion propuesta para el MVP
Esta etapa debe dejarse lo mas simple posible para evitar sobreingenieria.

#### 6.10.1 Base de datos
Se recomienda implementar migraciones con estas tablas:
- correo_plantillas
- correo_listas
- correo_lista_destinatarios
- correo_configuracion_empresa_modulo
- correo_eventos

Cada tabla debe incluir al menos:
- identificador unico,
- campos de auditoria basicos,
- estado activo/inactivo,
- y los campos necesarios para resolver plantilla, destinatarios y trazabilidad.

#### 6.10.2 Logica de negocio
La app debe resolver el correo en este orden:
1. Obtener datos de la inspeccion finalizada.
2. Identificar empresa y modulo.
3. Buscar configuracion exacta empresa + modulo.
4. Si no existe, usar fallback global o mostrar error.
5. Cargar la plantilla correspondiente.
6. Reemplazar variables con datos reales.
7. Cargar los destinatarios sugeridos desde la lista asociada.
8. Mostrar pantalla editable antes de abrir Outlook.

#### 6.10.3 Flujo de la app
1. Al finalizar una inspeccion, mostrar un modal de confirmacion.
2. Si el usuario acepta, abrir una pantalla de previsualizacion.
3. En esa pantalla mostrar:
   - asunto editable,
   - cuerpo editable,
   - campo de observaciones adicionales,
   - destinatarios sugeridos editables,
   - adjunto sugerido.
4. Al presionar "Abrir en Outlook", la app prepara los datos y redirecciona al usuario.
5. Si Outlook no esta disponible, mostrar alternativa manual.

#### 6.10.4 Adjuntos
Para esta etapa inicial:
- intentar adjuntar el PDF directamente;
- si el PDF pesa demasiado, dejarlo como riesgo a manejar despues;
- no implementar compresion aun salvo que sea necesario por un caso concreto.

#### 6.10.5 Trazabilidad
Cada vez que se prepare un correo, se debe registrar un evento de trazabilidad con:
- inspeccion_id,
- empresa_id,
- usuario_id,
- tipo de evento,
- resultado,
- y datos basicos del adjunto y plantilla usados.

#### 6.10.6 Caso base de prueba del MVP
Antes de implementar el sistema completo, conviene definir un caso concreto de referencia para validar el flujo end-to-end.

#### 6.10.6.1 Caso base propuesto
- Empresa: Servimaf
- Modulo: Hidroser
- Objetivo: preparar un correo de prueba al finalizar una inspeccion o registro del modulo.
- Escenario: enviar un correo con la lista de verificacion de grua horquilla patio fiordo austra.

#### 6.10.6.2 Plantilla inicial de ejemplo
Asunto base:
- Lista de verificacion de grua horquilla patio fiordo austra - {{fecha_inspeccion}}

Cuerpo base:
- Buenos dias / buenas tardes,
- Se adjunta la lista de verificacion correspondiente al registro realizado el dia {{fecha_inspeccion}} a las {{hora_inspeccion}}.
- Realizado por: {{supervisor_nombre}}
- Saludos cordiales,
- {{supervisor_nombre}}

#### 6.10.6.3 Observaciones adicionales
El campo de observaciones adicionales debe aparecer en la pantalla previa al envio, para que el usuario pueda agregar comentarios extras si lo necesita.

Ejemplo de uso:
- "Se adjunta la lista para revision previa."
- "Favor confirmar recepcion."

Este texto se concatenara al cuerpo al momento de preparar el correo, sin modificar la plantilla maestra.

#### 6.10.6.4 Adjunto
Por ahora, el adjunto inicial puede ser el PDF o archivo generado del registro/lista de verificacion.

Importante:
- si el archivo pesa demasiado, se deja como problema a resolver en una segunda etapa;
- no se implementara compresion ni reduccion de peso aun.

#### 6.10.6.5 Destinatarios de prueba
Para el caso inicial, se recomienda usar un correo de prueba real:
- matipro934@gmail.com

Esto permite validar el flujo completo sin depender de un grupo complejo aun.

#### 6.10.6.6 Modelo de asignacion de destinatarios sin ligar a empresa
No se recomienda asociar los correos directamente a empresas. En su lugar, se propone un modelo mas flexible:

- una tabla de usuarios o contactos de envio,
- una tabla de plantillas,
- una tabla de listas de destinatarios,
- y una tabla de asociacion usuario/lista/plantilla.

Esto permite que un usuario o contacto pueda estar asociado a una o varias plantillas y a una o varias listas, sin depender de la empresa.

Propuesta de estructura:
- correo_usuarios: almacena usuarios/contactos que pueden recibir correos.
- correo_plantillas: almacena la plantilla base.
- correo_listas: agrupa destinatarios por finalidad.
- correo_lista_destinatarios: vincula cada lista con usuarios/contactos.
- correo_configuracion: define que plantilla y que lista usar para un caso concreto.
- correo_asignaciones: opcional, permite asociar un usuario/contacto a una plantilla y/o lista de forma explicita.

Este enfoque evita mezclar empresa, modulo y destinatarios en una sola regla.

#### 6.10.6.7 Regla de obtencion del nombre del supervisor
El nombre del supervisor debe obtenerse de la firma o del campo de responsable asociado al registro, si ese dato existe en la informacion del formulario o en la firma del profesional.

Si no existe un nombre claro en el registro, se puede usar un valor fallback como:
- "Supervisor responsable"

Pero idealmente se tomara del nombre del usuario que firma o del responsable del registro.

## 7) Tamano maximo de adjuntos en Outlook (punto 4)

Referencia practica para MVP:
1. Usar umbral de seguridad de 20 MB por correo en app.
2. Si el adjunto supera umbral, comprimir (ZIP) y volver a validar.
3. Si aun supera umbral, advertir al usuario y ofrecer envio manual alternativo (por ejemplo, dividir adjuntos o enlace).

Nota importante:
- El limite real puede variar segun configuracion de Exchange/tenant/politicas corporativas.
- Aunque algunos entornos permiten mas, 20 MB es un valor conservador para evitar rebotes en etapa inicial.
- Dejar este valor configurable en BD o parametros de sistema.

## 8) Regla de adjuntos

1. Si PDF <= umbral: adjuntar PDF directo.
2. Si PDF > umbral: generar ZIP y usar ZIP.
3. Mantener ambos archivos (original y comprimido) para trazabilidad tecnica.

## 9) Definicion formal de trazabilidad (punto 5)

Trazabilidad significa registrar evidencia del proceso de preparacion y envio manual, sin asumir envio automatico por parte de la app.

### 9.1 Evento minimo obligatorio por inspeccion

1. inspeccion_finalizada
2. correo_preparado
3. correo_abierto_en_outlook
4. envio_confirmado_por_usuario
5. envio_cancelado_por_usuario
6. error_preparacion_correo

Nota:
- Los eventos 4 y 5 son mutuamente excluyentes para una misma iteracion de envio.

### 9.2 Campos obligatorios por evento

1. event_id
2. inspeccion_id
3. empresa_id
4. usuario_id
5. event_type
6. event_timestamp
7. resultado_evento (ok, warning, error)
8. canal (outlook_redirect)

### 9.3 Campos recomendados por evento

1. template_id
2. template_version
3. destinatarios_to
4. destinatarios_cc
5. destinatarios_cco
6. asunto_generado
7. variables_faltantes
8. adjunto_nombre
9. adjunto_tipo (pdf o zip)
10. adjunto_tamano_mb
11. error_code
12. error_message

### 9.4 Reglas de calidad de trazabilidad

1. No permitir marcar envio_confirmado_por_usuario si no existe correo_abierto_en_outlook previo.
2. Cada intento de envio genera su propia secuencia de eventos.
3. Registrar timezone junto al timestamp para auditoria consistente.
4. No almacenar contenido sensible del cuerpo completo si no es necesario; priorizar metadatos.

### 9.5 KPI sugeridos para operacion

1. tasa_preparacion = correos_preparados / inspecciones_finalizadas.
2. tasa_apertura_outlook = correo_abierto_en_outlook / correos_preparados.
3. tasa_confirmacion_envio = envio_confirmado_por_usuario / correo_abierto_en_outlook.
4. tasa_error_preparacion = error_preparacion_correo / correos_preparados.

### 9.6 Retencion y soporte

1. Retener eventos por al menos 12 meses.
2. Permitir busqueda por inspeccion_id, numero_informe y rango de fechas.
3. Exponer vista de historial para Super Admin en una etapa posterior.

## 10) Gobernanza y administracion

Etapa 1 (inmediata):
1. Gestion en BD directa por Super Admin (tu administras).

Etapa 2 (recomendada):
1. Crear modulo de administracion en app solo para Super Admin:
   - Listas de correo
   - Destinatarios
   - Plantillas
   - Reglas por empresa/modulo

Beneficio: reduces errores operativos y dependencia de cambios manuales en BD.

## 11) Casos de error y fallback

1. Outlook no instalado:
   - Avisar y habilitar envio manual con datos prellenados en app.
2. No hay destinatarios configurados:
   - Permitir ingreso manual y registrar incidente de configuracion.
3. Faltan variables en plantilla:
   - Mostrar alerta antes de abrir Outlook.
4. Adjunto supera limite tras compresion:
   - Advertir y permitir continuar sin adjunto o dividir envio.

## 12) Roadmap posterior (fuera de esta etapa)

1. Integrar Microsoft Graph para crear borrador real con adjuntos.
2. Abrir borrador en Outlook para edicion final del usuario.
3. Mantener principio: envio final siempre manual por usuario.

## 13) Criterios de aceptacion del MVP

1. Al finalizar inspeccion existe opcion de preparar correo.
2. Se autocompletan destinatarios segun configuracion vigente.
3. Asunto y cuerpo se generan con plantilla y variables.
4. Usuario puede editar todo antes de enviar.
5. Se abre Outlook para redaccion final.
6. El sistema no envia automaticamente.
7. Se registran eventos de trazabilidad clave.

## 14) Checklist operativo previo a implementacion

1. Confirmar nombre exacto de empresa admin en BD (Servimaf u otro literal).
2. Definir valor inicial de umbral adjunto (recomendado 20 MB configurable).
3. Definir plantillas iniciales por modulo.
4. Cargar listas de correo iniciales por empresa.
5. Alinear mensajes UX (confirmaciones, alertas y errores).

---

Documento base para implementacion MVP por redireccion a Outlook.
