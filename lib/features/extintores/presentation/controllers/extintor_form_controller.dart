import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'dart:typed_data';

import '../../../../shared/utils/debouncer.dart';
import '../../../inspection/domain/models/formulario_item.dart';
import '../../../sync/services/sync_service.dart';
import '../../data/repositories/local_extintor_repository.dart';
import '../../domain/models/extintor_state.dart';
import '../../domain/models/extintor_report_data.dart';
import '../../services/extintor_pdf_generator_service.dart';

class ExtintorFormController extends ChangeNotifier {
  bool _disposed = false;

  final _repository = LocalExtintorRepository();
  final _syncService = SyncService();
  final _debouncer = Debouncer(milliseconds: 1000);

  late final String _currentVisitId;

  // --- Estado general ---
  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  // --- Campos base del formulario ---
  final lugarCtrl = TextEditingController();
  final jefaturaCtrl = TextEditingController();
  TimeOfDay? timeInicio;
  TimeOfDay? timeTermino;
  DateTime fechaVisita = DateTime.now();

  String get fechaStr =>
      '${fechaVisita.day.toString().padLeft(2, '0')}-${fechaVisita.month.toString().padLeft(2, '0')}-${fechaVisita.year}';
  String get horaInicioStr => timeInicio != null
      ? '${timeInicio!.hour}:${timeInicio!.minute.toString().padLeft(2, '0')}'
      : '--:--';
  String get horaTerminoStr => timeTermino != null
      ? '${timeTermino!.hour}:${timeTermino!.minute.toString().padLeft(2, '0')}'
      : '--:--';

  // --- Historial autocomplete ---
  List<String> historialLugares = [];

  // --- Extintores ---
  List<ExtintorState> extintores = [];
  List<FormularioItem> _checklistItems = [];

  // Cuántos puntos tiene cada extintor (basado en items cargados)
  int get totalPuntosPorExtintor => _checklistItems.length;

  ExtintorFormController({Map<String, dynamic>? borradorInicial}) {
    if (borradorInicial != null) {
      _currentVisitId = borradorInicial['id'] as String;
      _cargarDatosEnUI(borradorInicial);
    } else {
      _currentVisitId = const Uuid().v4();
    }
    _init();
  }

  void _cargarDatosEnUI(Map<String, dynamic> data) {
    lugarCtrl.text = data['lugar_visita'] as String? ?? '';
    jefaturaCtrl.text = data['jefatura_a_cargo'] as String? ?? '';

    final fechaStr = data['fecha_realizacion'] as String?;
    if (fechaStr != null) {
      fechaVisita = DateTime.tryParse(fechaStr) ?? DateTime.now();
    }
    final hi = data['hora_inicio'] as String?;
    if (hi != null && hi != '--:--') {
      final p = hi.split(':');
      if (p.length == 2) {
        timeInicio = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
      }
    }
    final ht = data['hora_termino'] as String?;
    if (ht != null && ht != '--:--') {
      final p = ht.split(':');
      if (p.length == 2) {
        timeTermino = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
      }
    }
  }

  Future<void> _init() async {
    timeInicio ??= TimeOfDay.now();

    // 1. Cargar los 18 ítems del checklist
    _checklistItems = await _repository.getChecklistItems();

    // 2. Historial de lugares para autocomplete
    historialLugares = await _repository.getLugaresHistoricos();

    // 3. Si es un borrador, restaurar sus extintores
    if (extintores.isEmpty) {
      final rows = await _repository.getExtintoresPorVisita(
        _currentVisitId,
        _checklistItems,
      );
      if (rows.isNotEmpty) extintores = rows;
    }

    // 4. Si es nuevo, agregar el primer extintor vacío
    if (extintores.isEmpty && _checklistItems.isNotEmpty) {
      extintores = [ExtintorState.nuevo(numero: 1, items: _checklistItems)];
    }

    // 5. Activar listeners para auto-save
    lugarCtrl.addListener(_onFieldChanged);
    jefaturaCtrl.addListener(_onFieldChanged);

    isLoading = false;
    _safeNotify();
  }

