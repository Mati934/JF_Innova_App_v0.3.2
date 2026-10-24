import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/user_session.dart';
import '../../../../core/services/empresa_logo_service.dart';
import '../../../hidroser/domain/models/pdf/hidroser_report_data.dart';
import '../../../hidroser/services/hidroser_pdf_generator_service.dart';
import '../../../inspection/domain/models/formulario_item.dart';
import '../../../prosesso/domain/models/extintor_grid_controller.dart';
import '../../../prosesso/domain/models/prosesso_extintor_state.dart';
import '../../../sync/services/sync_service.dart';
import '../../data/repositories/local_merieux_repository.dart';
import '../../domain/models/merieux_visita.dart';

/// Controlador del submódulo "Merieux — Mantención de Extintores": mismo
/// encabezado que Merieux Visitas + grilla de N extintores con checklist de
/// 9 preguntas c/u (idéntico al módulo Prosesso, mismo banco de preguntas y
/// mismo modelo [ExtintorProsessoState]). Implementa [ExtintorGridController]
/// para reusar tal cual el widget `ProsessoExtintorCard` (misma UI que
/// Prosesso, sin duplicar código).
///
/// El PDF reusa [HidroserPdfGeneratorService]: cada extintor se renderiza
/// como una "categoría" propia del checklist (agrupación ya soportada por
/// ese generador), evitando duplicar un motor de PDF nuevo.
class MerieuxExtintoresFormController extends ChangeNotifier
    implements ExtintorGridController {
  final LocalMerieuxRepository _repo;
  final SyncService _sync;
  final Map<String, dynamic>? borradorInicial;

  MerieuxExtintoresFormController({
    this.borradorInicial,
    LocalMerieuxRepository? repo,
    SyncService? sync,
  }) : _repo = repo ?? LocalMerieuxRepository(),
       _sync = sync ?? SyncService();

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  late String visitaId;
  DateTime fechaRealizacion = DateTime.now();

  final regionCtrl = TextEditingController();
  final areaCtrl = TextEditingController();
  final jefaturaCtrl = TextEditingController();
  final origenCtrl = TextEditingController();
  final horaInicioCtrl = TextEditingController();
  final horaTerminoCtrl = TextEditingController();
  final correo1Ctrl = TextEditingController();
  final correo2Ctrl = TextEditingController();
  final observacionesCtrl = TextEditingController();

  /// Profesional/Fono/Correo son editables: la misma cuenta la puede usar
  /// más de una persona, así que se autocompletan como sugerencia (de la
  /// sesión) pero el usuario los puede corregir antes de guardar.
  final profesionalCtrl = TextEditingController();
  final fonoProfesionalCtrl = TextEditingController();
  final correoProfesionalCtrl = TextEditingController();

  /// Nombre de quién firma: se autocompleta con [profesionalCtrl] al cargar,
  /// pero es independiente (puede firmar alguien distinto de quien llenó el
  /// formulario).
  final firmaNombreCtrl = TextEditingController();

  Uint8List? signatureImage;

  List<ExtintorProsessoState> extintores = [];
  List<FormularioItem> _checklistItems = [];
  int get totalPuntosPorExtintor => _checklistItems.length;

  Future<void> init() async {
    isLoading = true;
    notifyListeners();
    try {
      visitaId = (borradorInicial?['id'] as String?) ?? const Uuid().v4();
      _checklistItems = await _repo.getItemsChecklistExtintores();

      await _cargarIdentidadProfesional();

      if (borradorInicial != null) {
        _aplicarBorrador(borradorInicial!);
        extintores = await _repo.getExtintoresPorVisita(
          visitaId,
          _checklistItems,
        );
      } else {
        horaInicioCtrl.text = DateFormat('HH:mm').format(DateTime.now());
      }

      if (extintores.isEmpty) {
        extintores = [
          ExtintorProsessoState.nuevo(numero: 1, items: _checklistItems),
        ];
      }
    } catch (e) {
      errorMessage = 'Error cargando formulario: $e';
      debugPrint('❌ $errorMessage');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _cargarIdentidadProfesional() async {
    String profesional = UserSession().nombreCompleto ?? '';
    String fono = '';
    String correo = UserSession().email ?? '';
    final userId = UserSession().userId;
    if (userId != null) {
      final userLocal = await _repo.getUsuarioLocal(userId);
      if (userLocal != null) {
        profesional = userLocal['nombre_completo']?.toString() ?? profesional;
        fono = userLocal['telefono']?.toString() ?? fono;
      }
    }
    profesionalCtrl.text = profesional;
    fonoProfesionalCtrl.text = fono;
    correoProfesionalCtrl.text = correo;
    firmaNombreCtrl.text = profesional;
  }

  void _aplicarBorrador(Map<String, dynamic> b) {
    profesionalCtrl.text = (b['profesional'] ?? profesionalCtrl.text)
        .toString();
    fonoProfesionalCtrl.text =
        (b['fono_profesional'] ?? fonoProfesionalCtrl.text).toString();
    correoProfesionalCtrl.text =
        (b['correo_profesional'] ?? correoProfesionalCtrl.text).toString();
    firmaNombreCtrl.text = (b['firma_nombre'] ?? profesionalCtrl.text)
        .toString();
    regionCtrl.text = (b['region'] ?? '').toString();
    areaCtrl.text = (b['area'] ?? '').toString();
    jefaturaCtrl.text = (b['jefatura_a_cargo'] ?? '').toString();
    origenCtrl.text = (b['origen_actividad'] ?? '').toString();
    horaInicioCtrl.text = (b['hora_inicio'] ?? '').toString();
    horaTerminoCtrl.text = (b['hora_termino'] ?? '').toString();
    correo1Ctrl.text = (b['correo_1'] ?? '').toString();
    correo2Ctrl.text = (b['correo_2'] ?? '').toString();
    observacionesCtrl.text = (b['observaciones'] ?? '').toString();

    final rawFecha = b['fecha_realizacion'];
    if (rawFecha != null) {
      fechaRealizacion =
          DateTime.tryParse(rawFecha.toString()) ?? DateTime.now();
    }
    signatureImage = b['signature_image'] is Uint8List
        ? b['signature_image'] as Uint8List
        : null;
  }

  void setSignatureImage(Uint8List bytes) {
    signatureImage = bytes;
    notifyListeners();
  }

  // --- GRILLA DE EXTINTORES --------------------------------------------

  void agregarExtintor() {
    extintores = [
      ...extintores,
      ExtintorProsessoState.nuevo(
        numero: extintores.length + 1,
        items: _checklistItems,
      ),
    ];
    notifyListeners();
  }

  @override
  void eliminarExtintor(int index) {
    if (extintores.length <= 1) return;
    final lista = List<ExtintorProsessoState>.from(extintores)..removeAt(index);
    // Renumerar
    extintores = [
      for (var i = 0; i < lista.length; i++)
        ExtintorProsessoState(
          localId: lista[i].localId,
          numero: i + 1,
          planta: lista[i].planta,
          ubicacion: lista[i].ubicacion,
          ubicacionSector: lista[i].ubicacionSector,
          ubicacion2: lista[i].ubicacion2,
          certificado: lista[i].certificado,
          anio: lista[i].anio,
          tipo: lista[i].tipo,
          peso: lista[i].peso,
          kg: lista[i].kg,
          fechaVencimiento: lista[i].fechaVencimiento,
          observaciones: lista[i].observaciones,
          fotoPaths: lista[i].fotoPaths,
          puntos: lista[i].puntos,
          expandido: lista[i].expandido,
        ),
    ];
    notifyListeners();
  }

  void _updateExt(
    int i,
    ExtintorProsessoState Function(ExtintorProsessoState) fn,
  ) {
    extintores = List.from(extintores)..[i] = fn(extintores[i]);
    notifyListeners();
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
  void responderPunto(int extIdx, String itemId, EstadoPuntoProsesso estado) {
    final e = extintores[extIdx];
    final pIdx = e.puntos.indexWhere((p) => p.itemId == itemId);
    if (pIdx == -1) return;
    extintores = List.from(extintores)
      ..[extIdx] = e.copyWith(
        puntos: List.from(e.puntos)
          ..[pIdx] = e.puntos[pIdx].copyWith(estado: estado),
      );
    notifyListeners();
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
    notifyListeners();
  }

  @override
  void clonarDelAnterior(int index) {
    if (index == 0) return;
    final origen = extintores[index - 1];
    extintores = List.from(extintores)
      ..[index] = extintores[index].clonarEstados(origen);
    notifyListeners();
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
    notifyListeners();
  }

  @override
  void toggleExpandido(int i) {
    extintores = List.from(extintores)
      ..[i] = extintores[i].copyWith(expandido: !extintores[i].expandido);
    notifyListeners();
  }

  // --- BUILD MODEL / PDF ------------------------------------------------

  MerieuxVisita _buildModel({required String estadoFinal}) {
    return MerieuxVisita(
      id: visitaId,
      tipoActividad: kMerieuxTipoExtintores,
      fechaRealizacion: fechaRealizacion,
      usuarioId: UserSession().userId,
      empresaId: UserSession().empresaId,
      profesional: profesionalCtrl.text.trim(),
      fonoProfesional: fonoProfesionalCtrl.text.trim(),
      correoProfesional: correoProfesionalCtrl.text.trim(),
      region: regionCtrl.text.trim(),
      area: areaCtrl.text.trim(),
      jefaturaACargo: jefaturaCtrl.text.trim(),
      origenActividad: origenCtrl.text.trim(),
      horaInicio: horaInicioCtrl.text.trim(),
      horaTermino: horaTerminoCtrl.text.trim(),
      correo1: correo1Ctrl.text.trim(),
      correo2: correo2Ctrl.text.trim(),
      observaciones: observacionesCtrl.text.trim(),
      estadoFinal: estadoFinal,
      firmaNombre: firmaNombreCtrl.text.trim(),
      signatureImage: signatureImage,
    );
  }

  HidroserReportData _buildReportData(MerieuxVisita v) {
    final fechaFmt = DateFormat('dd/MM/yyyy').format(v.fechaRealizacion);

    final headerFields = <HidroserHeaderField>[
      HidroserHeaderField(label: 'Región', valor: v.region ?? ''),
      HidroserHeaderField(label: 'Área', valor: v.area ?? ''),
      HidroserHeaderField(
        label: 'Jefatura a cargo',
        valor: v.jefaturaACargo ?? '',
      ),
      HidroserHeaderField(
        label: 'Origen de la actividad',
        valor: v.origenActividad ?? '',
      ),
      HidroserHeaderField(label: 'Hora de inicio', valor: v.horaInicio ?? ''),
      HidroserHeaderField(label: 'Hora de término', valor: v.horaTermino ?? ''),
      HidroserHeaderField(label: 'Correo 1', valor: v.correo1 ?? ''),
      if ((v.correo2 ?? '').isNotEmpty)
        HidroserHeaderField(label: 'Correo 2', valor: v.correo2!),
    ];

    // Cada extintor se renderiza como su propia "categoría" del checklist
    // (el generador de Hidroser agrupa por categoría con un título propio).
    final checklistItems = <HidroserChecklistItemDto>[];
    for (final ext in extintores) {
      final titulo = [
        'Extintor N°${ext.numero}',
        if ((ext.planta ?? '').isNotEmpty) 'Planta: ${ext.planta}',
        if ((ext.ubicacion ?? '').isNotEmpty) 'Ubicación: ${ext.ubicacion}',
        if ((ext.tipo ?? '').isNotEmpty) 'Tipo: ${ext.tipo}',
        if ((ext.certificado ?? '').isNotEmpty) 'Cert.: ${ext.certificado}',
        if ((ext.fechaVencimiento ?? '').isNotEmpty)
          'Vence: ${ext.fechaVencimiento}',
      ].join(' · ');

      for (final p in ext.puntos) {
        checklistItems.add(
          HidroserChecklistItemDto(
            categoria: titulo,
            pregunta: p.pregunta,
            respuesta: p.estado?.label ?? '-',
            observacion: (p.observacion ?? '').isEmpty ? null : p.observacion,
          ),
        );
      }
    }

    return HidroserReportData(
      empresaProveedor: UserSession().empresaNombre ?? 'Merieux',
      tituloLista: 'Mantención de Extintores',
      fecha: fechaFmt,
      correlativo: v.correlativo,
      profesional: v.profesional ?? '',
      fonoProfesional: v.fonoProfesional ?? '',
      correoProfesional: v.correoProfesional ?? '',
      headerFields: headerFields,
      checklistItems: checklistItems,
      observaciones: v.observaciones ?? '',
      firmas: [
        HidroserFirmaDto(
          rol: 'Profesional',
          nombre: v.firmaNombre?.isNotEmpty == true
              ? v.firmaNombre
              : v.profesional,
          imagen: v.signatureImage,
        ),
      ],
    );
  }

  Future<Uint8List> _generatePdf(HidroserReportData reportData) async {
    final fontReg = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final fontBold = await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');

    Uint8List? logoBytes;
    try {
      logoBytes = await EmpresaLogoService.instance.getLogoForActiveEmpresa(
        fallbackAsset: 'assets/images/LogoJFInnova2.png',
      );
    } catch (_) {}

    final params = HidroserPdfIsolateParams(
      data: reportData,
      fontRegular: fontReg.buffer.asUint8List(),
      fontBold: fontBold.buffer.asUint8List(),
      logoBytes: logoBytes,
    );
    return compute(generateHidroserPdfEntryPoint, params);
  }

  Future<void> previsualizarReporte(BuildContext context) async {
    isLoading = true;
    notifyListeners();
    try {
      final v = _buildModel(estadoFinal: 'En Progreso');
      final report = _buildReportData(v);
      final pdf = await _generatePdf(report);
      if (!context.mounted) return;
      await Printing.layoutPdf(onLayout: (_) async => pdf);
    } catch (e) {
      errorMessage = 'Error generando PDF: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> guardarBorrador() async {
    if (isSaving) return false;
    isSaving = true;
    notifyListeners();
    try {
      final v = _buildModel(estadoFinal: 'En Progreso');
      await _repo.guardarVisitaExtintores(v, extintores);
      return true;
    } catch (e) {
      errorMessage = 'Error guardando borrador: $e';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  /// Autoguardado silencioso (al salir/cerrar el formulario), sin tocar
  /// `isSaving`/`errorMessage` para no interferir con la navegación. Mismo
  /// criterio que el resto de los módulos de inspección: nunca se pierde el
  /// borrador al salir.
  Future<void> guardarBorradorSilencioso() async {
    try {
      final v = _buildModel(estadoFinal: 'En Progreso');
      await _repo.guardarVisitaExtintores(v, extintores);
    } catch (e) {
      debugPrint('⚠️ Error autoguardando borrador Merieux Extintores: $e');
    }
  }

  Future<bool> guardarDefinitivo() async {
    if (isSaving) return false;
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final v = _buildModel(estadoFinal: 'En Seguimiento');
      final report = _buildReportData(v);
      final pdfBytes = await _generatePdf(report);

      final dir = await getApplicationDocumentsDirectory();
      final pdfPath = '${dir.path}/merieux_extintores_${v.id}.pdf';
      await File(pdfPath).writeAsBytes(pdfBytes);
      v.pdfPathLocal = pdfPath;

      await _repo.guardarVisitaExtintores(v, extintores);
      unawaited(_sync.sincronizarTodo());
      return true;
    } catch (e, st) {
      errorMessage = 'Error guardando el registro: $e';
      debugPrint('❌ $errorMessage\n$st');
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    regionCtrl.dispose();
    areaCtrl.dispose();
    jefaturaCtrl.dispose();
    origenCtrl.dispose();
    horaInicioCtrl.dispose();
    horaTerminoCtrl.dispose();
    correo1Ctrl.dispose();
    correo2Ctrl.dispose();
    observacionesCtrl.dispose();
    profesionalCtrl.dispose();
    fonoProfesionalCtrl.dispose();
    correoProfesionalCtrl.dispose();
    firmaNombreCtrl.dispose();
    super.dispose();
  }
}
