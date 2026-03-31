import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/core/utils/rut_utils.dart';
import 'package:jf_innova_app/features/inspection/domain/models/pdf/inspection_report_data.dart';
import 'package:jf_innova_app/features/inspection/services/pdf_generator_service.dart';
import 'package:jf_innova_app/features/sync/services/sync_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/buceo_verificacion_model.dart';
import '../../domain/models/participante_model.dart';
import '../../domain/models/formulario_item.dart';
import '../../domain/repositories/inspection_repository.dart';
import '../../data/repositories/local_inspection_repository.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jf_innova_app/shared/services/image_service.dart';
import 'package:jf_innova_app/shared/utils/debouncer.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';

class InspectionFormController extends ChangeNotifier {
  final InspectionRepository _repo;
  final _syncService = SyncService();
  final _autoSaveDebouncer = Debouncer(milliseconds: 2000);
  final String activityId;
  final String tipoActividad;
  String? usuarioId;
  String? centroId;
  String? contratistaId;
  String? embarcacionId;
  List<FormularioItem> _items = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool pdfDiferido = false;
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
  final TextEditingController supervisorCentroController =
      TextEditingController();
  final TextEditingController supervisorNombreController =
      TextEditingController();
  final TextEditingController supervisorRutController = TextEditingController();
  final List<Map<String, dynamic>> fotosConObservacion = [];

  final TextEditingController correoEmpresaServiciosCtrl =
      TextEditingController();
  final TextEditingController numeroZarpeCtrl = TextEditingController();

  List<File> fotosGenerales = [];

  // --- VARIABLES ESPECÍFICAS DE BUCEO ---
  BuceoVerificacionModel? verificacionesBuceo;
  Map<String, dynamic>? verificacionesEmbarcacion;
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
    _autoSaveDebouncer.cancel();
    numeroInformeController.dispose();
    horaInicioController.dispose(); // NUEVO
    horaTerminoController.dispose(); // NUEVO
    encargadoCentroController.dispose();
    supervisorNombreController.dispose();
    supervisorRutController.dispose(); // 🟢 Limpieza
    supervisorCentroController.dispose(); // 🟢 Limpieza
    numeroZarpeCtrl.dispose(); // 🟢 Limpieza
    correoEmpresaServiciosCtrl.dispose();
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

