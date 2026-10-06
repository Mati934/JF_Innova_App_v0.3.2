import 'dart:convert';
import 'package:jf_innova_app/features/inspection/domain/models/formulario_item.dart';
import 'package:uuid/uuid.dart';

enum EstadoPuntoProsesso {
  cumple,
  noCumple,
  noAplica;

  String get label => switch (this) {
    EstadoPuntoProsesso.cumple => 'C',
    EstadoPuntoProsesso.noCumple => 'NC',
    EstadoPuntoProsesso.noAplica => 'NA',
  };

  String get textoExcel => switch (this) {
    EstadoPuntoProsesso.cumple => 'si',
    EstadoPuntoProsesso.noCumple => 'no',
    EstadoPuntoProsesso.noAplica => 'n/a',
  };

  static EstadoPuntoProsesso? fromString(String? s) => switch (s) {
    'C' => EstadoPuntoProsesso.cumple,
    'NC' => EstadoPuntoProsesso.noCumple,
    'NA' => EstadoPuntoProsesso.noAplica,
    _ => null,
  };
}

class PuntoProsessoState {
  final String itemId;
  final String pregunta;
  final EstadoPuntoProsesso? estado;
  final String? observacion;

  const PuntoProsessoState({
    required this.itemId,
    required this.pregunta,
    this.estado,
    this.observacion,
  });

  PuntoProsessoState copyWith({
    EstadoPuntoProsesso? estado,
    String? observacion,
    bool clearEstado = false,
  }) => PuntoProsessoState(
    itemId: itemId,
    pregunta: pregunta,
    estado: clearEstado ? null : (estado ?? this.estado),
    observacion: observacion ?? this.observacion,
  );

  Map<String, dynamic> toJson() => {
    'estado': estado?.label,
    'observacion': observacion,
  };

  factory PuntoProsessoState.fromItem(
    FormularioItem item, [
    Map<String, dynamic>? saved,
  ]) => PuntoProsessoState(
    itemId: item.id,
    pregunta: item.pregunta,
    estado: EstadoPuntoProsesso.fromString(saved?['estado'] as String?),
    observacion: saved?['observacion'] as String?,
  );
}

class ExtintorProsessoState {
  final String localId;
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
  final List<String> fotoPaths;
  final List<PuntoProsessoState> puntos;
  final bool expandido;

  const ExtintorProsessoState({
    required this.localId,
    required this.numero,
    this.planta,
    this.ubicacion,
    this.ubicacionSector,
    this.ubicacion2,
    this.certificado,
    this.anio,
    this.tipo,
    this.peso,
    this.kg = 'KG',
    this.fechaVencimiento,
    this.observaciones,
    this.fotoPaths = const [],
    required this.puntos,
    this.expandido = true,
  });

  bool get estaCompleto => puntos.every((p) => p.estado != null);
  int get puntosCompletados => puntos.where((p) => p.estado != null).length;
  int get totalPuntos => puntos.length;
  bool get todosCumplen =>
      estaCompleto &&
      puntos.every(
        (p) =>
            p.estado == EstadoPuntoProsesso.cumple ||
            p.estado == EstadoPuntoProsesso.noAplica,
      );
  List<PuntoProsessoState> get puntosNC =>
      puntos.where((p) => p.estado == EstadoPuntoProsesso.noCumple).toList();

  ExtintorProsessoState clonarEstados(ExtintorProsessoState origen) => copyWith(
    puntos: List.generate(puntos.length, (i) {
      if (i < origen.puntos.length) {
        return puntos[i].copyWith(estado: origen.puntos[i].estado);
      }
      return puntos[i];
    }),
  );

  ExtintorProsessoState copyWith({
    String? planta,
    String? ubicacion,
    String? ubicacionSector,
    String? ubicacion2,
    String? certificado,
    int? anio,
    String? tipo,
    String? peso,
    String? kg,
    String? fechaVencimiento,
    String? observaciones,
    List<String>? fotoPaths,
    List<PuntoProsessoState>? puntos,
    bool? expandido,
  }) => ExtintorProsessoState(
    localId: localId,
    numero: numero,
    planta: planta ?? this.planta,
    ubicacion: ubicacion ?? this.ubicacion,
    ubicacionSector: ubicacionSector ?? this.ubicacionSector,
    ubicacion2: ubicacion2 ?? this.ubicacion2,
    certificado: certificado ?? this.certificado,
    anio: anio ?? this.anio,
    tipo: tipo ?? this.tipo,
    peso: peso ?? this.peso,
    kg: kg ?? this.kg,
    fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
    observaciones: observaciones ?? this.observaciones,
    fotoPaths: fotoPaths ?? this.fotoPaths,
    puntos: puntos ?? this.puntos,
    expandido: expandido ?? this.expandido,
  );

  Map<String, dynamic> toDbRow(String visitaId) {
    final respuestas = <String, dynamic>{};
    for (final p in puntos) {
      if (p.estado != null || (p.observacion?.isNotEmpty ?? false)) {
        respuestas[p.itemId] = p.toJson();
      }
    }
    return {
      'id': localId,
      'visita_id': visitaId,
      'numero': numero,
      'planta': planta,
      'ubicacion': ubicacion,
      'ubicacion_sector': ubicacionSector,
      'ubicacion_2': ubicacion2,
      'certificado': certificado,
      'anio': anio,
      'tipo': tipo,
      'peso': peso,
      'kg': kg,
      'fecha_vencimiento': fechaVencimiento,
      'observaciones': observaciones,
      'fotos_json': jsonEncode(fotoPaths),
      'respuestas_json': jsonEncode(respuestas),
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  factory ExtintorProsessoState.nuevo({
    required int numero,
    required List<FormularioItem> items,
  }) => ExtintorProsessoState(
    localId: const Uuid().v4(),
    numero: numero,
    puntos: items.map((i) => PuntoProsessoState.fromItem(i)).toList(),
  );

  factory ExtintorProsessoState.fromDb({
    required Map<String, dynamic> row,
    required List<FormularioItem> items,
  }) {
    final respuestas = row['respuestas_json'] != null
        ? (jsonDecode(row['respuestas_json'] as String) as Map<String, dynamic>)
        : <String, dynamic>{};
    final fotos = row['fotos_json'] != null
        ? (jsonDecode(row['fotos_json'] as String) as List).cast<String>()
        : <String>[];

    return ExtintorProsessoState(
      localId: row['id'] as String,
      numero: row['numero'] as int,
      planta: row['planta'] as String?,
      ubicacion: row['ubicacion'] as String?,
      ubicacionSector: row['ubicacion_sector'] as String?,
      ubicacion2: row['ubicacion_2'] as String?,
      certificado: row['certificado'] as String?,
      anio: row['anio'] as int?,
      tipo: row['tipo'] as String?,
      peso: row['peso'] as String?,
      kg: (row['kg'] as String?) ?? 'KG',
      fechaVencimiento: row['fecha_vencimiento'] as String?,
      observaciones: row['observaciones'] as String?,
      fotoPaths: fotos,
      puntos: items.map((item) {
        final saved = respuestas[item.id] as Map<String, dynamic>?;
        return PuntoProsessoState.fromItem(item, saved);
      }).toList(),
    );
  }
}
