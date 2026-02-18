import 'package:flutter/material.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart' as animated;
// Asegúrate de que esta ruta sea correcta según tu estructura:
import '../../core/theme/app_theme.dart';

class CustomDropdown extends StatelessWidget {
  final List<String> items;
  final String? value;
  final String label;
  final Function(String?) onChanged;
  final Function(String)? onAddNew;
  final bool enableSearch;

  const CustomDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.label,
    required this.onChanged,
    this.onAddNew,
    this.enableSearch = true,
  });

  @override
  Widget build(BuildContext context) {
    // Usamos las variables del Theme para consistencia
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Etiqueta flotante
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                // USAMOS TU AZUL CORPORATIVO DESDE EL THEME
                color: AppTheme.primaryBlue,
              ),
            ),
          ),

          // EL WIDGET "BACÁN"
          enableSearch
              ? animated.CustomDropdown<String>.search(
                  hintText: 'Selecciona o busca...',
                  items: items,
                  initialItem: value,
                  onChanged: onChanged,

                  // --- DECORACIÓN UNIFICADA CON APP_THEME ---
                  decoration: animated.CustomDropdownDecoration(
                    // Bordes grises suaves como tus inputs normales
                    closedBorder: Border.all(color: Colors.grey.shade400),
                    closedFillColor: Colors.white,

                    // CAMBIO: Usamos radio 8 para que coincida con tu AppTheme
                    closedBorderRadius: BorderRadius.circular(8),
                    expandedBorderRadius: BorderRadius.circular(8),

                    hintStyle: TextStyle(color: Colors.grey.shade500),

                    // Texto seleccionado un poco más grueso y oscuro
                    headerStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),

                    // Sombra elegante
                    expandedShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withOpacity(
                          0.2,
                        ), // Sombra azulada sutil
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),

                  // Configuración de búsqueda
                  searchHintText: 'Escribe para filtrar...',

                  // Lógica de "Crear Nuevo"
                  noResultFoundBuilder: (context, text) {
                    if (onAddNew == null) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text("Sin resultados"),
                        ),
                      );
                    }

                    return InkWell(
                      onTap: () {
                        onAddNew!(text);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 12,
                        ),
                        color: Colors.grey.shade50,
                        child: Row(
                          children: [
                            // USAMOS EL ICONO Y COLOR CORPORATIVO
                            const Icon(
                              Icons.add_circle_outline,
                              color: AppTheme.primaryBlue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Agregar "$text"',
                              style: const TextStyle(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : animated.CustomDropdown<String>(
                  // --- MODO SIMPLE ---
                  hintText: 'Selecciona una opción',
                  items: items,
                  initialItem: value,
                  onChanged: onChanged,
                  decoration: animated.CustomDropdownDecoration(
                    closedBorder: Border.all(color: Colors.grey.shade400),
                    closedFillColor: Colors.white,
                    closedBorderRadius: BorderRadius.circular(8), // Radio 8
                    expandedBorderRadius: BorderRadius.circular(8),
                    headerStyle: const TextStyle(fontSize: 16),
                  ),
                ),
        ],
      ),
    );
  }
}
