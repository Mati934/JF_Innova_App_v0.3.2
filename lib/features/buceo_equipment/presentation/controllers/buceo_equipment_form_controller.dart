import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/services/empresa_logo_service.dart';
import '../../../../core/services/user_session.dart';
import '../../../inspection/domain/models/formulario_item.dart';
import '../../../sync/services/sync_service.dart';
import '../../data/repositories/local_buceo_equipment_repository.dart';
import '../../domain/models/buceo_equipment_inspeccion.dart';
import '../../domain/models/buceo_equipment_pdf_data.dart';
import '../../domain/models/buceo_equipment_variant.dart';
import '../../services/buceo_equipment_pdf_service.dart';

class BuceoEquipmentFormController extends ChangeNotifier {
  final BuceoEquipmentVariant variant;
  final Map<String, dynamic>? borradorInicial;
  final LocalBuceoEquipmentRepository _repo;
  final SyncService _sync;

  BuceoEquipmentFormController({
    required this.variant,
    this.borradorInicial,
    LocalBuceoEquipmentRepository? repo,
    SyncService? sync,
  }) : _repo = repo ?? LocalBuceoEquipmentRepository(),
       _sync = sync ?? SyncService();

  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  late String inspeccionId;
  DateTime fechaRealizacion = DateTime.now();

  final TextEditingController numeroInformeCtrl = TextEditingController();
  final TextEditingController embarcacionCtrl = TextEditingController();
  final TextEditingController lugarFaenaCtrl = TextEditingController();
  final TextEditingController empresaCtrl = TextEditingController();
  final TextEditingController areaCtrl = TextEditingController();
  final TextEditingController regionCtrl = TextEditingController();
  final TextEditingController supervisorJefaturaCtrl = TextEditingController();
  final TextEditingController profesionalCtrl = TextEditingController();
  final TextEditingController profesionalCorreoCtrl = TextEditingController();
  final TextEditingController profesionalFonoCtrl = TextEditingController();
  final TextEditingController observacionesCtrl = TextEditingController();

  final TextEditingController firmaProfesionalNombreCtrl =
      TextEditingController();
  final TextEditingController firmaSupervisorNombreCtrl =
      TextEditingController();

