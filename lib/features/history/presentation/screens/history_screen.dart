import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_filter_sheet.dart';
import '../../controllers/history_controller.dart';
import '../widgets/history_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final HistoryController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = HistoryController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Historial General"),
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            actions: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.filter_list_rounded),
                    tooltip: 'Filtros',
                    onPressed: () => _openFilterSheet(),
                  ),
                  if (_ctrl.activeFilterCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_ctrl.activeFilterCount}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Chips de filtros activos
              if (_ctrl.activeFilters.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _ctrl.activeFilters.entries.map((entry) {
                      final defs = _buildFilterDefs();
                      FilterDef? def;
                      try {
                        def = defs.firstWhere((d) => d.key == entry.key);
                      } catch (_) {}
                      final displayName =
                          def?.resolveDisplayName(entry.value) ?? entry.value;
                      final label = def?.label ?? entry.key;

                      return Chip(
                        avatar: Icon(
                          def?.icon ?? Icons.filter_alt,
                          size: 16,
                          color: AppTheme.primaryBlue,
                        ),
                        label: Text(
                          '$label: $displayName',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          final newFilters = Map<String, String>.from(
                            _ctrl.activeFilters,
                          );
                          newFilters.remove(entry.key);
                          _ctrl.applyFilters(newFilters);
                        },
                        backgroundColor: AppTheme.primaryBlue.withValues(
                          alpha: 0.08,
                        ),
                        side: BorderSide(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ),

              // Lista de resultados
              Expanded(
                child: _ctrl.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _ctrl.records.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_toggle_off,
                              size: 60,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "No hay registros",
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 20),
                        itemCount: _ctrl.records.length,
                        itemBuilder: (ctx, i) =>
                            HistoryCard(item: _ctrl.records[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CustomFilterSheet(
        currentFilters: _ctrl.activeFilters,
        filterDefs: _buildFilterDefs(),
        onApply: (filters) => _ctrl.applyFilters(filters),
      ),
    );
  }

  List<FilterDef> _buildFilterDefs() {
    final defs = <FilterDef>[
      FilterDef(
        key: 'modulo',
        label: 'Tipo',
        icon: Icons.category_rounded,
        items: const ['Inspección', 'Visita Técnica'],
      ),
    ];

    if (_ctrl.esAdmin) {
      // Centro filter
      final centroMap = {
        for (final c in _ctrl.listaCentros)
          c['id'].toString(): (c['nombre'] as String?) ?? '',
      };
      defs.add(
        FilterDef(
          key: 'centro_id',
          label: 'Centro',
          icon: Icons.location_city_rounded,
          items: centroMap.values.toList(),
          enableSearch: centroMap.length > 5,
          resolveId: (name) => centroMap.entries
              .firstWhere(
                (e) => e.value == name,
                orElse: () => MapEntry(name, name),
              )
              .key,
          resolveDisplayName: (id) => centroMap[id] ?? id,
        ),
      );

      // Usuario filter
      final usuarioMap = {
        for (final u in _ctrl.listaUsuarios)
          u['id'].toString(): (u['nombre_completo'] as String?) ?? '',
      };
      defs.add(
        FilterDef(
          key: 'usuario_id',
          label: 'Usuario',
          icon: Icons.person_rounded,
          items: usuarioMap.values.toList(),
          enableSearch: true,
          resolveId: (name) => usuarioMap.entries
              .firstWhere(
                (e) => e.value == name,
                orElse: () => MapEntry(name, name),
              )
              .key,
          resolveDisplayName: (id) => usuarioMap[id] ?? id,
        ),
      );
    }

    return defs;
  }
}
