-- =============================================================================
-- MODULO INSPECCION SEAROV: EMPRESA, COLUMNAS Y PREGUNTAS  ·  2026-10-29
-- Searov SpA tiene su propio modulo INSPECCION_SEAROV (tarjeta "Nueva
-- Inspeccion" en Inicio): mismo flujo que Inspeccion, con sus preguntas y su
-- PDF. El modulo marca cada actividad con actividades.formato_informe =
-- 'SEAROV'; el usuario no lo ve. Las actividades siguen siendo
-- INSPECCION_BUCEO / INSPECCION_EMBARCACION (numeracion por empresa, Historial).
-- Las preguntas van en formulario_items con tipo_actividad
-- INSPECCION_BUCEO_SEAROV / INSPECCION_EMBARCACION_SEAROV (solo banco).
-- Columnas nuevas (todas opcionales; las apps actuales no las usan):
--   actividades.formato_informe            NULL = estandar; 'SEAROV'.
--   formulario_items.potencialidad         ALTA / MEDIA, separada de la criticidad.
--   formulario_items.aplica_por_buzo       la pregunta se responde por buzo.
--   actividad_participantes.respuestas_personal  {item_id: 'C'|'NC'|'N/A'}.
-- Fuentes: documentos_checklists/Por Hacer/ (PDF de Searov y xlsx de barcos).
-- Ejecutar MANUALMENTE, antes de que un usuario de Searov use la app nueva.
-- No afecta a los modulos existentes: ninguna app actual lee estas columnas
-- ni los tipos *_SEAROV.
-- Reejecutable: si (IF NOT EXISTS, ON CONFLICT, NOT EXISTS).
-- Pasos: 0 (solo lectura) -> 1 (BEGIN..COMMIT) -> 2 (verificar).
-- =============================================================================

-- 0. SOLO LECTURA ----------------------------------------------------------------

-- 0.1 Searov no existe (esperado: 0 filas la primera vez).
SELECT id, nombre FROM public.empresas WHERE nombre ILIKE 'searov%';

-- 0.2 Columnas nuevas aun no existen (esperado: 0 filas la primera vez).
SELECT table_name, column_name FROM information_schema.columns
WHERE table_schema = 'public'
  AND (table_name, column_name) IN (('actividades', 'formato_informe'),
                                    ('formulario_items', 'potencialidad'),
                                    ('formulario_items', 'aplica_por_buzo'),
                                    ('actividad_participantes', 'respuestas_personal'));

-- 0.3 Sin preguntas Searov (esperado: 0).
SELECT COUNT(*) FROM public.formulario_items WHERE tipo_actividad LIKE '%_SEAROV';


-- 1. CAMBIO ----------------------------------------------------------------------
BEGIN;

-- 1.1 Columnas
ALTER TABLE public.actividades ADD COLUMN IF NOT EXISTS formato_informe text;
ALTER TABLE public.actividades DROP CONSTRAINT IF EXISTS actividades_formato_informe_check;
ALTER TABLE public.actividades
  ADD CONSTRAINT actividades_formato_informe_check
  CHECK (formato_informe IS NULL OR formato_informe IN ('ESTANDAR', 'SEAROV'));

ALTER TABLE public.formulario_items ADD COLUMN IF NOT EXISTS potencialidad text;
ALTER TABLE public.formulario_items DROP CONSTRAINT IF EXISTS formulario_items_potencialidad_check;
ALTER TABLE public.formulario_items
  ADD CONSTRAINT formulario_items_potencialidad_check
  CHECK (potencialidad IS NULL OR potencialidad IN ('ALTA', 'MEDIA'));
ALTER TABLE public.formulario_items
  ADD COLUMN IF NOT EXISTS aplica_por_buzo boolean NOT NULL DEFAULT false;

ALTER TABLE public.actividad_participantes
  ADD COLUMN IF NOT EXISTS respuestas_personal jsonb;

-- 1.2 Empresa (sin RUT ni logo: el PDF muestra el nombre).
INSERT INTO public.empresas (nombre)
VALUES ('Searov SpA')
ON CONFLICT (nombre) DO NOTHING;

-- 1.3 Modulos: Inspeccion Searov e Historial.
INSERT INTO public.empresa_modulos (empresa_id, modulo_key, habilitado, orden)
SELECT e.id, m.modulo_key, true, m.orden
FROM public.empresas e
CROSS JOIN (VALUES ('INSPECCION_SEAROV', 0), ('HISTORY', 5)) AS m(modulo_key, orden)
WHERE e.nombre = 'Searov SpA'
ON CONFLICT (empresa_id, modulo_key) DO UPDATE SET habilitado = true;

-- 1.4 Preguntas (68 de buceo, 75 de embarcacion). Criticidad por defecto
--     Tolerable: el inspector la ajusta en cada No cumple, como hoy.
INSERT INTO public.formulario_items
  (tipo_actividad, categoria, pregunta, orden, potencialidad, aplica_por_buzo, info_adicional,
   criticidad, activo, peso)
SELECT v.tipo_actividad, v.categoria, v.pregunta, v.orden, v.potencialidad, v.aplica_por_buzo,
       v.info_adicional, 'Tolerable'::public.nivel_criticidad, true, 1.0
FROM (VALUES
  ('INSPECCION_BUCEO_SEAROV', 'Personal (por buzo)', 'Traje de buceo en buen estado', 1, NULL, true, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Personal (por buzo)', 'Botines de buceo', 2, NULL, true, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Personal (por buzo)', 'Slip de buceo (opcional)', 3, NULL, true, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Personal (por buzo)', 'Polera de buceo (opcional)', 4, NULL, true, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Personal (por buzo)', 'Calcetas de buceo (opcional)', 5, NULL, true, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Personal (por buzo)', 'Guantes de protección', 6, NULL, true, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Personal (por buzo)', 'Cuchillo de buceo, sin punta, con amarre y funda', 7, NULL, true, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Personal (por buzo)', 'Computador de buceo o profundímetro digital operativo', 8, NULL, true, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Personal (por buzo)', 'Regulador de buceo con chicote (buen estado)', 9, NULL, true, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Personal (por buzo)', 'Arnés', 10, NULL, true, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Personal (por buzo)', 'Caperuza', 11, NULL, true, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Compresor de buceo profesional de baja presión, con entrega de volumen y presión mínima de 350 lt/min y 13 bar respectivamente, considerando la operación de dos buzos, hasta una profundidad máxima de 36 metros', 12, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Compresor cuenta con sistemas de filtros de purificación de aire', 13, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Banco auxiliar (botellas cargadas a alta presión) volumen mínimo de 48 lt y 204 bar', 14, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Panel de control de superficie (consola)', 15, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Máscara facial con comunicaciones', 16, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Umbilical', 17, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Nivel de aceite motor y cabezal', 18, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Manómetro operativo (números legibles, buen estado esfera de vidrio, aguja funciona)', 19, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Válvula de seguridad y válvula de corte rápido operativos', 20, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Partes móviles del compresor protegidas', 21, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Válvula de retención operativa', 22, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Arnés de levante con hebilla de escape rápido', 23, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Mosquetón de acero inoxidable', 24, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Cinturón de lastre con escape rápido', 25, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Buen estado llave de espiche acumulador', 26, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Aletas de propulsión', 27, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Manillas adecuadas para transporte', 28, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Ruedas en buen estado', 29, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de 36 metros', 'Bandera Alfa', 30, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Compresor de buceo profesional de baja presión, con entrega de volumen y presión mínima de 115 lt/min y 8 bar respectivamente, considerando la operación de 1 solo buzo, hasta una profundidad máxima de 20 metros', 31, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Compresor cuenta con sistemas de filtros de purificación de aire', 32, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Buen estado de correa de transmisión', 33, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Snorkel aspirador de aire alejado de humos de escape del motor, con filtro para impedir el ingreso de partículas y orientado a barlovento', 34, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Buen estado visual de motor y estanque acumulador', 35, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Nivel de aceite motor y cabezal', 36, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Manómetro operativo (números legibles, buen estado esfera de vidrio, aguja funciona)', 37, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Válvula de seguridad y válvula de corte rápido operativos', 38, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Partes móviles del compresor protegidas', 39, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Válvula de retención operativa', 40, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Arnés de levante con hebilla de escape rápido', 41, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Mosquetón de acero inoxidable', 42, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Cinturón de lastre con escape rápido', 43, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Buen estado llave de espiche acumulador', 44, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Aletas de propulsión (al menos 2 pares en la faena)', 45, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Manillas adecuadas para transporte', 46, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Ruedas en buen estado', 47, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', 'Bandera Alfa', 48, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Equipos y elementos de apoyo para faenas de hasta 20 metros', '02 monobotellas de seguridad de 5 lt con aire a 200 bar de presión, regulador y manómetro, con funda protectora que evite puntos de enredo y arnés de levante incorporado con mosquetón', 49, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Manguera de buceo', 'Buen estado visual', 50, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Manguera de buceo', 'Cumple con las marcas reglamentarias cada 10 m', 51, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Manguera de buceo', 'Cumple con no tener roturas y/o rayas en sus tramos', 52, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Manguera de buceo', 'Válvula de retención en buen estado', 53, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Manguera de buceo', 'Apta para continuar su uso en faena', 54, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Unión compresor / manguera de buceo', 'Buen estado niple de unión', 55, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Emergencia', 'Botiquín de primeros auxilios básico', 56, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Emergencia', 'Procedimiento o manual de primeros auxilios (plastificado)', 57, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Emergencia', 'Unidad de O2 medicinal para emergencia', 58, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Emergencia', 'Tablas de descompresión plastificadas (I a V)', 59, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Documentos', 'Permiso de buceo autorizado por la AAMM', 60, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Documentos', 'Matrículas del personal de buzos vigentes', 61, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Documentos', 'Matrícula del compresor vigente', 62, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Documentos', 'Plan de contingencia en caso de accidentes de buceo', 63, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Documentos', 'Resolución de autorización plan de contingencias o carta entrega', 64, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Documentos', 'Bitácora de buceo y lista de chequeo faena de buceo diaria', 65, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Documentos', 'Bitácora mantención compresor de buceo (u otro que acredite trazabilidad de mantenciones realizadas)', 66, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Documentos', 'Exámenes pre u ocupacionales por buzo aptos', 67, NULL, false, NULL),
  ('INSPECCION_BUCEO_SEAROV', 'Documentos', 'Registro entrega elemento de protección personal (EPP), para bucear y trabajo en superficie', 68, NULL, false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Cumplimiento normas laborales', 'Nomina personal contratista autorizado para ingreso a instalaciones (chequear solo cuando embarcación ya está trabajando en la compañía)', 1, 'ALTA', false, 'Debe ser verificado una vez de inicio a los servicios en unidades productivas'),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'La embarcacion posee certificado de Navegabilidad (Vigente)', 2, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'La embarcacion cuenta con Inscripción y Matrícula Embarcación', 3, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Personal embarcado posee contrato embarcos (Chequear solo cuando embarcación ya está trabajando en la compañía)', 4, 'MEDIA', false, 'Debe ser verificado una vez de inicio a los servicios en unidades productivas Aplica para personal que no es parte de la dotación del barco y que desarrolla funciones de apoyo para trabajos en la misma, ej: personal baños de peces.'),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'La embarcacion cuenta con autorización de Zarpe al dia (Personal a bordo debe coincidir con zarpe.', 5, 'ALTA', false, 'Debe ser verificado una vez de inicio a los servicios en unidades productivas'),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'La embarcacion cuenta con Bitácora de mar y puerto (Al día y visada por la AAMM)', 6, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'El patrón de la Nave, cuenta con matricula al dia (Chequear solo cuando embarcación ya está trabajando en la compañía)', 7, 'MEDIA', false, 'Debe ser verificado una vez de inicio a los servicios en unidades productivas'),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Los tripulantes de la Naves, cuenta con sus matriculas al dia (Chequear solo cuando embarcación ya está trabajando en la compañía)', 8, 'MEDIA', false, 'Debe ser verificado una vez de inicio a los servicios en unidades productivas'),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Los tripulantes o Patron, cuentan con Licencia Radio Operador (Al menos 1) (Chequear solo cuando embarcación ya está trabajando en la compañía)', 9, 'MEDIA', false, 'Debe ser verificado una vez de inicio a los servicios en unidades productivas'),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'La embarcacion cuenta con cartas de Navegación de la zona. (Chequear solo cuando embarcación ya está trabajando en la compañía)', 10, 'MEDIA', false, 'Debe ser verificado una vez de inicio a los servicios en unidades productivas'),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Cuentan con reglamento Internacional para Prevenir abordajes.', 11, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Cuenta con Manual de Sujecion de la carga vigente (Aplica para el transporte de rodados, bateas, otros), la nave cuenta con informe de estabilidad.', 12, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Cuenta con certificado de arqueo bruto', 13, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Cuenta con resolucion de dotacion minima de seguridad de naves menores', 14, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Cuenta con plano de lucha contra incendio y dispositivos de seguridad (Visado por AAMM)', 15, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Cuenta con licencia estacion barco', 16, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Cuenta con plano de arreglo general', 17, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Cuenta con Certificación Bollard Pull (Aplica solo embarcaciones que realicen remolques)', 18, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Cuenta con certificación balsa salvavidas y valvula hidrostatica', 19, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Cuenta con certificado de mantencion anual de extintores', 20, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Grúa hidráulica con informe de resistencia de carga (Vigencia anual) - Documento coincide con datos tecnicos identificados en equipo', 21, 'ALTA', false, 'De no contar con informe resistencia de cargas vigente, equipo queda inhabilitado para operar en instalaciones de la compañía'),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Huinche cuenta con informe de resistencia de carga (Vigencia anual)', 22, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Cabrestante cuenta con informe de resistencia de carga (Vigencia anual)', 23, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Dotacion de la embarcacion debe contar con capacitaciones/cursos de los planes de contigencia/Zafarranchos a bordo/Equipamiento de emergencia', 24, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Embarcacion acreditada para labores de apoyo a salmonicultura', 25, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Documentación', 'Certificado del control de plagas realizado en la embarcación (Insectos, roedores, u otras plagas)', 26, 'MEDIA', false, '1 vez por mes'),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'La embarcacion cuenta con cuadros zafarranchos en caso de emergencia (HOMBRE AL AGUA, INCENDIO, / INUNDACIÓN.', 27, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Ayudas térmicas en cantidad suficiente por cada persona que pueda haber a bordo y para los que no tengan asignado un traje de inmersion (de acuerdo al certificado de navegabilidad)', 28, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Obligatorio contar con traje de inmersion por cada miembro de la dotacion al operar al sur del paralelo 55° Sur o de acuerdo lo exija la AAMM correspondiente', 29, 'ALTA', false, 'En este caso solo aplica si la AAMM local lo exige, la compañía no opera al sur del paralelo 55° sur'),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Cuentan con extintores contra incendio operativos, vigentes y a lo menos un hacha de bombero.', 30, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Red humeda y bomba contraincendio operativos (Manguera de 30 mts con pitón de 3 estados)', 31, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Posee sistema de alarma ante incendio operativos en las diferentes secciones de la embarcacion, señalizadas y conectadas con el tablero general del puente (Luz y bocina).', 32, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Posee alarma visual y sonora de inundaciones en sala de maquinas, bodega, acomodaciones (Cocina/sala estar), puente operativas etc.', 33, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Señaletica y avisos de seguridad (Extintores, vias de evacuación, uso de EPP, señaleticas en escaleras, uso de casco en brazo hidraulico, señaleticas de SUSPEL, rombo NFPA, señaleticas de riesgos y prohibiciones según aplique.', 34, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Luces y balizas de navegación operativas', 35, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'La embarcacion tiene Iluminación de faenas nocturnas en cubierta', 36, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Cuenta con bengalas en caja estanca (3 fumigenas, 6 de mano, 6 de paracaidas), para embarcaciones menores entre 25 hasta 50 trg', 37, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Cuenta con bengalas en caja estanca (al menos 6 de mano, 6 de paracaidas), para embarcaciones mayores de 50 trg', 38, 'ALTA', false, 'Solo naves mayores'),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Cuentan con botiquín de primeros auxilios N°3 de acuerdo con lo estipulado en Res.Ex.N°552 (Se Autoriza Botiquín básico N°4 para embarcaciones que ingresan en modalidad SPOT)', 39, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Cuentan con salvavidas circulares con cabo de vida de 30 m.ts Cuenta con el boyerin luminoso, se ajusta a lo indicado en el plano general de seguridad (demarcar nombre y matricula de embarcación)', 40, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Los tripulantes cuentan con chalecos salvavidas en buen estado, poseen luces y silbatos adheridos', 41, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'El estado de los baños higiénicos, es optimo y con suministro de agua. (Agua Caliente, escusado conectado a red de agua de la embarcación, lavamanos)', 42, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'El estado de cocina y comedor es optimo (Limpio, superficies en cocina lavables, Estufa sin acumulación de grasas y aceites, estufa con protección ante caida de ollas y sartenes).', 43, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Las condiciones de habitabilidad, camas, estan de acuerdo a la dotacion.', 44, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Estado de las camas, colchones, frazadas, cobertores, almohadas', 45, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'El abastecimiento de agua de bebida para el personal, cuenta con autorización sanitaria (Certificado o boleta que acredite potabilidad).', 46, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Estanque de almacenamiento de agua posee sistema de cloración. (Debe contar con sistema para medir cloro libre residual)', 47, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Embarcación: estado de casco, estancos, cubierta, estan en buenas condiciones (sin goteras, sin filtraciones, escaleras con superficie antideslizante, entre otros.)', 48, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Las areas de Tránsito en general, se encuentran libres de obstaculos.', 49, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Cuenta con defensas laterales en costados de atraque.', 50, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Las partes y piezas en movimiento cuentan con proteccion en sus 4 caras', 51, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Cuenta con bote auxiliar (Se eximen los que la AAMM no lo exija, verificar documentación de respaldo)', 52, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'El bote auxiliar cuenta con remos, dispositivos de seguridad operativos, boyerines de contencion en bandas, cinta antideslizante en bancadas y bordas, señalizacion (Uso chaleco salvavidas, Casco seguridad, riesgo caidas, riesgo atrapamiento, dotacion minima/maxima)', 53, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Dotación de elementos de protección personal de trabajo de acuerdo a la actividad, tales como: trajes de agua, botas, trajes térmicos, casco, zapatos seguridad, entre otros según la tarea y necesidades de protección. ¿Su estado de conservación es optimo?', 54, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'La embarcación posee equipos de comunicación y de navegación nocturna (Radar, GPS,etc)', 55, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'La embarcación cuenta con equipo de generación eléctrica', 56, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Los circuitos eléctricos cuentan con protección diferencial', 57, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'La embarcación cuenta con circuito de agua para uso de higiene', 58, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Estanques de combustible, TK admisión y ventilación ( Petril en admisión y ventilación), cañerias de gas, ductos señalizados (Acordes con esquema de colores).', 59, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Sistema de escape de gases con aislación termica', 60, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Cuenta con lavadora y secadora de ropa para uso por parte del personal', 61, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Se evidencia inexistencia de acumulación de aguas sentina en la embarcación', 62, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Calefacción electrica en sector habitabilidad (Prohibicion de calefaccion de llama abierta)', 63, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Cuenta con camilla de rescate, arnes tipo araña, inmovilizador lateral, collar cervical y kit de ferulas', 64, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Posee manta ignifigua en cocina y extintor tipo K', 65, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Cuenta con 2 bicheros en buen estado (aplica solo naves menores de 50 trg)', 66, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Cuenta con una bomba de achique mecanica y manual operativas (Manifold de achique identificado)', 67, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Cuenta con Radiobalizas de Localizacion de Siniestros "RLS" vigente (aplica solo para naves mayores de 50 trg)', 68, 'ALTA', false, 'Solo naves mayores'),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Estado del Brazo Hidráulico (Buenas condiciones de seguridad visual) "Bitácora mantencion y/o máquinas", Esta identificado el SWL', 69, 'ALTA', false, 'En el momento de la inspeccion si no está abordo la bitacora, certificado, u otro y que el equipo presente alguna desviacion visual "puede navegar", pero en la instalacion antes de operar debe demostrar cumplimiento de lo anterior para utilizar en maniobras y correcta operatividad, de lo contrario no se podrá utilizar el equipo'),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Grua hidraulica posee alarma sonora y visual operativa.', 70, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Gancho de brazo hidraulico posee seguro en buen estado y operativo.', 71, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Estado de Huinche (Buenas condiciones de seguridad visual) "Bitácora mantencion y/o máquinas"', 72, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Estado de Cabrestante (Buenas condiciones de seguridad visual) "Bitácora mantención y/o máquinas"', 73, 'ALTA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Controles de grua hidraulica se encuentran identificados', 74, 'MEDIA', false, NULL),
  ('INSPECCION_EMBARCACION_SEAROV', 'Seguridad, higiene y emergencias', 'Embarcación cuenta con sistema de posicionamiento automatico operativo (POSAT)', 75, 'MEDIA', false, NULL)
) AS v(tipo_actividad, categoria, pregunta, orden, potencialidad, aplica_por_buzo, info_adicional)
WHERE NOT EXISTS (
  SELECT 1 FROM public.formulario_items f
  WHERE f.tipo_actividad = v.tipo_actividad AND f.pregunta = v.pregunta AND f.categoria = v.categoria
);

