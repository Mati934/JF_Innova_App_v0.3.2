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
      await _persistirDatos();
      return true;
    } catch (e) {
      _errorMessage = "Error guardando: $e";
      return false;
    } finally {
      _isSaving = false;
      if (!silent) notifyListeners();
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

      // Validar datos de la faena
      final vb = verificacionesBuceo;
      if (vb == null || vb.nivelBuceo == null) {
        _errorMessage = "Debe seleccionar el nivel de buceo.";
        notifyListeners();
        return false;
      }

      // Si se hizo buceo, la profundidad debe ser mayor a 0
      if (vb.nivelBuceo != 'No realizada' && (vb.profundidadMaxima ?? 0) <= 0) {
        _errorMessage = "Debe ingresar una profundidad válida para la faena.";
        notifyListeners();
        return false;
      }
    }

    // 3. SI TODO ESTÁ BIEN, PROCEDEMOS A GUARDAR
    _isSaving = true;
    notifyListeners();

    try {
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

      await _persistirDatos();

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
    if (_repo is LocalInspectionRepository) {
      await (_repo as LocalInspectionRepository).saveActividad(
        id: activityId,
        tipoActividad: tipoActividad,
        centroId: centroId,
        usuarioId: usuarioId,
        contratistaId: contratistaId,
        embarcacionId: embarcacionId,
        fecha: DateTime.now(),
      );
    }

    // 2. Guardar Respuestas del Checklist
    List<Map<String, dynamic>> lote = [];
    respuestas.forEach((key, val) {
      if (fotosPorPregunta.containsKey(key)) {
        _repo.saveFoto(
          activityId: activityId,
          itemId: key,
          file: XFile(fotosPorPregunta[key]!.path),
          descripcion: 'Item $key',
        );
      }
      lote.add({
        'actividad_id': activityId,
        'item_id': key,
        'estado': val,
        'observacion': observaciones[key],
        'criticidad_registrada': criticidades[key] ?? 'Tolerable',
      });
    });
    await _repo.saveRespuestasBatch(lote);

    // 3. Guardar Fotos Generales
    for (var f in fotosGenerales) {
      await _repo.saveFoto(
        activityId: activityId,
        itemId: null,
        file: XFile(f.path),
        descripcion: 'General',
      );
    }

    // 4. GUARDAR DATOS ESPECÍFICOS DE BUCEO (NUEVO)
    if (tipoActividad == 'INSPECCION_BUCEO') {
      if (verificacionesBuceo != null) {
        await _repo.guardarVerificacionesBuceo(verificacionesBuceo!);
      }
      // Guardamos la lista SIEMPRE, para reflejar adiciones y borrados
      await _repo.guardarParticipantes(activityId, participantes);
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

      // 4. PERSONAL
      final List<PersonalDto> equipoDto = participantes
          .map(
            (p) => PersonalDto(
              nombre: p.nombreCompleto,
              rut: p.rut,
              cargo: p.cargo,
              rolEnFaena: p.cargo ?? "Técnico",
            ),
          )
          .toList();

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

      // --- CORRECCIÓN FIN ---

      final reportData = InspectionReportData(
        empresaContratista: nombreEmpresa,
        cliente: nombreCliente,
        logoUrl: "",
        numeroReporte: "001",
        fecha: fechaStr,
        centro: nombreCentro,
        area: nombreArea,
        embarcacion: nombreEmbarcacion,
        matricula: matriculaEmbarcacion,
        tipoFaena: "INSPECCIÓN DE BUCEO",
        nivelBuceo: verificacionesBuceo?.nivelBuceo ?? "No indicado",
        profundidad: (verificacionesBuceo?.profundidadMaxima ?? 0).toString(),
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
