import 'package:flutter/material.dart';
import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/core/theme/app_theme.dart';
import 'package:jf_innova_app/shared/widgets/custom_dropdown.dart';

/// Definición de un tipo de filtro disponible.
class _FilterDef {
  final String key;
  final String label;
  final IconData icon;
  const _FilterDef(this.key, this.label, this.icon);
}

/// Widget para mostrarse como [showModalBottomSheet].
/// Gestiona su estado local de filtros antes de emitirlos con [onApply].
/// Los filtros se añaden uno a uno desde una lista dinámica cargada desde la BD.
class CustomFilterSheet extends StatefulWidget {
  final Map<String, String> currentFilters;
  final Function(Map<String, String>) onApply;

  const CustomFilterSheet({
    super.key,
    required this.currentFilters,
    required this.onApply,
  });

  @override
  State<CustomFilterSheet> createState() => _CustomFilterSheetState();
}

class _CustomFilterSheetState extends State<CustomFilterSheet> {
  late Map<String, String> _localFilters;

  // Datos cargados desde SQLite
  List<Map<String, dynamic>> _empresas = [];
  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _usuarios = [];
  bool _isLoadingData = true;

  // Estado del panel "Agregar filtro"
  bool _showAddPanel = false;
  String? _pendingType;
  String? _pendingId; // Valor real a guardar
  String? _pendingDisplayName; // Texto visible en el dropdown

  static const _criticidades = ['Bajo', 'Medio', 'Alto', 'Intolerable'];
  static const _estados = ['Abierto', 'En Proceso', 'Cerrado'];

