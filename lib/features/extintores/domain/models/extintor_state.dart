import 'dart:convert';
import 'package:jf_innova_app/features/inspection/domain/models/formulario_item.dart';
import 'package:uuid/uuid.dart';

enum EstadoExtintor {
  cumple,
  noCumple,
  noAplica;

  String get label => switch (this) {
    EstadoExtintor.cumple => 'C',
    EstadoExtintor.noCumple => 'NC',
    EstadoExtintor.noAplica => 'NA',
  };

  static EstadoExtintor? fromString(String? s) => switch (s) {
    'C' => EstadoExtintor.cumple,
    'NC' => EstadoExtintor.noCumple,
    'NA' => EstadoExtintor.noAplica,
    _ => null,
  };
}

class PuntoExtintorState {
  final String itemId;
  final String pregunta;
  final EstadoExtintor? estado;
  final String? observacion;

  const PuntoExtintorState({
    required this.itemId,
    required this.pregunta,
    this.estado,
    this.observacion,
  });

  PuntoExtintorState copyWith({
    EstadoExtintor? estado,
    String? observacion,
    bool clearEstado = false,
  }) => PuntoExtintorState(
    itemId: itemId,
    pregunta: pregunta,
    estado: clearEstado ? null : (estado ?? this.estado),
    observacion: observacion ?? this.observacion,
  );

  Map<String, dynamic> toJson() => {
    'estado': estado?.label,
    'observacion': observacion,
  };

  factory PuntoExtintorState.fromItem(
    FormularioItem item, [
    Map<String, dynamic>? saved,
  ]) => PuntoExtintorState(
    itemId: item.id,
    pregunta: item.pregunta,
    estado: EstadoExtintor.fromString(saved?['estado'] as String?),
    observacion: saved?['observacion'] as String?,
  );
}

class ExtintorState {
  final String localId;
  final int numero;
  final String? matricula;
  final String? tipoExtintor;
  final List<String> fotoPaths;
  final List<PuntoExtintorState> puntos;
  final bool expandido;

  const ExtintorState({
    required this.localId,
    required this.numero,
    this.matricula,
    this.tipoExtintor,
    this.fotoPaths = const [],
    required this.puntos,
    this.expandido = true,
  });

  bool get estaCompleto => puntos.every((p) => p.estado != null);
  int get puntosCompletados => puntos.where((p) => p.estado != null).length;
  int get totalPuntos => puntos.length;
  bool get todosCumplen =>
      puntos.every(
        (p) =>
            p.estado == EstadoExtintor.cumple ||
            p.estado == EstadoExtintor.noAplica,
      ) &&
      estaCompleto;
  List<PuntoExtintorState> get puntosNC =>
      puntos.where((p) => p.estado == EstadoExtintor.noCumple).toList();

  /// Copia estados del origen, NO matrícula, fotos ni observaciones
  ExtintorState clonarEstados(ExtintorState origen) => copyWith(
    puntos: List.generate(puntos.length, (i) {
      if (i < origen.puntos.length) {
        return puntos[i].copyWith(estado: origen.puntos[i].estado);
      }
      return puntos[i];
    }),
  );

  ExtintorState copyWith({
    String? matricula,
    String? tipoExtintor,
    List<String>? fotoPaths,
    List<PuntoExtintorState>? puntos,
    bool? expandido,
  }) => ExtintorState(
    localId: localId,
    numero: numero,
    matricula: matricula ?? this.matricula,
    tipoExtintor: tipoExtintor ?? this.tipoExtintor,
    fotoPaths: fotoPaths ?? this.fotoPaths,
    puntos: puntos ?? this.puntos,
    expandido: expandido ?? this.expandido,
  );

  /// Para SQLite: serializa respuestas y fotos como JSON String
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
      'matricula': matricula,
      'tipo_extintor': tipoExtintor,
      'fotos_json': jsonEncode(fotoPaths),
      'respuestas_json': jsonEncode(respuestas),
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  factory ExtintorState.nuevo({
    required int numero,
    required List<FormularioItem> items,
  }) => ExtintorState(
    localId: const Uuid().v4(),
    numero: numero,
    puntos: items.map((i) => PuntoExtintorState.fromItem(i)).toList(),
  );

  factory ExtintorState.fromDb({
    required Map<String, dynamic> row,
    required List<FormularioItem> items,
  }) {
    final respuestas = row['respuestas_json'] != null
        ? (jsonDecode(row['respuestas_json'] as String) as Map<String, dynamic>)
        : <String, dynamic>{};
    final fotos = row['fotos_json'] != null
        ? (jsonDecode(row['fotos_json'] as String) as List).cast<String>()
        : <String>[];

    return ExtintorState(
      localId: row['id'] as String,
      numero: row['numero'] as int,
      matricula: row['matricula'] as String?,
      tipoExtintor: row['tipo_extintor'] as String?,
      fotoPaths: fotos,
      puntos: items.map((item) {
        final saved = respuestas[item.id] as Map<String, dynamic>?;
        return PuntoExtintorState.fromItem(item, saved);
      }).toList(),
    );
  }
}
