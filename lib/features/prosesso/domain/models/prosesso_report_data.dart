import 'dart:typed_data';
import 'package:jf_innova_app/features/prosesso/domain/models/prosesso_extintor_state.dart';

class ProsessoReportData {
  final String visitaId;
  final String certNumero;
  final String fechaServicio;
  final String clienteNombre;
  final String clienteDireccion;
  final String realizadoPor;
  final String fechaRegistro;
  final String dsOrdinario;
  final String tipoServicio;
  final List<ExtintorProsessoResumen> extintores;
  final Uint8List? signatureBytes;

  const ProsessoReportData({
    required this.visitaId,
    required this.certNumero,
    required this.fechaServicio,
    required this.clienteNombre,
    required this.clienteDireccion,
    required this.realizadoPor,
    required this.fechaRegistro,
    this.dsOrdinario = 'D.S Y O.M. ORDINARIO N.º 12600/06/208/Vrs',
    this.tipoServicio = 'Mantenimiento de extintores',
    required this.extintores,
    this.signatureBytes,
  });
}

class ExtintorProsessoResumen {
  final int numero;
  final String? planta;
  final String? ubicacion;
  final String? ubicacionSector;
  final String? ubicacion2;
  final String? certificado;
  final int? anio;
  final String? tipo;
  final String? peso;
  final String? kg;
  final String? fechaVencimiento;
  final String? observaciones;
  final List<PuntoEstadoResumenProsesso> puntos;
  final List<String> fotoPaths;

  const ExtintorProsessoResumen({
    required this.numero,
    this.planta,
    this.ubicacion,
    this.ubicacionSector,
    this.ubicacion2,
    this.certificado,
    this.anio,
    this.tipo,
    this.peso,
    this.kg,
    this.fechaVencimiento,
    this.observaciones,
    required this.puntos,
    required this.fotoPaths,
  });

  factory ExtintorProsessoResumen.fromState(ExtintorProsessoState s) =>
      ExtintorProsessoResumen(
        numero: s.numero,
        planta: s.planta,
        ubicacion: s.ubicacion,
        ubicacionSector: s.ubicacionSector,
        ubicacion2: s.ubicacion2,
        certificado: s.certificado,
        anio: s.anio,
        tipo: s.tipo,
        peso: s.peso,
        kg: s.kg,
        fechaVencimiento: s.fechaVencimiento,
        observaciones: s.observaciones,
        puntos: s.puntos
            .map(
              (p) => PuntoEstadoResumenProsesso(
                pregunta: p.pregunta,
                estado: p.estado,
                observacion: p.observacion,
              ),
            )
            .toList(),
        fotoPaths: s.fotoPaths,
      );
}

class PuntoEstadoResumenProsesso {
  final String pregunta;
  final EstadoPuntoProsesso? estado;
  final String? observacion;

  const PuntoEstadoResumenProsesso({
    required this.pregunta,
    this.estado,
    this.observacion,
  });
}
