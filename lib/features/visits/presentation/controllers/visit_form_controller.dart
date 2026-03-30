import 'package:flutter/material.dart';
import 'package:jf_innova_app/features/inspection/data/repositories/local_inspection_repository.dart';
import 'package:jf_innova_app/features/inspection/domain/models/formulario_item.dart';
import 'package:jf_innova_app/features/visits/domain/models/visita_respuesta.dart';
import 'package:signature/signature.dart';
import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/features/visits/domain/models/pdf/visit_report_data.dart';
import 'package:jf_innova_app/features/visits/services/visit_pdf_generator_service.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart'; // 📦 IMPORTANTE AÑADIR ESTO
import '../../../sync/services/sync_service.dart';
import '../../domain/models/visit_model.dart';
import '../../data/repositories/local_visit_repository.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // Para compute()
import 'package:flutter/services.dart' show rootBundle; // Para las fuentes
import 'package:printing/printing.dart'; // Para mostrar el visor PDF
import '../../../../shared/utils/debouncer.dart';

// Nota: Ajusta el nombre exacto de la clase y archivo si lo llamaste distinto.
// Nota: Ajusta el nombre exacto de la clase y archivo si lo llamaste distinto.
class VisitFormController extends ChangeNotifier {
  // --- Checklist Dinámico ---
  String? selectedTipoActividad;
  List<FormularioItem> preguntasActivas = [];
  Map<String, VisitaRespuesta> respuestasMap = {};
  bool isLoadingPreguntas = false;
  List<Map<String, dynamic>> tiposChecklistDisponibles = [];
  // Instanciamos el repositorio para poder consultar el catálogo
  final LocalInspectionRepository inspectionRepository =
      LocalInspectionRepository();
  // Método para cargar preguntas cuando cambian el Dropdown
  Future<void> loadPreguntas(String tipoActividad) async {
    selectedTipoActividad = tipoActividad;
    isLoadingPreguntas = true;
    notifyListeners();
    try {
      preguntasActivas = await inspectionRepository.getItems(tipoActividad);
      respuestasMap.clear();
      // Restaurar respuestas previas si existen en el borrador
      await _restoreChecklistRespuestas();
    } catch (e) {
      errorMessage = 'Error al cargar el checklist: $e';
    } finally {
      isLoadingPreguntas = false;
      notifyListeners();
    }
  }

  void clearChecklist() {
    selectedTipoActividad = null;
    preguntasActivas = [];
    respuestasMap.clear();
    notifyListeners();
  }

  Map<String, List<FormularioItem>> agruparPorCategoria() {
    final Map<String, List<FormularioItem>> map = {};
    for (var item in preguntasActivas) {
      if (!map.containsKey(item.categoria)) map[item.categoria] = [];
      map[item.categoria]!.add(item);
    }
    return map;
  }

  // Método unificado y seguro para actualizar cualquier parte de la respuesta
  void updateRespuestaData({
    required String itemId,
    String? estado,
    String? observacion,
    String? criticidad,
    String? fotoPath,
  }) {
    final actual = respuestasMap[itemId];
    respuestasMap[itemId] = VisitaRespuesta(
      id: actual?.id ?? const Uuid().v4(),
      visitaId: _currentVisitId,
      itemId: itemId,
      estado: estado ?? actual?.estado ?? '',
      observacion: observacion ?? actual?.observacion ?? '',
      criticidad: criticidad ?? actual?.criticidad ?? 'Tolerable',
      fotoPath: fotoPath ?? actual?.fotoPath,
    );
    notifyListeners();
  }

  // Método simulado para la foto (conecta aquí tu ImageService)
  Future<void> tomarFotoRespuesta(String itemId) async {
    // final path = await imageService.tomarFoto();
    // if (path != null) {
    //    updateRespuestaData(itemId: itemId, fotoPath: path);
    // }
  }
  final _repository = LocalVisitRepository();
  final _syncService = SyncService();

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  // Controladores de Texto
  final empresaCtrl = TextEditingController();
  final regionCtrl = TextEditingController();
  final centroCtrl = TextEditingController();
  final jefaturaCtrl = TextEditingController();
  final origenCtrl = TextEditingController();
  final email1Ctrl = TextEditingController();
  final email2Ctrl = TextEditingController();
  final otroActividadCtrl = TextEditingController();
  final observacionesCtrl = TextEditingController();

