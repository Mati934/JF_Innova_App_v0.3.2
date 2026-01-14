import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/models/formulario_item.dart';
import '../../domain/repositories/inspection_repository.dart';
import '../../data/repositories/local_inspection_repository.dart';

class InspectionFormController extends ChangeNotifier {
  final InspectionRepository _repo;
  final String activityId;
  final String tipoActividad;
  String? centroId;

  List<FormularioItem> _items = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  final Map<String, String> respuestas = {};
  final Map<String, String> observaciones = {};
  final Map<String, String> criticidades = {};
  final Map<String, File> fotosPorPregunta = {};
  List<File> fotosGenerales = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  List<FormularioItem> get items => _items;

  // --- SEGURIDAD ANTI-CRASH (CRUCIAL) ---
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
  // --------------------------------------

  InspectionFormController({
    required this.activityId,
    required this.tipoActividad,
    this.centroId,
  }) : _repo = LocalInspectionRepository() {
    _init();
  }

  Future<void> _init() async {
    try {
      _isLoading = true;
      notifyListeners();

      if (centroId == null && _repo is LocalInspectionRepository) {
        final data = await (_repo as LocalInspectionRepository).getActividad(
          activityId,
        );
        if (data != null && data['centro_id'] != null) {
          centroId = data['centro_id'] as String;
        }
      }

      _items = await _repo.getItems(tipoActividad);

      final datos = await _repo.cargarRespuestasGuardadas(activityId);
      datos.forEach((id, val) {
        if (val['estado'] != null) respuestas[id] = val['estado'];
        if (val['observacion'] != null) observaciones[id] = val['observacion'];
        if (val['criticidad'] != null) criticidades[id] = val['criticidad'];
      });

      if (_repo is LocalInspectionRepository) {
        final fotos = await (_repo as LocalInspectionRepository)
            .getFotosPendientes(activityId);
        for (var f in fotos) {
          final file = File(f['local_path'] as String);
          if (file.existsSync()) {
            final itemId = f['item_id'] as String?;
            if (itemId != null)
              fotosPorPregunta[itemId] = file;
            else
              fotosGenerales.add(file);
          }
        }
      }
    } catch (e) {
      _errorMessage = "Error cargando: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setRespuesta(String id, String val) {
    respuestas[id] = val;
    notifyListeners();
  }

  void setObservacion(String id, String val) {
    observaciones[id] = val;
  }

  void setCriticidad(String id, String val) {
    criticidades[id] = val;
    notifyListeners();
  }

  void setFotoPregunta(String id, File f) {
    fotosPorPregunta[id] = f;
    notifyListeners();
  }

  void setFotosGenerales(List<File> f) {
    fotosGenerales = f;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> guardarBorrador({bool silent = false}) async {
    _isSaving = true;
    if (!silent) notifyListeners();
    try {
      await _persistirDatos();
      return true;
    } catch (e) {
      _errorMessage = "Error guardando: $e";
      return false;
    } finally {
      _isSaving = false;
      if (!silent) notifyListeners();
    }
  }

  Future<bool> finalizarInspeccion() async {
    if (centroId == null) {
      _errorMessage = "Error: Centro no seleccionado.";
      notifyListeners();
      return false;
    }
    if (respuestas.length < _items.length) {
      _errorMessage = "Faltan respuestas.";
      notifyListeners();
      return false;
    }
    _isSaving = true;
    notifyListeners();
    try {
      await _persistirDatos();
      return true;
    } catch (e) {
      _errorMessage = "Error finalizando: $e";
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _persistirDatos() async {
    if (_repo is LocalInspectionRepository) {
      await (_repo as LocalInspectionRepository).saveActividad(
        id: activityId,
        tipoActividad: tipoActividad,
        centroId: centroId,
        fecha: DateTime.now(),
      );
    }
    List<Map<String, dynamic>> lote = [];
    respuestas.forEach((key, val) {
      if (fotosPorPregunta.containsKey(key)) {
        _repo.saveFoto(
          activityId: activityId,
          itemId: key,
          file: XFile(fotosPorPregunta[key]!.path),
          descripcion: 'Item $key',
        );
      }
      lote.add({
        'actividad_id': activityId,
        'item_id': key,
        'estado': val,
        'observacion': observaciones[key],
        'criticidad_registrada': criticidades[key] ?? 'Tolerable',
      });
    });
    await _repo.saveRespuestasBatch(lote);
    for (var f in fotosGenerales) {
      await _repo.saveFoto(
        activityId: activityId,
        itemId: null,
        file: XFile(f.path),
        descripcion: 'General',
      );
    }
  }

  Map<String, List<FormularioItem>> agruparPorCategoria() {
    final Map<String, List<FormularioItem>> map = {};
    for (var item in _items) {
      if (!map.containsKey(item.categoria)) map[item.categoria] = [];
      map[item.categoria]!.add(item);
    }
    return map;
  }
}
