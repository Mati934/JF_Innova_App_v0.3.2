-- Renombra la lista de chequeo de Grúa Horquilla Patio Fiordo Austral
-- a nombres más cortos para una mejor visualización en las tarjetas.
--
-- Card (módulo Hidroser):
--   nombre    -> "Grúas Horquillas"
--   subtitulo -> "Lista de verificación"
--
-- Sustituye el subtítulo anterior ("Inspección diaria de grúa horquilla")
-- porque la inspección no es estrictamente diaria.

UPDATE hidroser_listas
SET nombre    = 'Grúas Horquillas',
    subtitulo = 'Lista de verificación'
WHERE codigo  = 'GRUA_HORQUILLA_PFA';
