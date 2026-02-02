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

          // RECUPERAR NÚMERO REPORTE
          if (data['numero_reporte'] != null &&
              data['numero_reporte'].toString().isNotEmpty) {
            numeroInformeController.text = data['numero_reporte'];
          } else {
            // --- LÓGICA CORREGIDA ---
            // Ya no usamos usuarioId, usamos el centroId de la actividad actual
            if (centroId != null) {
              final sugerido = await (_repo as LocalInspectionRepository)
                  .sugerirSiguienteNumeroReporte(
                    centroId!,
                  ); // Pasamos el CENTRO

              if (sugerido != null) {
                numeroInformeController.text = sugerido;
              } else {
                // Si es null (no hay historial local), lo dejamos vacío
                // El Trigger de Supabase le pondrá el número correcto al subir.
                numeroInformeController.text = "";
              }
            }
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
      await _persistirDatos();
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

  Future<bool> finalizarInspeccion() async {
    _errorMessage = null;

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
      await _persistirDatos();
      if (_repo is LocalInspectionRepository) {
        await (_repo as LocalInspectionRepository).saveActividad(
          id: activityId,
          tipoActividad: tipoActividad,
          centroId: centroId,
          fecha: DateTime.now(),
          usuarioId: usuarioId,
          contratistaId: contratistaId,
          embarcacionId: embarcacionId,
          estado: 'En Seguimiento',
        );
      }

      _syncService.sincronizarTodo().catchError(
        (e) => debugPrint("Sync Error: $e"),
      );

      return true;
    } catch (e) {
      _errorMessage = "Error al finalizar: $e";
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // --- PERSISTENCIA CORREGIDA (SOURCE OF TRUTH) ---
  Future<void> _persistirDatos() async {
    debugPrint("💾 PERSISTIR: Iniciando guardado completo...");

    // 1. Datos Actividad
    final actividadMap = {
      'id': activityId,
      'tipo_actividad': tipoActividad,
      'centro_id': centroId,
      'usuario_id': usuarioId,
      'contratista_id': contratistaId,
      'embarcacion_id': embarcacionId,
      'fecha_realizacion': DateTime.now().toIso8601String(),
      'numero_reporte': numeroInformeController.text.trim(),
      'numero_seguimiento': _numeroSeguimiento,
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

    // 3. PREPARAR FOTOS (Aquí estaba el bug)
    // Creamos la lista MAESTRA que representa la verdad absoluta visual
    List<Map<String, dynamic>> listaFotosParaRepo = [];

    // --- A. FOTOS POR PREGUNTA ---
    for (var entry in fotosPorPregunta.entries) {
      final itemId = entry.key;
      var file = entry.value;

      // Si NO está segura en disco, la aseguramos primero
      if (!file.path.contains('inspecciones_img') &&
          _repo is LocalInspectionRepository) {
        try {
          final rutaSegura = await (_repo as LocalInspectionRepository)
              .saveFoto(
                activityId: activityId,
                itemId: itemId,
                file: XFile(file.path),
                descripcion: 'Item $itemId',
              );
          file = File(rutaSegura); // Actualizamos la referencia local
          fotosPorPregunta[itemId] = file; // Actualizamos el mapa en memoria
        } catch (e) {
          debugPrint("⚠️ Error asegurando foto item $itemId: $e");
        }
      }

      // AGREGAMOS A LA LISTA DEL REPO (Sea vieja o nueva, DEBE ir)
      listaFotosParaRepo.add({
        'actividad_id': activityId,
        'item_id': itemId,
        'local_path': file.path,
        'descripcion': 'Item $itemId',
        'subido': 0,
      });
    }

    // --- B. FOTOS GENERALES ---
    List<File> nuevaListaGenerales = [];
    for (var f in fotosGenerales) {
      var file = f;

      // Si NO está segura, la aseguramos
      if (!file.path.contains('inspecciones_img') &&
          _repo is LocalInspectionRepository) {
        try {
          final rutaSegura = await (_repo as LocalInspectionRepository)
              .saveFoto(
                activityId: activityId,
                itemId: null,
                file: XFile(file.path),
                descripcion: 'General',
              );
          file = File(rutaSegura);
        } catch (e) {
          debugPrint("⚠️ Error asegurando foto general: $e");
        }
      }

      nuevaListaGenerales.add(
        file,
      ); // Mantenemos la lista en memoria actualizada

      // AGREGAMOS A LA LISTA DEL REPO
      listaFotosParaRepo.add({
        'actividad_id': activityId,
        'item_id': null, // Es general
        'local_path': file.path,
        'descripcion': 'General',
        'subido': 0,
      });
    }
    fotosGenerales = nuevaListaGenerales; // Actualizamos memoria

    // 4. Datos Buceo & Participantes
    Map<String, dynamic>? verificacionesMap;
    List<Map<String, dynamic>>? participantesMap;

    if (tipoActividad == 'INSPECCION_BUCEO') {
      if (verificacionesBuceo != null) {
        // Si verificacionesBuceo es null, lo creamos
        verificacionesBuceo ??= BuceoVerificacionModel(actividadId: activityId);

        debugPrint("🕵️ [LOG 1] Guardando datos de UI en Modelo...");

        // 🟢 INYECCIÓN DE VALORES (Aquí faltaba guardar los nuevos)
        verificacionesBuceo!.encargadoCentro = encargadoCentroController.text
            .trim();

        // ✅ CORRECCIÓN: Guardar Supervisor Contratista
        verificacionesBuceo!.supervisorNombre = supervisorNombreController.text
            .trim();
        verificacionesBuceo!.supervisorRut = supervisorRutController.text
            .trim();

        // Horas
        verificacionesBuceo!.horaInicio = horaInicioController.text.trim();
        verificacionesBuceo!.horaTermino = horaTerminoController.text.trim();

        // Generar Mapa final
        verificacionesMap = verificacionesBuceo!.toMap();

        debugPrint(
          "💾 Supervisor guardado: ${verificacionesMap['supervisor_nombre']}",
        );
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

    // 5. LLAMADA MAESTRA (Ahora incluye las fotos)
    if (_repo is LocalInspectionRepository) {
      await (_repo as LocalInspectionRepository).saveInspeccionCompleta(
        actividad: actividadMap,
        respuestas: loteRespuestas,
        participantes: participantesMap,
        verificacionesBuceo: verificacionesMap,
        fotos: listaFotosParaRepo, // <--- ¡AQUÍ ESTÁ LA MAGIA!
      );
    }

    debugPrint(
      "✅ GUARDADO COMPLETADO (Con ${listaFotosParaRepo.length} fotos persistidas).",
    );
  }

  Map<String, List<FormularioItem>> agruparPorCategoria() {
    final Map<String, List<FormularioItem>> map = {};
    for (var item in _items) {
      if (!map.containsKey(item.categoria)) map[item.categoria] = [];
      map[item.categoria]!.add(item);
    }
    return map;
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

  Future<void> previsualizarReporte(BuildContext context) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 1. Hora Término Automática
      // Si el usuario no ha puesto hora, la app pone la actual para el reporte final.
      if (horaTerminoController.text.isEmpty) {
        final now = TimeOfDay.now();
        final horaFinStr =
            "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
        horaTerminoController.text = horaFinStr;
        updateVerificacion((m) => m.horaTermino = horaFinStr);
      }

      final db = await DatabaseHelper.instance.database;

      // -----------------------------------------------------------------------
      // 🟢 MODIFICACIÓN 1: DETERMINAR TIPO DE INSPECCIÓN
      // Explicación: Eliminamos el bloque try-catch que consultaba a la DB.
      // Ahora confiamos en '_numeroSeguimiento' que cargaste en el _init().
      // Si es 1, es Consecutiva; si es 0, es Inicial.
      // -----------------------------------------------------------------------
      bool esConsecutivaFinal = (_numeroSeguimiento == 1);

      debugPrint(
        "📄 Generando PDF como: ${esConsecutivaFinal ? 'CONSECUTIVA' : 'INICIAL'} (Seguimiento: $_numeroSeguimiento)",
      );

      // 2. VARIABLES DE CABECERA
      String nombreCliente = "S/N";
      String nombreEmpresaContratista = "S/N";
      String nombreCentro = "CENTRO S/N";
      String nombreArea = "ÁREA S/N";
      String nombreEmbarcacion = "NAVE S/N";
      String matriculaEmbarcacion = "S/N";

      // Carga de bytes de imágenes (Safety Photos)
      final imgIV = await _pathToBytes(verificacionesBuceo?.imgAutorizacion);
      final imgV = await _pathToBytes(verificacionesBuceo?.imgInduccion);
      final imgVI = await _pathToBytes(verificacionesBuceo?.imgPermiso);
      final imgVII = await _pathToBytes(verificacionesBuceo?.imgPlan);
      final imgVIII = await _pathToBytes(verificacionesBuceo?.imgExamenes);

      // --- Lógica de Nombres (Profesional, Centro, Cliente, etc.) ---
      // (Se mantiene tu lógica de diagnóstico de Supabase y SQLite para el profesional)
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

      // Búsqueda de información geográfica y técnica en SQLite
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
              if (resCliente.isNotEmpty)
                nombreCliente = resCliente.first['nombre'] as String;
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
        if (resContratista.isNotEmpty)
          nombreEmpresaContratista = resContratista.first['nombre'] as String;
      }

      if (embarcacionId != null) {
        final resNave = await db.query(
          'embarcaciones',
          where: 'id = ?',
          whereArgs: [embarcacionId],
        );
        if (resNave.isNotEmpty) {
          nombreEmbarcacion = resNave.first['nombre'] as String;
          matriculaEmbarcacion =
              (resNave.first['matricula'] as String?) ?? "S/N";
        }
      }

      // 3. PROCESAMIENTO DE CHECKLIST Y ESTADÍSTICAS
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
          if (file != null && await file.exists())
            fotosBytes.add(await file.readAsBytes());
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

      // Sumar verificaciones críticas de buceo a las estadísticas
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

      // 4. GALERÍA Y EQUIPO
      List<Uint8List> galeriaGeneralBytes = [];
      for (var file in fotosGenerales) {
        if (await file.exists())
          galeriaGeneralBytes.add(await file.readAsBytes());
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

      // -----------------------------------------------------------------------
      // 🟢 MODIFICACIÓN 2: CREACIÓN DEL DTO (REPORT DATA)
      // Explicación: Inyectamos 'esConsecutivaFinal' directamente.
      // -----------------------------------------------------------------------
      final reportData = InspectionReportData(
        esConsecutiva: esConsecutivaFinal, // 👈 EL CAMBIO CLAVE
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
        verificacionesBuceo: {}, // Mapa de switches si fuera necesario
      );

      // -----------------------------------------------------------------------
      // 🟢 MODIFICACIÓN 3: NOMBRE DEL ARCHIVO
      // Explicación: Usamos la misma variable para que el .pdf diga lo correcto.
      // -----------------------------------------------------------------------
      final pdfService = PdfGeneratorService();
      final pdfBytes = await pdfService.generatePdf(reportData);

      final estadoReporteStr = esConsecutivaFinal ? "CONSECUTIVA" : "INICIAL";
      final nombreFinal =
          'Informe N°${reportData.numeroReporte} $estadoReporteStr $tipoActividad $nombreCentro.pdf';

      if (context.mounted) {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: nombreFinal,
        );
      }
    } catch (e) {
      debugPrint("Error PDF Offline: $e");
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

  // Helper para leer archivos de disco a RAM de forma segura
  Future<Uint8List?> _pathToBytes(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }
}
