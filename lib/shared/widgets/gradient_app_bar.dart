import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// AppBar con gradiente diagonal corporativo, alineado al rediseño visual de la app.
/// Mantiene la API estándar de [AppBar] (title, actions, leading…) para que se
/// pueda usar como reemplazo directo sin afectar la lógica de las pantallas.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;
  final PreferredSizeWidget? bottom;

  /// Colores del gradiente. Si es null usa la paleta corporativa por defecto.
  /// Debe traer al menos 2 colores; los stops se calculan automáticamente.
  final List<Color>? gradientColors;

  const GradientAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.elevation = 0,
    this.bottom,
    this.gradientColors,
  });

  static const List<Color> _defaultColors = [
    AppTheme.primaryBlue,
    Color(0xFF002244),
    AppTheme.logoGrey,
  ];
  static const List<double> _defaultStops = [0.0, 0.65, 1.0];

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? _defaultColors;
    // Usamos stops sólo si coinciden en cantidad con los colores por defecto.
    final stops = (colors.length == _defaultColors.length)
        ? _defaultStops
        : null;
    return AppBar(
      title: title,
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      elevation: elevation,
      foregroundColor: Colors.white,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      bottom: bottom,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
            stops: stops,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
