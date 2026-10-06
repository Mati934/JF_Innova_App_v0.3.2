import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/utils/debouncer.dart';
import '../../../inspection/domain/models/formulario_item.dart';
import '../../../sync/services/sync_service.dart';
import '../../data/repositories/local_prosesso_repository.dart';
import '../../domain/models/extintor_grid_controller.dart';
import '../../domain/models/prosesso_extintor_state.dart';
import '../../domain/models/prosesso_report_data.dart';
import '../../services/prosesso_pdf_service.dart';

class ProsessoFormController extends ChangeNotifier
    implements ExtintorGridController {
  bool _disposed = false;

  final _repository = LocalProsessoRepository();
  final _syncService = SyncService();
  final _debouncer = Debouncer(milliseconds: 1000);

  late final String _currentVisitId;

  bool isLoading = true;
  bool isSaving = false;

  /// Una vez finalizado, ignoramos cualquier autoguardado pendiente del
  /// debouncer para no revertir `estado_final` ni borrar `pdf_path_local`.
  bool _isFinalized = false;
  String? errorMessage;

  // Cabecera
  final clienteCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();
  final certNumeroCtrl = TextEditingController();
  DateTime fechaServicio = DateTime.now();

  int? _certCorrelativo;
  int? _certAnio;

  // Firma digital
  final signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  Uint8List? signatureImage;

  String get fechaStr =>
      '${fechaServicio.day.toString().padLeft(2, '0')}-${fechaServicio.month.toString().padLeft(2, '0')}-${fechaServicio.year}';

  // Extintores
  List<ExtintorProsessoState> extintores = [];
  List<FormularioItem> _checklistItems = [];

  String get currentVisitId => _currentVisitId;
  int get totalPuntosPorExtintor => _checklistItems.length;

  ProsessoFormController({Map<String, dynamic>? borradorInicial}) {
    if (borradorInicial != null) {
      _currentVisitId = borradorInicial['id'] as String;
      _cargarDatosEnUI(borradorInicial);
    } else {
      _currentVisitId = const Uuid().v4();
    }
    _init();
  }

  void _cargarDatosEnUI(Map<String, dynamic> data) {
    clienteCtrl.text = data['cliente_nombre'] as String? ?? '';
    direccionCtrl.text = data['cliente_direccion'] as String? ?? '';
    certNumeroCtrl.text = data['cert_numero'] as String? ?? '';
    _certCorrelativo = data['cert_correlativo'] as int?;
    _certAnio = data['cert_anio'] as int?;

    final sig = data['signature_image'];
    if (sig is Uint8List) signatureImage = sig;

    final fechaSrv = data['fecha_servicio'] as String?;
    if (fechaSrv != null) {
      fechaServicio = DateTime.tryParse(fechaSrv) ?? DateTime.now();
    } else {
      final fr = data['fecha_realizacion'] as String?;
      if (fr != null) fechaServicio = DateTime.tryParse(fr) ?? DateTime.now();
    }
  }

  Future<void> _init() async {
    _checklistItems = await _repository.getChecklistItems();

    if (_checklistItems.isEmpty) {
      errorMessage =
          'No se encontraron las preguntas de checklist. Ejecutá la migración Supabase y sincronizá.';
      isLoading = false;
      _safeNotify();
      return;
    }

    // Cargar extintores existentes (borrador)
    final rows = await _repository.getExtintoresPorVisita(
      _currentVisitId,
      _checklistItems,
    );
    if (rows.isNotEmpty) extintores = rows;

    // Sugerir Nº cert si está vacío
    if (certNumeroCtrl.text.trim().isEmpty) {
      certNumeroCtrl.text = await _repository.siguienteCertNumero(
        fechaServicio.year,
      );
    }

    if (extintores.isEmpty) {
      extintores = [
        ExtintorProsessoState.nuevo(numero: 1, items: _checklistItems),
      ];
    }

    clienteCtrl.addListener(_onFieldChanged);
    direccionCtrl.addListener(_onFieldChanged);
    certNumeroCtrl.addListener(_onFieldChanged);

    isLoading = false;
    _safeNotify();
  }

  void setSignatureImage(Uint8List bytes) {
    signatureImage = bytes;
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  void clearSignature() {
    signatureController.clear();
    signatureImage = null;
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  void _onFieldChanged() => _debouncer.run(guardarBorradorSilencioso);

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // ── EXTINTORES ────────────────────────────────────────────────────────────

  void agregarExtintor() {
    final nuevo = ExtintorProsessoState.nuevo(
      numero: extintores.length + 1,
      items: _checklistItems,
    );
    extintores = [...extintores, nuevo];
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  @override
  void duplicarExtintor(int index) {
    final origen = extintores[index];
    final nuevo =
        ExtintorProsessoState.nuevo(
          numero: extintores.length + 1,
          items: _checklistItems,
        ).copyWith(
          planta: origen.planta,
          ubicacion: origen.ubicacion,
          ubicacionSector: origen.ubicacionSector,
          ubicacion2: origen.ubicacion2,
          anio: origen.anio,
          tipo: origen.tipo,
          peso: origen.peso,
          kg: origen.kg,
          fechaVencimiento: origen.fechaVencimiento,
        );
    extintores = [...extintores, nuevo];
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  @override
  void eliminarExtintor(int index) {
    if (extintores.length <= 1) return;
    final lista = List<ExtintorProsessoState>.from(extintores)..removeAt(index);
    extintores = List.generate(lista.length, (i) {
      final e = lista[i];
      return ExtintorProsessoState(
        localId: e.localId,
        numero: i + 1,
        planta: e.planta,
        ubicacion: e.ubicacion,
        ubicacionSector: e.ubicacionSector,
        ubicacion2: e.ubicacion2,
        certificado: e.certificado,
        anio: e.anio,
        tipo: e.tipo,
        peso: e.peso,
        kg: e.kg,
        fechaVencimiento: e.fechaVencimiento,
        observaciones: e.observaciones,
        fotoPaths: e.fotoPaths,
        puntos: e.puntos,
        expandido: e.expandido,
      );
    });
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  @override
  void marcarTodoCumple(int index) {
    final e = extintores[index];
    extintores = List.from(extintores)
      ..[index] = e.copyWith(
        puntos: e.puntos
            .map((p) => p.copyWith(estado: EstadoPuntoProsesso.cumple))
            .toList(),
      );
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  @override
  void clonarDelAnterior(int index) {
    if (index == 0) return;
    final origen = extintores[index - 1];
    extintores = List.from(extintores)
      ..[index] = extintores[index].clonarEstados(origen);
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  @override
  void responderPunto(int extIdx, String itemId, EstadoPuntoProsesso estado) {
    final e = extintores[extIdx];
    final pIdx = e.puntos.indexWhere((p) => p.itemId == itemId);
    if (pIdx == -1) return;
    extintores = List.from(extintores)
      ..[extIdx] = e.copyWith(
        puntos: List.from(e.puntos)
          ..[pIdx] = e.puntos[pIdx].copyWith(estado: estado),
      );
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  // Update field helpers
  void _updateExt(
    int i,
    ExtintorProsessoState Function(ExtintorProsessoState) fn,
  ) {
    extintores = List.from(extintores)..[i] = fn(extintores[i]);
    _debouncer.run(guardarBorradorSilencioso);
    _safeNotify();
  }

  @override
  void updatePlanta(int i, String v) =>
      _updateExt(i, (e) => e.copyWith(planta: v));
  @override
  void updateUbicacion(int i, String v) =>
      _updateExt(i, (e) => e.copyWith(ubicacion: v));
  @override
  void updateSector(int i, String v) =>
      _updateExt(i, (e) => e.copyWith(ubicacionSector: v));
  @override
  void updateUbic2(int i, String v) =>
      _updateExt(i, (e) => e.copyWith(ubicacion2: v));
  @override
  void updateCertificado(int i, String v) =>
      _updateExt(i, (e) => e.copyWith(certificado: v));
  @override
  void updateAnio(int i, String v) =>
      _updateExt(i, (e) => e.copyWith(anio: int.tryParse(v)));
  @override
  void updateTipo(int i, String v) => _updateExt(i, (e) => e.copyWith(tipo: v));
  @override
  void updatePeso(int i, String v) => _updateExt(i, (e) => e.copyWith(peso: v));
  @override
  void updateKg(int i, String v) => _updateExt(i, (e) => e.copyWith(kg: v));
  @override
  void updateFechaVenc(int i, String v) =>
      _updateExt(i, (e) => e.copyWith(fechaVencimiento: v));
  @override
  void updateObservaciones(int i, String v) =>
      _updateExt(i, (e) => e.copyWith(observaciones: v));

  @override
  void toggleExpandido(int i) {
    extintores = List.from(extintores)
      ..[i] = extintores[i].copyWith(expandido: !extintores[i].expandido);
    _safeNotify();
  }

  Future<void> pickFechaServicio(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fechaServicio,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      fechaServicio = picked;
      _debouncer.run(guardarBorradorSilencioso);
      _safeNotify();
    }
  }

  // ── PERSISTENCIA ──────────────────────────────────────────────────────────

  Map<String, dynamic> _generarMapaVisita({
    String? pdfPathLocal,
    String? pdfCertPathLocal,
  }) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return {
      'id': _currentVisitId,
      'usuario_id': userId,
      'fecha_realizacion': fechaServicio.toIso8601String(),
      'fecha_servicio': fechaServicio.toIso8601String(),
      'empresa': 'Prosesso',
      'lugar_visita': clienteCtrl.text.trim(),
      'lugar_inspeccion': clienteCtrl.text.trim(),
      'cliente_nombre': clienteCtrl.text.trim(),
      'cliente_direccion': direccionCtrl.text.trim(),
      'cert_numero': certNumeroCtrl.text.trim(),
      'cert_anio': _certAnio,
      'cert_correlativo': _certCorrelativo,
      'pdf_path_local': pdfPathLocal,
      'pdf_certificado_path_local': pdfCertPathLocal,
      'signature_image': signatureImage,
    };
  }

  Future<void> guardarBorradorSilencioso() async {
    if (isSaving) return;
    if (_isFinalized) {
      debugPrint('🚫 Autoguardado PROSESSO ignorado: ya finalizado');
      return;
    }
    try {
      await _repository.saveServicio(
        visitaMap: _generarMapaVisita(),
        extintores: extintores,
        esBorrador: true,
      );
      debugPrint('💾 Borrador PROSESSO autoguardado');
    } catch (e) {
      debugPrint('⚠️ Error autoguardando PROSESSO: $e');
    }
  }

  Future<bool> guardar(BuildContext context) async {
    if (isSaving) return false;
    if (clienteCtrl.text.trim().isEmpty) {
      errorMessage = 'Debes ingresar el cliente.';
      _safeNotify();
      return false;
    }

    isSaving = true;
    errorMessage = null;
    // Bloqueamos cualquier autoguardado pendiente o futuro para evitar
    // pisar el registro recién finalizado (estado_final + pdf_path_local).
    _isFinalized = true;
    _debouncer.cancel();
    _safeNotify();

    try {
      final reportData = await _buildReportData();
      debugPrint(
        '🟢 PROSESSO finalize: report data lista (${extintores.length} extintores)',
      );
      final bundle = await _generatePdfBundle(reportData);
      debugPrint(
        '🟢 PROSESSO finalize: PDFs generados (registro=${bundle.registroBytes.length}B, cert=${bundle.certificadoBytes.length}B)',
      );

      final dir = await getApplicationDocumentsDirectory();
      final tag = clienteCtrl.text.trim().replaceAll(' ', '_');
      final shortId = _currentVisitId.substring(0, 5);
      final regPath = '${dir.path}/PROSESSO_Registro_${tag}_$shortId.pdf';
      final certPath = '${dir.path}/PROSESSO_Certificado_${tag}_$shortId.pdf';
      await Future.wait([
        File(regPath).writeAsBytes(bundle.registroBytes),
        File(certPath).writeAsBytes(bundle.certificadoBytes),
      ]);
      debugPrint('🟢 PROSESSO finalize: PDFs escritos en disco');

      await _repository.saveServicio(
        visitaMap: _generarMapaVisita(
          pdfPathLocal: regPath,
          pdfCertPathLocal: certPath,
        ),
        extintores: extintores,
        esBorrador: false,
      );
      debugPrint('🟢 PROSESSO finalize: registro persistido en SQLite');

      _syncService.sincronizarTodo().catchError((e) {
        debugPrint('Sync error PROSESSO: $e');
        return 0;
      });
      return true;
    } catch (e, st) {
      debugPrint('❌ PROSESSO finalize ERROR: $e');
      debugPrint('Stack: $st');
      errorMessage = 'Error guardando servicio: $e';
      // Permitimos reintentar finalizar si algo fall\u00f3.
      _isFinalized = false;
      return false;
    } finally {
      isSaving = false;
      _safeNotify();
    }
  }

  Future<void> previsualizarRegistro(BuildContext context) =>
      _previsualizar(context, registro: true);

  Future<void> previsualizarCertificado(BuildContext context) =>
      _previsualizar(context, registro: false);

  Future<void> _previsualizar(
    BuildContext context, {
    required bool registro,
  }) async {
    isSaving = true;
    _safeNotify();
    try {
      debugPrint(
        '🟡 PROSESSO preview (${registro ? "registro" : "certificado"}): generando…',
      );
      final bundle = await _generatePdfBundle(await _buildReportData());
      final bytes = registro ? bundle.registroBytes : bundle.certificadoBytes;
      debugPrint('🟢 PROSESSO preview: bytes=${bytes.length}');
      if (context.mounted) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name:
              '${registro ? "Registro" : "Certificado"}_${clienteCtrl.text.trim()}_$fechaStr.pdf',
        );
      }
    } catch (e, st) {
      debugPrint('❌ PROSESSO preview ERROR: $e');
      debugPrint('Stack: $st');
      errorMessage = 'Error generando PDF: $e';
    } finally {
      isSaving = false;
      _safeNotify();
    }
  }

  Future<void> eliminarBorrador() async {
    await _repository.eliminarBorrador(_currentVisitId);
    _syncService.sincronizarTodo().catchError((_) => 0);
  }

  Future<ProsessoReportData> _buildReportData() async {
    final user = Supabase.instance.client.auth.currentUser;
    String realizadoPor = '';
    if (user != null) {
      try {
        final u = await _repository.getUsuarioLocal(user.id);
        realizadoPor = u?['nombre_completo']?.toString() ?? user.email ?? '';
      } catch (_) {
        realizadoPor = user.email ?? '';
      }
    }

    return ProsessoReportData(
      visitaId: _currentVisitId,
      certNumero: certNumeroCtrl.text.trim(),
      fechaServicio: fechaStr,
      clienteNombre: clienteCtrl.text.trim(),
      clienteDireccion: direccionCtrl.text.trim(),
      realizadoPor: realizadoPor,
      fechaRegistro: fechaStr,
      extintores: extintores.map(ExtintorProsessoResumen.fromState).toList(),
      signatureBytes: signatureImage,
    );
  }

  Future<ProsessoPdfBundle> _generatePdfBundle(ProsessoReportData data) async {
    final params = await ProsessoPdfAssets.build(data);
    return await compute(generateProsessoPdfsEntryPoint, params);
  }

  @override
  void dispose() {
    _disposed = true;
    _debouncer.cancel();
    clienteCtrl.dispose();
    direccionCtrl.dispose();
    certNumeroCtrl.dispose();
    signatureController.dispose();
    super.dispose();
  }
}
