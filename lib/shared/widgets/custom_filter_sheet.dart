import 'package:flutter/material.dart';
import 'package:jf_innova_app/core/theme/app_theme.dart';
import 'package:jf_innova_app/shared/widgets/custom_dropdown.dart';

/// Definición pública de un tipo de filtro.
class FilterDef {
  final String key;
  final String label;
  final IconData icon;

  /// Items de texto a mostrar en el dropdown.
  final List<String> items;

  /// Si true, el dropdown tiene búsqueda.
  final bool enableSearch;

  /// Resuelve el texto visible → valor a guardar (por defecto identity).
  final String Function(String displayName) resolveId;

  /// Resuelve el valor guardado → texto visible (por defecto identity).
  final String Function(String id) resolveDisplayName;

  const FilterDef({
    required this.key,
    required this.label,
    required this.icon,
    required this.items,
    this.enableSearch = false,
    String Function(String)? resolveId,
    String Function(String)? resolveDisplayName,
  }) : resolveId = resolveId ?? _identity,
       resolveDisplayName = resolveDisplayName ?? _identity;

  static String _identity(String s) => s;
}

/// Widget genérico de filtros para [showModalBottomSheet].
/// Acepta [filterDefs] con las definiciones de filtros disponibles.
class CustomFilterSheet extends StatefulWidget {
  final Map<String, String> currentFilters;
  final Function(Map<String, String>) onApply;
  final List<FilterDef> filterDefs;

  const CustomFilterSheet({
    super.key,
    required this.currentFilters,
    required this.onApply,
    required this.filterDefs,
  });

  @override
  State<CustomFilterSheet> createState() => _CustomFilterSheetState();
}

class _CustomFilterSheetState extends State<CustomFilterSheet> {
  late Map<String, String> _localFilters;

  // Estado del panel "Agregar filtro"
  bool _showAddPanel = false;
  String? _pendingType;
  String? _pendingId;
  String? _pendingDisplayName;

  @override
  void initState() {
    super.initState();
    _localFilters = Map<String, String>.from(widget.currentFilters);
  }

  FilterDef? _findDef(String key) {
    try {
      return widget.filterDefs.firstWhere((d) => d.key == key);
    } catch (_) {
      return null;
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
          _buildActiveFilters(),
          const SizedBox(height: 8),
          if (_showAddPanel) _buildAddPanel() else _buildAddButton(),
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
        final def = _findDef(entry.key);
        final displayName = def?.resolveDisplayName(entry.value) ?? entry.value;
        final label = def?.label ?? entry.key;
        final icon = def?.icon ?? Icons.filter_alt_rounded;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                '$label: ',
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
    final tiposDisponibles = widget.filterDefs
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
    final tiposDisponibles = widget.filterDefs
        .where((d) => !_localFilters.containsKey(d.key))
        .toList();

    final pendingDef = _pendingType != null ? _findDef(_pendingType!) : null;

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
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.06),
                side: BorderSide(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
          if (pendingDef != null) ...[
            const SizedBox(height: 4),
            CustomDropdown(
              label: pendingDef.label,
              enableSearch: pendingDef.enableSearch,
              items: pendingDef.items,
              value: _pendingDisplayName,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _pendingDisplayName = val;
                    _pendingId = pendingDef.resolveId(val);
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
