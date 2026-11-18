import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/user_session.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../../../../shared/widgets/form_inputs/gallery_input.dart';
import '../../../ast/presentation/controllers/ast_photo_persistence_queue.dart';
import '../../data/repositories/local_formative_activity_repository.dart';
import '../../domain/models/formative_activity.dart';
import '../../services/formative_activity_pdf_service.dart';
import '../../../sync/services/sync_service.dart';

const _otherAreaKey = '__OTHER_AREA__';
const _noCenterKey = '__NO_CENTER__';
const _noAreaKey = '__NO_AREA__';
const _formativeColor = Color(0xFF1B3B6F);

class FormativeActivityFormScreen extends StatefulWidget {
  final String? activityId;

  const FormativeActivityFormScreen({super.key, this.activityId});

  @override
  State<FormativeActivityFormScreen> createState() =>
      _FormativeActivityFormScreenState();
}

class _FormativeActivityFormScreenState
    extends State<FormativeActivityFormScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _repository = LocalFormativeActivityRepository();
  final _attendeesController = TextEditingController();
  final _relatorController = TextEditingController();
  final _otherTypeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _otherAreaController = TextEditingController();
  final _photoQueue = AstPhotoPersistenceQueue();
  List<File> _photos = [];
  String? _photoError;

  final _activityId = const Uuid().v4();
  final _userId = UserSession().userId;
  final _companyId = UserSession().empresaId;
  final _companyName = UserSession().empresaNombre ?? 'Empresa';
  final _userName = UserSession().nombreCompleto ?? '';

  bool _loading = true;
  bool _saving = false;
  bool _autoSaving = false;
  bool _previewingPdf = false;
  bool _allowPop = false;
  bool _dirty = false;
  int _changeRevision = 0;
  String? _error;
  String? _autoSaveError;
  Timer? _autoSaveDebounce;
  Timer? _periodicAutoSave;
  String _activityType = 'CHARLA';
  String _areaSelection = _noAreaKey;
  String _centerSelection = _noCenterKey;
  DateTime _date = DateTime.now();
  TimeOfDay _start = TimeOfDay.now();
  TimeOfDay _end = TimeOfDay.fromDateTime(
    DateTime.now().add(const Duration(minutes: 15)),
  );
  Uint8List? _savedSignature;
  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _centers = [];

  String get _id => widget.activityId ?? _activityId;
  int? get _durationMinutes =>
      FormativeActivity.durationMinutes(_formatTime(_start), _formatTime(_end));
  int? get _accountedDuration {
    final duration = _durationMinutes;
    return duration == null
        ? null
        : FormativeActivity.accountedDurationMinutes(duration);
  }

  int get _attendees => int.tryParse(_attendeesController.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _relatorController.text = _userName;
    _attendeesController.addListener(_refreshTotals);
    _otherTypeController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _otherAreaController.addListener(_onFieldChanged);
    _relatorController.addListener(_onFieldChanged);
    _periodicAutoSave = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _saveDraftSilently(),
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = _userId;
      final companyId = _companyId;
      if (userId == null || companyId == null) {
        throw StateError('SESIÓN_SIN_USUARIO_O_EMPRESA');
      }
      _areas = await _repository.getAreas(companyId);
      _centers = await _repository.getCentros(companyId);
      if (_areas.isEmpty || _centers.isEmpty) {
        await SyncService().descargarDatosMaestros();
        _areas = await _repository.getAreas(companyId);
        _centers = await _repository.getCentros(companyId);
      }

      final existing = widget.activityId == null
          ? null
          : await _repository.getById(widget.activityId!);
      if (existing != null) {
        _loadExisting(existing);
        _photos = (await _repository.getPhotoPaths(_id)).map(File.new).toList();
      } else {
        final suggestedAreaId = await _repository.getSuggestedAreaId(
          userId,
          companyId,
        );
        if (suggestedAreaId != null &&
            _areas.any((area) => area['id']?.toString() == suggestedAreaId)) {
          _areaSelection = suggestedAreaId;
        }
      }
    } catch (e) {
      _error = 'Error cargando actividad: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadExisting(Map<String, dynamic> row) {
    _date =
        DateTime.tryParse(row['fecha_realizacion']?.toString() ?? '') ??
        DateTime.now();
    _activityType = row['actividad_formativa_tipo']?.toString() ?? 'CHARLA';
    final areaId = row['area_id']?.toString();
    _areaSelection =
        areaId != null && _areas.any((area) => area['id'] == areaId)
        ? areaId
        : (row['area_otro']?.toString().isNotEmpty == true
              ? _otherAreaKey
              : _noAreaKey);
    _otherAreaController.text = row['area_otro']?.toString() ?? '';
    final centerId = row['centro_id']?.toString();
    _centerSelection =
        centerId != null && _centers.any((center) => center['id'] == centerId)
        ? centerId
        : _noCenterKey;
    _otherTypeController.text = row['tipo_otro']?.toString() ?? '';
    _descriptionController.text = row['descripcion']?.toString() ?? '';
    _attendeesController.text = row['asistentes']?.toString() ?? '';
    _relatorController.text = row['relator_nombre']?.toString() ?? _userName;
    _start = _parseTime(row['hora_inicio']?.toString()) ?? _start;
    _end = _parseTime(row['hora_termino']?.toString()) ?? _end;
    final signature = row['firma_relator_image'];
    if (signature is Uint8List) _savedSignature = signature;
    if (signature is List<int>) _savedSignature = Uint8List.fromList(signature);
  }

  TimeOfDay? _parseTime(String? value) {
    final match = value == null
        ? null
        : RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
    if (match == null) return null;
    return TimeOfDay(
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
    );
  }

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  void _refreshTotals() {
    if (!mounted) return;
    setState(() {});
    _onFieldChanged();
  }

  void _onFieldChanged() {
    if (_loading || _saving) return;
    _dirty = true;
    _changeRevision++;
    _autoSaveError = null;
    _autoSaveDebounce?.cancel();
    if (_autoSaving) return;
    _autoSaveDebounce = Timer(
      const Duration(milliseconds: 900),
      _saveDraftSilently,
    );
  }

  Future<void> _saveDraftSilently() async {
    if (!_dirty ||
        _loading ||
        _saving ||
        _autoSaving ||
        _previewingPdf ||
        _error != null) {
      return;
    }
    _autoSaveDebounce?.cancel();
    _autoSaving = true;
    final savingRevision = _changeRevision;
    var saveSucceeded = false;
    try {
      await _waitForPhotos();
      await _repository.save(
        _buildActivity(status: 'En Progreso'),
        finalized: false,
        signatureBytes: _savedSignature,
      );
      saveSucceeded = true;
      _dirty = _changeRevision != savingRevision;
      _autoSaveError = null;
    } catch (e) {
      _autoSaveError = 'No se pudo guardar el borrador automáticamente: $e';
      debugPrint(_autoSaveError);
      if (mounted) _showMessage(_autoSaveError!);
    } finally {
      _autoSaving = false;
      if (mounted) {
        setState(() {});
        if (_dirty && saveSucceeded) {
          _autoSaveDebounce = Timer(
            const Duration(milliseconds: 900),
            _saveDraftSilently,
          );
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_saveDraftSilently());
    }
  }

  String? _areaName() {
    if (_areaSelection == _otherAreaKey || _areaSelection == _noAreaKey) {
      return null;
    }
    for (final area in _areas) {
      if (area['id']?.toString() == _areaSelection) {
        return area['nombre']?.toString();
      }
    }
    return null;
  }

  String? _centerName() {
    if (_centerSelection == _noCenterKey) return null;
    for (final center in _centers) {
      if (center['id']?.toString() == _centerSelection) {
        return center['nombre']?.toString();
      }
    }
    return null;
  }

  String get _centerLabel => _centerName() ?? 'Sin centro';

  String get _areaLabel {
    if (_areaSelection == _otherAreaKey) {
      return _otherAreaController.text.trim().isEmpty
          ? 'Otro (especificar)'
          : _otherAreaController.text.trim();
    }
    return _areaName() ?? 'Sin área';
  }

  String get _activityTypeLabel => switch (_activityType) {
    'CHARLA' => 'Charla',
    'SERVICIO' => 'Servicio',
    'CAPACITACION' => 'Capacitación',
    'OTRO' => 'Otro',
    _ => 'Charla',
  };

  List<String> get _centerOptions => [
    'Sin centro',
    ..._centers.map((center) => center['nombre']?.toString() ?? ''),
  ];

  List<String> get _areaOptions => [
    'Sin área',
    ..._areas.map((area) => area['nombre']?.toString() ?? ''),
    'Otro (especificar)',
  ];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _onFieldChanged();
    }
  }

  Future<void> _refreshCenters() async {
    try {
      await SyncService().descargarDatosMaestros();
      final companyId = _companyId;
      if (companyId == null) {
        throw StateError('SESIÓN_SIN_EMPRESA');
      }
      final centers = await _repository.getCentros(companyId);
      if (mounted) setState(() => _centers = centers);
      if (centers.isEmpty && mounted) {
        _showMessage(
          'La sincronización no encontró centros para esta empresa.',
        );
      }
    } catch (e) {
      if (mounted) _showMessage('No se pudieron actualizar los centros: $e');
    }
  }

  Future<void> _showSignatureDialog() async {
    final controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
    );
    try {
      final signature = await showDialog<Uint8List>(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            height: 430,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Firma del relator',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Signature(
                      controller: controller,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: controller.clear,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Limpiar'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _formativeColor,
                        ),
                        onPressed: () async {
                          final bytes = await controller.toPngBytes();
                          if (bytes == null || bytes.isEmpty) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Firma en el recuadro antes de confirmar.',
                                ),
                              ),
                            );
                            return;
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, bytes);
                          }
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Confirmar firma'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (signature != null && mounted) {
        setState(() => _savedSignature = signature);
        _onFieldChanged();
      }
    } finally {
      controller.dispose();
    }
  }

  Widget _datePickerCard() {
    final date = DateFormat('dd/MM/yyyy').format(_date);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_formativeColor.withValues(alpha: 0.08), Colors.white],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _formativeColor.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _formativeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: _formativeColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fecha de la actividad',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      date,
                      style: const TextStyle(
                        color: _formativeColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_calendar, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timePickerCard({
    required String label,
    required TimeOfDay time,
    required bool isStart,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pickTime(start: isStart),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isStart
                        ? Icons.play_circle_outline
                        : Icons.stop_circle_outlined,
                    size: 16,
                    color: _formativeColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _formatTime(time),
                style: const TextStyle(
                  color: _formativeColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Tocar para cambiar',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
    _onFieldChanged();
  }

  void _selectCenter(String? label) {
    if (label == null || label == 'Sin centro') {
      setState(() => _centerSelection = _noCenterKey);
      _onFieldChanged();
      return;
    }
    final center = _centers.firstWhere(
      (item) => item['nombre']?.toString() == label,
      orElse: () => <String, dynamic>{},
    );
    if (center.isNotEmpty) {
      setState(() => _centerSelection = center['id'].toString());
      _onFieldChanged();
    }
  }

  void _selectArea(String? label) {
    if (label == null || label == 'Sin área') {
      setState(() => _areaSelection = _noAreaKey);
    } else if (label == 'Otro (especificar)') {
      setState(() => _areaSelection = _otherAreaKey);
    } else {
      final area = _areas.firstWhere(
        (item) => item['nombre']?.toString() == label,
        orElse: () => <String, dynamic>{},
      );
      if (area.isNotEmpty) {
        setState(() => _areaSelection = area['id'].toString());
      }
    }
    _onFieldChanged();
  }

  void _selectActivityType(String? label) {
    const types = {
      'Charla': 'CHARLA',
      'Servicio': 'SERVICIO',
      'Capacitación': 'CAPACITACION',
      'Otro': 'OTRO',
    };
    final type = types[label];
    if (type != null) {
      setState(() => _activityType = type);
      _onFieldChanged();
    }
  }

  FormativeActivity _buildActivity({required String status}) =>
      FormativeActivity(
        id: _id,
        usuarioId: _userId!,
        empresaId: _companyId!,
        centroId: _centerSelection == _noCenterKey ? null : _centerSelection,
        centroNombre: _centerName(),
        areaId: _areaSelection == _otherAreaKey || _areaSelection == _noAreaKey
            ? null
            : _areaSelection,
        areaNombre: _areaName(),
        areaOtro: _areaSelection == _otherAreaKey
            ? _otherAreaController.text.trim()
            : null,
        tipoActividad: _activityType,
        tipoOtro: _activityType == 'OTRO'
            ? _otherTypeController.text.trim()
            : null,
        descripcion: _descriptionController.text.trim(),
        fecha: _date,
        horaInicio: _formatTime(_start),
        horaTermino: _formatTime(_end),
        asistentes: _attendees,
        relatorNombre: _relatorController.text.trim(),
        estadoFinal: status,
      );

  Future<Uint8List?> _signatureBytes() async => _savedSignature;

  Future<void> _waitForPhotos() async {
    await _photoQueue.waitUntilIdle();
    if (_photoError != null) throw StateError(_photoError!);
  }

  void _changePhotos(List<File> photos) {
    if (_photoQueue.isProcessing) return;
    final operation = _persistPhotos(photos);
    unawaited(_photoQueue.track(operation));
    setState(() {});
  }

  Future<void> _persistPhotos(List<File> photos) async {
    try {
      _photoError = null;
      final paths = await _repository.savePhotos(
        _id,
        photos.map((file) => file.path).toList(),
      );
      _photos = paths.map(File.new).toList();
      if (mounted) _onFieldChanged();
    } catch (e) {
      _photoError = 'No se pudo guardar el registro fotográfico: $e';
      try {
        _photos = (await _repository.getPhotoPaths(_id)).map(File.new).toList();
      } catch (_) {
        // Keep the visible selection if local storage is temporarily unavailable.
      }
      _showMessage(_photoError!);
    } finally {
      if (mounted) setState(() {});
    }
  }

  Map<String, dynamic> _buildPdfData({required String numeroReporte}) {
    final activity = _buildActivity(status: 'En Progreso');
    final duration = _durationMinutes;
    final accountedDuration = duration == null
        ? null
        : FormativeActivity.accountedDurationMinutes(duration);
    return {
      'id': activity.id,
      'usuario_id': activity.usuarioId,
      'empresa_id': activity.empresaId,
      'empresa_nombre': _companyName,
      'centro_id': activity.centroId,
      'nombre_centro': activity.centroNombre,
      'area_nombre': activity.areaNombre,
      'area_otro': activity.areaOtro,
      'tipo_actividad': 'ACTIVIDAD_FORMATIVA',
      'actividad_formativa_tipo': activity.tipoActividad,
      'tipo_otro': activity.tipoOtro,
      'descripcion': activity.descripcion,
      'fecha_realizacion': activity.fecha.toIso8601String(),
      'hora_inicio': activity.horaInicio,
      'hora_termino': activity.horaTermino,
      'asistentes': activity.asistentes,
      'hh_sin_relator': accountedDuration == null
          ? null
          : FormativeActivity.hoursWithoutRelator(
              activity.asistentes,
              accountedDuration,
            ),
      'hh_con_relator': accountedDuration == null
          ? null
          : FormativeActivity.hoursWithRelator(
              activity.asistentes,
              accountedDuration,
            ),
      'relator_nombre': activity.relatorNombre,
      'numero_reporte': numeroReporte,
    };
  }

  Future<void> _previewPdf() async {
    if (_previewingPdf || _saving || _autoSaving) return;
    setState(() => _previewingPdf = true);
    final previewRevision = _changeRevision;
    var saveSucceeded = false;
    try {
      await _waitForPhotos();
      await _repository.save(
        _buildActivity(status: 'En Progreso'),
        finalized: false,
        signatureBytes: _savedSignature,
      );
      saveSucceeded = true;
      _dirty = _changeRevision != previewRevision;
      final bytes = await FormativeActivityPdfService().generate(
        data: _buildPdfData(
          numeroReporte: widget.activityId == null
              ? 'Vista previa'
              : 'Pendiente de correlativo',
        ),
        signatureBytes: _savedSignature,
        photoPaths: await _repository.getPhotoPaths(_id),
      );
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Vista previa actividad formativa',
      );
    } catch (e) {
      _showMessage('No se pudo previsualizar el PDF: $e');
    } finally {
      if (mounted) {
        setState(() => _previewingPdf = false);
        if (_dirty && saveSucceeded) {
          _autoSaveDebounce = Timer(
            const Duration(milliseconds: 900),
            _saveDraftSilently,
          );
        }
      }
    }
  }

  Future<void> _save({required bool finalize}) async {
    if (_saving || _previewingPdf) return;
    final navigator = Navigator.of(context);
    if (finalize && !_formKey.currentState!.validate()) return;
    final duration = _durationMinutes;
    if (finalize && (duration == null || duration <= 0)) {
      _showMessage('La hora de término debe ser posterior a la de inicio.');
      return;
    }
    final signature = await _signatureBytes();
    if (finalize && (signature == null || signature.isEmpty)) {
      _showMessage('Captura la firma del relator para finalizar.');
      return;
    }

    setState(() => _saving = true);
    _autoSaveDebounce?.cancel();
    try {
      while (_autoSaving) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await _waitForPhotos();
      if (!mounted) return;
      await _repository.save(
        _buildActivity(status: finalize ? 'En Seguimiento' : 'En Progreso'),
        finalized: finalize,
        signatureBytes: signature,
      );
      if (finalize) {
        final row = await _repository.getById(_id);
        if (row == null) {
          throw StateError('No se pudo recuperar la actividad finalizada.');
        }
        final pdfBytes = await FormativeActivityPdfService().generate(
          data: row,
          signatureBytes: signature,
          photoPaths: await _repository.getPhotoPaths(_id),
        );
        final directory = await getApplicationDocumentsDirectory();
        final pdfPath =
            '${directory.path}${Platform.pathSeparator}'
            'actividad_formativa_$_id.pdf';
        await File(pdfPath).writeAsBytes(pdfBytes, flush: true);
        await _repository.setPdfPath(_id, pdfPath);
        await SyncService().sincronizarTodo();
      }
      if (!mounted) return;
      if (finalize) {
        setState(() => _allowPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        navigator.pop(true);
      } else {
        _showMessage('Borrador guardado.');
      }
    } catch (e) {
      _showMessage('No se pudo guardar el registro: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveOnExit() async {
    await _waitForPhotos();
    await _repository.save(
      _buildActivity(status: 'En Progreso'),
      finalized: false,
      signatureBytes: await _signatureBytes(),
    );
    _dirty = false;
  }

  Future<void> _handleBack(NavigatorState navigator) async {
    if (_saving || _loading) return;
    if (_error != null) {
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) navigator.pop();
      return;
    }

    setState(() => _saving = true);
    _autoSaveDebounce?.cancel();
    try {
      while (_autoSaving && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (!mounted) return;
      await _saveOnExit();
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) navigator.pop();
    } catch (e) {
      _showMessage('No se pudo guardar el borrador al salir: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveDebounce?.cancel();
    _periodicAutoSave?.cancel();
    _attendeesController.dispose();
    _relatorController.dispose();
    _otherTypeController.dispose();
    _descriptionController.dispose();
    _otherAreaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving || _loading) return;
        unawaited(_handleBack(Navigator.of(context)));
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _formativeColor,
          foregroundColor: Colors.white,
          title: const Text('Registro de actividad'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : SafeArea(
                top: false,
                child: AbsorbPointer(
                  absorbing: _saving,
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        _section(null, [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Empresa'),
                            subtitle: Text(_companyName),
                            leading: const Icon(Icons.business),
                          ),
                          CustomDropdown(
                            items: _areaOptions,
                            value: _areaLabel,
                            label: 'Área',
                            icon: Icons.apartment_outlined,
                            onChanged: _selectArea,
                          ),
                          CustomDropdown(
                            items: _centerOptions,
                            value: _centerLabel,
                            label: 'Centro',
                            icon: Icons.location_city_outlined,
                            onChanged: _selectCenter,
                          ),
                          if (_centers.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'No hay centros cargados para esta empresa.',
                                      style: TextStyle(
                                        color: Colors.orange.shade900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _refreshCenters,
                                    icon: const Icon(Icons.sync, size: 16),
                                    label: const Text('Actualizar'),
                                  ),
                                ],
                              ),
                            ),
                          if (_areaSelection == _otherAreaKey) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _otherAreaController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre del área',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ]),
                        _section('Actividad', [
                          CustomDropdown(
                            items: const [
                              'Charla',
                              'Servicio',
                              'Capacitación',
                              'Otro',
                            ],
                            value: _activityTypeLabel,
                            label: 'Tipo de actividad',
                            icon: Icons.category_outlined,
                            enableSearch: false,
                            onChanged: _selectActivityType,
                          ),
                          if (_activityType == 'OTRO') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _otherTypeController,
                              decoration: const InputDecoration(
                                labelText: 'Tipo de actividad',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  _activityType == 'OTRO' &&
                                      (value == null || value.trim().isEmpty)
                                  ? 'Indica el tipo de actividad'
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Descripción (opcional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _datePickerCard(),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _timePickerCard(
                                  label: 'Inicio',
                                  time: _start,
                                  isStart: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _timePickerCard(
                                  label: 'Término',
                                  time: _end,
                                  isStart: false,
                                ),
                              ),
                            ],
                          ),
                          if (_durationMinutes == null)
                            const Text(
                              'La hora de término debe ser posterior al inicio. '
                              'La v1 no admite actividades que crucen medianoche.',
                              style: TextStyle(color: Colors.red),
                            ),
                        ]),
                        _section('Participación y horas-hombre', [
                          TextFormField(
                            controller: _attendeesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cantidad de asistentes',
                              helperText: 'No incluyas al relator.',
                              prefixIcon: Icon(Icons.people_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final count = int.tryParse(value?.trim() ?? '');
                              return count == null || count < 0
                                  ? 'Ingresa una cantidad válida (0 o más)'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Duración real',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_durationMinutes ?? '—'} min',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Duración contabilizada',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_accountedDuration ?? '—'} min',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _hoursPanel(),
                        ]),
                        _section('Registro fotográfico', [
                          AbsorbPointer(
                            absorbing:
                                _photoQueue.isProcessing || _previewingPdf,
                            child: GalleryInput(
                              images: _photos,
                              onImagesChanged: _changePhotos,
                            ),
                          ),
                          if (_photoQueue.isProcessing)
                            const LinearProgressIndicator(),
                          if (_photoError != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _photoError!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                                TextButton(
                                  onPressed: () => _changePhotos(_photos),
                                  child: const Text(
                                    'Reintentar guardado de fotos',
                                  ),
                                ),
                              ],
                            ),
                        ]),
                        _section('Relator', [
                          TextFormField(
                            controller: _relatorController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del relator',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Indica el nombre del relator'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showSignatureDialog,
                              borderRadius: BorderRadius.circular(14),
                              child: Ink(
                                height: 170,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: _savedSignature == null
                                        ? Colors.grey.shade300
                                        : _formativeColor.withValues(
                                            alpha: 0.35,
                                          ),
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.035,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: _savedSignature == null
                                    ? Stack(
                                        children: [
                                          Positioned(
                                            left: 10,
                                            right: 10,
                                            bottom: 24,
                                            child: Divider(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          Positioned(
                                            left: 10,
                                            bottom: 5,
                                            child: Text(
                                              'Firma del relator',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            right: 8,
                                            top: 4,
                                            child: Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            child: Image.memory(
                                              _savedSignature!,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Quitar firma',
                                            onPressed: () {
                                              setState(
                                                () => _savedSignature = null,
                                              );
                                              _onFieldChanged();
                                            },
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ]),
                        if (_autoSaveError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              _autoSaveError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          )
                        else if (_autoSaving)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Guardando borrador automáticamente…',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: _saving || _previewingPdf
                              ? null
                              : _previewPdf,
                          icon: _previewingPdf
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Previsualizar PDF'),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _saving || _previewingPdf
                              ? null
                              : () => _save(finalize: true),
                          style: FilledButton.styleFrom(
                            backgroundColor: _formativeColor,
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: const Text('Finalizar registro'),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _hoursPanel() {
    final duration = _accountedDuration;
    if (duration == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Completa un horario válido para calcular HH.'),
        ),
      );
    }
    final withRelator = FormativeActivity.hoursWithRelator(
      _attendees,
      duration,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total HH',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: _formativeColor),
          ),
          const SizedBox(height: 4),
          Text(
            withRelator.toStringAsFixed(2),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: _formativeColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Incluye al relator.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _section(String? title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    ),
  );
}
