import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'dart:typed_data';

import '../../../../core/services/empresa_logo_service.dart';
import '../../../../core/services/user_session.dart';

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
  final empresaCtrl = TextEditingController();
  final regionCtrl = TextEditingController();
  final oficinaCtrl = TextEditingController();
  final lugarCtrl = TextEditingController();
  final jefaturaCtrl = TextEditingController();
  final origenCtrl = TextEditingController();
  final email1Ctrl = TextEditingController();
  final email2Ctrl = TextEditingController();
  final otroActividadCtrl = TextEditingController();
  final observacionesCtrl = TextEditingController();

  TimeOfDay? timeInicio;
  TimeOfDay? timeTermino;
  DateTime fechaVisita = DateTime.now();

  // --- Checkboxes actividades ---
  bool checkReunion = false;
  bool checkSenaletica = false;
  bool checkCapacitacion = false;
  bool checkVisitaSso = false;
  bool checkCharla = false;
  bool checkInvestigacion = false;
  bool checkInspeccionSso = false;
  bool checkObsConductual = false;
  bool checkOtro = false;

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
  List<String> historialRegiones = [];
  List<String> historialCentros = [];
  List<String> historialEmpresas = [];

  // --- Extintores ---
  List<ExtintorState> extintores = [];
  List<FormularioItem> _checklistItems = [];

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
    empresaCtrl.text = data['empresa'] as String? ?? '';
    regionCtrl.text = data['region'] as String? ?? '';
    oficinaCtrl.text = data['lugar_visita'] as String? ?? '';
    // Backward compat: si lugar_inspeccion existe, usarlo; si no, usar lugar_visita
    lugarCtrl.text =
        data['lugar_inspeccion'] as String? ??
        data['lugar_visita'] as String? ??
        '';
    jefaturaCtrl.text = data['jefatura_a_cargo'] as String? ?? '';
    origenCtrl.text = data['origen_visita'] as String? ?? '';
    email1Ctrl.text = data['email_empresa_1'] as String? ?? '';
    email2Ctrl.text = data['email_empresa_2'] as String? ?? '';
    otroActividadCtrl.text = data['otro_actividad_texto'] as String? ?? '';
    observacionesCtrl.text = data['apuntes_observaciones'] as String? ?? '';

    checkReunion = data['check_reunion'] == 1;
    checkSenaletica = data['check_instalacion_senaletica'] == 1;
    checkCapacitacion = data['check_capacitacion'] == 1;
    checkVisitaSso = data['check_visita_sso'] == 1;
    checkCharla = data['check_charla'] == 1;
    checkInvestigacion = data['check_investigacion_incidente'] == 1;
    checkInspeccionSso = data['check_inspeccion_sso'] == 1;
    checkObsConductual = data['check_obs_conductual'] == 1;
    checkOtro = data['check_otro'] == 1;

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

    _checklistItems = await _repository.getChecklistItems();

    historialLugares = await _repository.getLugaresHistoricos();
    historialRegiones = await _repository.getRegionesHistoricas();
    historialCentros = await _repository.getCentrosHistoricos();
    historialEmpresas = await _repository.getEmpresasHistoricas();

    if (extintores.isEmpty) {
      final rows = await _repository.getExtintoresPorVisita(
        _currentVisitId,
        _checklistItems,
      );
      if (rows.isNotEmpty) extintores = rows;
    }

    if (extintores.isEmpty && _checklistItems.isNotEmpty) {
      extintores = [ExtintorState.nuevo(numero: 1, items: _checklistItems)];
    }

    // Activar listeners para auto-save
    empresaCtrl.addListener(_onFieldChanged);
    regionCtrl.addListener(_onFieldChanged);
    oficinaCtrl.addListener(_onFieldChanged);
    lugarCtrl.addListener(_onFieldChanged);
    jefaturaCtrl.addListener(_onFieldChanged);
    origenCtrl.addListener(_onFieldChanged);
    email1Ctrl.addListener(_onFieldChanged);
    email2Ctrl.addListener(_onFieldChanged);
    otroActividadCtrl.addListener(_onFieldChanged);
    observacionesCtrl.addListener(_onFieldChanged);

    isLoading = false;
    _safeNotify();
  }

  void _onFieldChanged() => _debouncer.run(guardarBorradorSilencioso);

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // ── CHECKBOXES ──────────────────────────────────────────────────────────────

  void toggleCheck(String key, bool val) {
    switch (key) {
      case 'reunion':
        checkReunion = val;
        break;
      case 'senaletica':
        checkSenaletica = val;
        break;
      case 'capacitacion':
        checkCapacitacion = val;
        break;
      case 'visita_sso':
        checkVisitaSso = val;
        break;
      case 'charla':
        checkCharla = val;
        break;
      case 'investigacion':
        checkInvestigacion = val;
        break;
      case 'inspeccion_sso':
        checkInspeccionSso = val;
        break;
      case 'obs_conductual':
        checkObsConductual = val;
        break;
      case 'otro':
        checkOtro = val;
        break;
    }
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
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
        tipoExtintor: lista[i].tipoExtintor,
        pesoExtintor: lista[i].pesoExtintor,
        fechaUltimaMantencion: lista[i].fechaUltimaMantencion,
        fechaProximaMantencion: lista[i].fechaProximaMantencion,
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
    _debouncer.run(guardarBorradorSilencioso);
  }

  void updateMatricula(int index, String matricula) {
    extintores = List.from(extintores)
      ..[index] = extintores[index].copyWith(matricula: matricula);
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  void updateTipoExtintor(int index, String tipo) {
    extintores = List.from(extintores)
      ..[index] = extintores[index].copyWith(tipoExtintor: tipo);
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  void updatePesoExtintor(int index, String peso) {
    extintores = List.from(extintores)
      ..[index] = extintores[index].copyWith(pesoExtintor: peso);
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  void updateFechaUltimaMantencion(int index, String fecha) {
    extintores = List.from(extintores)
      ..[index] = extintores[index].copyWith(fechaUltimaMantencion: fecha);
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  void updateFechaProximaMantencion(int index, String fecha) {
    extintores = List.from(extintores)
      ..[index] = extintores[index].copyWith(fechaProximaMantencion: fecha);
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
      'empresa': empresaCtrl.text.trim(),
      'region': regionCtrl.text.trim().toUpperCase(),
      'lugar_visita': oficinaCtrl.text.trim().toUpperCase(),
      'lugar_inspeccion': lugarCtrl.text.trim().toUpperCase(),
      'jefatura_a_cargo': jefaturaCtrl.text.trim(),
      'origen_visita': origenCtrl.text.trim(),
      'hora_inicio': horaInicioStr == '--:--' ? null : horaInicioStr,
      'hora_termino': horaTerminoStr == '--:--' ? null : horaTerminoStr,
      'email_empresa_1': email1Ctrl.text.trim(),
      'email_empresa_2': email2Ctrl.text.trim(),
      'check_reunion': checkReunion ? 1 : 0,
      'check_instalacion_senaletica': checkSenaletica ? 1 : 0,
      'check_capacitacion': checkCapacitacion ? 1 : 0,
      'check_visita_sso': checkVisitaSso ? 1 : 0,
      'check_charla': checkCharla ? 1 : 0,
      'check_investigacion_incidente': checkInvestigacion ? 1 : 0,
      'check_inspeccion_sso': checkInspeccionSso ? 1 : 0,
      'check_obs_conductual': checkObsConductual ? 1 : 0,
      'check_otro': checkOtro ? 1 : 0,
      'otro_actividad_texto': otroActividadCtrl.text.trim(),
      'apuntes_observaciones': observacionesCtrl.text.trim(),
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
      errorMessage = 'Debes ingresar el lugar de inspección.';
      _safeNotify();
      return false;
    }

    isSaving = true;
    errorMessage = null;
    _safeNotify();

    try {
      final reportData = await _buildReportData();
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
      final pdfBytes = await _generatePdfBytes(await _buildReportData());
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

  Future<ExtintorReportData> _buildReportData() async {
    final user = Supabase.instance.client.auth.currentUser;
    String profesional = '';
    String fonoProfesional = '';
    String correoProfesional = user?.email ?? '';

    if (user != null) {
      try {
        final userLocal = await _repository.getUsuarioLocal(user.id);
        if (userLocal != null) {
          profesional = userLocal['nombre_completo']?.toString() ?? '';
          fonoProfesional = userLocal['telefono']?.toString() ?? '';
        }
      } catch (_) {}
    }

    return ExtintorReportData(
      empresaProveedor:
          (UserSession().empresaNombre ?? 'JF INNOVA').toUpperCase(),
      empresa: empresaCtrl.text.trim(),
      region: regionCtrl.text.trim().toUpperCase(),
      oficina: oficinaCtrl.text.trim().toUpperCase(),
      lugarInspeccion: lugarCtrl.text.trim().toUpperCase(),
      profesional: profesional,
      fonoProfesional: fonoProfesional,
      correoProfesional: correoProfesional,
      jefaturaCargo: jefaturaCtrl.text.trim(),
      origenVisita: origenCtrl.text.trim(),
      fecha: fechaStr,
      horaInicio: horaInicioStr,
      horaTermino: horaTerminoStr,
      emailEmpresa1: email1Ctrl.text.trim(),
      emailEmpresa2: email2Ctrl.text.trim(),
      checkReunion: checkReunion,
      checkSenaletica: checkSenaletica,
      checkCapacitacion: checkCapacitacion,
      checkVisitaSso: checkVisitaSso,
      checkCharla: checkCharla,
      checkInvestigacion: checkInvestigacion,
      checkInspeccionSso: checkInspeccionSso,
      checkObsConductual: checkObsConductual,
      checkOtro: checkOtro,
      otroActividadTexto: otroActividadCtrl.text.trim(),
      apuntesObservaciones: observacionesCtrl.text.trim(),
      extintores: extintores.map(ExtintorResumenItem.fromState).toList(),
    );
  }

  Future<Uint8List> _generatePdfBytes(ExtintorReportData data) async {
    final fontReg = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final fontBold = await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');

    Uint8List? logoBytes;
    try {
      logoBytes = await EmpresaLogoService.instance.getLogoForActiveEmpresa(
        fallbackAsset: 'assets/images/LogoJFInnova2.png',
      );
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
    empresaCtrl.dispose();
    regionCtrl.dispose();
    oficinaCtrl.dispose();
    lugarCtrl.dispose();
    jefaturaCtrl.dispose();
    origenCtrl.dispose();
    email1Ctrl.dispose();
    email2Ctrl.dispose();
    otroActividadCtrl.dispose();
    observacionesCtrl.dispose();
    super.dispose();
  }
}
