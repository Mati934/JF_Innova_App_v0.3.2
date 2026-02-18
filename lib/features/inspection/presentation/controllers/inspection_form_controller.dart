import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/features/inspection/domain/models/pdf/inspection_report_data.dart';
import 'package:jf_innova_app/features/inspection/services/pdf_generator_service.dart';
import 'package:jf_innova_app/features/sync/services/sync_service.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../domain/models/buceo_verificacion_model.dart';
import '../../domain/models/participante_model.dart';
import '../../domain/models/formulario_item.dart';
import '../../domain/repositories/inspection_repository.dart';
import '../../data/repositories/local_inspection_repository.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data'; // Necesario para Uint8List
import 'package:jf_innova_app/shared/services/image_service.dart'; // Tu servicio de imágenes
import 'package:flutter/services.dart' show rootBundle; // Para leer fuentes
import 'package:flutter/foundation.dart'; // Para compute

class InspectionFormController extends ChangeNotifier {
  final InspectionRepository _repo;
  final _syncService = SyncService();
  final String activityId;
  final String tipoActividad;
  String? usuarioId;
  String? centroId;
  String? contratistaId;
  String? embarcacionId;
  List<FormularioItem> _items = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  int _numeroSeguimiento = 0;

  final Map<String, String> respuestas = {};
  final Map<String, String> observaciones = {};
  final Map<String, String> criticidades = {};
  final Map<String, File> fotosPorPregunta = {};

  final TextEditingController numeroInformeController = TextEditingController();
  final TextEditingController horaInicioController =
      TextEditingController(); // NUEVO
  final TextEditingController horaTerminoController =
      TextEditingController(); // NUEVO

  // 🟢 NUEVOS: Para capturar lo que el usuario escribe
  final TextEditingController encargadoCentroController =
      TextEditingController();
  final TextEditingController supervisorNombreController =
      TextEditingController();
  final TextEditingController supervisorRutController = TextEditingController();
  // final TextEditingController supervisorCentroController =
  //     TextEditingController();

  List<File> fotosGenerales = [];

  // --- VARIABLES ESPECÍFICAS DE BUCEO ---
  BuceoVerificacionModel? verificacionesBuceo;
  List<ParticipanteModel> participantes = [];

  // Para guardar la hora real y poder manipularla
  TimeOfDay? _timeInicio;
  TimeOfDay? _timeTermino;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  List<FormularioItem> get items => _items;

  bool _disposed = false;

