import 'package:flutter/material.dart';
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

class VisitFormController extends ChangeNotifier {
  final _repository = LocalVisitRepository();
  final _syncService = SyncService();

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  // Controladores de Texto
  final regionCtrl = TextEditingController();
  final centroCtrl = TextEditingController();
  final jefaturaCtrl = TextEditingController();
  final origenCtrl = TextEditingController();
  final email1Ctrl = TextEditingController();
  final email2Ctrl = TextEditingController();
  final otroActividadCtrl = TextEditingController();
  final observacionesCtrl = TextEditingController();

  // Historial para Autocomplete
  List<String> historialRegiones = [];
  List<String> historialCentros = [];

  List<String> fotosPaths = [];
  List<File> fotos = [];

  TimeOfDay? timeInicio;
  TimeOfDay? timeTermino;
  String get horaInicioStr => timeInicio != null
      ? "${timeInicio!.hour}:${timeInicio!.minute.toString().padLeft(2, '0')}"
      : "--:--";
  String get horaTerminoStr => timeTermino != null
      ? "${timeTermino!.hour}:${timeTermino!.minute.toString().padLeft(2, '0')}"
      : "--:--";

  VisitModel model = VisitModel(activityId: '');

  VisitFormController() {
    _init();
  }

  Future<void> _init() async {
    timeInicio = TimeOfDay.now();
    await _loadHistorialAutocomplete();
    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadHistorialAutocomplete() async {
    historialRegiones = await _repository.getRegionesHistoricas();
    historialCentros = await _repository.getCentrosHistoricos();
  }

  void addFoto(String path) {
    fotosPaths.add(path);
    notifyListeners();
  }

  void removeFoto(int index) {
    if (index >= 0 && index < fotosPaths.length) {
      fotosPaths.removeAt(index);
      notifyListeners();
    }
  }

  void onFotosChanged(List<File> nuevasFotos) {
    fotos = nuevasFotos;
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
      notifyListeners();
    }
  }

  // --- 🛠️ 1. MÉTODOS REUTILIZABLES (DRY) ---

  Future<VisitReportData> _buildReportData() async {
    final db = await DatabaseHelper.instance.database;
    final user = Supabase.instance.client.auth.currentUser;

    String profesional = "-";
    String fonoProfesional = "-";
    String correoProfesional = user?.email ?? "-";

    if (user != null) {
      try {
        final userQuery = await db.query(
          'usuarios',
          where: 'id = ?',
          whereArgs: [user.id],
          limit: 1,
        );

        if (userQuery.isNotEmpty) {
          final u = userQuery.first;
          if (u['nombre_completo'] != null &&
              u['nombre_completo'].toString().trim().isNotEmpty) {
            profesional = u['nombre_completo'].toString();
          }
          if (u['telefono'] != null &&
              u['telefono'].toString().trim().isNotEmpty) {
            fonoProfesional = u['telefono'].toString();
          }
          if (u['email'] != null && u['email'].toString().trim().isNotEmpty) {
            correoProfesional = u['email'].toString();
          }
        }
      } catch (e) {
        debugPrint("⚠️ Error leyendo perfil SQLite: $e");
      }
    }

    List<Uint8List> fotosBytes = [];
    for (var file in fotos) {
      if (await file.exists()) {
        fotosBytes.add(await file.readAsBytes());
      }
    }

    final now = DateTime.now();
    final fechaFormateada =
        "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";

    return VisitReportData(
      region: regionCtrl.text.trim().toUpperCase(),
      centro: centroCtrl.text.trim().toUpperCase(),
      profesional: profesional,
      fonoProfesional: fonoProfesional,
      correoProfesional: correoProfesional,
      jefaturaCargo: jefaturaCtrl.text.trim(),
      fecha: fechaFormateada,
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
      fotos: fotosBytes,
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
    if (regionCtrl.text.trim().isEmpty || centroCtrl.text.trim().isEmpty) {
      errorMessage =
          "Debe escribir la Región y la Oficina/Área para generar el PDF.";
      notifyListeners();
      return;
    }

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
      errorMessage = "Debe escribir la Región y la Oficina/Área.";
      notifyListeners();
      return false;
    }

    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final uuid = const Uuid().v4();
      final userId = Supabase.instance.client.auth.currentUser?.id;

      debugPrint("⚙️ Generando PDF inmutable en background...");
      final reportData = await _buildReportData();
      final pdfBytes = await _generatePdfBytes(reportData);

      final directory = await getApplicationDocumentsDirectory();

      // CLEAN CODE: También usamos el nombre correcto para guardarlo en el disco físico del celular.
      // Le agregamos el UUID al final solo para garantizar que jamás se sobreescriba un archivo
      // si el mismo profesional hace dos visitas al mismo lugar el mismo día.
      final String nombreBase = _generarNombreArchivoSanitizado(
        reportData,
      ).replaceAll('.pdf', '');
      final String pdfPathLocal =
          '${directory.path}/${nombreBase}_${uuid.substring(0, 5)}.pdf';

      final file = File(pdfPathLocal);
      await file.writeAsBytes(pdfBytes);
      debugPrint("💾 PDF guardado en disco: $pdfPathLocal");

      // 2. Mapeo de BD Relacional
      final regionNormalizada = regionCtrl.text.trim().toUpperCase();
      final centroNormalizado = centroCtrl.text.trim().toUpperCase();

      final visitaCompletaMap = {
        'id': uuid,
        'usuario_id': userId,
        'fecha_realizacion': DateTime.now().toIso8601String(),
        'estado_final': 'Finalizada',
        'subido': 0,
        'eliminado': 0,
        'pdf_path_local': pdfPathLocal,
        'region': regionNormalizada,
        'lugar_visita': centroNormalizado,
        'jefatura_a_cargo': jefaturaCtrl.text.trim(),
        'origen_visita': origenCtrl.text.trim(),
        'hora_inicio': horaInicioStr,
        'hora_termino': horaTerminoStr,
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
      };

      final fotosListPaths = fotos.map((f) => f.path).toList();

      await _repository.saveVisitaCompleta(
        visitaCompletaMap: visitaCompletaMap,
        fotosPaths: fotosListPaths,
      );

      _syncService.sincronizarTodo().catchError(
        (e) => debugPrint("Sync error silencioso: $e"),
      );

      return true;
    } catch (e) {
      errorMessage = "Error guardando visita: $e";
      debugPrint("❌ $errorMessage");
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
}
