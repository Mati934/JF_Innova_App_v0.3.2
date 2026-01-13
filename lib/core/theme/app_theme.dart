import 'package:flutter/material.dart';

class AppTheme {
  // 1. Azul Corporativo (El que te gusta)
  static const Color primaryBlue = Color(0xFF003366);

  // 2. Colores del Logo (Aproximados)
  static const Color logoRed = Color(0xFFB71C1C); // Triángulo izquierdo
  static const Color logoYellow = Color(0xFFF9A825); // Triángulo derecho
  static const Color logoGrey = Color(0xFF455A64); // Triángulo superior / Texto

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto', // O la fuente que prefieras
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: logoGrey,
        error: logoRed,
        tertiary: logoYellow, // Usaremos esto para advertencias
        surface: Colors.white,
        background: const Color(0xFFF4F6F8),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),

      // Inputs con el borde azul corporativo al enfocar
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: primaryBlue, width: 2),
        ),
      ),
    );
  }
}