  /// Auto-guardado silencioso con debouncer (red de seguridad contra pérdida de datos)
  void _triggerAutoSave() {
    if (_isSaving || _isLoading) return;
    _autoSaveDebouncer.run(() async {
      if (_disposed || _isSaving) return;
      try {
        await _persistirDatos(esBorrador: true);
        debugPrint("💾 Auto-guardado silencioso completado");
      } catch (e) {
        debugPrint("⚠️ Auto-guardado falló (no crítico): $e");
      }
    });
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
          centroId = data['centro_id']?.toString();
          usuarioId = data['usuario_id']?.toString();
          contratistaId = data['contratista_id']?.toString();
          embarcacionId = data['embarcacion_id']?.toString();
          _numeroSeguimiento = data['numero_seguimiento'] as int? ?? 0;

          final numeroReal = data['numero_reporte']?.toString();

          if (numeroReal != null &&
              numeroReal.isNotEmpty &&
              numeroReal != "null") {
            numeroInformeController.text = numeroReal;
          } else {
            // Borrador sin número: estimar desde Supabase/SQLite
            _cargarNumeroEstimado();
          }
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

      // 4. Cargar Fotos Previas (Solo local) - CLEAN CODE APLICADO
      if (_repo is LocalInspectionRepository) {
        final fotos = await (_repo as LocalInspectionRepository)
            .getFotosPendientes(activityId);

        for (var f in fotos) {
          final file = File(f['local_path'] as String);

          // CORRECCIÓN CRÍTICA: Lectura de disco asíncrona para no congelar la UI
          if (await file.exists()) {
            final itemId = f['item_id'] as String?;

            if (itemId == null) {
              // Regla 1: Sin ID = Galería General
              fotosGenerales.add(file);
            } else {
              // LÓGICA RELACIONAL DE UUIDs
              final esDePregunta = _items.any(
                (pregunta) => pregunta.id == itemId,
              );

              if (esDePregunta) {
                // Regla 2: Es una foto asignada a una pregunta
                fotosPorPregunta[itemId] = file;
              } else {
                // Regla 3: Tiene UUID pero no es pregunta. Es foto extra.
                fotosConObservacion.add({
                  'id': itemId, // Usamos el UUID real
                  'file': file,
                  'observacion': f['descripcion'] ?? '',
                });
              }
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
    try {
      participantes = await _repo.getParticipantes(activityId);

      // Bifurcación Limpia (SOLID)
      if (tipoActividad == 'INSPECCION_BUCEO') {
        final datosBuceo = await _repo.getVerificacionesBuceo(activityId);
        if (datosBuceo != null) {
          verificacionesBuceo = datosBuceo;
          encargadoCentroController.text = datosBuceo.encargadoCentro ?? '';
          supervisorCentroController.text = datosBuceo.supervisorCentro ?? '';
          supervisorNombreController.text = datosBuceo.supervisorNombre ?? '';
          supervisorRutController.text = datosBuceo.supervisorRut ?? '';
        } else {
          verificacionesBuceo = BuceoVerificacionModel(actividadId: activityId);
        }
        _manejarHoras(
          verificacionesBuceo?.horaInicio,
          verificacionesBuceo?.horaTermino,
        );
      } else if (tipoActividad == 'INSPECCION_EMBARCACION') {
        if (_repo is LocalInspectionRepository) {
          verificacionesEmbarcacion = await (_repo as LocalInspectionRepository)
              .getVerificacionesEmbarcacion(activityId);
          if (verificacionesEmbarcacion != null) {
            correoEmpresaServiciosCtrl.text =
                verificacionesEmbarcacion!['correo_empresa'] ?? '';
            numeroZarpeCtrl.text =
                verificacionesEmbarcacion!['numero_zarpe'] ?? '';
          }
        }
        // Cargar horas guardadas de embarcación
        _manejarHoras(
          verificacionesEmbarcacion?['hora_inicio'],
          verificacionesEmbarcacion?['hora_termino'],
        );
      }
    } catch (e) {
      debugPrint("Error cargando datos específicos: $e");
    }
  }

  // Refactor DRY para no repetir la lógica de horas
  void _manejarHoras(String? hInicio, String? hTermino) {
    if (hInicio != null && hInicio.isNotEmpty) {
      horaInicioController.text = hInicio;
      try {
        final parts = hInicio.split(":");
        _timeInicio = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      } catch (_) {}
    } else {
      final now = TimeOfDay.now();
      _timeInicio = now;
      horaInicioController.text =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    }

    if (hTermino != null && hTermino.isNotEmpty) {
      horaTerminoController.text = hTermino;
      try {
        final parts = hTermino.split(":");
        _timeTermino = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      } catch (_) {}
    }
  }

  // --- NUEVA FUNCIÓN PARA ACTUALIZAR HORAS DESDE LA VISTA ---
  void actualizarHora(bool esInicio, TimeOfDay picked) {
    final formatted =
        "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";

    if (esInicio) {
      _timeInicio = picked;
      horaInicioController.text = formatted;
      // Solo actualizamos el modelo de buceo si corresponde
      if (tipoActividad == 'INSPECCION_BUCEO') {
        updateVerificacion((m) => m.horaInicio = formatted);
      }
    } else {
      _timeTermino = picked;
      horaTerminoController.text = formatted;
      if (tipoActividad == 'INSPECCION_BUCEO') {
        updateVerificacion((m) => m.horaTermino = formatted);
      }
    }
    // Forzamos a la UI a redibujar los relojes
    notifyListeners();
    _triggerAutoSave();
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

  // // 🟢 NUEVO: Método para cambiar el estado manual de embarcación
  // void setEstadoManualEmbarcacion(String? nuevoEstado) {
  //   estadoManualEmbarcacion = nuevoEstado;
  //   notifyListeners();
  // }

  void agregarParticipante(ParticipanteModel participante) {
    if (!participantes.any((p) => p.personalId == participante.personalId)) {
      participantes.add(participante);

      // --- BLOQUE DE AUTOMATIZACIÓN ---
      // Verificamos si el cargo contiene la palabra "Supervisor" (insensible a mayúsculas)
      final cargo = participante.cargo.toLowerCase();

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
      _triggerAutoSave();
    }
  }

  void removerParticipante(String personalId) {
    participantes.removeWhere((p) => p.personalId == personalId);
    notifyListeners();
    _triggerAutoSave();
  }

  void setRespuesta(String id, String val) {
    respuestas[id] = val;
    notifyListeners();
    _triggerAutoSave();
  }

  void setObservacion(String id, String val) {
    observaciones[id] = val;
    _triggerAutoSave();
  }

  void setCriticidad(String id, String val) {
    criticidades[id] = val;
    notifyListeners();
    _triggerAutoSave();
  }

  void agregarFotosConObservacion(List<File> nuevasFotos) {
    for (var f in nuevasFotos) {
      fotosConObservacion.add({
        'id': const Uuid()
            .v4(), // ID único temporal para manejar la lista en la UI
        'file': f,
        'observacion': '', // Inicia vacío
      });
    }
    notifyListeners();
    _triggerAutoSave();
  }

  void actualizarTextoFotoObservacion(String id, String texto) {
    final index = fotosConObservacion.indexWhere((e) => e['id'] == id);
    if (index != -1) {
      fotosConObservacion[index]['observacion'] = texto;
      // Nota Senior: NO llamo notifyListeners() aquí. Si lo hago, cada letra
      // que el usuario escriba redibujará toda la vista, causando lag.
    }
  }

  void eliminarFotoObservacion(String id) {
    fotosConObservacion.removeWhere((e) => e['id'] == id);
    notifyListeners();
    _triggerAutoSave();
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
    // MUTEX: Evita que el usuario spamee el guardado
    if (_isSaving) return false;

    _isSaving = true;
    if (!silent) notifyListeners();

    try {
      // 1. Guardado Local Inmediato (Tu red de seguridad nivel 1)
      await _persistirDatos(esBorrador: true);

      // 2. Respaldo en la Nube (Tu red de seguridad nivel 2)
      // AWAIT CRÍTICO: Esperamos a que termine el sync antes de liberar el Mutex.
      // Esto previene los crasheos por Deadlock en SQLite.
      try {
        await _iniciarSincronizacionSegura();
      } catch (e) {
        debugPrint(
          "⚠️ Borrador guardado localmente, pero falló el respaldo en la nube: $e",
        );
        // No lanzamos el error hacia arriba para no arruinar la experiencia.
        // Si no hay internet, se queda en local y ya está.
      }

      return true;
    } catch (e) {
      _errorMessage = "Error guardando borrador: $e";
      return false;
    } finally {
      // 3. Liberamos el cerrojo para que la app pueda seguir funcionando
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
      debugPrint("🚀 FINALIZAR: Iniciando proceso...");

      // ---------------------------------------------------------
      // PASO 1: GUARDAR COMO BORRADOR PRIMERO (protege los datos)
      // ---------------------------------------------------------
      // Guardamos como borrador para no perder datos si falla algo después
      await _persistirDatos(esBorrador: true, pdfUrlFinal: null);

      // ---------------------------------------------------------
      // PASO 2: SINCRONIZAR PARA OBTENER NUMERO DE INFORME
      // ---------------------------------------------------------
      // Intentamos sincronizar para obtener el número de informe real.
      // Si falla (sin conexión), usamos un número provisional.
      debugPrint("🔄 Sincronizando para obtener N° de Informe...");
      try {
        await _syncService.sincronizarTodo();
        await recargarNumeroDesdeDB();
        debugPrint("✅ N° Informe obtenido: ${numeroInformeController.text}");
      } catch (e) {
        debugPrint("⚠️ Sync falló (modo offline): $e");
        // Continuamos con número provisional
      }

      // Si no hay número de informe definitivo (offline o aún no asignado),
      // diferir la generación del PDF hasta que haya conexión
      final textoNumero = numeroInformeController.text;
      final bool tieneNumeroReal =
          textoNumero.isNotEmpty &&
          !textoNumero.startsWith("PROV-") &&
          !textoNumero.startsWith("~");

      if (!tieneNumeroReal) {
        // OFFLINE: Guardar como finalizado SIN PDF
        debugPrint(
          "📴 Sin número real. Guardando sin PDF (se generará al reconectar).",
        );
        pdfDiferido = true;

        await _persistirDatos(
          esBorrador: false,
          pdfUrlFinal: null,
          pdfPathLocal: null,
        );

        // Sync para subir el estado "En Seguimiento" a Supabase
        // (el sync previo subió como "En Progreso", necesitamos re-sincronizar)
        _syncService
            .sincronizarTodo()
            .then((_) async {
              if (!_disposed) await recargarNumeroDesdeDB();
            })
            .catchError((e) {
              debugPrint("⚠️ Sync post-finalización offline falló: $e");
            });

        // Limpieza de memoria
        fotosPorPregunta.clear();
        fotosGenerales.clear();
        participantes.clear();

        return true;
      }

      // ONLINE: Continuar con generación de PDF (tiene número real)
      pdfDiferido = false;

      // ---------------------------------------------------------
      // PASO 3: CARGAR ASSETS EN EL HILO PRINCIPAL (MAIN THREAD)
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
      } catch (e) {
        debugPrint("⚠️ No se pudo cargar el logo: $e");
      }

      // ---------------------------------------------------------
      // PASO 4: PREPARAR DATOS (DTO) - ahora con número real
      // ---------------------------------------------------------
      bool esConsecutivaFinal = (_numeroSeguimiento == 1);
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
      // PASO 5: GENERAR PDF EN ISOLATE (OTRO HILO)
      // ---------------------------------------------------------
      debugPrint("🧵 ISOLATE: Generando PDF en segundo plano...");

      final pdfBytes = await compute(generatePdfEntryPoint, params);

      debugPrint("✅ PDF Generado (${pdfBytes.lengthInBytes / 1024} KB).");

      // ---------------------------------------------------------
      // PASO 6: GUARDAR PDF LOCALMENTE Y SUBIR A STORAGE
      // ---------------------------------------------------------
      String? pdfUrlSubido;
      String? pdfPathLocal;

      // 6.1 Guardar PDF localmente primero (siempre funciona)
      try {
        final directory = await getApplicationDocumentsDirectory();
        final nombreArchivo = "reporte_${reportData.numeroReporte}.pdf";
        final localFile = File('${directory.path}/$nombreArchivo');
        await localFile.writeAsBytes(pdfBytes);
        pdfPathLocal = localFile.path;
        debugPrint("💾 PDF guardado localmente: $pdfPathLocal");
      } catch (e) {
        debugPrint("❌ Error guardando PDF local: $e");
        _errorMessage = "No se pudo guardar el PDF localmente.";
        _isSaving = false;
        notifyListeners();
        return false;
      }

      // 6.2 Intentar subir a Storage (puede fallar sin conexión)
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
        debugPrint("⚠️ Error subiendo PDF (modo offline): $e");
        // PDF se subirá después con el sync automático
        // pdfUrlSubido queda null, pero tenemos pdfPathLocal
      }

      // ---------------------------------------------------------
      // PASO 7: MARCAR COMO FINALIZADO
      // ---------------------------------------------------------
      // Guardamos con la URL si la tenemos, o con path local si no
      await _persistirDatos(
        esBorrador: false,
        pdfUrlFinal: pdfUrlSubido,
        pdfPathLocal: pdfUrlSubido == null ? pdfPathLocal : null,
      );

      // Sync final para subir el estado finalizado a la nube
      // SIEMPRE intentar, incluso si el sync previo falló (puede haber conexión ahora)
      _syncService
          .sincronizarTodo()
          .then((_) async {
            // Después del sync, recargar el número por si Supabase lo generó
            if (!_disposed) await recargarNumeroDesdeDB();
          })
          .catchError((e) {
            debugPrint("Sync final Error: $e");
          });

      // ---------------------------------------------------------
      // PASO 8: LIMPIEZA DE MEMORIA (GARBAGE COLLECTION MANUAL)
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
    String? pdfPathLocal,
  }) async {
    debugPrint(
      "💾 PERSISTIR: Iniciando guardado completo (Borrador: $esBorrador)...",
    );

    String? numeroFinal = numeroInformeController.text.trim();
    // No guardar estimados (~) ni legacy como numero_reporte en SQLite
    final bool esNumeroNoReal = numeroFinal.isEmpty ||
        numeroFinal == "Pendiente..." ||
        numeroFinal == "Pendiente" ||
        numeroFinal.startsWith("~");

    if (_repo is LocalInspectionRepository) {
      final datosActualesDB = await (_repo as LocalInspectionRepository)
          .getActividad(activityId);
      final numeroEnDB = datosActualesDB?['numero_reporte']?.toString();
      if (esNumeroNoReal &&
          (numeroEnDB != null &&
              numeroEnDB.isNotEmpty &&
              numeroEnDB != "null")) {
        numeroFinal = numeroEnDB;
        numeroInformeController.text = numeroFinal;
      }
    }

    // Si sigue siendo estimado o vacío, guardar null
    if (esNumeroNoReal) {
      numeroFinal = null;
    }

    // 1. Datos Actividad (AHORA INCLUYE PDF_URL y PDF_PATH_LOCAL)
    final actividadMap = {
      'id': activityId,
      'tipo_actividad': tipoActividad,
      'centro_id': centroId,
      'usuario_id': usuarioId,
      'contratista_id': contratistaId,
      'embarcacion_id': embarcacionId,
      'fecha_realizacion': DateTime.now().toIso8601String(),
      'numero_reporte': (numeroFinal != null && numeroFinal.isNotEmpty) ? numeroFinal : null,
      'numero_seguimiento': _numeroSeguimiento,
      'pdf_url': pdfUrlFinal,
      'pdf_path_local': pdfPathLocal, // Para sync posterior cuando no hay red
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

    // C. Fotos con Observación Extra
    for (var fMap in fotosConObservacion) {
      File file = fMap['file'];
      String obs = fMap['observacion'].toString().trim();

      listaFotosParaRepo.add({
        'actividad_id': activityId,
        // CORRECCIÓN: Mandamos el UUID puro, nada de textos raros.
        'item_id': fMap['id'],
        'local_path': file.path,
        'descripcion': obs.isEmpty ? 'Fotografía anexa' : obs,
        'subido': 0,
      });
    }

    // 4. Datos Buceo & Participantes
    Map<String, dynamic>? verificacionesMap;
    Map<String, dynamic>? embarcacionMap;
    List<Map<String, dynamic>>? participantesMap;

    if (tipoActividad == 'INSPECCION_BUCEO') {
      if (verificacionesBuceo != null) {
        verificacionesBuceo!.encargadoCentro = encargadoCentroController.text
            .trim();
        verificacionesBuceo!.supervisorCentro = supervisorCentroController.text
            .trim();
        verificacionesBuceo!.supervisorNombre = supervisorNombreController.text
            .trim();
        verificacionesBuceo!.supervisorRut = supervisorRutController.text
            .trim();
        verificacionesBuceo!.horaInicio = horaInicioController.text.trim();
        verificacionesBuceo!.horaTermino = horaTerminoController.text.trim();
        verificacionesMap = verificacionesBuceo!.toMap();
      }
    } else if (tipoActividad == 'INSPECCION_EMBARCACION') {
      embarcacionMap = {
        'actividad_id': activityId,
        'correo_empresa': correoEmpresaServiciosCtrl.text.trim(),
        'numero_zarpe': numeroZarpeCtrl.text.trim(),
        'hora_inicio': horaInicioController.text.trim(),
        'hora_termino': horaTerminoController.text.trim(),
      };
    }

    // Participantes: común a BUCEO y EMBARCACIÓN
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
          'contratista_id': p.contratistaId, // <--- INCLUIR CONTRATISTA_ID
        };
      }).toList();
    }

    // 5. LLAMADA MAESTRA
    if (_repo is LocalInspectionRepository) {
      await (_repo as LocalInspectionRepository).saveInspeccionCompleta(
        actividad: actividadMap,
        respuestas: loteRespuestas,
        participantes: participantesMap,
        verificacionesBuceo: verificacionesMap,
        verificacionesEmbarcacion: embarcacionMap,
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
        contratistaId: p.contratistaId, // <--- COPIAR CONTRATISTA_ID

        condicionesOptimas: valor,
      );

      notifyListeners();
      _triggerAutoSave();
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error Crítico PDF: $e",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 10),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // CLEAN CODE: El controlador solo recibe el archivo ya capturado por la UI
  Future<void> guardarFotoDetalleBuceo(
    File fotoOriginal,
    String nombreArchivoBase,
    Function(String) onFotoGuardada,
  ) async {
    try {
      // La compresión se mantiene aquí para asegurar que el archivo final sea ligero
      File fotoComprimida = await ImageService.comprimirImagen(fotoOriginal);

      if (_repo is LocalInspectionRepository) {
        final rutaSegura = await (_repo as LocalInspectionRepository).saveFoto(
          activityId: activityId,
          itemId:
              "verif_${nombreArchivoBase}_${DateTime.now().millisecondsSinceEpoch}",
          file: XFile(fotoComprimida.path),
          descripcion: "Verificación: $nombreArchivoBase",
        );

        onFotoGuardada(rutaSegura);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("⚠️ Error guardando foto detalle: $e");
      _errorMessage = "Error al guardar la foto: $e";
      notifyListeners();
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

  /// Estima el siguiente número de informe desde Supabase (online) o SQLite (offline).
  /// Muestra con prefijo ~ para indicar que es estimado.
  Future<void> _cargarNumeroEstimado() async {
    if (_repo is LocalInspectionRepository) {
      try {
        final estimado = await (_repo as LocalInspectionRepository)
            .estimarSiguienteNumeroInforme(tipoActividad);
        if (estimado != null && !_disposed) {
          numeroInformeController.text = "~$estimado";
          notifyListeners();
        }
      } catch (e) {
        debugPrint("⚠️ Error estimando número: $e");
      }
    }
  }

  // MÉTODO PRIVADO EN InspectionFormController
  Future<InspectionReportData> _buildReportData({
    required bool esConsecutiva,
  }) async {
    final db = await DatabaseHelper.instance.database;

    String versionApp = "v1.0.0";
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      versionApp = "v${packageInfo.version}";
    } catch (e) {
      debugPrint("⚠️ No se pudo leer la versión: $e");
    }

    String nombreCliente = "S/N";
    String nombreEmpresaContratista = "S/N";
    String nombreCentro = "CENTRO S/N";
    String nombreArea = "ÁREA S/N";
    String nombreEmbarcacion = "NAVE S/N";
    String matriculaEmbarcacion = "S/N";

    // CLEAN CODE:
    // Ahora pasamos Strings (rutas de archivo) en lugar de usar readAsBytes().
    // El Isolate del PDF será el encargado de leer el disco, liberando al UI Thread.
    final String? pathIV = verificacionesBuceo?.imgAutorizacion;
    final String? pathV = verificacionesBuceo?.imgInduccion;
    final String? pathVI = verificacionesBuceo?.imgPermiso;
    final String? pathVII = verificacionesBuceo?.imgPlan;
    final String? pathVIII = verificacionesBuceo?.imgExamenes;

    String nombreProfesional = "USUARIO APP";
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser != null) {
      try {
        // 1. Intento: SQLite (Tabla local 'usuarios')
        final userLocal = await db.query(
          'usuarios',
          where: 'id = ?',
          whereArgs: [currentUser.id],
          limit: 1,
        );

        if (userLocal.isNotEmpty &&
            userLocal.first['nombre_completo']?.toString().trim().isNotEmpty ==
                true) {
          nombreProfesional = userLocal.first['nombre_completo'].toString();
          debugPrint(
            "👤 [ID-INSP] Nombre recuperado de SQLite: $nombreProfesional",
          );
        } else {
          // 2. Fallback: Metadatos de Supabase
          final meta = currentUser.userMetadata;
          final String? nombreMeta =
              meta?['nombre_completo'] ??
              meta?['full_name'] ??
              meta?['display_name'] ??
              meta?['nombre'];

          if (nombreMeta != null && nombreMeta.trim().isNotEmpty) {
            nombreProfesional = nombreMeta;
            debugPrint(
              "☁️ [ID-INSP] Fallback: Nombre recuperado de Metadata: $nombreProfesional",
            );
          } else {
            // 3. Fallback: Email (Mejor que "USUARIO APP")
            nombreProfesional = currentUser.email ?? "USUARIO APP";
            debugPrint(
              "⚠️ [ID-INSP] Sin nombre en DB ni Metadata. Usando email: $nombreProfesional",
            );
          }
        }
      } catch (e) {
        debugPrint("❌ [ID-INSP] Error crítico recuperando identidad: $e");
      }
    }

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
      debugPrint(
        "🚢 [PDF] embarcacionId=$embarcacionId | resultados=${resNave.length}",
      );
      if (resNave.isNotEmpty) {
        nombreEmbarcacion = resNave.first['nombre']?.toString() ?? "NAVE S/N";
        matriculaEmbarcacion = resNave.first['matricula']?.toString() ?? "S/N";
      }
    } else {
      debugPrint("⚠️ [PDF] embarcacionId es NULL, usando fallback NAVE S/N");
    }

    int countC = 0, countNC = 0, countNA = 0, countIntolerables = 0;
    final List<InspectionItemDto> itemsProcesados = [];

    for (var item in items) {
      final respuesta = respuestas[item.id] ?? 'N/A';
      final observacion = observaciones[item.id] ?? '';
      final criticidad = criticidades[item.id] ?? item.criticidad;

      if (respuesta == 'C') {
        countC++;
      } else if (respuesta == 'NC') {
        countNC++;
        if (criticidad == 'Intolerable') countIntolerables++;
      } else if (respuesta == 'N/A') {
        countNA++;
      }

      // CLEAN CODE:
      // Solo recolectamos las rutas absolutas de las fotos, no los bytes.
      List<String> fotosPaths = [];
      if (fotosPorPregunta.containsKey(item.id)) {
        final file = fotosPorPregunta[item.id];
        if (file != null && await file.exists()) {
          fotosPaths.add(file.path);
        }
      }

      itemsProcesados.add(
        InspectionItemDto(
          categoria: item.categoria,
          pregunta: item.pregunta,
          respuesta: respuesta,
          criticidad: criticidad,
          comentario: observacion,
          fotosPaths:
              fotosPaths, // <--- CUIDADO: Tienes que actualizar el DTO en tu modelo PDF para aceptar List<String>
        ),
      );
    }

    if (tipoActividad == 'INSPECCION_BUCEO' && verificacionesBuceo != null) {
      final criticas = [
        verificacionesBuceo!.autorizacionAutoridadMaritima,
        verificacionesBuceo!.induccionCentroCultivo,
        verificacionesBuceo!.permisoBuceoCentroCorrecto,
        verificacionesBuceo!.planContingenciasCentroOk,
        verificacionesBuceo!.examenesOcupacionalesVigentes,
      ];
      for (var cumple in criticas) {
        cumple ? countC++ : countNC++;
      }
    }

    // CLEAN CODE: Rutas de la galería
    List<String> galeriaGeneralPaths = [];
    for (var file in fotosGenerales) {
      if (await file.exists()) {
        galeriaGeneralPaths.add(file.path);
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

    // 🟢 LÓGICA DE APROBACIÓN CON CORTAFUEGOS DE SEGURIDAD
    bool aprobadoFinal = true;
    String estadoGlobalFinal = "FINALIZADA"; // Por defecto para Embarcación

    if (tipoActividad == 'INSPECCION_BUCEO') {
      aprobadoFinal =
          countIntolerables == 0 &&
          (verificacionesBuceo?.faenaHabilitada ?? true);

      estadoGlobalFinal = aprobadoFinal ? "HABILITADA" : "SUSPENDIDA";
    } else {
      // INSPECCION_EMBARCACION: NO SE SUSPENDE
      aprobadoFinal = true;
      estadoGlobalFinal =
          "REALIZADA"; // O "FINALIZADA", elige la palabra técnica correcta para JF Innova
    }

    String fmtDate(DateTime? dt) {
      if (dt == null) return "-";
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    }

    List<Map<String, String>> fotosExtraPaths = [];
    for (var fMap in fotosConObservacion) {
      File file = fMap['file'];
      if (await file.exists()) {
        fotosExtraPaths.add({
          'path': file.path,
          'observacion': fMap['observacion']?.toString().trim() ?? '',
        });
      }
    }

    return InspectionReportData(
      appVersion: versionApp,
      esConsecutiva: esConsecutiva,
      empresaContratista: nombreEmpresaContratista,
      cliente: nombreCliente,
      logoUrl: "", // No lo necesitamos, el logo pasa en PdfIsolateParams
      numeroReporte: numeroInformeController.text.isNotEmpty
          ? numeroInformeController.text
          : "S/N",
      fecha:
          "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}",
      centro: nombreCentro,
      area: nombreArea,
      embarcacion: nombreEmbarcacion,
      matricula: matriculaEmbarcacion,
      numeroZarpe: numeroZarpeCtrl.text.isNotEmpty
          ? numeroZarpeCtrl.text.trim()
          : "S/N",

      // Pasamos un Map<String, String?> con las RUTAS
      safetyPhotosPaths: {
        'IV': pathIV,
        'V': pathV,
        'VI': pathVI,
        'VII': pathVII,
        'VIII': pathVIII,
      },
      safetyObservations: {
        'IV': verificacionesBuceo?.obsAutorizacion,
        'V': verificacionesBuceo?.obsInduccion,
        'VI': verificacionesBuceo?.obsPermiso,
        'VII': verificacionesBuceo?.obsPlan,
        'VIII': verificacionesBuceo?.obsExamenes,
      },
      encargadoCentro: verificacionesBuceo?.encargadoCentro,
      correoEmpresaServicios: correoEmpresaServiciosCtrl.text.trim(),
      profesional: nombreProfesional,
      tipoFaena: tipoActividad == 'INSPECCION_EMBARCACION'
          ? "INSPECCIÓN DE EMBARCACIÓN"
          : "INSPECCIÓN DE BUCEO",
      supervisor: verificacionesBuceo?.supervisorNombre ?? "No asignado",
      horaInicio: horaInicioController.text.isNotEmpty
          ? horaInicioController.text
          : "--:--",
      horaTermino: horaTerminoController.text.isNotEmpty
          ? horaTerminoController.text
          : "--:--",
      compresor1Matricula: verificacionesBuceo?.compresor1Matricula,
      compresor1Vigencia: fmtDate(verificacionesBuceo?.compresor1Vigencia),
      compresor1PH: fmtDate(verificacionesBuceo?.compresor1VigenciaPH),
      compresor1Buzos: verificacionesBuceo?.compresor1BuzosCargo?.toString(),
      compresor2Matricula: verificacionesBuceo?.compresor2Matricula,
      compresor2Vigencia: fmtDate(verificacionesBuceo?.compresor2Vigencia),
      compresor2PH: fmtDate(verificacionesBuceo?.compresor2VigenciaPH),
      compresor2Buzos: verificacionesBuceo?.compresor2BuzosCargo?.toString(),
      estadoGlobal: estadoGlobalFinal,
      esAprobado: aprobadoFinal,
      equipo: equipoDto,
      items: itemsProcesados,
      fotosGeneralesPaths:
          galeriaGeneralPaths, // <--- Asegúrate de actualizar esto en tu DTO
      fotosExtraObservaciones: fotosExtraPaths,
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

  // Añadir dentro de InspectionFormController
  Future<ParticipanteModel?> buscarBuzoPorRut(String rut) async {
    final normalized = RutUtils.normalize(rut);
    if (normalized.isEmpty || normalized.length < 8)
      return null; // Validación temprana

    if (_repo is LocalInspectionRepository) {
      try {
        return await (_repo as LocalInspectionRepository).getPersonalByRut(
          normalized,
        );
      } catch (e) {
        debugPrint("❌ Error buscando RUT en SQLite: $e");
        return null;
      }
    }
    return null;
  }
}
