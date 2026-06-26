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

## 6) Banco de correos: diseno recomendado

Para no acoplar todo a empresa de forma rigida, usar estructura flexible:

1. catalogo_destinatarios
   - id, nombre, correo, activo
2. listas_correo
   - id, nombre_lista, proposito, activo
3. lista_destinatario
   - lista_id, destinatario_id, tipo_sugerido (to/cc/cco)
4. empresa_lista_correo
   - empresa_id, lista_id, prioridad
5. plantilla_correo
   - id, nombre, asunto, cuerpo, variables, activo, version

Ventaja: puedes reutilizar listas entre empresas o asignar multiples listas por empresa sin bloquear crecimiento futuro.

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
