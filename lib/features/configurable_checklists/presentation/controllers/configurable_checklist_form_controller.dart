import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/user_session.dart';
import '../../../inspection/domain/models/formulario_item.dart';
import '../../data/repositories/local_configurable_checklist_repository.dart';
import '../../domain/models/configurable_checklist.dart';

class ConfigurableChecklistFormController extends ChangeNotifier {
  final ConfigurableChecklist checklist;
  final LocalConfigurableChecklistRepository _repo;
  final String? draftId;

  ConfigurableChecklistFormController({
    required this.checklist,
    this.draftId,
    LocalConfigurableChecklistRepository? repo,
  }) : _repo = repo ?? LocalConfigurableChecklistRepository();

  bool isLoading = true;
  String? errorMessage;
  ChecklistVersion? version;
  List<FormularioItem> items = const [];
  final respuestas = <String, String?>{};
  final observaciones = <String, String>{};
  final criticidades = <String, String>{};
  String inspectionId = '';
  String? quienInspecciona;
  String? observacionesGenerales;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      version = await _repo.getPublishedVersion(checklist.key);
      if (version == null) {
        throw StateError('CHECKLIST_VERSION_NO_DISPONIBLE');
      }
      items = version!.preguntas.map(FormularioItem.fromJson).toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));
      inspectionId = draftId ?? const Uuid().v4();
      for (final item in items) {
        criticidades[item.id] = item.criticidad;
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Map<String, List<FormularioItem>> get groupedItems {
    final grouped = <String, List<FormularioItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.categoria, () => []).add(item);
    }
    return grouped;
  }

  String? respuestaDe(String itemId) => respuestas[itemId];
  String observacionDe(String itemId) => observaciones[itemId] ?? '';
  String criticidadDe(String itemId) => criticidades[itemId] ?? 'Tolerable';

  void setRespuesta(String itemId, String value) {
    respuestas[itemId] = value;
    notifyListeners();
  }

  void setObservacion(String itemId, String value) {
    observaciones[itemId] = value;
  }

  void setCriticidad(String itemId, String value) {
    criticidades[itemId] = value;
  }

  bool get canSave => !isLoading && version != null;

  Future<void> saveDraft() async {
    if (!canSave) return;
    final session = UserSession();
    final userId = session.userId;
    final empresaId = session.empresaId;
    if (userId == null || empresaId == null) {
      throw StateError('CHECKLIST_USUARIO_EMPRESA_REQUERIDOS');
    }
    final currentVersion = version!;
    await _repo.saveDraft(
      inspection: {
        'id': inspectionId,
        'usuario_id': userId,
        'empresa_id': empresaId,
        'checklist_key': checklist.key,
        'form_type_key': checklist.formTypeKey,
        'version_id': currentVersion.id,
        'version': currentVersion.version,
        'snapshot': jsonEncode({
          'preguntas': currentVersion.preguntas,
          'campos_extra': currentVersion.camposExtra,
          'reglas': currentVersion.reglas,
        }),
        'fecha_realizacion': DateTime.now().toIso8601String(),
        'quien_inspecciona': quienInspecciona,
        'observaciones': observacionesGenerales,
        'campos_extra': '{}',
        'estado_final': 'Borrador',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'subido': 0,
        'eliminado': 0,
      },
      responses: items.map((item) {
        return {
          'id': const Uuid().v4(),
          'inspeccion_id': inspectionId,
          'item_key': item.id,
          'categoria': item.categoria,
          'pregunta': item.pregunta,
          'orden': item.orden,
          'estado': respuestas[item.id],
          'observacion': observaciones[item.id],
          'criticidad': criticidades[item.id],
          'subido': 0,
        };
      }).toList(),
    );
  }
}
