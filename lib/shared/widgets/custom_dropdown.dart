import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CustomDropdown extends StatelessWidget {
  final List<String> items;
  final String? value;
  final String label;
  final Function(String?) onChanged;
  final Function(String)? onAddNew;
  final bool enableSearch;
  final IconData? icon;
  final String? hintText;

  const CustomDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.label,
    required this.onChanged,
    this.onAddNew,
    this.enableSearch = true,
    this.icon,
    this.hintText,
  });

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DropdownPickerSheet(
        title: label,
        items: items,
        initialValue: value,
        enableSearch: enableSearch,
        onAddNew: onAddNew,
      ),
    );

    if (selected != null) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    final hint =
        hintText ?? (enableSearch ? 'Selecciona o busca…' : 'Selecciona…');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: AppTheme.primaryBlue),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                    letterSpacing: 0.2,
                  ),
                ),
                if (hasValue) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.green.shade500,
                  ),
                ],
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openPicker(context),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasValue
                        ? AppTheme.primaryBlue.withValues(alpha: 0.35)
                        : Colors.grey.shade300,
                    width: hasValue ? 1.5 : 1,
                  ),
                  boxShadow: hasValue
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasValue ? value! : hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: hasValue
                            ? const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              )
                            : TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.primaryBlue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownPickerSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? initialValue;
  final bool enableSearch;
  final Function(String)? onAddNew;

  const _DropdownPickerSheet({
    required this.title,
    required this.items,
    required this.initialValue,
    required this.enableSearch,
    this.onAddNew,
  });

  @override
  State<_DropdownPickerSheet> createState() => _DropdownPickerSheetState();
}

class _DropdownPickerSheetState extends State<_DropdownPickerSheet> {
  late final TextEditingController _searchCtrl;
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _filtered = List<String>.from(widget.items);
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilter);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List<String>.from(widget.items)
          : widget.items.where((e) => e.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
            if (widget.enableSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Escribe para filtrar…',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryBlue,
                        width: 2,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: widget.onAddNew == null
                          ? const Text(
                              'Sin resultados',
                              style: TextStyle(color: Colors.grey),
                            )
                          : TextButton.icon(
                              onPressed: () {
                                final text = _searchCtrl.text.trim();
                                if (text.isEmpty) return;
                                widget.onAddNew!(text);
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.add_circle_outline),
                              label: Text(
                                'Agregar "${_searchCtrl.text.trim()}"',
                              ),
                            ),
                    )
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _filtered[index];
                        final selected = widget.initialValue == item;
                        return ListTile(
                          title: Text(
                            item,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.primaryBlue,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
