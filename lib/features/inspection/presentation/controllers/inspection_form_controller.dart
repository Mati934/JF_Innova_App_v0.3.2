import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/features/inspection/domain/models/pdf/inspection_report_data.dart';
import 'package:jf_innova_app/features/inspection/services/pdf_generator_service.dart';
import 'package:jf_innova_app/features/sync/services/sync_service.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
// Asegúrate de que las rutas sean correctas en tu proyecto
import '../../domain/models/buceo_verificacion_model.dart';
import '../../domain/models/participante_model.dart';
import '../../domain/models/formulario_item.dart';
import '../../domain/repositories/inspection_repository.dart';
import '../../data/repositories/local_inspection_repository.dart';
import 'dart:typed_data';
import 'dart:async';

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

  final Map<String, String> respuestas = {};
  final Map<String, String> observaciones = {};
  final Map<String, String> criticidades = {};
  final Map<String, File> fotosPorPregunta = {};
  final TextEditingController numeroInformeController = TextEditingController();
  List<File> fotosGenerales = [];

  // --- VARIABLES ESPECÍFICAS DE BUCEO ---
  BuceoVerificacionModel? verificacionesBuceo;
  List<ParticipanteModel> participantes = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  List<FormularioItem> get items => _items;

  bool _disposed = false;

  @override
  void dispose() {
    numeroInformeController.dispose();
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
          // Cargamos todos los IDs necesarios para que persistan al finalizar
          centroId = data['centro_id'] as String?;
          usuarioId = data['usuario_id'] as String?;
          contratistaId = data['contratista_id'] as String?;
          embarcacionId = data['embarcacion_id'] as String?;

          debugPrint(
            "✅ Datos cargados del local para la actividad: $activityId",
          );
          debugPrint(
            "👤 Usuario: $usuarioId | 🏗️ Contratista: $contratistaId",
          );
        }
      }

      // 2. Cargar Items del Formulario
      _items = await _repo.getItems(tipoActividad);

      // 3. Cargar Respuestas Previas
      final datos = await _repo.cargarRespuestasGuardadas(activityId);
      debugPrint(
        "🔍 RECUPERANDO RESPUESTAS PARA $activityId",
      ); // <--- AGREGA ESTO
      debugPrint("🔍 CANTIDAD ENCONTRADA: ${datos.length}"); // <--- AGREGA ESTO
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

  // --- MÉTODOS DE BUCEO ---
  Future<void> cargarDatosEspecificos() async {
    if (tipoActividad == 'INSPECCION_BUCEO') {
      try {
        // Cargar Verificaciones
        final datosBuceo = await _repo.getVerificacionesBuceo(activityId);
        if (datosBuceo != null) {
          verificacionesBuceo = datosBuceo;
        } else {
          verificacionesBuceo = BuceoVerificacionModel(actividadId: activityId);
        }

        // Cargar Participantes
        participantes = await _repo.getParticipantes(activityId);

        // No llamamos notifyListeners aquí porque _init ya lo hará al final
      } catch (e) {
        print("Error cargando datos buceo: $e");
      }
    }
  }

  void updateVerificacion(Function(BuceoVerificacionModel) updates) {
    if (verificacionesBuceo != null) {
      updates(verificacionesBuceo!);
      notifyListeners();
    }
  }

  void agregarParticipante(ParticipanteModel participante) {
    if (!participantes.any((p) => p.personalId == participante.personalId)) {
      participantes.add(participante);
      notifyListeners();
    }
  }

  void removerParticipante(String personalId) {
    participantes.removeWhere((p) => p.personalId == personalId);
    notifyListeners();
  }
  // -------------------------

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

  void setFotoPregunta(String id, File f) {
    fotosPorPregunta[id] = f;
    notifyListeners();
  }

  void setFotosGenerales(List<File> f) {
    fotosGenerales = f;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> guardarBorrador({bool silent = false}) async {
    _isSaving = true;
    if (!silent) notifyListeners();

    try {
      // 1. Prioridad: Persistencia Local (Bloqueante)
      await _persistirDatos();

      // 2. Sincronización (No bloqueante pero explícita)
      // Usamos unawaited para indicar al linter y al lector que INTENCIONALMENTE
      // no esperamos a que esto termine para retornar el control al usuario.
      unawaited(_iniciarSincronizacionSegura());

      return true;
    } catch (e) {
      _errorMessage = "Error guardando localmente: $e";
      // Loggear error crítico aquí
      return false;
    } finally {
      _isSaving = false;
      if (!silent) notifyListeners();
    }
  }

  // Método auxiliar para aislar la lógica de sync y mantener el try-catch limpio
  Future<void> _iniciarSincronizacionSegura() async {
    try {
      await _syncService.sincronizarTodo();
    } catch (e) {
      debugPrint("⚠️ Sync falló (estrategia offline-first aplicada): $e");
      // Aquí podrías encolar un reintento para más tarde
    }
  }

  Future<bool> finalizarInspeccion() async {
    _errorMessage = null;

    // 2. VALIDACIÓN: Datos de Buceo (si aplica)
    if (tipoActividad == 'INSPECCION_BUCEO') {
      // Validar cuadrilla
      if (participantes.length < 2) {
        _errorMessage = "Debe haber al menos 2 participantes en la cuadrilla.";
        notifyListeners();
        return false;
      }
    }
    // Validar datos de la faena
    //   final vb = verificacionesBuceo;
    //   if (vb == null || vb.nivelBuceo == null) {
    //     _errorMessage = "Debe seleccionar el nivel de buceo.";
    //     notifyListeners();
    //     return false;
    //   }

    //   // Si se hizo buceo, la profundidad debe ser mayor a 0
    //   if (vb.nivelBuceo != 'No realizada' && (vb.profundidadMaxima ?? 0) <= 0) {
    //     _errorMessage = "Debe ingresar una profundidad válida para la faena.";
    //     notifyListeners();
    //     return false;
    //   }
    // }

    // 3. SI TODO ESTÁ BIEN, PROCEDEMOS A GUARDAR
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
          estado:
              'En Seguimiento', // Al cambiar a este estado, desaparece del Home
        );
      }

      // Forzamos una sincronización inmediata si hay internet
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

  Future<void> _persistirDatos() async {
    print("💾 PERSISTIR: Iniciando guardado...");
    print(
      "ℹ️ Tipo Actividad actual: '$tipoActividad'",
    ); // Verifica que sea EXACTAMENTE 'INSPECCION_BUCEO'
    // 1. Preparar Actividad
    final actividadMap = {
      'id': activityId,
      'tipo_actividad': tipoActividad,
      'centro_id': centroId,
      'usuario_id': usuarioId,
      'contratista_id': contratistaId,
      'embarcacion_id': embarcacionId,
      'fecha_realizacion': DateTime.now()
          .toIso8601String(), // SQLite prefiere texto
      // ... agrega los campos que falten según tu modelo
    };

    // --- 2. Preparar Respuestas del Checklist (Datos de texto) ---
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

    // --- 3. Preparar Fotos por Pregunta (DESACOPLADO) ---
    // Iteramos directamente sobre las fotos, sin importar si hay respuesta marcada
    for (var entry in fotosPorPregunta.entries) {
      final itemId = entry.key;
      final file = entry.value;

      // Guardamos la foto independientemente de si respondieron C/NC
      if (_repo is LocalInspectionRepository) {
        await (_repo as LocalInspectionRepository).saveFoto(
          activityId: activityId,
          itemId: itemId,
          file: XFile(file.path),
          descripcion: 'Item $itemId',
        );
      }
    }

    // 3. Preparar Datos de Buceo (Si aplica)
    Map<String, dynamic>? verificacionesMap;
    List<Map<String, dynamic>>? participantesMap;

    if (tipoActividad == 'INSPECCION_BUCEO') {
      if (verificacionesBuceo != null) {
        verificacionesMap = verificacionesBuceo!.toMap();
        print(
          "🤿 DEBUG: Verificaciones a guardar: $verificacionesMap",
        ); // Asumiendo que tienes toMap()
      } else {
        print(
          "⚠️ ALERTA: verificacionesBuceo es NULL. No se guardará el estado de faena.",
        );
      }
      print(
        "👥 DEBUG: Cantidad de participantes en memoria: ${participantes.length}",
      );
      print(
        "👥 DEBUG: Cantidad de participantes en memoria: ${participantes.length}",
      );
      // Convertimos tus objetos ParticipanteModel a Map para SQLite
      if (participantes.isNotEmpty) {
        participantesMap = participantes.map((p) {
          final map = {
            'actividad_id': activityId,
            'personal_id': p.personalId,
            'rol_en_faena': p.cargo,
            'condiciones_optimas': p.condicionesOptimas
                ? 1
                : 0, // SQLite usa 1 o 0
            // --- DATOS DE LA PERSONA (PARA CREARLA SI NO EXISTE) ---
            'nombre_completo': p.nombreCompleto, // <--- ESTO FALTABA
            'rut': p.rut, // <--- ESTO FALTABA
            // Asumimos que si lo creas al vuelo, está activo
            'activo': 1,
            // Si tienes cargo base en el modelo, úsalo, si no usa el rol
            'cargo': p.cargo,
          };
          return map;
        }).toList();
        print(
          "👥 DEBUG: Primer participante mapeado: ${participantesMap?.first}",
        );
      }
    }
    print(
      '📦 DEBUG PAYLOAD: Intentando guardar ${loteRespuestas.length} respuestas.',
    );
    if (loteRespuestas.isNotEmpty) {
      print('📦 EJEMPLO: ${loteRespuestas.first}');
    } else {
      print(
        '🚨 ALERTA: La lista de respuestas está VACÍA. El usuario respondió algo?',
      );
      print('Dump del mapa respuestas: $respuestas');
    }
    // 4. LLAMADA MAESTRA (Solo para repositorio local)
    if (_repo is LocalInspectionRepository) {
      await (_repo as LocalInspectionRepository).saveInspeccionCompleta(
        actividad: actividadMap,
        respuestas: loteRespuestas,
        participantes: participantesMap,
        verificacionesBuceo: verificacionesMap,
      );
    } else {
      // Lógica para Supabase directo si alguna vez la usas
    }

    // 5. Guardar fotos generales (pueden ir aparte, son archivos)
    for (var f in fotosGenerales) {
      await _repo.saveFoto(
        activityId: activityId,
        itemId: null,
        file: XFile(f.path),
        descripcion: 'General',
      );
    }
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
      // Como el modelo suele ser inmutable (final), creamos una copia con el dato cambiado
      // Si tu modelo no tiene copyWith, lo hacemos manual:
      final p = participantes[index];
      participantes[index] = ParticipanteModel(
        personalId: p.personalId,
        nombreCompleto: p.nombreCompleto,
        rut: p.rut,
        cargo: p.cargo,
        condicionesOptimas: valor, // <--- CAMBIO AQUÍ
      );
      notifyListeners();
    }
  }

  Future<void> previsualizarReporte(BuildContext context) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 1. BUSCAR NOMBRES REALES EN LA BASE DE DATOS (OFFLINE)
      String nombreCliente = "CLIENTE S/N";
      String nombreEmpresa = "JF INNOVA";
      String nombreCentro = "CENTRO S/N";
      String nombreArea = "ÁREA S/N";
      String nombreEmbarcacion = "NAVE S/N";
      String matriculaEmbarcacion = "S/N";

      final db = await DatabaseHelper.instance.database;

      // A. Buscar Centro y Área
      if (centroId != null) {
        final resCentro = await db.query(
          'centros',
          where: 'id = ?',
          whereArgs: [centroId],
        );
        if (resCentro.isNotEmpty) {
          nombreCentro = resCentro.first['nombre'] as String;
          // Buscar Área
          final areaId = resCentro.first['area_id'] as String;
          final resArea = await db.query(
            'areas',
            where: 'id = ?',
            whereArgs: [areaId],
          );
          if (resArea.isNotEmpty) {
            nombreArea = resArea.first['nombre'] as String;
          }
        }
      }

      // B. Buscar Contratista
      if (contratistaId != null) {
        final resContratista = await db.query(
          'contratistas',
          where: 'id = ?',
          whereArgs: [contratistaId],
        );
        if (resContratista.isNotEmpty) {
          // Opcional: Si quieres usar el nombre del contratista en vez de JF Innova
          // nombreEmpresa = resContratista.first['nombre'] as String;
        }
      }

      // C. Buscar Embarcación
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

      // 2. ESTADÍSTICAS
      int countC = 0;
      int countNC = 0;
      int countNA = 0;
      int countIntolerables = 0;
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

      // 3. FOTOS GENERALES
      List<Uint8List> galeriaGeneralBytes = [];
      for (var file in fotosGenerales) {
        if (await file.exists()) {
          galeriaGeneralBytes.add(await file.readAsBytes());
        }
      }

      // 4. PERSONAL (Lógica corregida)
      final List<PersonalDto> equipoDto = participantes.map((p) {
        // --- AQUÍ ESTÁ LA MAGIA ---
        // Definimos qué texto mostrar en la columna "Condición Física" del PDF
        String textoCondicion =
            "-"; // Guion por defecto para Supervisor/Asistente

        // Si es un Buzo, traducimos el switch (true/false) a Texto
        if (p.cargo != null && p.cargo!.toLowerCase().contains("buzo")) {
          if (p.condicionesOptimas) {
            textoCondicion = "Optima";
          } else {
            textoCondicion = "NO APTO";
          }
        }
        // ---------------------------

        return PersonalDto(
          nombre: p.nombreCompleto,
          rut: p.rut,
          cargo: p.cargo,
          // Usamos 'rolEnFaena' para transportar el estado físico al PDF
          rolEnFaena: textoCondicion,
        );
      }).toList();

      // 5. DATOS FINALES
      final now = DateTime.now();
      final fechaStr =
          "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

      // --- CORRECCIÓN INICIO ---

      // A. Validación del Checklist (Tu lógica original)
      final bool checklistOk = countIntolerables == 0;

      // B. Validación Específica de Buceo (Switches y Estado Manual)
      bool seguridadBuceoOk = true;
      if (tipoActividad == 'INSPECCION_BUCEO' && verificacionesBuceo != null) {
        // Aquí usamos el getter inteligente que creaste en tu modelo
        seguridadBuceoOk = verificacionesBuceo!.faenaHabilitada;
      }

      // C. Estado Final: Solo se habilita si EL CHECKLIST ESTÁ LIMPIO Y LA SEGURIDAD OK
      final bool aprobado = checklistOk && seguridadBuceoOk;

      final switchesMap = <String, bool>{
        'IV. Autorización de la Faena':
            verificacionesBuceo?.autorizacionAutoridadMaritima ?? false,
        'Inducción Centro de Cultivo':
            verificacionesBuceo?.induccionCentroCultivo ?? false,
        'V. Permiso de Buceo (Centro Correcto)':
            verificacionesBuceo?.permisoBuceoCentroCorrecto ?? false,
        'VI. Plan de Contingencias':
            verificacionesBuceo?.planContingenciasCentroOk ?? false,
        'VII. Exámenes Ocupacionales Vigentes':
            verificacionesBuceo?.examenesOcupacionalesVigentes ?? false,
      };

      final obsPrevencionista =
          verificacionesBuceo?.observacionGeneral ??
          "Sin observaciones registradas.";

      String numeroManual = numeroInformeController.text.trim();
      if (numeroManual.isEmpty) numeroManual = "S/N";

      // --- CORRECCIÓN FIN ---

      final reportData = InspectionReportData(
        empresaContratista: nombreEmpresa,
        cliente: nombreCliente,
        logoUrl: "",
        numeroReporte: numeroManual,
        fecha: fechaStr,
        centro: nombreCentro,
        area: nombreArea,
        embarcacion: nombreEmbarcacion,
        matricula: matriculaEmbarcacion,
        tipoFaena: "INSPECCIÓN DE BUCEO",
        supervisor: verificacionesBuceo?.supervisorNombre ?? "No asignado",

        // AQUI ES DONDE SE IMPRIME EL TEXTO QUE EL PDF VA A LEER
        estadoGlobal: aprobado ? "HABILITADA" : "SUSPENDIDA",
        esAprobado: aprobado,

        equipo: equipoDto,
        items: itemsProcesados,
        fotosGenerales: galeriaGeneralBytes,
        totalCumple: countC,
        totalNoCumple: countNC,
        totalNoAplica: countNA,
        totalIntolerables: countIntolerables,
        observacionPrevencionista: obsPrevencionista,
        verificacionesBuceo: switchesMap,
      );

      // 6. GENERAR
      final pdfService = PdfGeneratorService();
      final pdfBytes = await pdfService.generatePdf(reportData);

      if (context.mounted) {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: 'Reporte_${nombreCentro}_$fechaStr.pdf',
        );
      }
    } catch (e) {
      debugPrint("Error PDF Offline: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
