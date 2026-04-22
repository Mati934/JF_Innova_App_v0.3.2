import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/core/theme/app_theme.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_model.dart';
import 'package:jf_innova_app/features/tickets/presentation/controllers/ticket_controller.dart';
import 'package:jf_innova_app/features/tickets/presentation/widgets/ticket_category_selector.dart';
import 'package:jf_innova_app/shared/widgets/custom_dropdown.dart';

/// Pantalla de creación y edición de tickets.
///
/// - [ticket] null → modo creación vacío.
/// - [ticket] con codigoTicket → edición de ticket existente.
/// - [ticket] sin codigoTicket pero con actividadId → nuevo ticket desde historial.
class TicketFormScreen extends StatefulWidget {
  final TicketController controller;
  final TicketModel? ticket;

  const TicketFormScreen({super.key, required this.controller, this.ticket});

  @override
  State<TicketFormScreen> createState() => _TicketFormScreenState();
}

class _TicketFormScreenState extends State<TicketFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();

  // ---------- Dropdowns estáticos ----------
  String _criticidad = 'Medio';
  DateTime? _fechaTentativa;
  String? _categoriaId;
  String? _categoriaOtro;

  static const _criticidades = ['Bajo', 'Medio', 'Alto', 'Intolerable'];

  // ---------- Selecciones de contexto ----------
  String? _empresaDisplay;
  String? _areaDisplay;
  String? _centroDisplay;
  String? _embarcacionDisplay;
  String? _responsableDisplay;
  String? _actividadDisplay; // numero_reporte de la actividad seleccionada

  // ---------- Datos maestros ----------
  List<Map<String, dynamic>> _empresas = [];
  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _centros =
      []; // centros del área seleccionada (dropdown)
  List<Map<String, dynamic>> _todosCentros =
      []; // todos los centros (lookup inverso)
  List<Map<String, dynamic>> _embarcaciones = [];
  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _actividades = [];
  bool _isLoadingMaestros = true;

  /// Solo un ticket con codigoTicket es un ticket ya existente que se edita.
  bool get _isEditing => widget.ticket?.codigoTicket != null;

  @override
  void initState() {
    super.initState();
    _initFromTicket();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadCategorias();
    });
    _loadMaestros();
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Carga de datos maestros
  // ---------------------------------------------------------------------------

  Future<void> _loadMaestros() async {
    try {
      final db = DatabaseHelper.instance;
      final results = await Future.wait([
        db.getAllEmpresas(),
        db.getAreas(),
        db.getAllEmbarcaciones(),
        db.getAllUsuarios(),
        db.getAllCentros(),
      ]);
      final informes = await _loadInformes();
      if (!mounted) return;
      setState(() {
        _empresas = results[0];
        _areas = results[1];
        _embarcaciones = results[2];
        _usuarios = results[3];
        _todosCentros = results[4];
        _actividades = informes;
        _isLoadingMaestros = false;
      });
      await _resolveDisplaysFromTicket();
    } catch (_) {
      if (mounted) setState(() => _isLoadingMaestros = false);
    }
  }

  /// Obtiene la lista de informes (N° de Informe) para el dropdown.
  /// Prioriza Supabase (historial_unificado); si no hay conexión usa SQLite local.
  Future<List<Map<String, dynamic>>> _loadInformes() async {
    try {
      final response = await Supabase.instance.client
          .from('actividades')
          .select('id, numero_informe, centro_id, embarcacion_id')
          .not('numero_informe', 'is', null)
          .order('numero_informe', ascending: false);
      return List<Map<String, dynamic>>.from(response)
          .where((e) => e['numero_informe']?.toString().isNotEmpty == true)
          .map((e) => {
                ...e,
                'numero_reporte': e['numero_informe'].toString(),
              })
          .toList();
    } catch (_) {
      return DatabaseHelper.instance.getAllActividades();
    }
  }

  Future<void> _loadCentros(String areaId) async {
    final centros = await DatabaseHelper.instance.getCentros(areaId);
    if (mounted) setState(() => _centros = centros);
  }

  /// Inicializa los campos de texto con el ticket existente; los de contexto
  /// se resuelven en [_resolveDisplaysFromTicket] una vez cargados los maestros.
  void _initFromTicket() {
    final t = widget.ticket;
    if (t == null) return;
    _descripcionController.text = t.descripcion;
    _criticidad = t.criticidad;
    _fechaTentativa = t.fechaTentativaCierre;
    _categoriaId = t.categoriaId == '1'
        ? null
        : t.categoriaId; // '1' era placeholder
    _categoriaOtro = t.categoriaOtro;
  }

  /// Resuelve los nombres de pantalla para empresa/área/centro/embarcación
  /// a partir de los IDs guardados en el ticket. Se llama después de cargar maestros.
  Future<void> _resolveDisplaysFromTicket() async {
    final t = widget.ticket;
    if (t == null) return;

    String? empresaDisplay;
    String? areaDisplay;
    String? embarcacionDisplay;
    String? responsableDisplay;

    if (t.empresaId.isNotEmpty) {
      final e = _empresas.firstWhere(
        (x) => x['id'] == t.empresaId,
        orElse: () => {},
      );
      if (e.isNotEmpty) empresaDisplay = e['nombre'] as String?;
    }
    if (t.areaId != null) {
      final a = _areas.firstWhere((x) => x['id'] == t.areaId, orElse: () => {});
      if (a.isNotEmpty) areaDisplay = a['nombre'] as String?;
    }
    if (t.embarcacionId != null) {
      final emb = _embarcaciones.firstWhere(
        (x) => x['id'] == t.embarcacionId,
        orElse: () => {},
      );
      if (emb.isNotEmpty) embarcacionDisplay = emb['nombre'] as String?;
    }
    if (t.responsableId != null) {
      final u = _usuarios.firstWhere(
        (x) => x['id'] == t.responsableId,
        orElse: () => {},
      );
      if (u.isNotEmpty) responsableDisplay = u['nombre_completo'] as String?;
    }

    if (mounted) {
      setState(() {
        _empresaDisplay = empresaDisplay;
        _areaDisplay = areaDisplay;
        _embarcacionDisplay = embarcacionDisplay;
        _responsableDisplay = responsableDisplay;
        if (t.actividadId != null) {
          final act = _actividades.firstWhere(
            (x) => x['id'] == t.actividadId,
            orElse: () => {},
          );
          if (act.isNotEmpty) {
            _actividadDisplay = act['numero_reporte'] as String?;
          }
        }
      });
    }

    // Cargar centros del área y resolver el nombre del centro.
    if (t.areaId != null) {
      await _loadCentros(t.areaId!);
      if (t.centroId != null && mounted) {
        final c = _centros.firstWhere(
          (x) => x['id'] == t.centroId,
          orElse: () => {},
        );
        if (c.isNotEmpty && mounted) {
          setState(() => _centroDisplay = c['nombre'] as String?);
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String? _findId(
    List<Map<String, dynamic>> list,
    String? displayName, {
    String nameKey = 'nombre',
  }) {
    if (displayName == null || list.isEmpty) return null;
    for (final item in list) {
      if (item[nameKey] == displayName) return item['id'] as String?;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  Future<void> _onAreaChanged(String? val) async {
    setState(() {
      _areaDisplay = val;
      _centroDisplay = null;
      _centros = [];
    });
    if (val == null) return;
    final areaId = _findId(_areas, val);
    if (areaId != null) await _loadCentros(areaId);
  }

  /// Al seleccionar un N° de Informe, auto-rellena Área, Centro y Embarcación
  /// con los datos del informe (centro_id → area_id, embarcacion_id).
  Future<void> _onInformeChanged(String? val) async {
    setState(() => _actividadDisplay = val);
    if (val == null) return;

    final informe = _actividades.firstWhere(
      (a) => a['numero_reporte'] == val,
      orElse: () => {},
    );
    if (informe.isEmpty) return;

    final centroId = informe['centro_id'] as String?;
    final embarcacionId = informe['embarcacion_id'] as String?;

    // Derive areaId from centro using the full centros lookup
    String? areaId;
    String? areaDisplay;
    if (centroId != null) {
      final centroObj = _todosCentros.firstWhere(
        (c) => c['id'] == centroId,
        orElse: () => {},
      );
      if (centroObj.isNotEmpty) {
        areaId = centroObj['area_id'] as String?;
      }
    }
    if (areaId != null) {
      final areaObj = _areas.firstWhere(
        (a) => a['id'] == areaId,
        orElse: () => {},
      );
      if (areaObj.isNotEmpty) areaDisplay = areaObj['nombre'] as String?;
    }

    // Find embarcacion display name
    String? embarcacionDisplay;
    if (embarcacionId != null) {
      final embObj = _embarcaciones.firstWhere(
        (e) => e['id'] == embarcacionId,
        orElse: () => {},
      );
      if (embObj.isNotEmpty) embarcacionDisplay = embObj['nombre'] as String?;
    }

    // Apply derived values, reset centro (set after async load below)
    if (mounted) {
      setState(() {
        if (areaDisplay != null) _areaDisplay = areaDisplay;
        if (embarcacionDisplay != null) {
          _embarcacionDisplay = embarcacionDisplay;
        }
        _centroDisplay = null;
        _centros = [];
      });
    }

    // Load filtered centros for the derived area, then set centro display
    if (areaId != null) {
      await _loadCentros(areaId);
      if (centroId != null && mounted) {
        final c = _centros.firstWhere(
          (x) => x['id'] == centroId,
          orElse: () => {},
        );
        if (c.isNotEmpty && mounted) {
          setState(() => _centroDisplay = c['nombre'] as String?);
        }
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_categoriaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor seleccione una actividad.')),
      );
      return;
    }

    final solicitanteId =
        Supabase.instance.client.auth.currentUser?.id ??
        widget.ticket?.solicitanteId ??
        'user-local';

    final empresaId = _findId(_empresas, _empresaDisplay) ?? '';
    final areaId = _findId(_areas, _areaDisplay);
    final centroId = _findId(_centros, _centroDisplay);
    final embarcacionId = _findId(_embarcaciones, _embarcacionDisplay);
    final responsableId = _findId(
      _usuarios,
      _responsableDisplay,
      nameKey: 'nombre_completo',
    );
    final actividadId =
        _findId(_actividades, _actividadDisplay, nameKey: 'numero_reporte') ??
        widget.ticket?.actividadId;

    final ticket = TicketModel(
      id: widget.ticket?.id ?? const Uuid().v4(),
      codigoTicket: widget.ticket?.codigoTicket,
      empresaId: empresaId,
      areaId: areaId,
      centroId: centroId,
      embarcacionId: embarcacionId,
      actividadId: actividadId,
      categoriaId: _categoriaId!,
      categoriaOtro: _categoriaOtro,
      descripcion: _descripcionController.text.trim(),
      criticidad: _criticidad,
      fechaTentativaCierre: _fechaTentativa,
      estado: widget.ticket?.estado ?? 'Abierto',
      solicitanteId: solicitanteId,
      responsableId: responsableId,
      createdAt: widget.ticket?.createdAt ?? DateTime.now(),
    );

    final success = await widget.controller.saveTicket(ticket);
    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al guardar el ticket. Intenta nuevamente.'),
          backgroundColor: AppTheme.logoRed,
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaTentativa ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day + 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _fechaTentativa = picked);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Ticket' : 'Nuevo Ticket'),
      ),
      body: _isLoadingMaestros
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Contexto ─────────────────────────────────────────
                    CustomDropdown(
                      label: 'Empresa',
                      enableSearch: true,
                      items: _empresas
                          .map((e) => e['nombre'] as String)
                          .toList(),
                      value: _empresaDisplay,
                      onChanged: (val) => setState(() => _empresaDisplay = val),
                    ),
                    CustomDropdown(
                      label: 'Área',
                      enableSearch: true,
                      items: _areas.map((e) => e['nombre'] as String).toList(),
                      value: _areaDisplay,
                      onChanged: _onAreaChanged,
                    ),
                    if (_areaDisplay != null)
                      CustomDropdown(
                        label: 'Centro',
                        enableSearch: true,
                        items: _centros
                            .map((e) => e['nombre'] as String)
                            .toList(),
                        value: _centroDisplay,
                        onChanged: (val) =>
                            setState(() => _centroDisplay = val),
                      ),
                    CustomDropdown(
                      label: 'N° de Informe',
                      enableSearch: true,
                      items: _actividades
                          .map((e) => e['numero_reporte'] as String)
                          .toList(),
                      value: _actividadDisplay,
                      onChanged: _onInformeChanged,
                    ),
                    CustomDropdown(
                      label: 'Embarcación',
                      enableSearch: true,
                      items: _embarcaciones
                          .map((e) => e['nombre'] as String)
                          .toList(),
                      value: _embarcacionDisplay,
                      onChanged: (val) =>
                          setState(() => _embarcacionDisplay = val),
                    ),
                    CustomDropdown(
                      label: 'Responsable',
                      enableSearch: true,
                      items: _usuarios
                          .map((e) => e['nombre_completo'] as String)
                          .toList(),
                      value: _responsableDisplay,
                      onChanged: (val) =>
                          setState(() => _responsableDisplay = val),
                    ),

                    // ── Actividad (Categoría) ────────────────────────────
                    _buildActividadSection(),
                    const SizedBox(height: 4),

                    // ── Detalle ──────────────────────────────────────────
                    _buildDescripcionField(),
                    const SizedBox(height: 16),
                    _buildCriticidadDropdown(),
                    _buildDateField(),
                    const SizedBox(height: 32),
                    _buildSaveButton(),
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 24,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Secciones del formulario
  // ---------------------------------------------------------------------------

  Widget _buildActividadSection() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final categorias = widget.controller.categorias;

        if (!widget.controller.isCategoriasLoaded) {
          return const SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (_isEditing) {
          final nombre = categorias
              .where((c) => c.id == _categoriaId)
              .map((c) => c.nombre)
              .firstOrNull;

          return InputDecorator(
            decoration: InputDecoration(
              labelText: 'Actividad',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: const Tooltip(
                message: 'La actividad no puede modificarse en la edición.',
                child: Icon(Icons.lock_outline_rounded, size: 18),
              ),
            ),
            child: Text(nombre ?? _categoriaId ?? '—'),
          );
        }

        return TicketCategorySelector(
          categorias: categorias,
          onChanged: (id, otro) {
            _categoriaId = id;
            _categoriaOtro = otro;
          },
        );
      },
    );
  }

  Widget _buildDescripcionField() {
    return TextFormField(
      controller: _descripcionController,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Descripción',
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'La descripción es obligatoria.';
        }
        if (value.trim().length < 10) {
          return 'Debe tener al menos 10 caracteres.';
        }
        return null;
      },
    );
  }

  Widget _buildCriticidadDropdown() {
    return CustomDropdown(
      label: 'Criticidad',
      enableSearch: false,
      items: _criticidades,
      value: _criticidad,
      onChanged: (val) {
        if (val != null) setState(() => _criticidad = val);
      },
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Fecha Tentativa de Cierre',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          suffixIcon: _fechaTentativa != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Quitar fecha',
                  onPressed: () => setState(() => _fechaTentativa = null),
                )
              : const Icon(Icons.calendar_today_rounded),
        ),
        child: Text(
          _fechaTentativa != null
              ? _formatDate(_fechaTentativa!)
              : 'Seleccionar',
          style: TextStyle(
            color: _fechaTentativa != null ? null : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isSaving = widget.controller.isSaving;
        return ElevatedButton(
          onPressed: isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _isEditing ? 'Actualizar Ticket' : 'Guardar Ticket',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
