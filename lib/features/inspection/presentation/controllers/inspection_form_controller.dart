import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// Asegúrate de que las rutas sean correctas en tu proyecto
import '../../domain/models/buceo_verificacion_model.dart';
import '../../domain/models/participante_model.dart';
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

  // --- VARIABLES ESPECÍFICAS DE BUCEO ---
  BuceoVerificacionModel? verificacionesBuceo;
  List<ParticipanteModel> participantes = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  List<FormularioItem> get items => _items;

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

      // 1. Cargar Centro si falta
      if (centroId == null && _repo is LocalInspectionRepository) {
        final data = await (_repo as LocalInspectionRepository).getActividad(
          activityId,
        );
        if (data != null && data['centro_id'] != null) {
          centroId = data['centro_id'] as String;
        }
      }

      // 2. Cargar Items del Formulario
      _items = await _repo.getItems(tipoActividad);

      // 3. Cargar Respuestas Previas
      final datos = await _repo.cargarRespuestasGuardadas(activityId);
      datos.forEach((id, val) {
        if (val['estado'] != null) respuestas[id] = val['estado'];
        if (val['observacion'] != null) observaciones[id] = val['observacion'];
        if (val['criticidad'] != null) criticidades[id] = val['criticidad'];
      });

      // 4. Cargar Fotos Previas (Solo local)
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

      // 5. CARGAR DATOS ESPECÍFICOS (BUCEO)
      await cargarDatosEspecificos();
    } catch (e) {
      _errorMessage = "Error cargando: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- MÉTODOS DE BUCEO ---
  Future<void> cargarDatosEspecificos() async {
    if (tipoActividad == 'INSPECCION_BUCEO') {
      try {
        // Cargar Verificaciones
        final datosBuceo = await _repo.getVerificacionesBuceo(activityId);
        if (datosBuceo != null) {
          verificacionesBuceo = datosBuceo;
        } else {
          verificacionesBuceo = BuceoVerificacionModel(actividadId: activityId);
        }

        // Cargar Participantes
        participantes = await _repo.getParticipantes(activityId);

        // No llamamos notifyListeners aquí porque _init ya lo hará al final
      } catch (e) {
        print("Error cargando datos buceo: $e");
      }
    }
  }

  void updateVerificacion(Function(BuceoVerificacionModel) updates) {
    if (verificacionesBuceo != null) {
      updates(verificacionesBuceo!);
      notifyListeners();
    }
  }

  void agregarParticipante(ParticipanteModel participante) {
    if (!participantes.any((p) => p.personalId == participante.personalId)) {
      participantes.add(participante);
      notifyListeners();
    }
  }

  void removerParticipante(String personalId) {
    participantes.removeWhere((p) => p.personalId == personalId);
    notifyListeners();
  }
  // -------------------------

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

    // Validación de respuestas completas
    if (respuestas.length < _items.length) {
      // Opcional: podrías permitir finalizar incompleto si es borrador, pero aquí pedimos todo
      _errorMessage = "Faltan respuestas en el checklist.";
      notifyListeners();
      return false;
    }

    _isSaving = true;
    notifyListeners();
    try {
      await _persistirDatos();
      // Aquí podrías agregar lógica para marcar la inspección como 'FINALIZADA' en BD
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
    // 1. Guardar Cabecera General
    if (_repo is LocalInspectionRepository) {
      await (_repo as LocalInspectionRepository).saveActividad(
        id: activityId,
        tipoActividad: tipoActividad,
        centroId: centroId,
        fecha: DateTime.now(),
      );
    }

    // 2. Guardar Respuestas del Checklist
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

    // 3. Guardar Fotos Generales
    for (var f in fotosGenerales) {
      await _repo.saveFoto(
        activityId: activityId,
        itemId: null,
        file: XFile(f.path),
        descripcion: 'General',
      );
    }

    // 4. GUARDAR DATOS ESPECÍFICOS DE BUCEO (NUEVO)
    if (tipoActividad == 'INSPECCION_BUCEO') {
      if (verificacionesBuceo != null) {
        await _repo.guardarVerificacionesBuceo(verificacionesBuceo!);
      }
      // Guardamos la lista SIEMPRE, para reflejar adiciones y borrados
      await _repo.guardarParticipantes(activityId, participantes);
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
