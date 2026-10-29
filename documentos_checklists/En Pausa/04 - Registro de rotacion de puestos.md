# Borrador: registro de rotacion de puestos

**Estado:** candidato a formulario operativo; no es un checklist de inspeccion de equipo.  
**Origen:** hoja "LISTA ROTACION PUESTO" y su hoja "Control de Revisiones Rotacion".

## Campos que muestra la fuente

| Campo | Requerido propuesto | Nota |
|---|---:|---|
| Fecha | Si | Fecha del programa/registro |
| Semana o periodo | Si | La fuente incluye "H-ON"; confirmar significado y dato esperado |
| Area | Si | Elegir una de las areas listadas |
| Puesto | Si | Catalogo editable de puestos |
| Jornada 1: nombres | Si | Una o mas personas asignadas |
| Jornada 2: nombres | Si | Una o mas personas asignadas |
| Responsable de la planilla | Si | Nombre y firma |
| Supervisor | Si | Nombre y firma |

## Areas y puestos transcritos

- **Volteo Bins:** Volteo Bins; Alimentacion Linea; Repaso; Alimentacion linea; Empacado; Preparacion Caja; Incorporacion hielo; Enhuinchado caja; Embolsado; Enhuinchado caja embolsada; Armado Cajas.
- **Eviscerado:** Volteador bins; Alimentacion Baader 142; Repaso; Eviscerado; Corte Rinon; Repaso Cuchara; Alimentacion Cuello Cisne.
- **Filete:** Alimentacion Baader 434; Alimentacion Baader 200/581; Linea de Recorte Punteo; Linea de Recorte lomo; Linea de Recorte Whizard; Corte Velis; Clasificado; Recuperado; Alimentacion Tunel.
- **Empaque:** Recepcion tunel; Empacado; Enhuinchado; Enzunchado; Empacador.
- **Matanza:** Operacion Stunner; Repaso Operacion Stunner; Alimentacion Cinta; Alimentacion Repaso Stunner; Alimentacion Bins de Cosecha.

La planilla fuente tiene nombres y posibles inconsistencias de escritura repetidos; normalizar nombres de areas/puestos con el usuario antes de crear un catalogo.

## Por que separar este registro

No contiene preguntas de cumplimiento con respuestas Si/No/No aplica. Su estructura es una asignacion de personal por puesto y jornada, con responsables y firmas. Reutilizar el motor de checklist lo forzaria a representar una matriz de asignaciones como preguntas; se recomienda definirlo como formulario/registro aparte y decidir si necesita un grupo o flujo propio.

## Pendientes de validacion

- Aclarar que significa "H-ON" y como se identifica el periodo de rotacion.
- Confirmar si las jornadas son exactamente dos y si una persona puede ocupar varios puestos.
- Definir si se requiere guardar cambios de asignacion y trazabilidad de versiones.
- Confirmar catalogo y escritura oficial de areas y puestos.