  final signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );

  final _debouncer = Debouncer(
    milliseconds: 1000,
  ); // Espera 1 seg antes de guardar
  late String _currentVisitId;

  // Historial para Autocomplete
  List<String> historialEmpresas = [];
  List<String> historialRegiones = [];
  List<String> historialCentros = [];

  List<String> fotosPaths = [];
  List<File> fotos = [];

  Uint8List? signatureImage;

  TimeOfDay? timeInicio;
  TimeOfDay? timeTermino;

  DateTime fechaVisita = DateTime.now();
  String get fechaVisitaStr =>
      "${fechaVisita.day.toString().padLeft(2, '0')}-${fechaVisita.month.toString().padLeft(2, '0')}-${fechaVisita.year}";
  String get horaInicioStr => timeInicio != null
      ? "${timeInicio!.hour}:${timeInicio!.minute.toString().padLeft(2, '0')}"
      : "--:--";
  String get horaTerminoStr => timeTermino != null
      ? "${timeTermino!.hour}:${timeTermino!.minute.toString().padLeft(2, '0')}"
      : "--:--";

  VisitModel model = VisitModel(activityId: '');

  VisitFormController({Map<String, dynamic>? borradorInicial}) {
    if (borradorInicial != null) {
      _currentVisitId = borradorInicial['id'] ?? borradorInicial['activity_id'];
      model = VisitModel.fromMap(borradorInicial);
      _cargarDatosEnUI(); // Llenamos UI ANTES de activar los listeners
    } else {
      _currentVisitId = const Uuid().v4();
      model.activityId = _currentVisitId;
    }
    _init();
  }

  void _cargarDatosEnUI() {
    empresaCtrl.text = model.empresa ?? '';
    regionCtrl.text = model.region ?? '';
    centroCtrl.text = model.centro ?? '';
    jefaturaCtrl.text = model.jefaturaCargo ?? '';
    origenCtrl.text = model.origenVisita ?? '';
    email1Ctrl.text = model.emailEmpresa1 ?? '';
    email2Ctrl.text = model.emailEmpresa2 ?? '';
    otroActividadCtrl.text = model.otroActividadTexto ?? '';
    observacionesCtrl.text = model.apuntesObservaciones ?? '';
    signatureImage = model.signatureImage;

    if (model.horaInicio != null && model.horaInicio != "--:--") {
      final p = model.horaInicio!.split(':');
      if (p.length == 2)
        timeInicio = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
    if (model.horaTermino != null && model.horaTermino != "--:--") {
      final p = model.horaTermino!.split(':');
      if (p.length == 2)
        timeTermino = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
  }

  Future<void> _init() async {
    timeInicio ??= TimeOfDay.now();
    await _loadHistorialAutocomplete();

    // Cargar tipos de checklist disponibles
    tiposChecklistDisponibles = await _repository.getTiposChecklistVisita();

    // 🚨 PARCHE DE HIDRATACIÓN DE FOTOS (Faltaba esto)
    if (_currentVisitId.isNotEmpty) {
      final fotosGuardadas = await _repository.getFotosPendientes(
        _currentVisitId,
      );
      for (var f in fotosGuardadas) {
        final path = f['local_path'] as String?;
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            fotos.add(file);
            fotosPaths.add(path);
          }
        }
      }

      // Restaurar checklist del borrador si existe
      await _restoreChecklistFromBorrador();
    }

    // Activamos listeners al final
    empresaCtrl.addListener(_onFieldChanged);
    regionCtrl.addListener(_onFieldChanged);
    centroCtrl.addListener(_onFieldChanged);
    jefaturaCtrl.addListener(_onFieldChanged);
    observacionesCtrl.addListener(_onFieldChanged);

    isLoading = false;
    notifyListeners();
  }

  // 3. CENTRALIZACIÓN DE MAPA (DRY)
  Map<String, dynamic> _generarMapaVisita({String? pdfPathLocal}) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return {
      'id': _currentVisitId,
      'usuario_id': userId,
      'fecha_realizacion': fechaVisita.toIso8601String(),
      'pdf_path_local': pdfPathLocal,
      'empresa': empresaCtrl.text.trim(),
      'region': regionCtrl.text.trim().toUpperCase(),
      'lugar_visita': centroCtrl.text.trim().toUpperCase(),
      'jefatura_a_cargo': jefaturaCtrl.text.trim(),
      'origen_visita': origenCtrl.text.trim(),
      // 🔥 SANITIZACIÓN: Si es el string de la UI, mandamos null
      'hora_inicio': (horaInicioStr == "--:--") ? null : horaInicioStr,
      'hora_termino': (horaTerminoStr == "--:--") ? null : horaTerminoStr,
      'email_empresa_1': email1Ctrl.text.trim(),
      'email_empresa_2': email2Ctrl.text.trim(),
      'check_reunion': model.checkReunion ? 1 : 0,
      'check_instalacion_senaletica': model.checkSenaletica ? 1 : 0,
      'check_capacitacion': model.checkCapacitacion ? 1 : 0,
      'check_visita_sso': model.checkVisitaSso ? 1 : 0,
      'check_charla': model.checkCharla ? 1 : 0,
      'check_investigacion_incidente': model.checkInvestigacion ? 1 : 0,
      'check_inspeccion_sso': model.checkInspeccionSso ? 1 : 0,
      'check_obs_conductual': model.checkObsConductual ? 1 : 0,
      'check_otro': model.checkOtro ? 1 : 0,
      'otro_actividad_texto': otroActividadCtrl.text.trim(),
      'apuntes_observaciones': observacionesCtrl.text.trim(),
      'signature_image': signatureImage,
      'tipo_actividad': selectedTipoActividad,
    };
  }

  void _onFieldChanged() {
    _debouncer.run(() => guardarBorradorSilencioso());
  }

  Future<void> _loadHistorialAutocomplete() async {
    historialEmpresas = await _repository.getEmpresasHistoricas();
    historialRegiones = await _repository.getRegionesHistoricas();
    historialCentros = await _repository.getCentrosHistoricos();
  }

  void addFoto(String path) {
    if (!fotosPaths.contains(path)) {
      fotosPaths.add(path);
      fotos.add(File(path)); // Mantener sincronía para la UI
      notifyListeners();
    }
  }

  void removeFoto(int index) {
    if (index >= 0 && index < fotosPaths.length) {
      fotosPaths.removeAt(index);
      notifyListeners();
    }
  }

  void onFotosChanged(List<File> nuevasFotos) {
    fotos = nuevasFotos;
    // Actualizar la lista de rutas para que el PDF se entere
    fotosPaths = nuevasFotos.map((f) => f.path).toList();
    _debouncer.run(() => guardarBorradorSilencioso());
    notifyListeners();
  }

  void toggleCheck(String key, bool val) {
    switch (key) {
      case 'reunion':
        model.checkReunion = val;
        break;
      case 'senaletica':
        model.checkSenaletica = val;
        break;
      case 'capacitacion':
        model.checkCapacitacion = val;
        break;
      case 'visita_sso':
        model.checkVisitaSso = val;
        break;
      case 'charla':
        model.checkCharla = val;
        break;
      case 'investigacion':
        model.checkInvestigacion = val;
        break;
      case 'inspeccion_sso':
        model.checkInspeccionSso = val;
        break;
      case 'conductual':
        model.checkObsConductual = val;
        break;
      case 'otro':
        model.checkOtro = val;
        break;
    }
    _debouncer.run(() => guardarBorradorSilencioso());
    notifyListeners();
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
      _debouncer.run(() => guardarBorradorSilencioso());
      notifyListeners();
    }
  }

  Future<void> pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fechaVisita,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      fechaVisita = picked;
      _debouncer.run(() => guardarBorradorSilencioso());
      notifyListeners();
    }
  }

  // --- 🛠️ 1. MÉTODOS REUTILIZABLES (DRY) ---

  Future<VisitReportData> _buildReportData() async {
    final user = Supabase.instance.client.auth.currentUser;

    String profesional = "Sin Profesional";
    String fonoProfesional = "No registrado";
    String correoProfesional = user?.email ?? "No registrado";

    if (user != null) {
      try {
        // CLEAN ARCHITECTURE: Delegamos la consulta al repositorio, no al controller.
        final userLocal = await _repository.getUsuarioLocal(user.id);

        if (userLocal != null) {
          profesional = userLocal['nombre_completo']?.toString() ?? profesional;
          // 🔥 CORRECCIÓN: Ahora sí extraemos el teléfono de la base local
          fonoProfesional =
              userLocal['telefono']?.toString() ?? fonoProfesional;

          debugPrint("🚀 [IDENTIDAD] Datos cargados desde SQLite local.");
        } else {
          // Fallback a metadata si no hay base local
          final metaName =
              user.userMetadata?['full_name'] ??
              user.userMetadata?['display_name'];
          if (metaName != null) {
            profesional = metaName.toString();
            debugPrint("ℹ️ [IDENTIDAD] Fallback: Metadata Supabase.");
          } else {
            debugPrint(
              "❌ [IDENTIDAD] Usuario ${user.id} sin datos locales ni metadata.",
            );
          }
        }
      } catch (e) {
        debugPrint("🚨 [IDENTIDAD] Crash crítico obteniendo identidad: $e");
      }
    }

    final List<String> galeriaPaths = fotosPaths
        .where((p) => File(p).existsSync())
        .toList();

    // Construir checklist items para el PDF
    final List<VisitChecklistItemDto> checklistItemsPdf = [];
    if (selectedTipoActividad != null) {
      for (var item in preguntasActivas) {
        final resp = respuestasMap[item.id];
        checklistItemsPdf.add(
          VisitChecklistItemDto(
            categoria: item.categoria,
            pregunta: item.pregunta,
            respuesta: resp?.estado ?? '-',
            criticidad: resp?.criticidad,
            observacion: resp?.observacion,
          ),
        );
      }
    }

    return VisitReportData(
      empresa: empresaCtrl.text.trim(),
      region: regionCtrl.text.trim().toUpperCase(),
      centro: centroCtrl.text.trim().toUpperCase(),
      profesional: profesional,
      fonoProfesional: fonoProfesional, // ¡Ahora sí viajará al PDF!
      correoProfesional: correoProfesional,
      jefaturaCargo: jefaturaCtrl.text.trim(),
      fecha: fechaVisitaStr,
      horaInicio: horaInicioStr,
      horaTermino: horaTerminoStr,
      origenVisita: origenCtrl.text.trim(),
      emailEmpresa1: email1Ctrl.text.trim(),
      emailEmpresa2: email2Ctrl.text.trim(),
      checkReunion: model.checkReunion,
      checkSenaletica: model.checkSenaletica,
      checkCapacitacion: model.checkCapacitacion,
      checkVisitaSso: model.checkVisitaSso,
      checkCharla: model.checkCharla,
      checkInvestigacion: model.checkInvestigacion,
      checkInspeccionSso: model.checkInspeccionSso,
      checkObsConductual: model.checkObsConductual,
      checkOtro: model.checkOtro,
      otroActividadTexto: otroActividadCtrl.text.trim(),
      apuntesObservaciones: observacionesCtrl.text.trim(),
      fotosPaths: galeriaPaths,
      signatureImage: signatureImage,
      tipoChecklist: selectedTipoActividad,
      checklistItems: checklistItemsPdf,
    );
  }

  Future<Uint8List> _generatePdfBytes(VisitReportData reportData) async {
    final fontReg = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
    final fontBold = await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");

    Uint8List? logoBytes;
    try {
      final logoData = await rootBundle.load('assets/images/LogoJFInnova2.png');
      logoBytes = logoData.buffer.asUint8List();
    } catch (_) {}

    final params = VisitPdfIsolateParams(
      data: reportData,
      fontRegular: fontReg.buffer.asUint8List(),
      fontBold: fontBold.buffer.asUint8List(),
      logoBytes: logoBytes,
    );

    return await compute(generateVisitPdfEntryPoint, params);
  }

  // --- 🚀 2. FLUJOS PRINCIPALES ---

  Future<void> previsualizarReporte(BuildContext context) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      debugPrint("📄 Preparando previsualización de Visita Técnica...");
      final reportData = await _buildReportData();
      final pdfBytes = await _generatePdfBytes(reportData);

      if (context.mounted) {
        // CLEAN CODE: Aplicamos la nomenclatura solicitada
        final nombrePdf = _generarNombreArchivoSanitizado(reportData);

        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: nombrePdf,
        );
      }
    } catch (e) {
      errorMessage = "Error armando el reporte: $e";
      debugPrint("❌ $errorMessage");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> guardarVisita() async {
    if (isSaving) return false;
    if (regionCtrl.text.trim().isEmpty || centroCtrl.text.trim().isEmpty) {
      errorMessage =
          "❌ No puedes guardar un registro oficial sin Región y Oficina/Área.";
      notifyListeners();
      return false;
    }

    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final reportData = await _buildReportData();
      final pdfBytes = await _generatePdfBytes(reportData);
      final directory = await getApplicationDocumentsDirectory();

      final String nombreBase = _generarNombreArchivoSanitizado(
        reportData,
      ).replaceAll('.pdf', '');
      final String pdfPathLocal =
          '${directory.path}/${nombreBase}_${_currentVisitId.substring(0, 5)}.pdf';

      final file = File(pdfPathLocal);
      await file.writeAsBytes(pdfBytes);

      // Usamos la función DRY y le decimos al Repo que YA NO es borrador
      final visitaMap = _generarMapaVisita(pdfPathLocal: pdfPathLocal);
      final fotosListPaths = fotos.map((f) => f.path).toList();

      await _repository.saveVisitaCompleta(
        visitaMap: visitaMap,
        fotosPaths: fotosListPaths,
        esBorrador: false,
        tipoChecklist: selectedTipoActividad,
        respuestasChecklist: _buildRespuestasJson(),
      );

      _syncService.sincronizarTodo().catchError(
        (e) => debugPrint("Sync error silencioso: $e"),
      );
      return true;
    } catch (e) {
      errorMessage = "Error guardando visita: $e";
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  String _generarNombreArchivoSanitizado(VisitReportData data) {
    // 1. Recopilamos los datos y manejamos nulos o vacíos
    final String region = data.region.isNotEmpty ? data.region : 'SinRegion';
    final String centro = data.centro.isNotEmpty ? data.centro : 'SinOficina';
    final String fecha = data.fecha; // Ej: 23-02-2026
    final String profesional =
        data.profesional != "-" && data.profesional.isNotEmpty
        ? data.profesional
        : 'SinProfesional';
    final String jefatura = data.jefaturaCargo.isNotEmpty
        ? data.jefaturaCargo
        : 'SinJefatura';

    // 2. Construimos la cadena en bruto
    String nombreBruto =
        "${region}_${centro}_${fecha}_${profesional}_$jefatura";

    // 3. Sanitización Estándar (Clean Code)
    // - Reemplaza espacios por guiones bajos
    // - Elimina caracteres especiales que rompen los sistemas de archivos
    final String nombreSanitizado = nombreBruto
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[áäâà]'), 'a')
        .replaceAll(RegExp(r'[éëêè]'), 'e')
        .replaceAll(RegExp(r'[íïîì]'), 'i')
        .replaceAll(RegExp(r'[óöôò]'), 'o')
        .replaceAll(RegExp(r'[úüûù]'), 'u')
        .replaceAll(RegExp(r'[ÁÄÂÀ]'), 'A')
        .replaceAll(RegExp(r'[ÉËÊÈ]'), 'E')
        .replaceAll(RegExp(r'[ÍÏÎÌ]'), 'I')
        .replaceAll(RegExp(r'[ÓÖÔÒ]'), 'O')
        .replaceAll(RegExp(r'[ÚÜÛÙ]'), 'U')
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'N')
        .replaceAll(
          RegExp(r'[^\w\-]'),
          '',
        ); // Borra cualquier cosa que no sea letra, número o guion

    return "$nombreSanitizado.pdf";
  }

  Future<void> guardarBorradorSilencioso() async {
    if (isSaving) return; // Mutex para evitar colisiones
    try {
      final visitaMap = _generarMapaVisita();
      final fotosListPaths = fotos.map((f) => f.path).toList();

      await _repository.saveVisitaCompleta(
        visitaMap: visitaMap,
        fotosPaths: fotosListPaths,
        esBorrador: true,
        tipoChecklist: selectedTipoActividad,
        respuestasChecklist: _buildRespuestasJson(),
      );
      debugPrint("💾 Borrador [En Progreso] autoguardado");
    } catch (e) {
      debugPrint("⚠️ Error guardando borrador silencioso: $e");
    }
  }

  Future<bool> eliminarBorrador() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;

      final visitaMap = {
        'estado_final': 'Eliminada',
        'eliminado': 1,
        'subido': 0,
      };

      final db = await DatabaseHelper.instance.database;
      await db.update(
        'visitas_tecnicas_pendientes',
        visitaMap,
        where: 'id = ?',
        whereArgs: [_currentVisitId],
      );

      debugPrint("🗑️ Borrador marcado como Eliminado.");

      _syncService.sincronizarTodo().catchError(
        (e) => debugPrint("Sync error: $e"),
      );

      return true;
    } catch (e) {
      debugPrint("❌ Error eliminando borrador: $e");
      return false;
    }
  }

  void cargarBorrador(Map<String, dynamic> borradorBD) {
    // 1. Restauramos el modelo y machacamos el ID nuevo generado en el constructor
    // por el ID real del borrador. ¡Cero duplicados!
    model = VisitModel.fromMap(borradorBD);
    _currentVisitId = model.activityId;

    // 2. Poblamos los controladores de texto para que la UI refleje los datos
    regionCtrl.text = model.region ?? '';
    centroCtrl.text = model.centro ?? '';
    jefaturaCtrl.text = model.jefaturaCargo ?? '';
    origenCtrl.text = model.origenVisita ?? '';
    email1Ctrl.text = model.emailEmpresa1 ?? '';
    email2Ctrl.text = model.emailEmpresa2 ?? '';
    otroActividadCtrl.text = model.otroActividadTexto ?? '';
    observacionesCtrl.text = model.apuntesObservaciones ?? '';

    // 3. Restauramos los TimeOfDay parseando los strings
    if (model.horaInicio != null && model.horaInicio != "--:--") {
      final partes = model.horaInicio!.split(':');
      if (partes.length == 2) {
        timeInicio = TimeOfDay(
          hour: int.parse(partes[0]),
          minute: int.parse(partes[1]),
        );
      }
    }

    if (model.horaTermino != null && model.horaTermino != "--:--") {
      final partes = model.horaTermino!.split(':');
      if (partes.length == 2) {
        timeTermino = TimeOfDay(
          hour: int.parse(partes[0]),
          minute: int.parse(partes[1]),
        );
      }
    }

    // Nota de Mentor: Para que el borrador sea 100% fiel, luego tendrás que hacer
    // una query a 'fotos_pendientes' filtrando por _currentVisitId y cargar esos paths
    // en tu lista 'fotosPaths'. Pero esto estabiliza los textos y checkboxes.

    notifyListeners();
  }

  // --- Helpers de Checklist ---

  Map<String, dynamic>? _buildRespuestasJson() {
    if (respuestasMap.isEmpty) return null;
    final Map<String, dynamic> json = {};
    for (var entry in respuestasMap.entries) {
      json[entry.key] = entry.value.toMap();
    }
    return json;
  }

  Future<void> _restoreChecklistFromBorrador() async {
    final checklistData = await _repository.getChecklistPorVisita(
      _currentVisitId,
    );
    if (checklistData != null) {
      final tipo = checklistData['tipo_checklist'] as String;
      selectedTipoActividad = tipo;
      preguntasActivas = await inspectionRepository.getItems(tipo);
      _parseRespuestasFromJson(
        checklistData['respuestas'] as Map<String, dynamic>,
      );
    }
  }

  Future<void> _restoreChecklistRespuestas() async {
    final checklistData = await _repository.getChecklistPorVisita(
      _currentVisitId,
    );
    if (checklistData != null &&
        checklistData['tipo_checklist'] == selectedTipoActividad) {
      _parseRespuestasFromJson(
        checklistData['respuestas'] as Map<String, dynamic>,
      );
    }
  }

  void _parseRespuestasFromJson(Map<String, dynamic> respuestas) {
    respuestasMap.clear();
    for (var entry in respuestas.entries) {
      final data = entry.value as Map<String, dynamic>;
      respuestasMap[entry.key] = VisitaRespuesta(
        id: data['id']?.toString() ?? const Uuid().v4(),
        visitaId: _currentVisitId,
        itemId: entry.key,
        estado: data['estado']?.toString() ?? '',
        observacion: data['observacion']?.toString() ?? '',
        criticidad: data['criticidad']?.toString(),
        fotoPath: data['foto_path']?.toString(),
      );
    }
  }
}