  final SignatureController signatureProfesional = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
  );
  final SignatureController signatureSupervisor = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
  );

  Uint8List? firmaProfesionalImage;
  Uint8List? firmaSupervisorImage;

  List<Map<String, String>> compresores = [
    {
      'nombre': 'Compresor 1',
      'matricula': '',
      'vigencia': '',
      'ph': '',
      'buzosCargo': '',
    },
  ];

  List<Map<String, String>> buzos = [
    {'titulo': 'Buzo 1', 'nombre': '', 'matricula': '', 'profundidad': ''},
  ];

  final Map<String, File> fotosPorPregunta = {};
  List<File> fotosGenerales = [];

  final List<Map<String, dynamic>> items = [];
  int? _numeroInformeAproximado;

  Future<void> init() async {
    isLoading = true;
    notifyListeners();
    try {
      inspeccionId = (borradorInicial?['id'] as String?) ?? const Uuid().v4();
      profesionalCtrl.text = UserSession().nombreCompleto ?? '';
      empresaCtrl.text = UserSession().empresaNombre ?? '';
      profesionalCorreoCtrl.text = UserSession().email ?? '';
      firmaProfesionalNombreCtrl.text = profesionalCtrl.text;
      await _cargarDatosUsuarioPorDefecto();
      _numeroInformeAproximado = await _repo.getProximoNumeroInformeEstimado(
        variant.codigo,
      );

      final rawItems = await _repo.getItemsForLista(variant.codigo);
      if (rawItems.isNotEmpty) {
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
      } else {
        items.clear();
      }

      if (borradorInicial != null) {
        _aplicarBorrador(borradorInicial!);
      } else {
        numeroInformeCtrl.text = _numeroInformeSugerido();
      }
    } catch (e) {
      errorMessage = 'Error cargando formulario: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String _numeroInformeSugerido() {
    final aprox = _numeroInformeAproximado;
    if (aprox == null) return 'Automatico (al guardar definitivo)';
    return 'Automatico (aprox. $aprox)';
  }

  Future<void> _cargarDatosUsuarioPorDefecto() async {
    final userId = UserSession().userId;
    if (userId == null) return;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'usuarios',
        columns: ['telefono'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final telefono = (rows.first['telefono'] ?? '').toString().trim();
      if (telefono.isNotEmpty) {
        profesionalFonoCtrl.text = telefono;
      }
    } catch (_) {
      // No bloquea el formulario si falla la lectura local de usuario.
    }
  }

  bool _esItemPersonalPorBuzo(Map<String, dynamic> item) {
    final categoria = (item['categoria'] ?? '').toString().trim().toLowerCase();
    return categoria == 'personal por buzo' ||
        categoria == 'checklist por buzo';
  }

  List<Map<String, dynamic>> get checklistItemsGenerales {
    return items.where((i) => !_esItemPersonalPorBuzo(i)).toList();
  }

  Map<String, Map<int, String>> personalChecklistMatrix() {
    final result = <String, Map<int, String>>{};
    final re = RegExp(r'^(.*)\s+\(BUZO\s+(\d+)\)$');

    for (final item in items.where(_esItemPersonalPorBuzo)) {
      final id = item['id']?.toString();
      final pregunta = (item['pregunta'] ?? '').toString().trim();
      if (id == null || pregunta.isEmpty) continue;

      final m = re.firstMatch(pregunta);
      if (m == null) continue;

      final base = m.group(1)?.trim();
      final idx = int.tryParse(m.group(2) ?? '');
      if (base == null || idx == null) continue;

      result.putIfAbsent(base, () => <int, String>{})[idx] = id;
    }

    return result;
  }

  List<int> buzosChecklistVisibles() {
    final indices = <int>{};
    for (final m in personalChecklistMatrix().values) {
      indices.addAll(m.keys);
    }
    final ordenados = indices.toList()..sort();
    return ordenados.where((i) => i <= buzos.length).toList();
  }

  String? respuestaPorPreguntaBuzo(String preguntaBase, int buzoIdx) {
    final itemId = personalChecklistMatrix()[preguntaBase]?[buzoIdx];
    if (itemId == null) return null;
    return respuestaDe(itemId);
  }

  void setRespuestaPreguntaBuzo(
    String preguntaBase,
    int buzoIdx,
    String estado,
  ) {
    final itemId = personalChecklistMatrix()[preguntaBase]?[buzoIdx];
    if (itemId == null) return;
    setRespuestaById(itemId, estado);
  }

  Map<String, List<FormularioItem>> agruparPorCategoria() {
    final map = <String, List<FormularioItem>>{};
    for (final m in items) {
      final item = FormularioItem(
        id: m['id'].toString(),
        pregunta: (m['pregunta'] ?? '').toString(),
        categoria: (m['categoria'] ?? 'General').toString(),
        criticidad: (m['criticidad'] ?? 'Tolerable').toString(),
      );
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
    if (i < 0) return;
    items[i]['estado'] = estado;
    notifyListeners();
  }

  void setObservacionById(String id, String texto) {
    final i = _indexById(id);
    if (i < 0) return;
    items[i]['observacion'] = texto;
  }

  void setCriticidadById(String id, String criticidad) {
    final i = _indexById(id);
    if (i < 0) return;
    items[i]['criticidad'] = criticidad;
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

  void addCompresor() {
    if (compresores.length >= 3) return;
    final idx = compresores.length + 1;
    compresores.add({
      'nombre': 'Compresor $idx',
      'matricula': '',
      'vigencia': '',
      'ph': '',
      'buzosCargo': '',
    });
    notifyListeners();
  }

  void removeCompresor(int index) {
    if (compresores.length <= 1) return;
    if (index < 0 || index >= compresores.length) return;
    compresores.removeAt(index);
    notifyListeners();
  }

  void updateCompresor(int index, String key, String value) {
    if (index < 0 || index >= compresores.length) return;
    compresores[index][key] = value;
  }

  void addBuzo() {
    if (buzos.length >= 5) return;
    final idx = buzos.length + 1;
    buzos.add({
      'titulo': 'Buzo $idx',
      'nombre': '',
      'matricula': '',
      'profundidad': '',
    });
    notifyListeners();
  }

  void removeBuzo(int index) {
    if (buzos.length <= 1) return;
    if (index < 0 || index >= buzos.length) return;
    buzos.removeAt(index);
    for (int i = 0; i < buzos.length; i++) {
      buzos[i]['titulo'] = 'Buzo ${i + 1}';
    }
    notifyListeners();
  }

  void updateBuzo(int index, String key, String value) {
    if (index < 0 || index >= buzos.length) return;
    buzos[index][key] = value;
  }

  void setFecha(DateTime f) {
    fechaRealizacion = f;
    notifyListeners();
  }

  void setFirmaProfesional(Uint8List? bytes) {
    firmaProfesionalImage = bytes;
    notifyListeners();
  }

  void setFirmaSupervisor(Uint8List? bytes) {
    firmaSupervisorImage = bytes;
    notifyListeners();
  }

  BuceoEquipmentInspeccion _buildInspeccionModel({
    required String estadoFinal,
  }) {
    final camposExtra = <String, String>{
      'embarcacion': embarcacionCtrl.text.trim(),
      'lugar_faena': lugarFaenaCtrl.text.trim(),
      'empresa': empresaCtrl.text.trim(),
      'area': areaCtrl.text.trim(),
      'region': regionCtrl.text.trim(),
      'supervisor_jefatura': supervisorJefaturaCtrl.text.trim(),
      'profesional_correo': profesionalCorreoCtrl.text.trim(),
      'profesional_fono': profesionalFonoCtrl.text.trim(),
      'compresores': jsonEncode(compresores),
      'buzos': jsonEncode(buzos),
      'tipo_lista': variant.codigo,
    };

    return BuceoEquipmentInspeccion(
      id: inspeccionId,
      listaCodigo: variant.codigo,
      fechaRealizacion: fechaRealizacion,
      usuarioId: UserSession().userId,
      empresaId: UserSession().empresaId,
      quienInspecciona: profesionalCtrl.text.trim(),
      observaciones: observacionesCtrl.text.trim(),
      camposExtra: camposExtra,
      firmaSupervisorNombre: firmaSupervisorNombreCtrl.text.trim().isEmpty
          ? null
          : firmaSupervisorNombreCtrl.text.trim(),
      firmaOperadorNombre: firmaProfesionalNombreCtrl.text.trim().isEmpty
          ? null
          : firmaProfesionalNombreCtrl.text.trim(),
      firmaSupervisorImage: firmaSupervisorImage,
      firmaOperadorImage: firmaProfesionalImage,
      estadoFinal: estadoFinal,
    );
  }

  BuceoEquipmentPdfData _buildPdfData(BuceoEquipmentInspeccion insp) {
    final fechaFmt = DateFormat('dd/MM/yyyy HH:mm').format(fechaRealizacion);
    final counts = _conteoChecklist();

    final checklistItems = items
        .map(
          (m) => BuceoPdfChecklistItem(
            categoria: (m['categoria'] ?? 'General').toString(),
            pregunta: (m['pregunta'] ?? '').toString(),
            respuesta: (m['estado'] ?? 'C').toString(),
            observacion: (m['observacion'] ?? '').toString(),
            fotoPath: fotosPorPregunta[m['id']?.toString() ?? '']?.path,
          ),
        )
        .toList();

    return BuceoEquipmentPdfData(
      empresaProveedor: UserSession().empresaNombre ?? 'JF INNOVA',
      tituloInforme: 'Informe tecnico',
      subtituloInforme:
          'Inspeccion de Buceo - Equipo semiautonomo liviano y complementos',
      nombreLista: variant.nombre,
      numeroInforme: _numeroInformeParaPdf(),
      fecha: fechaFmt,
      empresa: empresaCtrl.text.trim(),
      area: areaCtrl.text.trim(),
      region: regionCtrl.text.trim(),
      supervisorJefatura: supervisorJefaturaCtrl.text.trim(),
      embarcacion: embarcacionCtrl.text.trim(),
      lugarFaena: lugarFaenaCtrl.text.trim(),
      profesional: profesionalCtrl.text.trim(),
      profesionalCorreo: profesionalCorreoCtrl.text.trim(),
      profesionalFono: profesionalFonoCtrl.text.trim(),
      totalCumple: counts.$1,
      totalNoCumple: counts.$2,
      totalNoAplica: counts.$3,
      compresores: compresores
          .map(
            (c) => BuceoPdfCompresor(
              nombre: c['nombre'] ?? '',
              matricula: c['matricula'] ?? '',
              vigencia: c['vigencia'] ?? '',
              ph: c['ph'] ?? '',
              buzosCargo: c['buzosCargo'] ?? '',
            ),
          )
          .toList(),
      buzos: buzos
          .map(
            (b) => BuceoPdfBuzo(
              titulo: b['titulo'] ?? '',
              nombre: b['nombre'] ?? '',
              matricula: b['matricula'] ?? '',
              profundidad: b['profundidad'] ?? '',
            ),
          )
          .toList(),
      checklistItems: checklistItems,
      galeriaPaths: fotosGenerales
          .where((f) => f.existsSync())
          .map((f) => f.path)
          .toList(),
      firmas: [
        BuceoPdfFirma(
          rol: 'Profesional',
          nombre: firmaProfesionalNombreCtrl.text.trim(),
          imagen: firmaProfesionalImage,
        ),
        BuceoPdfFirma(
          rol: 'Supervisor del servicio',
          nombre: firmaSupervisorNombreCtrl.text.trim(),
          imagen: firmaSupervisorImage,
        ),
      ],
    );
  }

  String _numeroInformeParaPdf() {
    final current = numeroInformeCtrl.text.trim();
    if (current.isEmpty) return _numeroInformeSugerido();
    if (current.toLowerCase().startsWith('automatico')) {
      if (_numeroInformeAproximado != null) {
        return 'Aprox. ${_numeroInformeAproximado!}';
      }
      return 'Automatico';
    }
    return current;
  }

  (int, int, int) _conteoChecklist() {
    int c = 0;
    int nc = 0;
    int na = 0;
    for (final i in items) {
      final e = (i['estado'] ?? '').toString().toUpperCase();
      if (e == 'C') c++;
      if (e == 'NC') nc++;
      if (e == 'N/A') na++;
    }
    return (c, nc, na);
  }

  Future<Uint8List> _generatePdf(BuceoEquipmentPdfData data) async {
    final fontReg = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final fontBold = await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');

    Uint8List? logoBytes;
    try {
      logoBytes = await EmpresaLogoService.instance.getLogoForActiveEmpresa(
        fallbackAsset: 'assets/images/LogoJFInnova2.png',
      );
    } catch (_) {}

    final params = BuceoEquipmentPdfIsolateParams(
      data: data,
      fontRegular: fontReg.buffer.asUint8List(),
      fontBold: fontBold.buffer.asUint8List(),
      logoBytes: logoBytes,
    );
    return compute(generateBuceoEquipmentPdfEntryPoint, params);
  }

  Future<void> previsualizarReporte(BuildContext context) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final insp = _buildInspeccionModel(estadoFinal: 'Borrador');
      final report = _buildPdfData(insp);
      final pdf = await _generatePdf(report);
      if (!context.mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => pdf,
        name: _nombrePdf(insp),
      );
    } catch (e) {
      errorMessage = 'Error generando PDF: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> guardarDefinitivo() async {
    if (isSaving) return false;
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final insp = _buildInspeccionModel(estadoFinal: 'En Seguimiento');
      final report = _buildPdfData(insp);
      final pdfBytes = await _generatePdf(report);

      final dir = await getApplicationDocumentsDirectory();
      final pdfPath = '${dir.path}/buceo_equipo_${insp.id}.pdf';
      await File(pdfPath).writeAsBytes(pdfBytes);
      insp.pdfPathLocal = pdfPath;

      final respuestas = items
          .map(
            (m) => BuceoEquipmentRespuesta(
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
      unawaited(_sync.sincronizarTodo());
      return true;
    } catch (e, st) {
      errorMessage = 'Error guardando inspeccion: $e';
      debugPrint('Error guardando buceo: $e\n$st');
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> guardarBorradorSilencioso() async {
    if (isLoading) return false;
    if (!_hayDatos()) return false;
    try {
      final insp = _buildInspeccionModel(estadoFinal: 'Borrador');
      final respuestas = items
          .map(
            (m) => BuceoEquipmentRespuesta(
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
      return true;
    } catch (e) {
      debugPrint('Error autoguardando buceo: $e');
      return false;
    }
  }

  bool _hayDatos() {
    if (embarcacionCtrl.text.trim().isNotEmpty) return true;
    if (lugarFaenaCtrl.text.trim().isNotEmpty) return true;
    if (areaCtrl.text.trim().isNotEmpty) return true;
    if (regionCtrl.text.trim().isNotEmpty) return true;
    if (supervisorJefaturaCtrl.text.trim().isNotEmpty) return true;
    if (observacionesCtrl.text.trim().isNotEmpty) return true;
    return false;
  }

  String _nombrePdf(BuceoEquipmentInspeccion insp) {
    final ref = insp.correlativo ?? insp.id.substring(0, 8);
    return 'Buceo_${variant.codigo}_$ref'.replaceAll(RegExp(r'\s+'), '_');
  }

  void _aplicarBorrador(Map<String, dynamic> b) {
    profesionalCtrl.text = (b['quien_inspecciona'] ?? '').toString();
    observacionesCtrl.text = (b['observaciones'] ?? '').toString();
    firmaProfesionalNombreCtrl.text = (b['firma_operador_nombre'] ?? '')
        .toString();
    firmaSupervisorNombreCtrl.text = (b['firma_supervisor_nombre'] ?? '')
        .toString();

    final rawFecha = b['fecha_realizacion'];
    if (rawFecha != null) {
      try {
        fechaRealizacion = DateTime.parse(rawFecha.toString());
      } catch (_) {}
    }

    final extraMap = _parseCamposExtra(b['campos_extra']);
    numeroInformeCtrl.text =
        extraMap['numero_informe'] ??
        (b['numero_informe']?.toString() ?? _numeroInformeSugerido());
    embarcacionCtrl.text = extraMap['embarcacion'] ?? '';
    lugarFaenaCtrl.text = extraMap['lugar_faena'] ?? '';
    empresaCtrl.text = extraMap['empresa'] ?? empresaCtrl.text;
    areaCtrl.text = extraMap['area'] ?? '';
    regionCtrl.text = extraMap['region'] ?? '';
    supervisorJefaturaCtrl.text = extraMap['supervisor_jefatura'] ?? '';
    profesionalCorreoCtrl.text =
        extraMap['profesional_correo'] ?? profesionalCorreoCtrl.text;
    profesionalFonoCtrl.text =
        extraMap['profesional_fono'] ?? profesionalFonoCtrl.text;

    final comp = _decodeList(extraMap['compresores']);
    if (comp.isNotEmpty) {
      compresores = comp
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v.toString())))
          .toList();
    }

    final bz = _decodeList(extraMap['buzos']);
    if (bz.isNotEmpty) {
      buzos = bz
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v.toString())))
          .toList();
    }

    for (int i = 0; i < buzos.length; i++) {
      buzos[i]['titulo'] = 'Buzo ${i + 1}';
    }

    firmaSupervisorImage = b['firma_supervisor_image'] is Uint8List
        ? b['firma_supervisor_image'] as Uint8List
        : null;
    firmaProfesionalImage = b['firma_operador_image'] is Uint8List
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

  Map<String, String> _parseCamposExtra(dynamic rawCamposExtra) {
    if (rawCamposExtra is String && rawCamposExtra.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCamposExtra);
        if (decoded is Map<String, dynamic>) {
          return decoded.map((k, v) => MapEntry(k, (v ?? '').toString()));
        }
      } catch (_) {}
    } else if (rawCamposExtra is Map<String, dynamic>) {
      return rawCamposExtra.map((k, v) => MapEntry(k, (v ?? '').toString()));
    }
    return <String, String>{};
  }

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  void dispose() {
    numeroInformeCtrl.dispose();
    embarcacionCtrl.dispose();
    lugarFaenaCtrl.dispose();
    empresaCtrl.dispose();
    areaCtrl.dispose();
    regionCtrl.dispose();
    supervisorJefaturaCtrl.dispose();
    profesionalCtrl.dispose();
    profesionalCorreoCtrl.dispose();
    profesionalFonoCtrl.dispose();
    observacionesCtrl.dispose();
    firmaProfesionalNombreCtrl.dispose();
    firmaSupervisorNombreCtrl.dispose();
    signatureProfesional.dispose();
    signatureSupervisor.dispose();
    super.dispose();
  }
}
