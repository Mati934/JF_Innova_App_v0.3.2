import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../../../core/services/user_session.dart';
import '../../../../core/services/empresa_logo_service.dart';
import '../../../inspection/domain/models/formulario_item.dart';
import '../../../sync/services/sync_service.dart';
import '../../data/repositories/local_hidroser_repository.dart';
import '../../domain/models/hidroser_inspeccion.dart';
import '../../domain/models/hidroser_lista.dart';
import '../../domain/models/pdf/hidroser_report_data.dart';
import '../../services/hidroser_pdf_generator_service.dart';

/// Controlador del formulario de una inspección Hidroser.
///
/// Carga las preguntas asociadas a la lista, mantiene el estado de las
/// respuestas, gestiona dos firmas (supervisor / operador) y genera el PDF
/// usando [HidroserPdfGeneratorService] en un isolate.
class HidroserFormController extends ChangeNotifier {
  final HidroserLista lista;
  final LocalHidroserRepository _repo;
  final SyncService _sync;

  /// Si se pasa, indica que el formulario fue abierto desde un borrador
  /// previamente guardado en la tabla `hidroser_inspecciones_pendientes`.
  /// Mapa con las mismas columnas + clave `respuestas` con la lista de
  /// respuestas asociadas.
  final Map<String, dynamic>? borradorInicial;

  HidroserFormController({
    required this.lista,
    this.borradorInicial,
    LocalHidroserRepository? repo,
    SyncService? sync,
  }) : _repo = repo ?? LocalHidroserRepository(),
       _sync = sync ?? SyncService();

  // --- ESTADO ---------------------------------------------------------
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  late String inspeccionId;
  DateTime fechaRealizacion = DateTime.now();
  final TextEditingController quienInspeccionaCtrl = TextEditingController();
  final TextEditingController observacionesCtrl = TextEditingController();
  final TextEditingController firmaSupervisorNombreCtrl =
      TextEditingController();
  final TextEditingController firmaOperadorNombreCtrl = TextEditingController();

  /// Controllers de los campos extra (clave -> controller).
  final Map<String, TextEditingController> camposExtraCtrls = {};

  /// Firmas embebidas como PNG.
  Uint8List? firmaSupervisorImage;
  Uint8List? firmaOperadorImage;

  /// Foto asociada a cada pregunta del checklist (itemId → File).
  final Map<String, File> fotosPorPregunta = {};

  /// Galería general de la inspección.
  List<File> fotosGenerales = [];

