import 'prosesso_extintor_state.dart' show EstadoPuntoProsesso;

/// Contrato mínimo que necesita [ProsessoExtintorCard] para operar sobre la
/// grilla de extintores. Cualquier controlador (Prosesso, Merieux Extintores,
/// futuros módulos con el mismo checklist) puede implementarlo para reusar el
/// widget de la tarjeta sin duplicar su UI.
abstract class ExtintorGridController {
  void toggleExpandido(int index);
  void marcarTodoCumple(int index);
  void clonarDelAnterior(int index);
  void duplicarExtintor(int index);
  void eliminarExtintor(int index);
  void updatePlanta(int index, String value);
  void updateUbicacion(int index, String value);
  void updateSector(int index, String value);
  void updateUbic2(int index, String value);
  void updateCertificado(int index, String value);
  void updateAnio(int index, String value);
  void updateTipo(int index, String value);
  void updatePeso(int index, String value);
  void updateKg(int index, String value);
  void updateFechaVenc(int index, String value);
  void updateObservaciones(int index, String value);
  void responderPunto(int index, String itemId, EstadoPuntoProsesso estado);
}
