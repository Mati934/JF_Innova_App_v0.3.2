import 'package:flutter/material.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_categoria_model.dart';
import 'package:jf_innova_app/shared/widgets/custom_dropdown.dart';

/// Selector de categoría para el formulario de tickets.
///
/// Muestra un [DropdownButtonFormField] con las categorías disponibles.
/// Si el usuario selecciona la opción "Otro", aparece un [TextFormField]
/// adicional para especificar la categoría manualmente.
class TicketCategorySelector extends StatefulWidget {
  final List<TicketCategoriaModel> categorias;
  final Function(String categoriaId, String? categoriaOtro) onChanged;

  const TicketCategorySelector({
    super.key,
    required this.categorias,
    required this.onChanged,
  });

  @override
  State<TicketCategorySelector> createState() => _TicketCategorySelectorState();
}

class _TicketCategorySelectorState extends State<TicketCategorySelector> {
  String? _selectedId;
  bool _isOtroSelected = false;
  final _otroController = TextEditingController();

  @override
  void dispose() {
    _otroController.dispose();
    super.dispose();
  }

  void _onDropdownChanged(String? categoriaId) {
    if (categoriaId == null) return;

    final categoria = widget.categorias.firstWhere((c) => c.id == categoriaId);
    final isOtro = categoria.nombre.trim().toLowerCase() == 'otro';

    // Limpiamos el texto antes de actualizar estado para no emitir texto residual.
    if (!isOtro) _otroController.clear();

    setState(() {
      _selectedId = categoriaId;
      _isOtroSelected = isOtro;
    });

    // Al seleccionar "Otro" el campo de texto aún está vacío: se emite null.
    widget.onChanged(categoriaId, null);
  }

  @override
  Widget build(BuildContext context) {
    final selectedNombre = _selectedId != null
        ? widget.categorias
              .where((c) => c.id == _selectedId)
              .map((c) => c.nombre)
              .firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomDropdown(
          label: 'Actividad',
          enableSearch: false,
          items: widget.categorias.map((c) => c.nombre).toList(),
          value: selectedNombre,
          onChanged: (nombre) {
            if (nombre == null) return;
            final cat = widget.categorias.firstWhere((c) => c.nombre == nombre);
            _onDropdownChanged(cat.id);
          },
        ),
        if (_isOtroSelected) ...[
          TextFormField(
            controller: _otroController,
            decoration: InputDecoration(
              labelText: 'Especifique la categoría',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (text) {
              if (_selectedId != null) {
                widget.onChanged(
                  _selectedId!,
                  text.trim().isEmpty ? null : text.trim(),
                );
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
