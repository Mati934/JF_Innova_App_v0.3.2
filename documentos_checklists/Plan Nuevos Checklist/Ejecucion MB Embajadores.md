# Activar Equipos Criticos e Historial en MB Embajadores

## Preparado

Una tarjeta **Equipos Criticos** en Inicio y tres tarjetas dentro del grupo:

| Checklist | Preguntas | Icono | Prefijo de informe |
|---|---:|---|---|
| Equipo Critico | 7 | precision_manufacturing | MEC |
| Paradas de Emergencia de Cintas | 4 | emergency | MPE |
| Transpaleta Manual | 7 | pallet | MTP |

Las tres abren la pantalla generica existente. Comparten supervisor/correo,
los ocho campos dinamicos de Herramientas y Equipos y dos campos nuevos:
**Equipo inspeccionado (codigo y descripcion)** y **Operador del equipo**.
Los dos nuevos son obligatorios al finalizar; los ocho originales siguen
siendo opcionales para conservar el contrato existente.

El grupo usa `factory` y color azul. El modulo Historial conserva su icono
existente y muestra informes segun los permisos actuales; no otorga acceso
global a informes de otros usuarios o empresas.

## Antes de ejecutar

1. Instalar/usar la app actualizada para contar con los iconos y cambios del motor.
2. Abrir [el SQL de configuracion](../../supabase_seed_checklists_equipos_criticos_mb_v1.sql)
   en Supabase SQL Editor.
3. Ejecutar solo la seccion 0. Debe aparecer exactamente una empresa llamada
   **MB Embajadores** y las tablas/funcion listadas deben existir.
4. Si faltan requisitos, revisar las migraciones del
   [motor](../../supabase_migration_motor_checklists_configurables_v1.sql) y
   [campos dinamicos](../../supabase_migration_checklist_campos_dinamicos_v1.sql).
   No ejecutarlas a ciegas: contienen verificaciones y requieren revisar su
   compatibilidad con el estado real de la base de datos.

## Ejecutar y comprobar

1. Ejecutar el bloque completo `BEGIN` hasta `COMMIT`. No se ejecuta desde la app.
2. Ejecutar la seccion 2: comprobar 3 listas activas con 7/4/7 preguntas y
   10 campos dinamicos; un grupo, 3 hijos y 3 nodos sueltos alternativos
   deshabilitados; `HISTORY` habilitado.
3. Comprobar los permisos: cuatro capacidades por usuario actual vinculado
   a MB Embajadores (por perfil o por `usuario_empresas`). Si la empresa no
   tiene usuarios, no habra permisos individuales todavia.
4. Sincronizar/actualizar datos maestros con conexion y entrar a la empresa
   MB Embajadores. Inicio debe mostrar Equipos Criticos e Historial.
5. Para usuarios agregados despues, volver a ejecutar el SQL o abrir la
   administracion de Checklists de MB Embajadores para completar los permisos,
   como se hace con Herramientas y Equipos.

El SQL es reejecutable sin duplicar entradas, y no reemplaza versiones
publicadas ni vuelve a habilitar nodos que el administrador haya apagado.
Si una version inicial existente es incompatible, aborta para revision.
HISTORY se habilita explicitamente en cada ejecucion.

## Piloto obligatorio antes del uso general

- Inspeccionar un equipo por informe; no agrupar varias maquinas en una sola respuesta.
- Confirmar preguntas y componentes con Prevencion de Riesgos, en particular
  tipo de transpaleta, freno y prueba segura de emergencia.
- Guardar borrador sin conexion, cerrar/reabrir y comparar todos los campos.
- Finalizar con respuestas C / NC / N-A y comprobar que no se permite omitir
  equipo ni operador.
- Agregar foto por pregunta, foto general y firma; verificar el PDF.
- Sincronizar y verificar valores, vinculos de evidencias, firma/PDF e informe
  en el Historial autorizado.
- Simular error/reconexion: un fallo de campo dinamico o foto debe dejar la
  inspeccion pendiente y un reintento no debe duplicar respuestas/evidencias.

No se implementa responsable/fecha de cumplimiento por hallazgo en esta
configuracion: no existen esos campos en el modelo actual de respuestas.
Tampoco se garantiza escalabilidad de produccion sin mediciones de volumen
y tiempos ni se confirma que las migraciones ya esten aplicadas.

## Validacion realizada en desarrollo

- 35 pruebas focalizadas aprobadas: catalogo/permisos, menu, campos obligatorios,
  iconos, vinculos de fotos y contrato de las preguntas del SQL.
- Analisis de Dart sin problemas en las superficies modificadas.
- SQL ejecutado con PostgreSQL compatible local (PGlite) y datos ficticios:
  primera ejecucion, reejecucion sin duplicados, preservacion del estado del
  administrador y rechazo de empresa ausente/ambigua o campo comun inactivo.
- Se conserva una proyeccion legible de los campos en `campos_extra` para que
  el Historial existente lea obra/faena; los valores tipados siguen guardandose
  en `checklist_campo_valores`.
- No se ejecutaron migraciones ni pruebas contra Supabase de produccion.
