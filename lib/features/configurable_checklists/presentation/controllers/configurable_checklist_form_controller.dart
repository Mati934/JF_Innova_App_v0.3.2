import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/empresa_logo_service.dart';
import '../../../../core/services/user_session.dart';
import '../../../inspection/domain/models/formulario_item.dart';
import '../../../sync/services/sync_service.dart';
import '../../data/repositories/local_configurable_checklist_repository.dart';
import '../../domain/checklist_submission.dart';
import '../../domain/models/configurable_checklist.dart';
import '../../domain/models/pdf/checklist_report_data.dart';
import '../../services/checklist_pdf_generator_service.dart';

/// Controlador del formulario de un checklist configurable (motor genérico:
/// Herramientas y Equipos — esmeril, soldadora, taladro, extensión eléctrica,
/// herramientas manuales — y cualquier otro sembrado a futuro con
/// `form_type_key = generic_standard_form`).
///
/// Incluye "Datos generales" (encabezado editable equivalente al PDF de
/// referencia), fotos por pregunta, fotos generales y firma, además de la
/// generación del PDF final.
class ConfigurableChecklistFormController extends ChangeNotifier {
  final ConfigurableChecklist checklist;
  final LocalConfigurableChecklistRepository _repo;
  final SyncService _syncService;
  final String? draftId;

  ConfigurableChecklistFormController({
    required this.checklist,
    this.draftId,
    LocalConfigurableChecklistRepository? repo,
    SyncService? syncService,
  }) : _repo = repo ?? LocalConfigurableChecklistRepository(),
       _syncService = syncService ?? SyncService();

  bool isLoading = true;
  bool isSaving = false;
  bool isPreviewing = false;
  bool _isFinalized = false;
  String? errorMessage;
  ChecklistVersion? version;
  List<FormularioItem> items = const [];
  final respuestas = <String, String?>{};
  final observaciones = <String, String>{};
  final criticidades = <String, String>{};
  String inspectionId = '';
  DateTime fechaRealizacion = DateTime.now();

  /// id local estable por pregunta (item_key -> uuid de la fila de
  /// respuesta). Se preserva entre guardados para poder vincular fotos y
  /// registros de forma consistente en vez de regenerarlo cada vez.
  final respuestaIds = <String, String>{};

  /// Fotos por pregunta (item_key -> archivo local ya blindado en disco).
  final fotosPorPregunta = <String, File>{};

  /// Fotos generales de la inspección.
  List<File> fotosGenerales = [];

  /// Firma (nombre + imagen PNG capturada con `Signature`).
  Uint8List? firmaImagen;
  String? lastSavedPdfPath;
  bool lastSyncSucceeded = false;
  Future<void>? _syncEnCurso;

  // --- Encabezado fijo (columnas propias en checklist_inspecciones) ------
  final supervisorCtrl = TextEditingController();
  final supervisorCorreoCtrl = TextEditingController();
  final firmaNombreCtrl = TextEditingController();
  final apuntesObservacionesCtrl = TextEditingController();

  // --- "Datos generales" DINÁMICOS: uno por cada `ChecklistCampoDefinicion`
  // asignado a este checklist (catálogo `checklist_campo_definiciones` +
  // `checklist_campo_asignaciones`, congelado en el snapshot de la versión).
  // Agregar/quitar un campo a un checklist es un cambio de DATOS (SQL), no
  // requiere tocar esta clase.
  final camposTextoCtrls = <String, TextEditingController>{};
  final camposHora = <String, TimeOfDay?>{};
  final camposFecha = <String, DateTime?>{};
  final camposBooleano = <String, bool>{};
  final camposSeleccionUnica = <String, String?>{};
  final camposSeleccionMultiple = <String, Set<String>>{};

  /// id local estable por campo dinámico (clave -> uuid de la fila de valor),
  /// mismo motivo que [respuestaIds]: preservarlo entre guardados.
  final campoValorIds = <String, String>{};

