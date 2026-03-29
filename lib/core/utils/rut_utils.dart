import 'package:flutter/services.dart';

class RutUtils {
  RutUtils._();

  /// Normaliza un RUT eliminando puntos, guiones, espacios y caracteres de control.
  /// Resultado en minúscula. Ej: "12.345.678-9" → "123456789"
  static String normalize(String? rut) {
    if (rut == null) return '';
    return rut
        .replaceAll(RegExp(r'[\.\-\s\r\n\t\u00AD]'), '')
        .toLowerCase()
        .trim();
  }

  /// Valida un RUT chileno usando algoritmo módulo 11.
  /// Acepta cualquier formato de entrada (con/sin puntos y guión).
  static bool isValid(String? rut) {
    final normalized = normalize(rut);
    if (normalized.length < 8 || normalized.length > 9) return false;

    final body = normalized.substring(0, normalized.length - 1);
    final givenDigit = normalized[normalized.length - 1];

    if (!RegExp(r'^\d+$').hasMatch(body)) return false;

    final expectedDigit = _computeCheckDigit(body);
    return givenDigit == expectedDigit;
  }

  /// Calcula el dígito verificador para el cuerpo numérico de un RUT.
  static String _computeCheckDigit(String body) {
    final digits = body.split('').reversed.toList();
    final multipliers = [2, 3, 4, 5, 6, 7];
    int sum = 0;

    for (int i = 0; i < digits.length; i++) {
      sum += int.parse(digits[i]) * multipliers[i % 6];
    }

    final remainder = 11 - (sum % 11);
    if (remainder == 11) return '0';
    if (remainder == 10) return 'k';
    return remainder.toString();
  }

  /// Formatea un RUT normalizado para display. Ej: "123456789" → "12.345.678-9"
  static String format(String? rut) {
    final normalized = normalize(rut);
    if (normalized.isEmpty) return '';
    if (normalized.length < 2) return normalized.toUpperCase();

    final body = normalized.substring(0, normalized.length - 1);
    final digit = normalized[normalized.length - 1].toUpperCase();

    // Insertar puntos cada 3 dígitos desde la derecha
    final buffer = StringBuffer();
    for (int i = 0; i < body.length; i++) {
      final posFromRight = body.length - 1 - i;
      buffer.write(body[i]);
      if (posFromRight > 0 && posFromRight % 3 == 0) {
        buffer.write('.');
      }
    }

    return '$buffer-$digit';
  }
}

/// TextInputFormatter que auto-formatea RUT mientras el usuario escribe.
class RutInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Extraer solo dígitos y k/K
    final raw = newValue.text.replaceAll(RegExp(r'[^\dkK]'), '').toLowerCase();
    if (raw.isEmpty) {
      return const TextEditingValue();
    }

    // Limitar a 9 caracteres (8 dígitos + 1 verificador)
    final limited = raw.length > 9 ? raw.substring(0, 9) : raw;

    // Formatear: tratamos todo como cuerpo parcial hasta tener >= 8 chars
    String formatted;
    if (limited.length < 8) {
      // Aún no hay verificador, todo es cuerpo parcial
      final buffer = StringBuffer();
      for (int i = 0; i < limited.length; i++) {
        final posFromRight = limited.length - 1 - i;
        buffer.write(limited[i]);
        if (posFromRight > 0 && posFromRight % 3 == 0) {
          buffer.write('.');
        }
      }
      formatted = buffer.toString();
    } else {
      // >= 8: último char es verificador
      final body = limited.substring(0, limited.length - 1);
      final digit = limited[limited.length - 1].toUpperCase();

      final buffer = StringBuffer();
      for (int i = 0; i < body.length; i++) {
        final posFromRight = body.length - 1 - i;
        buffer.write(body[i]);
        if (posFromRight > 0 && posFromRight % 3 == 0) {
          buffer.write('.');
        }
      }
      formatted = '$buffer-$digit';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
