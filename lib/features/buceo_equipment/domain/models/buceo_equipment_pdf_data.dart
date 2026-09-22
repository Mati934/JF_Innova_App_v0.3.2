import 'dart:typed_data';

class BuceoPdfCompresor {
  final String nombre;
  final String matricula;
  final String vigencia;
  final String ph;
  final String buzosCargo;

  const BuceoPdfCompresor({
    required this.nombre,
    required this.matricula,
    required this.vigencia,
    required this.ph,
    required this.buzosCargo,
  });
}

class BuceoPdfBuzo {
  final String titulo;
  final String nombre;
  final String matricula;
  final String profundidad;

  const BuceoPdfBuzo({
    required this.titulo,
    required this.nombre,
    required this.matricula,
    required this.profundidad,
  });
}

class BuceoPdfChecklistItem {
  final String categoria;
  final String pregunta;
  final String respuesta;
  final String observacion;
  final String? fotoPath;

  const BuceoPdfChecklistItem({
    required this.categoria,
    required this.pregunta,
    required this.respuesta,
    required this.observacion,
    this.fotoPath,
  });
}

class BuceoPdfFirma {
  final String rol;
  final String? nombre;
  final Uint8List? imagen;

  const BuceoPdfFirma({required this.rol, this.nombre, this.imagen});
}

class BuceoEquipmentPdfData {
  final String empresaProveedor;
  final String tituloInforme;
  final String subtituloInforme;
  final String nombreLista;
  final String numeroInforme;
  final String fecha;
  final String empresa;
  final String area;
  final String region;
  final String supervisorJefatura;
  final String embarcacion;
  final String lugarFaena;
  final String profesional;
  final String profesionalCorreo;
  final String profesionalFono;

  final int totalCumple;
  final int totalNoCumple;
  final int totalNoAplica;

  final List<BuceoPdfCompresor> compresores;
  final List<BuceoPdfBuzo> buzos;
  final List<BuceoPdfChecklistItem> checklistItems;
  final List<String> galeriaPaths;
  final List<BuceoPdfFirma> firmas;

  const BuceoEquipmentPdfData({
    required this.empresaProveedor,
    required this.tituloInforme,
    required this.subtituloInforme,
    required this.nombreLista,
    required this.numeroInforme,
    required this.fecha,
    required this.empresa,
    required this.area,
    required this.region,
    required this.supervisorJefatura,
    required this.embarcacion,
    required this.lugarFaena,
    required this.profesional,
    required this.profesionalCorreo,
    required this.profesionalFono,
    required this.totalCumple,
    required this.totalNoCumple,
    required this.totalNoAplica,
    required this.compresores,
    required this.buzos,
    required this.checklistItems,
    required this.galeriaPaths,
    required this.firmas,
  });
}
