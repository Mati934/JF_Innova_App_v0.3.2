import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ModuleSelectorGrid extends StatelessWidget {
  final VoidCallback onInspeccionTap;
  final VoidCallback onVisitaTap;
  final VoidCallback onRendicionTap;

  const ModuleSelectorGrid({
    super.key,
    required this.onInspeccionTap,
    required this.onVisitaTap,
    required this.onRendicionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8.0, bottom: 15.0),
          child: Text(
            "Seleccione Operación",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF003366),
            ),
          ),
        ),

        // AQUÍ ESTÁ LA MAGIA DE LA GRILLA
        GridView.count(
          shrinkWrap: true, // Ocupa solo el espacio necesario
          physics:
              const NeverScrollableScrollPhysics(), // No hace scroll propio
          crossAxisCount: 2, // 2 Columnas
          mainAxisSpacing: 15, // Espacio vertical
          crossAxisSpacing: 15, // Espacio horizontal
          childAspectRatio: 1.1, // Relación Ancho/Alto (más cuadrado)
          children: [
            // 1. INSPECCIÓN
            _ModuleCard(
              title: "Nueva Inspección",
              subtitle: "Barcos / Buceo",
              icon: Icons.assignment_turned_in,
              color: AppTheme.primaryBlue,
              onTap: onInspeccionTap,
            ),

            // 2. VISITA TÉCNICA
            _ModuleCard(
              title: "Registro de Visita",
              subtitle: "R-003",
              icon: Icons.location_city,
              color: Colors.teal, // Color diferente para diferenciar
              onTap: onVisitaTap,
            ),

            // 3. RENDICIONES (Deshabilitado por ahora)
            _ModuleCard(
              title: "Rendiciones",
              subtitle: "Gastos",
              icon: Icons.receipt_long,
              color: Colors.orange,
              onTap: onRendicionTap,
              isDisabled: true, // <--- Bloqueado
            ),
          ],
        ),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDisabled;

  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDisabled ? Colors.grey.shade100 : Colors.white,
      elevation: isDisabled ? 0 : 4,
      borderRadius: BorderRadius.circular(20),
      shadowColor: color.withOpacity(0.4),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDisabled ? Colors.grey.shade300 : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isDisabled
                      ? Colors.grey.shade300
                      : color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isDisabled ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDisabled ? Colors.grey : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDisabled ? Colors.grey : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