  @override
  void dispose() {
    numeroInformeController.dispose();
    horaInicioController.dispose(); // NUEVO
    horaTerminoController.dispose(); // NUEVO
    encargadoCentroController.dispose();
    supervisorNombreController.dispose();
    supervisorRutController.dispose(); // 🟢 Limpieza
    //supervisorCentroController.dispose(); // 🟢 Limpieza
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  InspectionFormController({
    required this.activityId,
    required this.tipoActividad,
    this.centroId,
  }) : _repo = LocalInspectionRepository() {
    _init();
  }

  Future<void> _init() async {
    try {
      _isLoading = true;
      notifyListeners();

      // 1. Cargar Datos de la Actividad desde SQLite
      if (_repo is LocalInspectionRepository) {
        final data = await (_repo as LocalInspectionRepository).getActividad(
          activityId,
        );

        if (data != null) {
          centroId = data['centro_id'] as String?;
          usuarioId = data['usuario_id'] as String?;
          contratistaId = data['contratista_id'] as String?;
          embarcacionId = data['embarcacion_id'] as String?;
          _numeroSeguimiento = data['numero_seguimiento'] as int? ?? 0;

          // --- CAMBIO AQUÍ: LÓGICA PASIVA ---
          // Ya no "sugerimos" nada. Leemos lo que hay.

          final numeroReal = data['numero_reporte']?.toString();

          if (numeroReal != null &&
              numeroReal.isNotEmpty &&
              numeroReal != "null") {
            // Si el Sync ya trajo el número, lo mostramos
            numeroInformeController.text = numeroReal;
          } else {
            // Si no hay número (estamos offline y recién creada), mostramos texto de espera
            // Ojo: Si prefieres que salga vacío, ponle ""
            numeroInformeController.text = "Pendiente...";
          }
          // ----------------------------------
        }
      }

      // 2. Cargar Items
      _items = await _repo.getItems(tipoActividad);

      // 3. Cargar Respuestas Previas
      final datos = await _repo.cargarRespuestasGuardadas(activityId);
      datos.forEach((id, val) {
        if (val['estado'] != null) respuestas[id] = val['estado'];
        if (val['observacion'] != null) observaciones[id] = val['observacion'];
        if (val['criticidad'] != null) criticidades[id] = val['criticidad'];
      });

      // 4. Cargar Fotos Previas (Solo local)
      if (_repo is LocalInspectionRepository) {
        final fotos = await (_repo as LocalInspectionRepository)
            .getFotosPendientes(activityId);
        for (var f in fotos) {
          final file = File(f['local_path'] as String);
          if (file.existsSync()) {
            final itemId = f['item_id'] as String?;
            if (itemId != null) {
              fotosPorPregunta[itemId] = file;
            } else {
              fotosGenerales.add(file);
            }
          }
        }
      }

      // 5. CARGAR DATOS ESPECÍFICOS (BUCEO)
      await cargarDatosEspecificos();
    } catch (e) {
      _errorMessage = "Error cargando: $e";
      debugPrint("❌ Error en _init: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cargarDatosEspecificos() async {
    if (tipoActividad == 'INSPECCION_BUCEO') {
      try {
        final datosBuceo = await _repo.getVerificacionesBuceo(activityId);
        if (datosBuceo != null) {
          verificacionesBuceo = datosBuceo;

          // 🟢 CARGA DE DATOS A LA UI (Aquí faltaban los nuevos)
          encargadoCentroController.text = datosBuceo.encargadoCentro ?? '';

          // ✅ CORRECCIÓN: Cargar los datos del Supervisor Contratista
          supervisorNombreController.text = datosBuceo.supervisorNombre ?? '';
          supervisorRutController.text = datosBuceo.supervisorRut ?? '';
        } else {
          verificacionesBuceo = BuceoVerificacionModel(actividadId: activityId);
        }

        participantes = await _repo.getParticipantes(activityId);

        // --- LÓGICA DE HORAS ---
        // 1. Hora Inicio
        if (verificacionesBuceo?.horaInicio != null &&
            verificacionesBuceo!.horaInicio!.isNotEmpty) {
          horaInicioController.text = verificacionesBuceo!.horaInicio!;
          try {
            final parts = verificacionesBuceo!.horaInicio!.split(":");
            _timeInicio = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          } catch (_) {}
        } else {
          // Automática
          final now = TimeOfDay.now();
          _timeInicio = now;
          final horaStr =
              "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
          horaInicioController.text = horaStr;
          verificacionesBuceo?.horaInicio = horaStr;
        }

        // 2. Hora Término
        if (verificacionesBuceo?.horaTermino != null &&
            verificacionesBuceo!.horaTermino!.isNotEmpty) {
          horaTerminoController.text = verificacionesBuceo!.horaTermino!;
          try {
            final parts = verificacionesBuceo!.horaTermino!.split(":");
            _timeTermino = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          } catch (_) {}
        }
      } catch (e) {
        debugPrint("Error cargando datos buceo: $e");
      }
    }
  }

  // --- NUEVA FUNCIÓN PARA ACTUALIZAR HORAS DESDE LA VISTA ---
  void actualizarHora(bool esInicio, TimeOfDay picked) {
    final formatted =
        "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";

    if (esInicio) {
      _timeInicio = picked;
      horaInicioController.text = formatted;
      updateVerificacion((m) => m.horaInicio = formatted);
    } else {
      _timeTermino = picked;
      horaTerminoController.text = formatted;
      updateVerificacion((m) => m.horaTermino = formatted);
    }
  }

  // Helper para que el widget sepa qué hora mostrar en el reloj
  TimeOfDay getHoraInicialReloj(bool esInicio) {
    if (esInicio) return _timeInicio ?? TimeOfDay.now();
    return _timeTermino ?? TimeOfDay.now();
  }

  void updateVerificacion(Function(BuceoVerificacionModel) updates) {
    if (verificacionesBuceo == null) {
      verificacionesBuceo = BuceoVerificacionModel(actividadId: activityId);
    }
    updates(verificacionesBuceo!);
    notifyListeners();
  }

  void agregarParticipante(ParticipanteModel participante) {
    if (!participantes.any((p) => p.personalId == participante.personalId)) {
      participantes.add(participante);

      // --- BLOQUE DE AUTOMATIZACIÓN ---
      // Verificamos si el cargo contiene la palabra "Supervisor" (insensible a mayúsculas)
      final cargo = participante.cargo?.toLowerCase() ?? '';

      if (cargo.contains('supervisor')) {
        debugPrint(
          "🤖 Auto-rellenando Supervisor Contratista: ${participante.nombreCompleto}",
        );

        // 1. Llenamos los TextFields visualmente
        supervisorNombreController.text = participante.nombreCompleto;
        supervisorRutController.text = participante.rut;

        // 2. Actualizamos el modelo de datos por debajo
        updateVerificacion((m) {
          m.supervisorNombre = participante.nombreCompleto;
          m.supervisorRut = participante.rut;
        });
      }
      // -------------------------------

      notifyListeners();
    }
  }

  void removerParticipante(String personalId) {
    participantes.removeWhere((p) => p.personalId == personalId);
    notifyListeners();
  }

  void setRespuesta(String id, String val) {
    respuestas[id] = val;
    notifyListeners();
  }

  void setObservacion(String id, String val) {
    observaciones[id] = val;
  }

  void setCriticidad(String id, String val) {
    criticidades[id] = val;
    notifyListeners();
  }

  // --- MÉTODOS DE FOTO BLINDADOS (GUARDADO INMEDIATO) ---

  Future<void> setFotoPregunta(String id, File f) async {
    // 1. UI Optimista
    fotosPorPregunta[id] = f;
    notifyListeners();

    try {
      if (_repo is LocalInspectionRepository) {
        debugPrint("🛡️ Blindando foto inmediata item $id...");
        // AWAIT CRÍTICO: No dejamos que el código siga hasta que esté en disco seguro
        final rutaSegura = await (_repo as LocalInspectionRepository).saveFoto(
          activityId: activityId,
          itemId: id,
          file: XFile(f.path),
          descripcion: 'Item $id',
        );
        // Actualizamos la referencia a la ruta segura
        fotosPorPregunta[id] = File(rutaSegura);
        debugPrint("🔒 Foto segura OK.");
      }
    } catch (e) {
      debugPrint("⚠️ Error blindando foto: $e");
    }
  }

  Future<void> setFotosGenerales(List<File> newFiles) async {
    // 1. UI Optimista
    fotosGenerales = newFiles;
    notifyListeners();

    try {
      if (_repo is LocalInspectionRepository) {
        debugPrint("🛡️ Blindando galería general...");
        List<File> listaSegura = [];

        for (var f in newFiles) {
          // Si ya es segura, la mantenemos
          if (f.path.contains("inspecciones_img")) {
            listaSegura.add(f);
            continue;
          }
          // Si es nueva, la guardamos
          final rutaSegura = await (_repo as LocalInspectionRepository)
              .saveFoto(
                activityId: activityId,
                itemId: null,
                file: XFile(f.path),
                descripcion: 'General',
              );
          listaSegura.add(File(rutaSegura));
        }
        // Actualizamos la lista con puras rutas seguras
        fotosGenerales = listaSegura;
        notifyListeners();
        debugPrint("🔒 Galería segura OK.");
      }
    } catch (e) {
      debugPrint("⚠️ Error blindando galería: $e");
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> guardarBorrador({bool silent = false}) async {
    _isSaving = true;
    if (!silent) notifyListeners();

    try {
      // AQUÍ ESTÁ LA CLAVE: Persistir datos con Red de Seguridad
      await _persistirDatos(esBorrador: true);
      unawaited(_iniciarSincronizacionSegura());
      return true;
    } catch (e) {
      _errorMessage = "Error guardando localmente: $e";
      return false;
    } finally {
      _isSaving = false;
      if (!silent) notifyListeners();
    }
  }

  Future<void> _iniciarSincronizacionSegura() async {
    try {
      await _syncService.sincronizarTodo();
    } catch (e) {
      debugPrint("⚠️ Sync falló (offline): $e");
    }
  }

  // EN InspectionFormController

  // EN InspectionFormController.dart

  Future<bool> finalizarInspeccion() async {
    // 1. Limpiamos errores previos
    _errorMessage = null;

    // 2. Validación de Negocio (Buceo necesita min 2 personas)
    if (tipoActividad == 'INSPECCION_BUCEO') {
      if (participantes.length < 2) {
        _errorMessage = "Debe haber al menos 2 participantes en la cuadrilla.";
        notifyListeners();
        return false;
      }
    }

    _isSaving = true;
    notifyListeners();

    try {
      debugPrint("🚀 FINALIZAR: Iniciando proceso optimizado con Isolates...");

      // ---------------------------------------------------------
      // PASO 1: CARGAR ASSETS EN EL HILO PRINCIPAL (MAIN THREAD)
      // ---------------------------------------------------------
      // Los Isolates no tienen acceso a los assets de la app, así que
      // debemos cargarlos aquí y pasárselos como bytes crudos.
      final fontReg = await rootBundle.load(
        "assets/fonts/OpenSans-Regular.ttf",
      );
      final fontBold = await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");
      final fontItalic = await rootBundle.load(
        "assets/fonts/OpenSans-Italic.ttf",
      );

      Uint8List? logoBytes;
      try {
        final logoData = await rootBundle.load(
          'assets/images/aquachileporfin3.png',
        );
        logoBytes = logoData.buffer.asUint8List();
      } catch (e) {
        debugPrint("⚠️ No se pudo cargar el logo: $e");
      }

      // ---------------------------------------------------------
      // PASO 2: PREPARAR DATOS (DTO)
      // ---------------------------------------------------------
      // Aquí llamamos a _buildReportData.
      // IMPORTANTE: Asegúrate de que _buildReportData use '_pathToCompressedBytes'
      // para que las fotos ya vayan ligeras.
      bool esConsecutivaFinal = (_numeroSeguimiento == 1);
      final reportData = await _buildReportData(
        esConsecutiva: esConsecutivaFinal,
      );

      // Empaquetamos todo en la clase que creamos en el paso anterior
      final params = PdfIsolateParams(
        data: reportData,
        fontRegular: fontReg.buffer.asUint8List(),
        fontBold: fontBold.buffer.asUint8List(),
        fontItalic: fontItalic.buffer.asUint8List(),
        logoBytes: logoBytes,
      );

      // ---------------------------------------------------------
      // PASO 3: GENERAR PDF EN ISOLATE (OTRO HILO) 🧵
      // ---------------------------------------------------------
      // 'compute' lanza la función 'generatePdfEntryPoint' en otro núcleo del CPU.
      // Esto evita que la UI se congele y usa memoria RAM independiente.
      debugPrint("🧵 ISOLATE: Generando PDF en segundo plano...");

      final pdfBytes = await compute(generatePdfEntryPoint, params);

      debugPrint("✅ PDF Generado (${pdfBytes.lengthInBytes / 1024} KB).");

      // ---------------------------------------------------------
      // PASO 4: SUBIDA A SUPABASE (NUBE)
      // ---------------------------------------------------------
      String? pdfUrlSubido;
      try {
        final supabase = Supabase.instance.client;
        final nombreArchivo = "reporte_${reportData.numeroReporte}.pdf";
        final pathStorage = "$activityId/$nombreArchivo";

        debugPrint("☁️ Subiendo PDF a Storage...");
        await supabase.storage
            .from('reportes')
            .uploadBinary(
              pathStorage,
              pdfBytes,
              fileOptions: const FileOptions(upsert: true),
            );

        pdfUrlSubido = supabase.storage
            .from('reportes')
            .getPublicUrl(pathStorage);
        debugPrint("🔗 URL PDF: $pdfUrlSubido");
      } catch (e) {
        debugPrint(
          "⚠️ Subida falló (Posiblemente Offline). Se guardará localmente sin URL.",
        );
        pdfUrlSubido = null;
      }

      // ---------------------------------------------------------
      // PASO 5: PERSISTENCIA LOCAL Y SYNC
      // ---------------------------------------------------------
      await _persistirDatos(esBorrador: false, pdfUrlFinal: pdfUrlSubido);

      // Intentamos sincronizar en segundo plano (sin await para no bloquear)
      _syncService.sincronizarTodo().catchError(
        (e) => debugPrint("Sync Error: $e"),
      );

      // ---------------------------------------------------------
      // PASO 6: LIMPIEZA DE MEMORIA (GARBAGE COLLECTION MANUAL)
      // ---------------------------------------------------------
      // Solo limpiamos si todo salió bien. Así liberamos RAM agresivamente.
      debugPrint("🧹 ÉXITO: Liberando memoria de fotos...");
      fotosPorPregunta.clear();
      fotosGenerales.clear();
      participantes.clear();
      // _items.clear(); // Descomenta si no vas a reusar la lista de items

      return true;
    } catch (e) {
      _errorMessage = "Error al finalizar: $e";
      debugPrint("❌ ERROR CRÍTICO: $e");
      // NOTA: No limpiamos las fotos aquí para que el usuario pueda reintentar.
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // --- PERSISTENCIA CORREGIDA (SOURCE OF TRUTH) ---
  // EN InspectionFormController

  Future<void> _persistirDatos({
    required bool esBorrador,
    String? pdfUrlFinal,
  }) async {
    debugPrint(
      "💾 PERSISTIR: Iniciando guardado completo (Borrador: $esBorrador)...",
    );

    String? numeroFinal = numeroInformeController.text.trim();
    if (_repo is LocalInspectionRepository) {
      final datosActualesDB = await (_repo as LocalInspectionRepository)
          .getActividad(activityId);
      final numeroEnDB = datosActualesDB?['numero_reporte']?.toString();
      if ((numeroFinal.isEmpty || numeroFinal == "Pendiente...") &&
          (numeroEnDB != null &&
              numeroEnDB.isNotEmpty &&
              numeroEnDB != "null")) {
        numeroFinal = numeroEnDB;
        numeroInformeController.text = numeroFinal!;
      }
    }

    // 1. Datos Actividad (AHORA INCLUYE PDF_URL)
    final actividadMap = {
      'id': activityId,
      'tipo_actividad': tipoActividad,
      'centro_id': centroId,
      'usuario_id': usuarioId,
      'contratista_id': contratistaId,
      'embarcacion_id': embarcacionId,
      'fecha_realizacion': DateTime.now().toIso8601String(),
      'numero_reporte': numeroFinal,
      'numero_seguimiento': _numeroSeguimiento,
      'pdf_url':
          pdfUrlFinal, // <--- CAMBIO IMPORTANTE: Guardamos la URL si existe
    };

    // 2. Respuestas
    List<Map<String, dynamic>> loteRespuestas = [];
    respuestas.forEach((key, val) {
      loteRespuestas.add({
        'actividad_id': activityId,
        'item_id': key,
        'estado': val,
        'observacion': observaciones[key],
        'criticidad_registrada': criticidades[key] ?? 'Tolerable',
      });
    });

    // 3. FOTOS
    List<Map<String, dynamic>> listaFotosParaRepo = [];

    // A. Fotos por pregunta
    for (var entry in fotosPorPregunta.entries) {
      final itemId = entry.key;
      var file = entry.value;
      // Aseguramiento básico
      listaFotosParaRepo.add({
        'actividad_id': activityId,
        'item_id': itemId,
        'local_path': file.path,
        'descripcion': 'Item $itemId',
        'subido': 0,
      });
    }

    // B. Fotos Generales
    for (var f in fotosGenerales) {
      listaFotosParaRepo.add({
        'actividad_id': activityId,
        'item_id': null,
        'local_path': f.path,
        'descripcion': 'General',
        'subido': 0,
      });
    }

    // 4. Datos Buceo & Participantes
    Map<String, dynamic>? verificacionesMap;
    List<Map<String, dynamic>>? participantesMap;

    if (tipoActividad == 'INSPECCION_BUCEO') {
      if (verificacionesBuceo != null) {
        verificacionesBuceo!.encargadoCentro = encargadoCentroController.text
            .trim();
        verificacionesBuceo!.supervisorNombre = supervisorNombreController.text
            .trim();
        verificacionesBuceo!.supervisorRut = supervisorRutController.text
            .trim();
        verificacionesBuceo!.horaInicio = horaInicioController.text.trim();
        verificacionesBuceo!.horaTermino = horaTerminoController.text.trim();
        verificacionesMap = verificacionesBuceo!.toMap();
      }
      if (participantes.isNotEmpty) {
        participantesMap = participantes.map((p) {
          return {
            'actividad_id': activityId,
            'personal_id': p.personalId,
            'rol_en_faena': p.cargo,
            'condiciones_optimas': p.condicionesOptimas ? 1 : 0,
            'nombre_completo': p.nombreCompleto,
            'rut': p.rut,
            'cargo': p.cargo,
            'activo': 1,
            'matricula': p.matricula,
          };
        }).toList();
      }
    }

    // 5. LLAMADA MAESTRA
    if (_repo is LocalInspectionRepository) {
      await (_repo as LocalInspectionRepository).saveInspeccionCompleta(
        actividad: actividadMap,
        respuestas: loteRespuestas,
        participantes: participantesMap,
        verificacionesBuceo: verificacionesMap,
        fotos: listaFotosParaRepo,
        esBorrador: esBorrador,
      );
    }

    debugPrint(
      "✅ GUARDADO COMPLETADO. Estado: ${esBorrador ? 'Borrador' : 'Final'} | PDF: $pdfUrlFinal",
    );
  }

  void toggleCondicionesBuzo(String personalId, bool valor) {
    final index = participantes.indexWhere((p) => p.personalId == personalId);
    if (index != -1) {
      final p = participantes[index];

      // Creamos la copia actualizada
      participantes[index] = ParticipanteModel(
        personalId: p.personalId,
        nombreCompleto: p.nombreCompleto,
        rut: p.rut,
        cargo: p.cargo,

        // 🟢 ¡AQUÍ FALTABA ESTA LÍNEA!
        // Tenemos que copiar la matrícula antigua al nuevo objeto
        matricula: p.matricula,

        condicionesOptimas: valor,
      );

      notifyListeners();
    }
  }

  // EN InspectionFormController

  Future<void> previsualizarReporte(BuildContext context) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 1. Lógica de hora (Igual que antes)
      if (horaTerminoController.text.isEmpty) {
        final now = TimeOfDay.now();
        final horaFinStr =
            "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
        horaTerminoController.text = horaFinStr;
        updateVerificacion((m) => m.horaTermino = horaFinStr);
      }

      bool esConsecutivaFinal = (_numeroSeguimiento == 1);
      debugPrint(
        "📄 Previsualizando como: ${esConsecutivaFinal ? 'CONSECUTIVA' : 'INICIAL'}",
      );

      // ---------------------------------------------------------
      // PASO A: CARGAR ASSETS (Igual que en finalizarInspeccion)
      // ---------------------------------------------------------
      final fontReg = await rootBundle.load(
        "assets/fonts/OpenSans-Regular.ttf",
      );
      final fontBold = await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");
      final fontItalic = await rootBundle.load(
        "assets/fonts/OpenSans-Italic.ttf",
      );
      Uint8List? logoBytes;
      try {
        final logoData = await rootBundle.load(
          'assets/images/aquachileporfin3.png',
        );
        logoBytes = logoData.buffer.asUint8List();
      } catch (_) {}

      // ---------------------------------------------------------
      // PASO B: ARMAR DATOS Y PARÁMETROS
      // ---------------------------------------------------------
      // Usamos el constructor de datos (que ya comprime las fotos)
      final reportData = await _buildReportData(
        esConsecutiva: esConsecutivaFinal,
      );

      final params = PdfIsolateParams(
        data: reportData,
        fontRegular: fontReg.buffer.asUint8List(),
        fontBold: fontBold.buffer.asUint8List(),
        fontItalic: fontItalic.buffer.asUint8List(),
        logoBytes: logoBytes,
      );

      // ---------------------------------------------------------
      // PASO C: GENERAR PDF EN ISOLATE (SIN CONGELAR UI) 🧵
      // ---------------------------------------------------------
      final pdfBytes = await compute(generatePdfEntryPoint, params);

      // ---------------------------------------------------------
      // PASO D: MOSTRAR PREVISUALIZACIÓN
      // ---------------------------------------------------------
      final estadoReporteStr = esConsecutivaFinal ? "CONSECUTIVA" : "INICIAL";
      final nombreFinal =
          'Informe N°${reportData.numeroReporte} $estadoReporteStr $tipoActividad.pdf';

      if (context.mounted) {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: nombreFinal,
        );
      }
    } catch (e) {
      debugPrint("❌ Error PDF Preview: $e");
      _errorMessage = "Error generando PDF: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> tomarFotoDetalleBuceo(
    String nombreArchivoBase,
    Function(String) onFotoGuardada,
  ) async {
    try {
      final ImagePicker picker = ImagePicker();
      // Usamos la cámara básica, pero la magia viene abajo
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image == null) return;

      // 🟢 1. COMPRESIÓN INMEDIATA (Clean Code)
      // Antes de guardar, comprimimos usando tu servicio centralizado
      File fotoOriginal = File(image.path);
      File fotoComprimida = await ImageService.comprimirImagen(fotoOriginal);

      if (_repo is LocalInspectionRepository) {
        final rutaSegura = await (_repo as LocalInspectionRepository).saveFoto(
          activityId: activityId,
          itemId:
              "verif_${nombreArchivoBase}_${DateTime.now().millisecondsSinceEpoch}",
          // Guardamos la versión ligera (200KB) en vez de la pesada (5MB)
          file: XFile(fotoComprimida.path),
          descripcion: "Verificación: $nombreArchivoBase",
        );

        onFotoGuardada(rutaSegura);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("⚠️ Error tomando foto detalle: $e");
      _errorMessage = "Error al guardar la foto: $e";
      notifyListeners();
    }
  }

  // 🟢 COMPRESIÓN PREVENTIVA
  // Lee el archivo, lo comprime en memoria y devuelve bytes ligeros.
  Future<Uint8List?> _pathToCompressedBytes(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;

    try {
      // Opción A: Si tienes tu ImageService configurado para devolver File comprimido
      // Usamos tu servicio existente para no reinventar la rueda
      final fileComprimido = await ImageService.comprimirImagen(file);
      return await fileComprimido.readAsBytes();

      // Opción B (Si ImageService falla): FlutterImageCompress directo (si lo tienes instalado)
      // return await FlutterImageCompress.compressWithFile(path, quality: 70, minWidth: 800);
    } catch (e) {
      debugPrint("⚠️ Error comprimiendo imagen $path: $e");
      // Fallback: Si falla la compresión, leemos el original (riesgoso pero necesario)
      return await file.readAsBytes();
    }
  }

  // En InspectionFormController
  Future<void> recargarNumeroDesdeDB() async {
    if (_repo is LocalInspectionRepository) {
      final data = await (_repo as LocalInspectionRepository).getActividad(
        activityId,
      );
      final numDB = data?['numero_reporte']?.toString();

      if (numDB != null &&
          numDB.isNotEmpty &&
          numDB != "null" &&
          numDB != numeroInformeController.text) {
        numeroInformeController.text = numDB;
        notifyListeners(); // ¡Esto actualiza la UI automáticamente!
        debugPrint("🔄 UI Actualizada con Folio: $numDB");
      }
    }
  }

  // MËTODO PRIVADO EN InspectionFormController
  Future<InspectionReportData> _buildReportData({
    required bool esConsecutiva,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // 1. VARIABLES DE CABECERA DEFAULT
    String nombreCliente = "S/N";
    String nombreEmpresaContratista = "S/N";
    String nombreCentro = "CENTRO S/N";
    String nombreArea = "ÁREA S/N";
    String nombreEmbarcacion = "NAVE S/N";
    String matriculaEmbarcacion = "S/N";

    // 2. CARGA DE IMÁGENES DE SEGURIDAD (Safety Photos)
    final imgIV = await _pathToCompressedBytes(
      verificacionesBuceo?.imgAutorizacion,
    );
    final imgV = await _pathToCompressedBytes(
      verificacionesBuceo?.imgInduccion,
    );
    final imgVI = await _pathToCompressedBytes(verificacionesBuceo?.imgPermiso);
    final imgVII = await _pathToCompressedBytes(verificacionesBuceo?.imgPlan);
    final imgVIII = await _pathToCompressedBytes(
      verificacionesBuceo?.imgExamenes,
    );

    // 3. NOMBRE PROFESIONAL
    String nombreProfesional = "USUARIO APP";
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser?.userMetadata != null) {
      final meta = currentUser!.userMetadata!;
      nombreProfesional =
          meta['nombre_completo'] ??
          meta['nombre'] ??
          meta['full_name'] ??
          "USUARIO APP";
    }

    // 4. BÚSQUEDA DE DATOS RELACIONALES EN SQLITE
    if (centroId != null) {
      final resCentro = await db.query(
        'centros',
        where: 'id = ?',
        whereArgs: [centroId],
      );
      if (resCentro.isNotEmpty) {
        nombreCentro = resCentro.first['nombre'] as String;
        final areaId = resCentro.first['area_id'] as String;
        final resArea = await db.query(
          'areas',
          where: 'id = ?',
          whereArgs: [areaId],
        );
        if (resArea.isNotEmpty) {
          nombreArea = resArea.first['nombre'] as String;
          if (resArea.first['empresa_id'] != null) {
            final resCliente = await db.query(
              'empresas',
              where: 'id = ?',
              whereArgs: [resArea.first['empresa_id']],
            );
            if (resCliente.isNotEmpty) {
              nombreCliente = resCliente.first['nombre'] as String;
            }
          }
        }
      }
    }

    if (contratistaId != null) {
      final resContratista = await db.query(
        'contratistas',
        where: 'id = ?',
        whereArgs: [contratistaId],
      );
      if (resContratista.isNotEmpty) {
        nombreEmpresaContratista = resContratista.first['nombre'] as String;
      }
    }

    if (embarcacionId != null) {
      final resNave = await db.query(
        'embarcaciones',
        where: 'id = ?',
        whereArgs: [embarcacionId],
      );
      if (resNave.isNotEmpty) {
        nombreEmbarcacion = resNave.first['nombre'] as String;
        matriculaEmbarcacion = (resNave.first['matricula'] as String?) ?? "S/N";
      }
    }

    // 5. PROCESAMIENTO DE CHECKLIST Y ESTADÍSTICAS
    int countC = 0, countNC = 0, countNA = 0, countIntolerables = 0;
    final List<InspectionItemDto> itemsProcesados = [];

    for (var item in items) {
      final respuesta = respuestas[item.id] ?? 'N/A';
      final observacion = observaciones[item.id] ?? '';
      final criticidad = criticidades[item.id] ?? item.criticidad;

      if (respuesta == 'C')
        countC++;
      else if (respuesta == 'NC') {
        countNC++;
        if (criticidad == 'Intolerable') countIntolerables++;
      } else if (respuesta == 'N/A')
        countNA++;

      List<Uint8List> fotosBytes = [];
      if (fotosPorPregunta.containsKey(item.id)) {
        final file = fotosPorPregunta[item.id];
        if (file != null && await file.exists()) {
          fotosBytes.add(await file.readAsBytes());
        }
      }

      itemsProcesados.add(
        InspectionItemDto(
          categoria: item.categoria,
          pregunta: item.pregunta,
          respuesta: respuesta,
          criticidad: criticidad,
          comentario: observacion,
          fotos: fotosBytes,
        ),
      );
    }

    // Sumar verificaciones críticas de buceo
    if (tipoActividad == 'INSPECCION_BUCEO' && verificacionesBuceo != null) {
      final criticas = [
        verificacionesBuceo!.autorizacionAutoridadMaritima,
        verificacionesBuceo!.induccionCentroCultivo,
        verificacionesBuceo!.permisoBuceoCentroCorrecto,
        verificacionesBuceo!.planContingenciasCentroOk,
        verificacionesBuceo!.examenesOcupacionalesVigentes,
      ];
      for (var cumple in criticas) cumple ? countC++ : countNC++;
    }

    // 6. GALERÍA Y EQUIPO
    List<Uint8List> galeriaGeneralBytes = [];
    for (var file in fotosGenerales) {
      if (await file.exists()) {
        galeriaGeneralBytes.add(await file.readAsBytes());
      }
    }

    final List<PersonalDto> equipoDto = participantes.map((p) {
      String textoCondicion = p.condicionesOptimas ? "Optima" : "NO APTO";
      return PersonalDto(
        nombre: p.nombreCompleto,
        rut: p.rut,
        cargo: p.cargo,
        matricula: p.matricula.isEmpty ? "-" : p.matricula,
        rolEnFaena: textoCondicion,
      );
    }).toList();

    final bool aprobado =
        countIntolerables == 0 &&
        (verificacionesBuceo?.faenaHabilitada ?? true);

    // Función helper rápida para formatear fechas dentro de este método
    String _fmtDate(DateTime? dt) {
      if (dt == null) return "-";
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    }

    // 7. RETORNO DEL OBJETO DATA (SIN GENERAR PDF AÚN)
    return InspectionReportData(
      esConsecutiva: esConsecutiva,
      empresaContratista: nombreEmpresaContratista,
      cliente: nombreCliente,
      logoUrl: "",
      numeroReporte: numeroInformeController.text.isNotEmpty
          ? numeroInformeController.text
          : "S/N",
      fecha:
          "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}",
      centro: nombreCentro,
      area: nombreArea,
      embarcacion: nombreEmbarcacion,
      matricula: matriculaEmbarcacion,
      safetyPhotos: {
        'IV': imgIV,
        'V': imgV,
        'VI': imgVI,
        'VII': imgVII,
        'VIII': imgVIII,
      },
      safetyObservations: {
        'IV': verificacionesBuceo?.obsAutorizacion,
        'V': verificacionesBuceo?.obsInduccion,
        'VI': verificacionesBuceo?.obsPermiso,
        'VII': verificacionesBuceo?.obsPlan,
        'VIII': verificacionesBuceo?.obsExamenes,
      },
      encargadoCentro: verificacionesBuceo?.encargadoCentro,
      profesional: nombreProfesional,
      tipoFaena: "INSPECCIÓN DE BUCEO",
      supervisor: verificacionesBuceo?.supervisorNombre ?? "No asignado",
      horaInicio: verificacionesBuceo?.horaInicio ?? "--:--",
      horaTermino: verificacionesBuceo?.horaTermino ?? "--:--",

      // 🔥🔥🔥 AQUÍ ESTABA EL ERROR: FALTABA MAPEAR LOS COMPRESORES 🔥🔥🔥
      // Compresor 1
      compresor1Matricula: verificacionesBuceo?.compresor1Matricula,
      compresor1Vigencia: _fmtDate(verificacionesBuceo?.compresor1Vigencia),
      compresor1PH: _fmtDate(verificacionesBuceo?.compresor1VigenciaPH),
      compresor1Buzos: verificacionesBuceo?.compresor1BuzosCargo?.toString(),

      // Compresor 2
      compresor2Matricula: verificacionesBuceo?.compresor2Matricula,
      compresor2Vigencia: _fmtDate(verificacionesBuceo?.compresor2Vigencia),
      compresor2PH: _fmtDate(verificacionesBuceo?.compresor2VigenciaPH),
      compresor2Buzos: verificacionesBuceo?.compresor2BuzosCargo?.toString(),

      // ---------------------------------------------------------------
      estadoGlobal: aprobado ? "HABILITADA" : "SUSPENDIDA",
      esAprobado: aprobado,
      equipo: equipoDto,
      items: itemsProcesados,
      fotosGenerales: galeriaGeneralBytes,
      totalCumple: countC,
      totalNoCumple: countNC,
      totalNoAplica: countNA,
      totalIntolerables: countIntolerables,
      observacionPrevencionista:
          verificacionesBuceo?.observacionGeneral ?? "Sin observaciones.",
      verificacionesBuceo: {
        'IV. Autorización de la Faena':
            verificacionesBuceo?.autorizacionAutoridadMaritima ?? false,
        'V. Inducción Centro de Cultivo':
            verificacionesBuceo?.induccionCentroCultivo ?? false,
        'VI. Permiso de Buceo (Centro Correcto)':
            verificacionesBuceo?.permisoBuceoCentroCorrecto ?? false,
        'VII. Plan de Contingencias':
            verificacionesBuceo?.planContingenciasCentroOk ?? false,
        'VIII. Exámenes Ocupacionales Vigentes':
            verificacionesBuceo?.examenesOcupacionalesVigentes ?? false,
      },
    );
  }

  // Agrega esto al final de tu Controller
  Map<String, List<FormularioItem>> agruparPorCategoria() {
    final Map<String, List<FormularioItem>> map = {};
    for (var item in _items) {
      if (!map.containsKey(item.categoria)) map[item.categoria] = [];
      map[item.categoria]!.add(item);
    }
    return map;
  }
}
