import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/user_session.dart';
import '../../../sync/services/sync_service.dart';
import '../../data/repositories/local_ast_repository.dart';
import '../../domain/models/ast_models.dart';
import '../../domain/models/pdf/ast_report_data.dart';
import '../../services/ast_pdf_generator_service.dart';
import 'ast_photo_persistence_queue.dart';

/// Controlador del formulario AST: descripción, hallazgos, observaciones,
/// galería general y generación del PDF.
class AstFormController extends ChangeNotifier {
  final String informeId;
  final LocalAstRepository _repo;
  final SyncService _sync;
  late final AstPhotoPersistenceQueue _photoQueue = AstPhotoPersistenceQueue(
    onChanged: notifyListeners,
  );

  AstFormController({
    required this.informeId,
    LocalAstRepository? repo,
    SyncService? sync,
  }) : _repo = repo ?? LocalAstRepository(),
       _sync = sync ?? SyncService();

  bool isLoading = true;
  bool isSaving = false;
  bool get isProcessingPhotos => _photoQueue.isProcessing;
  String? errorMessage;

  late AstInforme _informe;
  AstInforme get informe => _informe;

  final TextEditingController descripcionCtrl = TextEditingController();
  final TextEditingController observacionesCtrl = TextEditingController();

  /// Hallazgos en edición. Cada uno expone su File de evidencia (si existe).
  final List<AstHallazgo> hallazgos = [];

  /// Galería general (archivos ya persistidos en disco).
  List<File> fotosGenerales = [];

  String? get correlativo => _informe.correlativo;