  List<ChecklistCampoDefinicion> get camposDefiniciones =>
      version?.camposDefiniciones ?? const [];

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      version = await _repo.getPublishedVersion(checklist.key);
      if (version == null) {
        throw StateError('CHECKLIST_VERSION_NO_DISPONIBLE');
      }
      items = version!.preguntas.map(FormularioItem.fromJson).toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));
      _initCamposControllers();
      inspectionId = draftId ?? const Uuid().v4();
      supervisorCtrl.text = UserSession().nombreCompleto ?? '';
      if (draftId != null) {
        final empresaId = UserSession().empresaId;
        if (empresaId == null) {
          throw StateError('CHECKLIST_USUARIO_EMPRESA_REQUERIDOS');
        }
        final draft = await _repo.getDraft(draftId!, empresaId);
        if (draft == null) throw StateError('CHECKLIST_BORRADOR_NO_ENCONTRADO');
        _aplicarBorrador(draft);
      }
      for (final item in items) {
        criticidades.putIfAbsent(item.id, () => item.criticidad);
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _initCamposControllers() {
    for (final def in camposDefiniciones) {
      switch (def.tipo) {
        case 'hora':
          camposHora.putIfAbsent(def.clave, () => null);
          break;
        case 'fecha':
          camposFecha.putIfAbsent(def.clave, () => null);
          break;
        case 'booleano':
          camposBooleano.putIfAbsent(def.clave, () => false);
          break;
        case 'seleccion_unica':
          camposSeleccionUnica.putIfAbsent(def.clave, () => null);
          break;
        case 'seleccion_multiple':
          camposSeleccionMultiple.putIfAbsent(def.clave, () => <String>{});
          break;
        default: // texto, texto_largo, numero, email, telefono
          camposTextoCtrls.putIfAbsent(
            def.clave,
            () => TextEditingController(),
          );
      }
    }
  }

  void _aplicarBorrador(Map<String, dynamic> draft) {
    final inspection = Map<String, dynamic>.from(draft['inspeccion'] as Map);
    supervisorCtrl.text = (inspection['quien_inspecciona'] ?? '').toString();
    supervisorCorreoCtrl.text = (inspection['supervisor_correo'] ?? '')
        .toString();
    apuntesObservacionesCtrl.text = (inspection['observaciones'] ?? '')
        .toString();
    firmaNombreCtrl.text = (inspection['firma_nombre'] ?? '').toString();

    final rawFecha = inspection['fecha_realizacion'];
    if (rawFecha != null) {
      try {
        fechaRealizacion = DateTime.parse(rawFecha.toString());
      } catch (_) {}
    }

    final firmaPath = inspection['firma_local_path']?.toString();
    if (firmaPath != null && firmaPath.isNotEmpty) {
      final f = File(firmaPath);
      if (f.existsSync()) firmaImagen = f.readAsBytesSync();
    }

    final camposPorClave = {for (final d in camposDefiniciones) d.clave: d};
    final valores =
        (draft['campos_valores'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];
    for (final v in valores) {
      final clave = v['clave']?.toString();
      if (clave == null || clave.isEmpty) continue;
      final def = camposPorClave[clave];
      if (def == null) continue;
      final valorId = v['id']?.toString();
      if (valorId != null && valorId.isNotEmpty) campoValorIds[clave] = valorId;

      switch (def.tipo) {
        case 'hora':
          camposHora[clave] = _parseHora(v['valor_texto']?.toString());
          break;
        case 'fecha':
          final raw = v['valor_fecha']?.toString();
          camposFecha[clave] = raw == null || raw.isEmpty
              ? null
              : DateTime.tryParse(raw);
          break;
        case 'booleano':
          camposBooleano[clave] =
              v['valor_booleano'] == 1 || v['valor_booleano'] == true;
          break;
        case 'seleccion_unica':
          camposSeleccionUnica[clave] = v['valor_texto']?.toString();
          break;
        case 'seleccion_multiple':
          final raw = v['valor_texto']?.toString();
          camposSeleccionMultiple[clave] = (raw == null || raw.isEmpty)
              ? <String>{}
              : raw.split('||').where((e) => e.isNotEmpty).toSet();
          break;
        default:
          final ctrl = camposTextoCtrls[clave];
          if (ctrl != null) {
            ctrl.text = def.tipo == 'numero'
                ? (v['valor_numero']?.toString() ?? '')
                : (v['valor_texto']?.toString() ?? '');
          }
      }
    }

    for (final response
        in (draft['respuestas'] as List).cast<Map<String, dynamic>>()) {
      final itemKey = response['item_key']?.toString();
      if (itemKey == null || itemKey.isEmpty) continue;
      respuestas[itemKey] = response['estado']?.toString();
      observaciones[itemKey] = response['observacion']?.toString() ?? '';
      criticidades[itemKey] = response['criticidad']?.toString() ?? '';
      final respId = response['id']?.toString();
      if (respId != null && respId.isNotEmpty) {
        respuestaIds[itemKey] = respId;
      }
    }

    final evidencias =
        (draft['evidencias'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];
    for (final ev in evidencias) {
      final tipo = ev['tipo']?.toString();
      final localPath = ev['local_path']?.toString();
      if (localPath == null || localPath.isEmpty) continue;
      final f = File(localPath);
      if (!f.existsSync()) continue;
      if (tipo == 'GENERAL') {
        fotosGenerales.add(f);
      } else if (tipo == 'RESPUESTA') {
        final itemKey = ev['respuesta_id']?.toString();
        if (itemKey != null && itemKey.isNotEmpty) {
          fotosPorPregunta[itemKey] = f;
        }
      }
    }
  }

  TimeOfDay? _parseHora(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String? _formatHora(TimeOfDay? t) {
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Map<String, List<FormularioItem>> get groupedItems {
    final grouped = <String, List<FormularioItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.categoria, () => []).add(item);
    }
    return grouped;
  }

  /// Campos dinámicos agrupados por `seccion` (para renderizar con un
  /// subtítulo por grupo), preservando el orden de cada uno.
  Map<String, List<ChecklistCampoDefinicion>> get camposPorSeccion {
    final grouped = <String, List<ChecklistCampoDefinicion>>{};
    for (final def in camposDefiniciones) {
      grouped.putIfAbsent(def.seccion, () => []).add(def);
    }
    return grouped;
  }

  String? respuestaDe(String itemId) => respuestas[itemId];
  String observacionDe(String itemId) => observaciones[itemId] ?? '';
  String criticidadDe(String itemId) => criticidades[itemId] ?? 'Tolerable';

  void setRespuesta(String itemId, String value) {
    respuestas[itemId] = value;
    notifyListeners();
  }

  void setObservacion(String itemId, String value) {
    observaciones[itemId] = value;
  }

  void setCriticidad(String itemId, String value) {
    criticidades[itemId] = value;
  }

  void setCampoHora(String clave, TimeOfDay t) {
    camposHora[clave] = t;
    notifyListeners();
  }

  void setCampoFecha(String clave, DateTime d) {
    camposFecha[clave] = d;
    notifyListeners();
  }

  void setCampoBooleano(String clave, bool value) {
    camposBooleano[clave] = value;
    notifyListeners();
  }

  void setCampoSeleccionUnica(String clave, String value) {
    camposSeleccionUnica[clave] = value;
    notifyListeners();
  }

  void toggleCampoSeleccionMultiple(String clave, String opcion) {
    final actual = camposSeleccionMultiple.putIfAbsent(clave, () => <String>{});
    if (!actual.add(opcion)) actual.remove(opcion);
    notifyListeners();
  }

  void setFirmaImagen(Uint8List bytes) {
    firmaImagen = bytes;
    notifyListeners();
  }

  Future<void> setFotoPregunta(String itemId, File file) async {
    // UI optimista.
    fotosPorPregunta[itemId] = file;
    notifyListeners();
    try {
      final rutaSegura = await _repo.saveFotoPregunta(
        inspeccionId: inspectionId,
        itemKey: itemId,
        file: file,
      );
      fotosPorPregunta[itemId] = File(rutaSegura);
    } catch (e) {
      debugPrint('⚠️ Error guardando foto de pregunta: $e');
    }
  }

  Future<void> setFotosGenerales(List<File> files) async {
    fotosGenerales = files;
    notifyListeners();
    try {
      final rutas = await _repo.saveFotosGenerales(
        inspeccionId: inspectionId,
        files: files,
      );
      fotosGenerales = rutas.map(File.new).toList();
    } catch (e) {
      debugPrint('⚠️ Error guardando fotos generales: $e');
    }
  }

  bool get canSave => !isLoading && version != null;

  List<String> get missingResponses => missingChecklistResponses(
    items
        .map((item) => <String, dynamic>{'id': item.id})
        .toList(growable: false),
    respuestas,
  );

  bool get canFinalize => canSave && missingResponses.isEmpty;

  /// Valor legible de un campo dinámico (usado tanto para armar el PDF como
  /// para mostrarlo en la UI si se necesitara).
  String valorLegibleDe(ChecklistCampoDefinicion def) {
    switch (def.tipo) {
      case 'hora':
        return _formatHora(camposHora[def.clave]) ?? '';
      case 'fecha':
        final d = camposFecha[def.clave];
        return d == null ? '' : DateFormat('dd/MM/yyyy').format(d);
      case 'booleano':
        return (camposBooleano[def.clave] ?? false) ? 'Sí' : 'No';
      case 'seleccion_unica':
        return camposSeleccionUnica[def.clave] ?? '';
      case 'seleccion_multiple':
        return (camposSeleccionMultiple[def.clave] ?? const <String>{}).join(
          ', ',
        );
      default:
        return camposTextoCtrls[def.clave]?.text.trim() ?? '';
    }
  }

  /// Construye las filas a persistir en `checklist_campo_valores_pendientes`,
  /// una por cada campo asignado al checklist (tipada según `def.tipo`).
  List<Map<String, dynamic>> _buildCamposValores() {
    return camposDefiniciones.map((def) {
      final valorId = campoValorIds.putIfAbsent(
        def.clave,
        () => const Uuid().v4(),
      );
      String? valorTexto;
      double? valorNumero;
      String? valorFecha;
      int? valorBooleano;

      switch (def.tipo) {
        case 'hora':
          valorTexto = _formatHora(camposHora[def.clave]);
          break;
        case 'fecha':
          valorFecha = camposFecha[def.clave]
              ?.toIso8601String()
              .split('T')
              .first;
          break;
        case 'booleano':
          valorBooleano = (camposBooleano[def.clave] ?? false) ? 1 : 0;
          break;
        case 'seleccion_unica':
          valorTexto = camposSeleccionUnica[def.clave];
          break;
        case 'seleccion_multiple':
          valorTexto = (camposSeleccionMultiple[def.clave] ?? const <String>{})
              .join('||');
          break;
        case 'numero':
          valorNumero = double.tryParse(
            camposTextoCtrls[def.clave]?.text.trim() ?? '',
          );
          break;
        default:
          valorTexto = camposTextoCtrls[def.clave]?.text.trim();
      }

      return {
        'id': valorId,
        'inspeccion_id': inspectionId,
        'campo_id': def.id,
        'clave': def.clave,
        'tipo': def.tipo,
        'valor_texto': valorTexto,
        'valor_numero': valorNumero,
        'valor_fecha': valorFecha,
        'valor_booleano': valorBooleano,
        'subido': 0,
      };
    }).toList();
  }

  Future<void> saveDraft() => _save('Borrador');

  Future<bool> guardarBorradorSilencioso() async {
    if (isLoading || _isFinalized) return false;
    try {
      await _save('Borrador');
      return true;
    } catch (e) {
      debugPrint('⚠️ Error autoguardando borrador de checklist: $e');
      return false;
    }
  }

  Future<void> finalize() async {
    if (!canSave) return;
    if (missingResponses.isNotEmpty) {
      throw StateError('CHECKLIST_RESPUESTAS_INCOMPLETAS');
    }
    isSaving = true;
    _isFinalized = true;
    notifyListeners();
    try {
      final pdfBytes = await _generatePdf();
      final dir = await getApplicationDocumentsDirectory();
      final pdfPath = '${dir.path}/checklist_$inspectionId.pdf';
      await File(pdfPath).writeAsBytes(pdfBytes);
      lastSavedPdfPath = pdfPath;

      await _save('En Seguimiento', pdfPathLocal: pdfPath);

      lastSyncSucceeded = false;
      _syncEnCurso = _syncService
          .sincronizarTodo()
          .then((_) {
            lastSyncSucceeded = true;
          })
          .catchError((e) {
            lastSyncSucceeded = false;
            debugPrint(
              '⚠️ Sync checklist configurable en segundo plano falló: $e',
            );
          });
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> esperarSyncConTimeout({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final fut = _syncEnCurso;
    if (fut == null) return lastSyncSucceeded;
    try {
      await fut.timeout(timeout);
    } catch (_) {}
    return lastSyncSucceeded;
  }

  Future<Uint8List> previsualizarPdf() async {
    if (isPreviewing) return Uint8List(0);
    isPreviewing = true;
    notifyListeners();
    try {
      return await _generatePdf();
    } finally {
      isPreviewing = false;
      notifyListeners();
    }
  }

  Future<Uint8List> _generatePdf() async {
    final fontReg = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final fontBold = await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');
    Uint8List? logoBytes;
    try {
      logoBytes = await EmpresaLogoService.instance.getLogoForActiveEmpresa(
        fallbackAsset: 'assets/images/LogoJFInnova2.png',
      );
    } catch (_) {}

    final fechaFmt = DateFormat('dd/MM/yyyy HH:mm').format(fechaRealizacion);
    final datosGenerales = <ChecklistHeaderField>[
      ChecklistHeaderField(
        label: 'Supervisor a cargo',
        valor: supervisorCtrl.text.trim(),
      ),
      ChecklistHeaderField(
        label: 'Correo de supervisor',
        valor: supervisorCorreoCtrl.text.trim(),
      ),
      for (final def in camposDefiniciones)
        ChecklistHeaderField(
          label: def.etiqueta,
          valor: valorLegibleDe(def).isEmpty && def.clave == 'correo_empresa_2'
              ? 'N/A'
              : valorLegibleDe(def),
        ),
    ];

    var numero = 1;
    final checklistItems = items.map((item) {
      final foto = fotosPorPregunta[item.id];
      return ChecklistPdfItemDto(
        numero: numero++,
        descripcion: item.pregunta,
        categoria: item.categoria,
        respuesta: respuestas[item.id],
        observacion: observaciones[item.id]?.isEmpty ?? true
            ? null
            : observaciones[item.id],
        fotoPath: (foto != null && foto.existsSync()) ? foto.path : null,
      );
    }).toList();

    final reportData = ChecklistReportData(
      empresaNombre: UserSession().empresaNombre ?? 'JF INNOVA',
      tituloChecklist: checklist.nombreVisible,
      fecha: fechaFmt,
      datosGenerales: datosGenerales,
      checklistItems: checklistItems,
      apuntesObservaciones: apuntesObservacionesCtrl.text.trim(),
      fotosGeneralesPaths: fotosGenerales
          .where((f) => f.existsSync())
          .map((f) => f.path)
          .toList(),
      firmaNombre: firmaNombreCtrl.text.trim().isEmpty
          ? null
          : firmaNombreCtrl.text.trim(),
      firmaImagen: firmaImagen,
    );

    final params = ChecklistPdfIsolateParams(
      data: reportData,
      fontRegular: fontReg.buffer.asUint8List(),
      fontBold: fontBold.buffer.asUint8List(),
      logoBytes: logoBytes,
    );
    return compute(generateChecklistPdfEntryPoint, params);
  }

  Future<void> _save(String estadoFinal, {String? pdfPathLocal}) async {
    if (!canSave) return;
    final session = UserSession();
    final userId = session.userId;
    final empresaId = session.empresaId;
    if (userId == null || empresaId == null) {
      throw StateError('CHECKLIST_USUARIO_EMPRESA_REQUERIDOS');
    }
    final currentVersion = version!;

    String? firmaLocalPath;
    if (firmaImagen != null) {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/checklist_firma_$inspectionId.png';
      await File(path).writeAsBytes(firmaImagen!);
      firmaLocalPath = path;
    }

    await _repo.saveDraft(
      inspection: {
        'id': inspectionId,
        'usuario_id': userId,
        'empresa_id': empresaId,
        'checklist_key': checklist.key,
        'form_type_key': checklist.formTypeKey,
        'version_id': currentVersion.id,
        'version': currentVersion.version,
        'snapshot': jsonEncode({
          'preguntas': currentVersion.preguntas,
          'campos_extra': currentVersion.camposExtra,
          'reglas': currentVersion.reglas,
        }),
        'fecha_realizacion': fechaRealizacion.toIso8601String(),
        'quien_inspecciona': supervisorCtrl.text.trim(),
        'supervisor_correo': supervisorCorreoCtrl.text.trim(),
        'observaciones': apuntesObservacionesCtrl.text.trim(),
        'firma_nombre': firmaNombreCtrl.text.trim(),
        if (firmaLocalPath != null) 'firma_local_path': firmaLocalPath,
        'estado_final': estadoFinal,
        if (pdfPathLocal != null) 'pdf_path_local': pdfPathLocal,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'subido': 0,
        'eliminado': 0,
      },
      responses: items.map((item) {
        final respId = respuestaIds.putIfAbsent(
          item.id,
          () => const Uuid().v4(),
        );
        return {
          'id': respId,
          'inspeccion_id': inspectionId,
          'item_key': item.id,
          'categoria': item.categoria,
          'pregunta': item.pregunta,
          'orden': item.orden,
          'estado': respuestas[item.id],
          'observacion': observaciones[item.id],
          'criticidad': criticidades[item.id],
          'subido': 0,
        };
      }).toList(),
      camposValores: _buildCamposValores(),
    );
  }

  @override
  void dispose() {
    supervisorCtrl.dispose();
    supervisorCorreoCtrl.dispose();
    firmaNombreCtrl.dispose();
    apuntesObservacionesCtrl.dispose();
    for (final c in camposTextoCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }
}
