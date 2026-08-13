class MandatoryBuceoPhotoSlot {
  final String key;
  final String title;

  const MandatoryBuceoPhotoSlot({required this.key, required this.title});
}

const List<MandatoryBuceoPhotoSlot> mandatoryBuceoPhotoSlots = [
  MandatoryBuceoPhotoSlot(key: 'compresor_general', title: 'Compresor General'),
  MandatoryBuceoPhotoSlot(
    key: 'aceite_vegetal_principal',
    title: 'Estado de Aceite Vegetal Compresor Principal',
  ),
  MandatoryBuceoPhotoSlot(
    key: 'aceite_vegetal_backup',
    title: 'Estado Aceite Vegetal Compresor Back Up',
  ),
  MandatoryBuceoPhotoSlot(
    key: 'matriculas_buceo',
    title: 'Matriculas de Buceo',
  ),
  MandatoryBuceoPhotoSlot(
    key: 'bitacora_compresores',
    title: 'Bitacora de Compresores',
  ),
  MandatoryBuceoPhotoSlot(
    key: 'bitacora_buceo_supervisor',
    title: 'Bitacora de Buceo Supervisor',
  ),
  MandatoryBuceoPhotoSlot(
    key: 'registro_oxigeno_normobarico',
    title: 'Registro Aplicacion Oxigeno Normobarico',
  ),
  MandatoryBuceoPhotoSlot(
    key: 'certificado_inspeccion_compresores',
    title: 'Certificado de Inspeccion de Compresores',
  ),
];

String mandatoryPhotoItemId(String key) => 'mandatory::$key';
