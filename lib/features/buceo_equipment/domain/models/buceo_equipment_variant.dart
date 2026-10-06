class BuceoEquipmentVariant {
  final String codigo;
  final String nombre;
  final String subtitulo;
  final String tipoFormularioItems;

  const BuceoEquipmentVariant({
    required this.codigo,
    required this.nombre,
    required this.subtitulo,
    required this.tipoFormularioItems,
  });
}

const buceoEquipoSalVariant = BuceoEquipmentVariant(
  codigo: 'BUCEO_SAL_20M',
  nombre: 'Inspeccion de equipo SAL',
  subtitulo: 'Lista de chequeo faena 20 metros',
  tipoFormularioItems: 'BUCEO_SAL_20M',
);

const buceoEquipoSamVariant = BuceoEquipmentVariant(
  codigo: 'BUCEO_SAM_36M',
  nombre: 'Inspeccion de equipo SAM',
  subtitulo: 'Lista de chequeo faena 36 metros',
  tipoFormularioItems: 'BUCEO_SAM_36M',
);

const buceoEquipmentVariants = <BuceoEquipmentVariant>[
  buceoEquipoSalVariant,
  buceoEquipoSamVariant,
];