  void _onFieldChanged() => _debouncer.run(guardarBorradorSilencioso);

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // ── GESTIÓN DE EXTINTORES ──────────────────────────────────────────────────

  void agregarExtintor() {
    if (_checklistItems.isEmpty) return;
    extintores = [
      ...extintores,
      ExtintorState.nuevo(
        numero: extintores.length + 1,
        items: _checklistItems,
      ),
    ];
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  void eliminarExtintor(int index) {
    if (extintores.length <= 1) return;
    final lista = List<ExtintorState>.from(extintores)..removeAt(index);
    extintores = List.generate(
      lista.length,
      (i) => ExtintorState(
        localId: lista[i].localId,
        numero: i + 1,
        matricula: lista[i].matricula,
        fotoPaths: lista[i].fotoPaths,
        puntos: lista[i].puntos,
        expandido: lista[i].expandido,
      ),
    );
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  void marcarTodoCumple(int index) {
    final e = extintores[index];
    extintores = List.from(extintores)
      ..[index] = e.copyWith(
        puntos: e.puntos
            .map((p) => p.copyWith(estado: EstadoExtintor.cumple))
            .toList(),
      );
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  void clonarDelAnterior(int index) {
    if (index == 0) return;
    final origen = extintores[index - 1];
    final destino = extintores[index];
    extintores = List.from(extintores)..[index] = destino.clonarEstados(origen);
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  void responderPunto(int extintorIndex, String itemId, EstadoExtintor estado) {
    final e = extintores[extintorIndex];
    final pIndex = e.puntos.indexWhere((p) => p.itemId == itemId);
    if (pIndex == -1) return;
    extintores = List.from(extintores)
      ..[extintorIndex] = e.copyWith(
        puntos: List.from(e.puntos)
          ..[pIndex] = e.puntos[pIndex].copyWith(estado: estado),
      );
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  void updateObservacion(int extintorIndex, String itemId, String obs) {
    final e = extintores[extintorIndex];
    final pIndex = e.puntos.indexWhere((p) => p.itemId == itemId);
    if (pIndex == -1) return;
    extintores = List.from(extintores)
      ..[extintorIndex] = e.copyWith(
        puntos: List.from(e.puntos)
          ..[pIndex] = e.puntos[pIndex].copyWith(observacion: obs),
      );
    // No notifyListeners aquí — el TextField maneja su propio estado
    _debouncer.run(guardarBorradorSilencioso);
  }

  void updateMatricula(int index, String matricula) {
    extintores = List.from(extintores)
      ..[index] = extintores[index].copyWith(matricula: matricula);
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  void addFotoExtintor(int index, String path) {
    final e = extintores[index];
    if (e.fotoPaths.contains(path)) return;
    extintores = List.from(extintores)
      ..[index] = e.copyWith(fotoPaths: [...e.fotoPaths, path]);
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  void removeFotoExtintor(int index, int fotoIndex) {
    final e = extintores[index];
    if (fotoIndex >= e.fotoPaths.length) return;
    final fotos = List<String>.from(e.fotoPaths)..removeAt(fotoIndex);
    extintores = List.from(extintores)..[index] = e.copyWith(fotoPaths: fotos);
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  void toggleExpandido(int index) {
    extintores = List.from(extintores)
      ..[index] = extintores[index].copyWith(
        expandido: !extintores[index].expandido,
      );
    _safeNotify();
  }

  // ── FECHA Y HORA ──────────────────────────────────────────────────────────

  Future<void> pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fechaVisita,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      fechaVisita = picked;
      _debouncer.run(guardarBorradorSilencioso);
      _safeNotify();
    }
  }

  Future<void> pickTime(BuildContext context, bool esInicio) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      if (esInicio)
        timeInicio = picked;
      else
        timeTermino = picked;
      _debouncer.run(guardarBorradorSilencioso);
      _safeNotify();
    }
  }

  // ── PERSISTENCIA ──────────────────────────────────────────────────────────

  Map<String, dynamic> _generarMapaVisita({String? pdfPathLocal}) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return {
      'id': _currentVisitId,
      'usuario_id': userId,
      'fecha_realizacion': fechaVisita.toIso8601String(),
      'lugar_visita': lugarCtrl.text.trim().toUpperCase(),
      'jefatura_a_cargo': jefaturaCtrl.text.trim(),
      'hora_inicio': horaInicioStr == '--:--' ? null : horaInicioStr,
      'hora_termino': horaTerminoStr == '--:--' ? null : horaTerminoStr,
      'pdf_path_local': pdfPathLocal,
    };
  }

  Future<void> guardarBorradorSilencioso() async {
    if (isSaving) return;
    try {
      await _repository.saveInspeccionExtintores(
        visitaMap: _generarMapaVisita(),
        extintores: extintores,
        esBorrador: true,
      );
      debugPrint('💾 Borrador extintores autoguardado');
    } catch (e) {
      debugPrint('⚠️ Error autoguardando extintores: $e');
    }
  }

  Future<bool> guardar(BuildContext context) async {
    if (isSaving) return false;
    if (lugarCtrl.text.trim().isEmpty) {
      errorMessage = '❌ Debes ingresar el lugar de inspección.';
      _safeNotify();
      return false;
    }

    isSaving = true;
    errorMessage = null;
    _safeNotify();

    try {
      final reportData = _buildReportData();
      final pdfBytes = await _generatePdfBytes(reportData);
      final directory = await getApplicationDocumentsDirectory();
      final pdfPath =
          '${directory.path}/Extintores_${lugarCtrl.text.trim().replaceAll(' ', '_')}_${_currentVisitId.substring(0, 5)}.pdf';
      await File(pdfPath).writeAsBytes(pdfBytes);

      await _repository.guardarPdfPath(_currentVisitId, pdfPath);
      await _repository.saveInspeccionExtintores(
        visitaMap: _generarMapaVisita(pdfPathLocal: pdfPath),
        extintores: extintores,
        esBorrador: false,
      );

      _syncService.sincronizarTodo().catchError((e) {
        debugPrint('Sync error silencioso extintores: $e');
        return 0;
      });
      return true;
    } catch (e) {
      errorMessage = 'Error guardando inspección: $e';
      return false;
    } finally {
      isSaving = false;
      _safeNotify();
    }
  }

  Future<void> previsualizarPdf(BuildContext context) async {
    isLoading = true;
    _safeNotify();
    try {
      final pdfBytes = await _generatePdfBytes(_buildReportData());
      if (context.mounted) {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: 'Extintores_${lugarCtrl.text.trim()}_$fechaStr.pdf',
        );
      }
    } catch (e) {
      errorMessage = 'Error generando PDF: $e';
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> eliminarBorrador() async {
    await _repository.eliminarBorrador(_currentVisitId);
    _syncService.sincronizarTodo().catchError((_) => 0);
  }

  // ── PDF ───────────────────────────────────────────────────────────────────

  ExtintorReportData _buildReportData() {
    return ExtintorReportData(
      region: '',
      centro: lugarCtrl.text.trim().toUpperCase(),
      profesional: '',
      fonoProfesional: '',
      correoProfesional: Supabase.instance.client.auth.currentUser?.email ?? '',
      jefaturaCargo: jefaturaCtrl.text.trim(),
      fecha: fechaStr,
      horaInicio: horaInicioStr,
      horaTermino: horaTerminoStr,
      extintores: extintores.map(ExtintorResumenItem.fromState).toList(),
    );
  }

  Future<Uint8List> _generatePdfBytes(ExtintorReportData data) async {
    final fontReg = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final fontBold = await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');

    Uint8List? logoBytes;
    try {
      final logoData = await rootBundle.load('assets/images/LogoJFInnova2.png');
      logoBytes = logoData.buffer.asUint8List();
    } catch (_) {}

    final params = ExtintorPdfIsolateParams(
      data: data,
      fontRegular: fontReg.buffer.asUint8List(),
      fontBold: fontBold.buffer.asUint8List(),
      logoBytes: logoBytes,
    );

    return await compute(generateExtintorPdfEntryPoint, params);
  }

  @override
  void dispose() {
    _disposed = true;
    _debouncer.cancel();
    lugarCtrl.dispose();
    jefaturaCtrl.dispose();
    super.dispose();
  }
}
