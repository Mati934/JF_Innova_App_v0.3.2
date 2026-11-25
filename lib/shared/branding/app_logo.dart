import '../../core/services/user_session.dart';

/// Branding centralizado de la app.
///
/// =============================================================================
/// 🎨 CÓMO CAMBIAR EL LOGO QUE SE MUESTRA EN LA APP
/// =============================================================================
/// 1. Sube el archivo nuevo a `assets/images/`.
/// 2. Asegúrate de que esté declarado en `pubspec.yaml` (la carpeta
///    `assets/images/` ya está declarada, así que basta con copiar el archivo).
/// 3. Edita el mapa [_logoPorEmpresa] de abajo:
///    - Para cambiar el logo de una empresa existente, reemplaza el `path`.
///    - Para añadir una empresa nueva, agrega una entrada con la clave en
///      minúsculas y sin espacios (ej: `'aquachile'`, `'hidroser'`).
///    - Para cambiar el logo por defecto (cuando no se reconoce la empresa),
///      edita [_logoFallback].
///
/// El mismo logo aparece automáticamente en:
///   - La animación de splash post-login (`AnimatedSplash`).
///   - El header del Home (`HomeScreen`).
/// =============================================================================
class AppLogo {
  AppLogo._();

  /// Ruta por defecto cuando la empresa no está mapeada o no hay sesión.
  static const String _logoFallback = 'assets/images/logo_jfinnova.png';

  /// Mapa empresa → asset de logo.
  /// La clave debe estar en minúsculas y sin espacios (ver [_normalize]).
  /// Hoy todas las empresas usan el logo unificado de JF Innova.
  static const Map<String, String> _logoPorEmpresa = {
    'jfinnova': 'assets/images/logo_jfinnova.png',
    'aquachile': 'assets/images/logo_jfinnova.png',
    'servimaf': 'assets/images/logo_jfinnova.png',
    'hidroser': 'assets/images/logo_jfinnova.png',
  };

  /// Devuelve la ruta del asset de logo correspondiente a la empresa actual.
  ///
  /// Si [empresaNombre] es `null`, usa la empresa de la sesión activa.
  /// Si no hay match, usa [_logoFallback].
  static String pathForCurrentEmpresa({String? empresaNombre}) {
    final nombre = empresaNombre ?? UserSession().empresaNombre;
    final key = _normalize(nombre);
    if (key.isEmpty) return _logoFallback;
    return _logoPorEmpresa[key] ?? _logoFallback;
  }

  static String _normalize(String? raw) =>
      (raw ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), '');
}