COMMIT;


-- 2. VERIFICAR (solo lectura) -----------------------------------------------------

-- 2.1 Empresa y modulos (esperado: Searov SpA con INSPECCION_SEAROV y HISTORY).
SELECT e.nombre, string_agg(em.modulo_key, ', ' ORDER BY em.orden) AS modulos
FROM public.empresas e
LEFT JOIN public.empresa_modulos em ON em.empresa_id = e.id
WHERE e.nombre = 'Searov SpA'
GROUP BY 1;

-- 2.2 Preguntas (esperado: buceo 68 en 7 categorias, 11 por buzo;
--     embarcacion 75 en 3 categorias, 35 ALTA y 40 MEDIA).
SELECT tipo_actividad, COUNT(*) AS preguntas, COUNT(DISTINCT categoria) AS categorias,
       COUNT(*) FILTER (WHERE aplica_por_buzo) AS por_buzo,
       COUNT(*) FILTER (WHERE potencialidad = 'ALTA') AS alta,
       COUNT(*) FILTER (WHERE potencialidad = 'MEDIA') AS media
FROM public.formulario_items
WHERE tipo_actividad LIKE '%_SEAROV'
GROUP BY 1;

-- 2.3 Columna de actividades creada y sin datos (esperado: 0 con formato).
SELECT COUNT(*) FILTER (WHERE formato_informe IS NOT NULL) AS con_formato FROM public.actividades;
