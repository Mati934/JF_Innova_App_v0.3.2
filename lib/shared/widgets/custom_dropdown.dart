import 'package:flutter/material.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart' as animated;
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

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    final closedDecoration = animated.CustomDropdownDecoration(
      closedBorder: Border.all(
        color: hasValue
            ? AppTheme.primaryBlue.withValues(alpha: 0.35)
            : Colors.grey.shade300,
        width: hasValue ? 1.5 : 1,
      ),
      closedFillColor: Colors.white,
      closedBorderRadius: BorderRadius.circular(12),
      expandedBorderRadius: BorderRadius.circular(12),
      hintStyle: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      headerStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
      closedShadow: hasValue
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
      expandedShadow: [
        BoxShadow(
          color: AppTheme.primaryBlue.withValues(alpha: 0.18),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
      listItemDecoration: animated.ListItemDecoration(
        selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.10),
        selectedIconBorder: const BorderSide(
          color: AppTheme.primaryBlue,
          width: 2,
        ),
        selectedIconColor: AppTheme.primaryBlue,
      ),
      searchFieldDecoration: animated.SearchFieldDecoration(
        textStyle: const TextStyle(fontSize: 14),
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
        ),
        prefixIcon: const Icon(
          Icons.search,
          color: AppTheme.primaryBlue,
          size: 20,
        ),
      ),
    );

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
          enableSearch
              ? animated.CustomDropdown<String>.search(
                  hintText: hint,
                  items: items,
                  initialItem: value,
                  onChanged: onChanged,
                  decoration: closedDecoration,
                  searchHintText: 'Escribe para filtrar…',
                  noResultFoundBuilder: (context, text) {
                    if (onAddNew == null) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Sin resultados',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }
                    return InkWell(
                      onTap: () => onAddNew!(text),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 14,
                        ),
                        color: AppTheme.primaryBlue.withValues(alpha: 0.04),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add_circle_outline,
                              color: AppTheme.primaryBlue,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Agregar "$text"',
                                style: const TextStyle(
                                  color: AppTheme.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : animated.CustomDropdown<String>(
                  hintText: hint,
                  items: items,
                  initialItem: value,
                  onChanged: onChanged,
                  decoration: closedDecoration,
                ),
        ],
      ),
    );
  }
}