  Future<void> init() async {
    isLoading = true;
    notifyListeners();
    try {
      final data = await _repo.getInformeConHallazgosById(informeId);
      if (data == null) {
        // Informe nuevo sin persistir aún (no debería ocurrir: el setup lo crea).
        _informe = AstInforme(
          id: informeId,
          usuarioId: UserSession().userId,
          empresaId: UserSession().empresaId,
          profesional: UserSession().nombreCompleto ?? '',
        );
      } else {
        _informe = _informeFromRow(data);
        descripcionCtrl.text = _informe.descripcionActividad;
        observacionesCtrl.text = _informe.observaciones;

        final rawHallazgos = (data['hallazgos'] as List?) ?? const [];
        for (final h in rawHallazgos) {
          if (h is Map) {
            hallazgos.add(AstHallazgo.fromMap(Map<String, dynamic>.from(h)));
          }
        }

        fotosGenerales = _informe.fotosGenerales
            .map((p) => File(p))
            .where((f) => f.existsSync())
            .toList();
      }
    } catch (e) {
      errorMessage = 'Error cargando AST: $e';
      debugPrint('❌ $errorMessage');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  AstInforme _informeFromRow(Map<String, dynamic> r) {
    List<String> fotos = [];
    final rawFotos = r['fotos_generales'];
    if (rawFotos is String && rawFotos.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawFotos);
        if (decoded is List) fotos = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return AstInforme(
      id: r['id'] as String,
      usuarioId: r['usuario_id'] as String?,
      empresaId: r['empresa_id'] as String?,
      areaId: r['area_id'] as String?,
      centroId: r['centro_id'] as String?,
      contratistaId: r['contratista_id'] as String?,
      embarcacionId: r['embarcacion_id'] as String?,
      areaNombre: r['area_nombre'] as String?,
      centroNombre: r['centro_nombre'] as String?,
      contratistaNombre: r['contratista_nombre'] as String?,
      embarcacionNombre: r['embarcacion_nombre'] as String?,
      profesional: (r['profesional'] ?? '') as String,
      fechaRealizacion:
          DateTime.tryParse((r['fecha_realizacion'] ?? '') as String) ??
          DateTime.now(),
      descripcionActividad: (r['descripcion_actividad'] ?? '') as String,
      observaciones: (r['observaciones'] ?? '') as String,
      correlativo: r['correlativo'] as String?,
      estadoFinal: (r['estado_final'] ?? 'En Progreso') as String,
      pdfUrl: r['pdf_url'] as String?,
      pdfPathLocal: r['pdf_path_local'] as String?,
      fotosGenerales: fotos,
    );
  }

  // --- ACCIONES UI ----------------------------------------------------------

  void agregarHallazgo() {
    hallazgos.add(
      AstHallazgo(
        id: const Uuid().v4(),
        informeId: informeId,
        numero: hallazgos.length + 1,
      ),
    );
    notifyListeners();
  }

  void eliminarHallazgo(String id) {
    hallazgos.removeWhere((h) => h.id == id);
    _renumerar();
    notifyListeners();
  }

  void _renumerar() {
    for (var i = 0; i < hallazgos.length; i++) {
      hallazgos[i].numero = i + 1;
    }
  }

  void setTituloHallazgo(String id, String titulo) {
    final h = _byId(id);
    if (h != null) h.titulo = titulo;
  }

  void setDetalleHallazgo(String id, String detalle) {
    final h = _byId(id);
    if (h != null) h.detalle = detalle;
  }

  Future<void> setFotoHallazgo(String id, File foto) {
    return _photoQueue.track(_persistirFotoHallazgo(id, foto));
  }

  Future<void> _persistirFotoHallazgo(String id, File foto) async {
    final h = _byId(id);
    if (h == null) return;
    final permanente = await _persistirFoto(foto, 'hallazgo_$id');
    h.fotoPath = permanente;
    notifyListeners();
  }

  void quitarFotoHallazgo(String id) {
    final h = _byId(id);
    if (h == null) return;
    h.fotoPath = null;
    notifyListeners();
  }

  File? fotoHallazgo(String id) {
    final h = _byId(id);
    if (h?.fotoPath == null) return null;
    final f = File(h!.fotoPath!);
    return f.existsSync() ? f : null;
  }

  AstHallazgo? _byId(String id) {
    for (final h in hallazgos) {
      if (h.id == id) return h;
    }
    return null;
  }

  Future<void> setFotosGenerales(List<File> nuevas) {
    return _photoQueue.track(_persistirFotosGenerales(nuevas));
  }

  Future<void> _persistirFotosGenerales(List<File> nuevas) async {
    final List<File> persistidas = [];
    for (final f in nuevas) {
      // Evita recopiar las que ya están en el directorio permanente.
      if (f.path.contains('ast_img')) {
        persistidas.add(f);
      } else {
        final ruta = await _persistirFoto(f, 'general');
        persistidas.add(File(ruta));
      }
    }
    fotosGenerales = persistidas;
    notifyListeners();
  }

  /// Copia una foto al almacenamiento permanente de la app y devuelve la ruta.
  Future<String> _persistirFoto(File origen, String prefijo) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/ast_img');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    if (origen.path.contains(folder.path)) return origen.path;
    final nombre = '${DateTime.now().millisecondsSinceEpoch}_$prefijo.jpg';
    final destino = '${folder.path}/$nombre';
    await origen.copy(destino);
    return destino;
  }

  void setFecha(DateTime f) {
    _informe.fechaRealizacion = f;
    notifyListeners();
  }

  // --- BUILD MODEL ----------------------------------------------------------

  void _volcarFormularioAlModelo({required String estadoFinal}) {
    _informe.descripcionActividad = descripcionCtrl.text.trim();
    _informe.observaciones = observacionesCtrl.text.trim();
    _informe.estadoFinal = estadoFinal;
    _informe.fotosGenerales = fotosGenerales
        .where((f) => f.existsSync())
        .map((f) => f.path)
        .toList();
  }

  AstReportData _buildReportData() {
    final fechaFmt = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(_informe.fechaRealizacion);

    final datos = <AstHeaderField>[
      AstHeaderField(label: 'Área', valor: _informe.areaNombre ?? ''),
      AstHeaderField(label: 'Centro', valor: _informe.centroNombre ?? ''),
      AstHeaderField(label: 'Empresa', valor: _informe.contratistaNombre ?? ''),
      if ((_informe.embarcacionNombre ?? '').isNotEmpty)
        AstHeaderField(
          label: 'Embarcación',
          valor: _informe.embarcacionNombre!,
        ),
      AstHeaderField(label: 'Profesional', valor: _informe.profesional),
      AstHeaderField(label: 'Fecha', valor: fechaFmt),
    ];

    final hallazgosDto = hallazgos
        .map(
          (h) => AstHallazgoDto(
            numero: h.numero,
            titulo: h.titulo,
            detalle: h.detalle,
            fotoPath: (h.fotoPath != null && File(h.fotoPath!).existsSync())
                ? h.fotoPath
                : null,
          ),
        )
        .toList();

    return AstReportData(
      empresaProveedor: UserSession().empresaNombre ?? 'JF INNOVA',
      fecha: fechaFmt,
      correlativo: _informe.correlativo,
      datos: datos,
      descripcionActividad: descripcionCtrl.text.trim(),
      hallazgos: hallazgosDto,
      observaciones: observacionesCtrl.text.trim(),
      fotosPaths: fotosGenerales
          .where((f) => f.existsSync())
          .map((f) => f.path)
          .toList(),
    );
  }

  Future<Uint8List> _generatePdf(AstReportData data) async {
    final fontReg = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final fontBold = await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');

    // El módulo AST siempre usa el logo de AquaChile, independientemente de
    // la empresa activa del usuario.
    Uint8List? logoBytes;
    try {
      final logoData = await rootBundle.load(
        'assets/images/aquachileporfin3.png',
      );
      logoBytes = logoData.buffer.asUint8List();
    } catch (_) {}

    final params = AstPdfIsolateParams(
      data: data,
      fontRegular: fontReg.buffer.asUint8List(),
      fontBold: fontBold.buffer.asUint8List(),
      logoBytes: logoBytes,
    );
    return compute(generateAstPdfEntryPoint, params);
  }

  // --- FLUJOS ---------------------------------------------------------------

  Future<void> previsualizarReporte(BuildContext context) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final pdf = await _generatePdf(_buildReportData());
      if (!context.mounted) return;
      await Printing.layoutPdf(onLayout: (_) async => pdf, name: _nombrePdf());
    } catch (e) {
      errorMessage = 'Error generando PDF: $e';
      debugPrint('❌ $errorMessage');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Finaliza el AST: marca estado 'En Seguimiento' (gatilla el correlativo en
  /// el trigger de Supabase), genera el PDF, persiste y dispara la sync.
  Future<bool> finalizar() async {
    if (isSaving) return false;
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _photoQueue.waitUntilIdle();
      _volcarFormularioAlModelo(estadoFinal: 'En Seguimiento');

      final pdfBytes = await _generatePdf(_buildReportData());
      final dir = await getApplicationDocumentsDirectory();
      final pdfPath = '${dir.path}/ast_${_informe.id}.pdf';
      await File(pdfPath).writeAsBytes(pdfBytes);
      _informe.pdfPathLocal = pdfPath;

      await _repo.guardarInforme(_informe, hallazgos);

      unawaited(_sync.sincronizarTodo());
      return true;
    } catch (e, st) {
      errorMessage = 'Error finalizando AST: $e';
      debugPrint('❌ $errorMessage\n$st');
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  /// Guarda el estado actual como borrador (sin PDF ni sync bloqueante).
  Future<bool> guardarBorradorSilencioso() async {
    if (isLoading) return false;
    try {
      await _photoQueue.waitUntilIdle();
      _volcarFormularioAlModelo(estadoFinal: 'En Progreso');
      await _repo.guardarInforme(_informe, hallazgos);
      debugPrint('💾 Borrador AST autoguardado ($informeId)');
      return true;
    } catch (e) {
      debugPrint('⚠️ Error autoguardando borrador AST: $e');
      return false;
    }
  }

  String _nombrePdf() {
    final numero = _informe.correlativo ?? _informe.id.substring(0, 8);
    final centro = (_informe.centroNombre ?? '').trim();
    final partes = <String>[
      'Informe AST',
      numero,
      if (centro.isNotEmpty) centro,
    ];
    return partes.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  void dispose() {
    descripcionCtrl.dispose();
    observacionesCtrl.dispose();
    super.dispose();
  }
}
