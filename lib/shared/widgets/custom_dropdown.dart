import 'package:flutter/material.dart';

class CustomDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<Map<String, dynamic>> items;
  final Function(String?) onChanged;
  final bool isLoading;

  const CustomDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
      ),
      value: value,
      items: items.map((item) {
        return DropdownMenuItem(
          value: item['id'] as String,
          child: Text(item['nombre'] ?? '', overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: isLoading ? null : onChanged,
      validator: (v) => v == null ? 'Campo requerido' : null,
    );
  }
}