  final SignatureController signatureSupervisor = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
  );
  final SignatureController signatureOperador = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
  );

  /// Preguntas del checklist agrupadas con su respuesta actual.
  /// Cada item: { 'id', 'pregunta', 'categoria', 'estado', 'observacion' }
  final List<Map<String, dynamic>> items = [];

  /// Vista tipada de los items para reusar widgets de checklist
  /// (`QuestionCard` / `CategoryHeader`).
  List<FormularioItem> get formularioItems => items
      .map(
        (m) => FormularioItem(
          id: m['id'].toString(),
          pregunta: (m['pregunta'] ?? '').toString(),
          categoria: (m['categoria'] ?? 'General').toString(),
          criticidad: (m['criticidad'] ?? 'Tolerable').toString(),
        ),
      )
      .toList();

  /// Agrupa las preguntas por categoría preservando el orden de aparición.
  Map<String, List<FormularioItem>> agruparPorCategoria() {
    final map = <String, List<FormularioItem>>{};
    for (final item in formularioItems) {
      map.putIfAbsent(item.categoria, () => []).add(item);
    }
    return map;
  }

  int _indexById(String id) =>
      items.indexWhere((m) => m['id'].toString() == id);

  String? respuestaDe(String id) {
    final i = _indexById(id);
    return i < 0 ? null : items[i]['estado'] as String?;
  }

  String? observacionDe(String id) {
    final i = _indexById(id);
    return i < 0 ? null : items[i]['observacion'] as String?;
  }

  String criticidadDe(String id) {
    final i = _indexById(id);
    if (i < 0) return 'Tolerable';
    return (items[i]['criticidad'] ?? 'Tolerable').toString();
  }

  void setRespuestaById(String id, String estado) {
    final i = _indexById(id);
    if (i >= 0) setRespuesta(i, estado);
  }

  void setObservacionById(String id, String texto) {
    final i = _indexById(id);
    if (i >= 0) setObservacion(i, texto);
  }

  void setCriticidadById(String id, String criticidad) {
    final i = _indexById(id);
    if (i >= 0) setCriticidad(i, criticidad);
  }

  Future<void> init() async {
    isLoading = true;
    notifyListeners();
    try {
      inspeccionId = (borradorInicial?['id'] as String?) ?? const Uuid().v4();
      quienInspeccionaCtrl.text = UserSession().nombreCompleto ?? '';

      for (final def in lista.camposExtra) {
        camposExtraCtrls[def.clave] = TextEditingController();
      }

      final rawItems = await _repo.getItemsForLista(lista);
      items
        ..clear()
        ..addAll(
          rawItems.map(
            (r) => {
              'id': r['id'],
              'pregunta': r['pregunta'] ?? r['texto'] ?? '',
              'categoria': r['categoria'] ?? 'General',
              'estado': 'C',
              'observacion': '',
              'criticidad': null,
            },
          ),
        );

      if (borradorInicial != null) {
        _aplicarBorrador(borradorInicial!);
      }
    } catch (e) {
      errorMessage = 'Error cargando lista: $e';
      debugPrint('❌ $errorMessage');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Vuelca los datos de un borrador previo sobre el estado actual del form.
  /// Tolera campos faltantes (parseo defensivo).
  void _aplicarBorrador(Map<String, dynamic> b) {
    quienInspeccionaCtrl.text = (b['quien_inspecciona'] ?? '').toString();
    observacionesCtrl.text = (b['observaciones'] ?? '').toString();
    firmaSupervisorNombreCtrl.text = (b['firma_supervisor_nombre'] ?? '')
        .toString();
    firmaOperadorNombreCtrl.text = (b['firma_operador_nombre'] ?? '')
        .toString();

    final rawFecha = b['fecha_realizacion'];
    if (rawFecha != null) {
      try {
        fechaRealizacion = DateTime.parse(rawFecha.toString());
      } catch (_) {}
    }

    final rawExtra = b['campos_extra'];
    Map<String, dynamic> extraMap = const {};
    if (rawExtra is String && rawExtra.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawExtra);
        if (decoded is Map<String, dynamic>) extraMap = decoded;
      } catch (_) {}
    } else if (rawExtra is Map<String, dynamic>) {
      extraMap = rawExtra;
    }
    extraMap.forEach((k, v) {
      final c = camposExtraCtrls[k];
      if (c != null) c.text = (v ?? '').toString();
    });

    firmaSupervisorImage = b['firma_supervisor_image'] is Uint8List
        ? b['firma_supervisor_image'] as Uint8List
        : null;
    firmaOperadorImage = b['firma_operador_image'] is Uint8List
        ? b['firma_operador_image'] as Uint8List
        : null;

    final respuestas = (b['respuestas'] as List?) ?? const [];
    for (final r in respuestas) {
      if (r is! Map) continue;
      final itemId = r['item_id']?.toString();
      if (itemId == null) continue;
      final i = items.indexWhere((m) => m['id'].toString() == itemId);
      if (i < 0) continue;
      items[i]['estado'] = (r['estado'] ?? items[i]['estado']).toString();
      items[i]['observacion'] = (r['observacion'] ?? '').toString();
      items[i]['criticidad'] = r['criticidad']?.toString();
    }
  }

  // --- ACCIONES UI ----------------------------------------------------

  void setRespuesta(int index, String estado) {
    items[index]['estado'] = estado;
    notifyListeners();
  }

  void setObservacion(int index, String texto) {
    items[index]['observacion'] = texto;
  }

  void setCriticidad(int index, String? criticidad) {
    items[index]['criticidad'] = criticidad;
    notifyListeners();
  }

  void setFirmaSupervisorImage(Uint8List bytes) {
    firmaSupervisorImage = bytes;
    notifyListeners();
  }

  void setFirmaOperadorImage(Uint8List bytes) {
    firmaOperadorImage = bytes;
    notifyListeners();
  }

  void setFotoPregunta(String itemId, File foto) {
    fotosPorPregunta[itemId] = foto;
    notifyListeners();
  }

  void setFotosGenerales(List<File> fotos) {
    fotosGenerales = fotos;
    notifyListeners();
  }

  void setFecha(DateTime f) {
    fechaRealizacion = f;
    notifyListeners();
  }

  // --- BUILD MODEL ----------------------------------------------------

  HidroserInspeccion _buildInspeccionModel({required String estadoFinal}) {
    final camposExtra = <String, String>{};
    for (final def in lista.camposExtra) {
      final v = (camposExtraCtrls[def.clave]?.text ?? '').trim();
      if (v.isNotEmpty) camposExtra[def.clave] = v;
    }

    return HidroserInspeccion(
      id: inspeccionId,
      listaCodigo: lista.codigo,
      fechaRealizacion: fechaRealizacion,
      usuarioId: UserSession().userId,
      empresaId: UserSession().empresaId,
      quienInspecciona: quienInspeccionaCtrl.text.trim(),
      observaciones: observacionesCtrl.text.trim(),
      camposExtra: camposExtra,
      firmaSupervisorNombre: firmaSupervisorNombreCtrl.text.trim().isEmpty
          ? null
          : firmaSupervisorNombreCtrl.text.trim(),
      firmaOperadorNombre: firmaOperadorNombreCtrl.text.trim().isEmpty
          ? null
          : firmaOperadorNombreCtrl.text.trim(),
      firmaSupervisorImage: firmaSupervisorImage,
      firmaOperadorImage: firmaOperadorImage,
      estadoFinal: estadoFinal,
    );
  }

  HidroserReportData _buildReportData(HidroserInspeccion insp) {
    final fechaFmt = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(insp.fechaRealizacion);

    final headerFields = <HidroserHeaderField>[
      HidroserHeaderField(
        label: 'Quien realiza la inspección',
        valor: insp.quienInspecciona ?? '',
      ),
      for (final def in lista.camposExtra)
        if ((insp.camposExtra[def.clave] ?? '').isNotEmpty)
          HidroserHeaderField(
            label: def.label,
            valor: insp.camposExtra[def.clave]!,
          ),
    ];

    final checklistItems = items
        .map(
          (m) => HidroserChecklistItemDto(
            categoria: (m['categoria'] ?? 'General').toString(),
            pregunta: (m['pregunta'] ?? '').toString(),
            respuesta: (m['estado'] ?? 'C').toString(),
            criticidad: m['criticidad']?.toString(),
            observacion: (m['observacion'] ?? '').toString().isEmpty
                ? null
                : (m['observacion']).toString(),
            fotoPath: () {
              final f = fotosPorPregunta[m['id']?.toString() ?? ''];
              if (f != null && f.existsSync()) return f.path;
              return null;
            }(),
          ),
        )
        .toList();

    final firmas = <HidroserFirmaDto>[
      HidroserFirmaDto(
        rol: 'Supervisor de turno',
        nombre: insp.firmaSupervisorNombre,
        imagen: insp.firmaSupervisorImage,
      ),
      HidroserFirmaDto(
        rol: 'Operador de grúa',
        nombre: insp.firmaOperadorNombre,
        imagen: insp.firmaOperadorImage,
      ),
    ];

    // Para el PDF mantenemos el título descriptivo largo aunque en la UI
    // mostremos uno corto ("Grúas Horquillas"). Por ahora mapeamos por
    // código de lista; si no hay match, caemos al `lista.nombre` actual.
    const tituloPdfPorCodigo = {
      'GRUA_HORQUILLA_PFA':
          'Lista de verificación de Grúa Horquilla Patio Fiordo Austral',
    };
    final tituloPdf = tituloPdfPorCodigo[lista.codigo] ?? lista.nombre;

    return HidroserReportData(
      empresaProveedor: UserSession().empresaNombre ?? 'JF INNOVA',
      tituloLista: tituloPdf,
      subtitulo: lista.subtitulo,
      fecha: fechaFmt,
      correlativo: insp.correlativo,
      profesional: UserSession().nombreCompleto ?? '',
      fonoProfesional: '',
      correoProfesional: UserSession().email ?? '',
      headerFields: headerFields,
      checklistItems: checklistItems,
      observaciones: insp.observaciones ?? '',
      firmas: firmas,
      fotosPaths: [
        ...fotosGenerales.where((f) => f.existsSync()).map((f) => f.path),
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

  // --- FLUJOS ---------------------------------------------------------

  Future<void> previsualizarReporte(BuildContext context) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final insp = _buildInspeccionModel(estadoFinal: 'Borrador');
      final report = _buildReportData(insp);
      final pdf = await _generatePdf(report);
      if (!context.mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => pdf,
        name: _nombrePdf(insp),
      );
    } catch (e) {
      errorMessage = 'Error generando PDF: $e';
      debugPrint('❌ $errorMessage');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Guarda definitivo: marca estado_final='En Seguimiento' (gatilla
  /// correlativo en el trigger Supabase) y dispara sync.
  Future<bool> guardarDefinitivo() async {
    if (isSaving) return false;
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final insp = _buildInspeccionModel(estadoFinal: 'En Seguimiento');
      final report = _buildReportData(insp);
      final pdfBytes = await _generatePdf(report);

      // Persistir PDF en disco
      final dir = await getApplicationDocumentsDirectory();
      final pdfPath = '${dir.path}/hidroser_${insp.id}.pdf';
      await File(pdfPath).writeAsBytes(pdfBytes);
      insp.pdfPathLocal = pdfPath;

      final respuestas = items
          .map(
            (m) => HidroserRespuesta(
              id: const Uuid().v4(),
              inspeccionId: insp.id,
              itemId: m['id'].toString(),
              estado: (m['estado'] ?? 'C').toString(),
              observacion: (m['observacion'] ?? '').toString().isEmpty
                  ? null
                  : m['observacion'].toString(),
              criticidad: m['criticidad']?.toString(),
            ),
          )
          .toList();

      await _repo.guardarInspeccion(insp, respuestas);

      // Sync (fire-and-forget — el SyncService maneja errores y reintenta)
      unawaited(_sync.sincronizarTodo());
      return true;
    } catch (e, st) {
      errorMessage = 'Error guardando inspección: $e';
      debugPrint('❌ $errorMessage\n$st');
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  String _nombrePdf(HidroserInspeccion insp) {
    final ref = insp.correlativo ?? insp.id.substring(0, 8);
    return 'Hidroser_${lista.codigo}_$ref'.replaceAll(RegExp(r'\s+'), '_');
  }

  /// Guarda el estado actual del formulario como borrador. Pensado para
  /// invocarse al cerrar/retroceder el form (no genera PDF, no sincroniza).
  /// No emite errores ni cambia [isSaving]; si falla, sólo loguea.
  /// Devuelve `true` si se guardó algo.
  Future<bool> guardarBorradorSilencioso() async {
    // Si todavía no terminó de cargar la lista o no hay nada que guardar,
    // no creamos borradores vacíos.
    if (isLoading) return false;
    if (items.isEmpty && !_hayDatosCabecera()) return false;
    try {
      final insp = _buildInspeccionModel(estadoFinal: 'Borrador');
      final respuestas = items
          .map(
            (m) => HidroserRespuesta(
              id: const Uuid().v4(),
              inspeccionId: insp.id,
              itemId: m['id'].toString(),
              estado: (m['estado'] ?? 'C').toString(),
              observacion: (m['observacion'] ?? '').toString().isEmpty
                  ? null
                  : m['observacion'].toString(),
              criticidad: m['criticidad']?.toString(),
            ),
          )
          .toList();
      await _repo.guardarInspeccion(insp, respuestas);
      debugPrint('💾 Borrador Hidroser autoguardado ($inspeccionId)');
      return true;
    } catch (e) {
      debugPrint('⚠️ Error autoguardando borrador Hidroser: $e');
      return false;
    }
  }

  bool _hayDatosCabecera() {
    if (quienInspeccionaCtrl.text.trim().isNotEmpty) return true;
    if (observacionesCtrl.text.trim().isNotEmpty) return true;
    if (firmaSupervisorNombreCtrl.text.trim().isNotEmpty) return true;
    if (firmaOperadorNombreCtrl.text.trim().isNotEmpty) return true;
    for (final c in camposExtraCtrls.values) {
      if (c.text.trim().isNotEmpty) return true;
    }
    return false;
  }

  @override
  void dispose() {
    quienInspeccionaCtrl.dispose();
    observacionesCtrl.dispose();
    firmaSupervisorNombreCtrl.dispose();
    firmaOperadorNombreCtrl.dispose();
    for (final c in camposExtraCtrls.values) {
      c.dispose();
    }
    signatureSupervisor.dispose();
    signatureOperador.dispose();
    super.dispose();
  }
}
