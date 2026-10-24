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
import '../../../sync/services/sync_service.dart';
import '../../data/repositories/local_merieux_repository.dart';
import '../../domain/models/merieux_visita.dart';

/// Controlador del submódulo "Merieux — Registro de Visita": mismo
/// encabezado que Merieux Extintores, pero con un checklist único opcional
/// (Sin checklist / Vehículos Livianos). Reutiliza el generador de PDF de
/// Hidroser ([HidroserPdfGeneratorService]), que ya está diseñado para ser
/// adaptable a cualquier encabezado + checklist + 1 firma.
class MerieuxVisitaFormController extends ChangeNotifier {
  final LocalMerieuxRepository _repo;
  final SyncService _sync;
  final Map<String, dynamic>? borradorInicial;

  MerieuxVisitaFormController({
    this.borradorInicial,
    LocalMerieuxRepository? repo,
    SyncService? sync,
  }) : _repo = repo ?? LocalMerieuxRepository(),
       _sync = sync ?? SyncService();

  bool isLoading = false;
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

  /// `false` = "Registro de Visita (Sin checklist)"; `true` = incluye el
  /// checklist de Vehículos Livianos (mismo banco que VISITA_R008).
  bool incluirChecklistVehiculos = false;

  Uint8List? signatureImage;

  List<FormularioItem> _checklistItems = [];
  List<FormularioItem> get checklistItems => _checklistItems;

  /// Preguntas: { 'id', 'pregunta', 'categoria', 'estado', 'observacion' }
  final List<Map<String, dynamic>> items = [];

  int _indexById(String id) =>
      items.indexWhere((m) => m['id'].toString() == id);

  String? respuestaDe(String id) {
    final i = _indexById(id);
    return i < 0 ? null : items[i]['estado'] as String?;
  }

  void setRespuestaById(String id, String estado) {
    final i = _indexById(id);
    if (i >= 0) {
      items[i]['estado'] = estado;
      notifyListeners();
    }
  }

  void setObservacionById(String id, String texto) {
    final i = _indexById(id);
    if (i >= 0) items[i]['observacion'] = texto;
  }

  Future<void> init() async {
    isLoading = true;
    notifyListeners();
    try {
      visitaId = (borradorInicial?['id'] as String?) ?? const Uuid().v4();
      _checklistItems = await _repo.getItemsChecklistVisita();

      await _cargarIdentidadProfesional();

      if (borradorInicial != null) {
        _aplicarBorrador(borradorInicial!);
      } else {
        horaInicioCtrl.text = DateFormat('HH:mm').format(DateTime.now());
      }

      if (incluirChecklistVehiculos) {
        _cargarPreguntas();
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

  void _cargarPreguntas() {
    items
      ..clear()
      ..addAll(
        _checklistItems.map(
          (i) => {
            'id': i.id,
            'pregunta': i.pregunta,
            'categoria': i.categoria,
            'estado': 'C',
            'observacion': '',
          },
        ),
      );
  }

  /// Cambia entre "sin checklist" y "con checklist de Vehículos Livianos".
  void toggleIncluirChecklist(bool value) {
    incluirChecklistVehiculos = value;
    if (value && items.isEmpty) {
      _cargarPreguntas();
    } else if (!value) {
      items.clear();
    }
    notifyListeners();
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

    final checklistTipo = b['checklist_tipo'] as String?;
    incluirChecklistVehiculos =
        checklistTipo == kMerieuxChecklistVehiculosLivianos;
    if (incluirChecklistVehiculos) {
      _cargarPreguntas();
      final respuestas = (b['respuestas'] as List?) ?? const [];
      for (final r in respuestas) {
        if (r is! Map) continue;
        final itemId = r['item_id']?.toString();
        if (itemId == null) continue;
        final i = items.indexWhere((m) => m['id'].toString() == itemId);
        if (i < 0) continue;
        items[i]['estado'] = (r['estado'] ?? items[i]['estado']).toString();
        items[i]['observacion'] = (r['observacion'] ?? '').toString();
      }
    }
  }

  void setSignatureImage(Uint8List bytes) {
    signatureImage = bytes;
    notifyListeners();
  }

  void setFecha(DateTime f) {
    fechaRealizacion = f;
    notifyListeners();
  }

  // --- BUILD MODEL / PDF ------------------------------------------------

  MerieuxVisita _buildModel({required String estadoFinal}) {
    return MerieuxVisita(
      id: visitaId,
      tipoActividad: kMerieuxTipoVisitas,
      checklistTipo: incluirChecklistVehiculos
          ? kMerieuxChecklistVehiculosLivianos
          : null,
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

    final checklistItems = items
        .map(
          (m) => HidroserChecklistItemDto(
            categoria: (m['categoria'] ?? 'General').toString(),
            pregunta: (m['pregunta'] ?? '').toString(),
            respuesta: (m['estado'] ?? 'C').toString(),
            observacion: (m['observacion'] ?? '').toString().isEmpty
                ? null
                : (m['observacion']).toString(),
          ),
        )
        .toList();

    return HidroserReportData(
      empresaProveedor: UserSession().empresaNombre ?? 'Merieux',
      tituloLista: incluirChecklistVehiculos
          ? 'Registro de Visita — Chequeo Vehículos Livianos'
          : 'Registro de Visita',
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
      await _repo.guardarVisita(v, _armarRespuestas(v.id));
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
      await _repo.guardarVisita(v, _armarRespuestas(v.id));
    } catch (e) {
      debugPrint('⚠️ Error autoguardando borrador Merieux Visita: $e');
    }
  }

  List<MerieuxRespuesta> _armarRespuestas(String visitaId) {
    if (!incluirChecklistVehiculos) return const [];
    return items
        .map(
          (m) => MerieuxRespuesta(
            id: const Uuid().v4(),
            visitaId: visitaId,
            itemId: m['id'].toString(),
            estado: (m['estado'] ?? 'C').toString(),
            observacion: (m['observacion'] ?? '').toString().isEmpty
                ? null
                : m['observacion'].toString(),
          ),
        )
        .toList();
  }

  /// Guarda definitivo (dispara correlativo en el trigger Supabase) y
  /// sincroniza.
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
      final pdfPath = '${dir.path}/merieux_visita_${v.id}.pdf';
      await File(pdfPath).writeAsBytes(pdfBytes);
      v.pdfPathLocal = pdfPath;

      await _repo.guardarVisita(v, _armarRespuestas(v.id));
      unawaited(_sync.sincronizarTodo());
      return true;
    } catch (e, st) {
      errorMessage = 'Error guardando la visita: $e';
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
