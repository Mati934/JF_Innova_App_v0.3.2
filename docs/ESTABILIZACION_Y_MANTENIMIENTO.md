# Estrategia de estabilizacion y mantenimiento

Este documento fija el criterio para dejar la app lista y evitar que aparezcan cambios innecesarios a partir de ahora.

## Objetivo

Mantener la aplicacion en modo estable, con foco en:

- corregir errores reales;
- cerrar pendiente tecnico para iPhone;
- evitar nuevas funcionalidades sin justificacion operativa;
- reducir el costo de mantenimiento.

## Regla de trabajo desde ahora

1. No agregar features nuevas salvo que resuelvan un problema real de operacion.
2. No tocar flujos estables por refactor estetico o limpieza no urgente.
3. Cualquier cambio debe venir con validacion concreta.
4. Toda dependencia nueva debe justificarse antes de agregarse.
5. Toda capacidad nueva debe nacer con su permiso, clave persistente y criterio de administracion.

## Prioridades permitidas

Solo se aceptan cambios en estas categorias:

- bugfixes de produccion;
- compatibilidad iPhone;
- ajustes de seguridad;
- sincronizacion y estabilidad offline/online;
- correcciones de datos o migraciones necesarias;
- mejoras que reduzcan soporte en terreno.

## Prioridades que se congelan

- nuevas pantallas no solicitadas;
- cambios de diseño no funcionales;
- refactors grandes sin beneficio directo;
- reescrituras de modulos que ya funcionan;
- cambios de infraestructura que no impacten una necesidad concreta.

## Flujo de versionado

1. Hacer cambios pequenos y trazables.
2. Validar el impacto localmente antes de subir.
3. Crear commit con mensaje descriptivo.
4. Publicar solo cuando el cambio aporte estabilidad real.
5. En iPhone, compilar en Mac y probar en dispositivo fisico antes de liberar.

## Criterio para publicar una nueva version

Publicar solo si se cumple al menos una de estas condiciones:

- corrige un error que bloquea operacion;
- mejora la firma, seguridad o estabilidad;
- resuelve un problema de compatibilidad iOS;
- cierra una deuda tecnica necesaria para seguir trabajando.

## Criterio para no tocar el repo

Si el cambio no reduce riesgo, no arregla un error ni habilita iPhone, se deja para despues.

## Nota operativa

Windows queda como puesto principal de desarrollo.
El Mac solo se usa para firma, compilacion iOS y validacion final.