  static const _filterDefs = <_FilterDef>[
    _FilterDef('empresa_id', 'Empresa', Icons.business_rounded),
    _FilterDef('area_id', 'Área', Icons.map_outlined),
    _FilterDef('solicitante_id', 'Solicitante', Icons.person_rounded),
    _FilterDef('criticidad', 'Criticidad', Icons.warning_amber_rounded),
    _FilterDef('estado', 'Estado', Icons.flag_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _localFilters = Map<String, String>.from(widget.currentFilters);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = DatabaseHelper.instance;
      final results = await Future.wait([
        db.getAllEmpresas(),
        db.getAreas(),
        db.getAllUsuarios(),
      ]);
      if (mounted) {
        setState(() {
          _empresas = results[0];
          _areas = results[1];
          _usuarios = results[2];
          _isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  // Devuelve los items de texto para mostrar en el CustomDropdown del tipo dado.
  List<String> _itemsForType(String type) {
    switch (type) {
      case 'empresa_id':
        return _empresas.map((e) => e['nombre'] as String).toList();
      case 'area_id':
        return _areas.map((e) => e['nombre'] as String).toList();
      case 'solicitante_id':
        return _usuarios.map((e) => e['nombre_completo'] as String).toList();
      case 'criticidad':
        return _criticidades;
      case 'estado':
        return _estados;
      default:
        return [];
    }
  }

  // Resuelve el ID real a partir del texto visible seleccionado en el dropdown.
  String _resolveId(String type, String displayName) {
    switch (type) {
      case 'empresa_id':
        return _empresas.firstWhere(
              (e) => e['nombre'] == displayName,
              orElse: () => {'id': displayName},
            )['id']
            as String;
      case 'area_id':
        return _areas.firstWhere(
              (e) => e['nombre'] == displayName,
              orElse: () => {'id': displayName},
            )['id']
            as String;
      case 'solicitante_id':
        return _usuarios.firstWhere(
              (e) => e['nombre_completo'] == displayName,
              orElse: () => {'id': displayName},
            )['id']
            as String;
      default:
        // criticidad y estado se guardan tal cual (no son IDs)
        return displayName;
    }
  }

  // Resuelve el texto visible a partir del valor guardado en _localFilters.
  String _resolveDisplayName(String key, String value) {
    switch (key) {
      case 'empresa_id':
        return _empresas.firstWhere(
              (e) => e['id'] == value,
              orElse: () => {'nombre': value},
            )['nombre']
            as String;
      case 'area_id':
        return _areas.firstWhere(
              (e) => e['id'] == value,
              orElse: () => {'nombre': value},
            )['nombre']
            as String;
      case 'solicitante_id':
        return _usuarios.firstWhere(
              (e) => e['id'] == value,
              orElse: () => {'nombre_completo': value},
            )['nombre_completo']
            as String;
      default:
        return value;
    }
  }

  void _confirmAdd() {
    if (_pendingType == null || _pendingId == null) return;
    setState(() {
      _localFilters[_pendingType!] = _pendingId!;
      _pendingType = null;
      _pendingId = null;
      _pendingDisplayName = null;
      _showAddPanel = false;
    });
  }

  void _cancelAdd() {
    setState(() {
      _pendingType = null;
      _pendingId = null;
      _pendingDisplayName = null;
      _showAddPanel = false;
    });
  }

  void _clearAll() {
    setState(() {
      _localFilters.clear();
      _cancelAdd();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const Divider(height: 28),
          if (_isLoadingData)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            _buildActiveFilters(),
            const SizedBox(height: 8),
            if (_showAddPanel) _buildAddPanel() else _buildAddButton(),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              widget.onApply(_localFilters);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Aplicar Filtros'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Filtros',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        if (_localFilters.isNotEmpty)
          TextButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.clear_all_rounded, size: 18),
            label: const Text('Limpiar todo'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
          ),
      ],
    );
  }

  Widget _buildActiveFilters() {
    if (_localFilters.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(
              Icons.filter_list_off_rounded,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'Sin filtros aplicados',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _localFilters.entries.map((entry) {
        final def = _filterDefs.firstWhere(
          (d) => d.key == entry.key,
          orElse: () =>
              _FilterDef(entry.key, entry.key, Icons.filter_alt_rounded),
        );
        final displayName = _resolveDisplayName(entry.key, entry.value);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(def.icon, size: 18, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                '${def.label}: ',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.primaryBlue,
                ),
              ),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _localFilters.remove(entry.key)),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAddButton() {
    // Ocultamos el botón si ya se agregaron todos los tipos disponibles
    final tiposDisponibles = _filterDefs
        .where((d) => !_localFilters.containsKey(d.key))
        .toList();
    if (tiposDisponibles.isEmpty) return const SizedBox.shrink();

    return OutlinedButton.icon(
      onPressed: () => setState(() => _showAddPanel = true),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Agregar filtro'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryBlue,
        side: const BorderSide(color: AppTheme.primaryBlue),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildAddPanel() {
    final tiposDisponibles = _filterDefs
        .where((d) => !_localFilters.containsKey(d.key))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipo de filtro',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tiposDisponibles.map((def) {
              final isSelected = _pendingType == def.key;
              return FilterChip(
                avatar: Icon(
                  def.icon,
                  size: 16,
                  color: isSelected ? Colors.white : AppTheme.primaryBlue,
                ),
                label: Text(def.label),
                selected: isSelected,
                onSelected: (_) => setState(() {
                  _pendingType = def.key;
                  _pendingId = null;
                  _pendingDisplayName = null;
                }),
                selectedColor: AppTheme.primaryBlue,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.primaryBlue,
                  fontSize: 13,
                ),
                backgroundColor: AppTheme.primaryBlue.withOpacity(0.06),
                side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.3)),
                showCheckmark: false,
              );
            }).toList(),
          ),
          if (_pendingType != null) ...[
            const SizedBox(height: 4),
            CustomDropdown(
              label: _filterDefs.firstWhere((d) => d.key == _pendingType).label,
              enableSearch:
                  _pendingType != 'criticidad' && _pendingType != 'estado',
              items: _itemsForType(_pendingType!),
              value: _pendingDisplayName,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _pendingDisplayName = val;
                    _pendingId = _resolveId(_pendingType!, val);
                  });
                }
              },
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelAdd,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _pendingId != null ? _confirmAdd : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Confirmar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
