// Cómo se guardan los nombres propios que se escriben en Administración (servicios, embarcaciones, centros):
// mayúscula inicial en cada palabra, conectores en minúscula, siglas y romanos en mayúscula, formas societarias
// abreviadas ("Ltda.", "SpA", "S.A."). Regla de Mati (2026-11-17), la misma que usa el dashboard para mostrar:
// jf_innova_web/dashboard-jfinnova/src/utils/nombres.ts. Si se cambia algo aquí, cambiarlo allá con los mismos casos.

const _conectores = {
  'y',
  'e',
  'o',
  'u',
  'de',
  'del',
  'la',
  'las',
  'los',
  'el',
  'en',
  'al',
  'por',
  'con',
  'para',
};

/// Siglas conocidas (se escriben tal cual). Agregar aquí las que aparezcan.
const _siglas = {
  'ROV',
  'JM',
  'MJL',
  'ITG',
  'ITD',
  'PMO',
  'AST',
  'SAG',
  'LM',
  'CT',
  'EPP',
  'DPR',
  'NC',
};

const _societarias = {
  'LTDA': 'Ltda.',
  'LIMITADA': 'Ltda.',
  'SPA': 'SpA',
  'EIRL': 'EIRL',
  'CIA': 'Cía.',
  'CÍA': 'Cía.',
};

/// Tildes frecuentes que se suelen escribir sin tilde (clave en mayúsculas, sin tilde).
const _tildes = {
  'RIO': 'Río',
  'RIOS': 'Ríos',
  'CHILOE': 'Chiloé',
  'MARITIMO': 'Marítimo',
  'MARITIMOS': 'Marítimos',
  'MARITIMA': 'Marítima',
  'MARIT': 'Marít',
  'ACUICOLA': 'Acuícola',
  'ACUICOLAS': 'Acuícolas',
  'GESTION': 'Gestión',
  'MARIA': 'María',
  'CRISTOBAL': 'Cristóbal',
  'JOSE': 'José',
  'MATIAS': 'Matías',
  'HECTOR': 'Héctor',
  'RAMON': 'Ramón',
  'JOAQUIN': 'Joaquín',
  'ANDRES': 'Andrés',
  'SEBASTIAN': 'Sebastián',
  'MARTIN': 'Martín',
  'PACIFICO': 'Pacífico',
  'ATLANTIDA': 'Atlántida',
  'BORQUEZ': 'Bórquez',
  'RELONCAVI': 'Reloncaví',
  'AYSEN': 'Aysén',
  'BAHIA': 'Bahía',
  'DESINFECCION': 'Desinfección',
  'INGENIERIA': 'Ingeniería',
  'ASESORIAS': 'Asesorías',
  'INVERSION': 'Inversión',
  'INVERSIONES': 'Inversiones',
  'PATRICIO': 'Patricio',
  'AVILES': 'Avilés',
  'CARDENAS': 'Cárdenas',
  'GONZALEZ': 'González',
  'PEREZ': 'Pérez',
  'RODRIGUEZ': 'Rodríguez',
  'HERNANDEZ': 'Hernández',
  'FARIAS': 'Farías',
  'EMBARCACION': 'Embarcación',
  'VICTOR': 'Víctor',
  'LEON': 'León',
  'ANGEL': 'Ángel',
  'CORDOVA': 'Córdova',
  'VALPARAISO': 'Valparaíso',
  'PUQUELDON': 'Puqueldón',
};

final _romano = RegExp(
  r'^(I|II|III|IV|V|VI|VII|VIII|IX|X|XI|XII|XIII|XIV|XV|XVI|XVII|XVIII|XIX|XX)$',
);
final _vocal = RegExp(r'[AEIOUÁÉÍÓÚÜ]');
final _bordes = RegExp(
  r'^([^\p{L}\p{N}&]*)(.*?)([^\p{L}\p{N}&]*)$',
  unicode: true,
);

String _capital(String w) =>
    w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase();

String _palabra(String token, bool primera, bool ultima) {
  final m = _bordes.firstMatch(token);
  if (m == null || (m.group(2) ?? '').isEmpty) return token;
  final antes = m.group(1)!;
  final nucleo = m.group(2)!;
  final despues = m.group(3)!;
  final u = nucleo.toUpperCase();
  final sinPuntos = u.replaceAll('.', '');
  final sinPuntoInicial = despues.startsWith('.')
      ? despues.substring(1)
      : despues;

  final soc = _societarias[sinPuntos];
  if (soc != null) return '$antes$soc$sinPuntoInicial';
  if (sinPuntos == 'SA' && ultima) return '${antes}S.A.$sinPuntoInicial';

  if (RegExp(r'^l{2,3}$').hasMatch(nucleo)) {
    return '$antes${'I' * nucleo.length}$despues';
  }
  if (_romano.hasMatch(u)) return '$antes$u$despues';
  if (_siglas.contains(u) ||
      RegExp(r'^[A-Z]&[A-Z]$').hasMatch(u) ||
      RegExp(r'^[A-Z]/[A-Z]$').hasMatch(u)) {
    return '$antes$u$despues';
  }
  // Con dígitos: números y códigos cortos en mayúscula ("4", "2B"); palabra con número pegado ("Tranquilo1").
  if (RegExp(r'\d').hasMatch(u)) {
    final corto = u.length <= 3 || RegExp(r'^\d+$').hasMatch(u);
    return '$antes${corto ? u : _capital(nucleo)}$despues';
  }
  final minus = nucleo.toLowerCase();
  if (!primera && _conectores.contains(minus)) return '$antes$minus$despues';
  if (u.length == 1 ||
      (u.length <= 4 &&
          RegExp(r'^[A-ZÑ]+$').hasMatch(u) &&
          !_vocal.hasMatch(u) &&
          u != 'Y')) {
    return '$antes$u$despues';
  }
  final t = _tildes[u];
  if (t != null) return '$antes$t$despues';
  // Ya escrita con mayúsculas en medio (marcas: "AquaChile"): se respeta tal cual.
  if (RegExp(r'\p{Ll}', unicode: true).hasMatch(nucleo) &&
      RegExp(r'\p{Lu}', unicode: true).hasMatch(nucleo.substring(1))) {
    return '$antes$nucleo$despues';
  }
  // Partes con guion o barra ("SERRANO-TAHUENAHUEC", "ELENA/ISLOTE"); apóstrofo tras una letra
  // ("O'HIGGINS" → "O'Higgins", pero "GLADY'S" → "Glady's").
  String parte(String p) {
    final t = _tildes[p.toUpperCase()];
    if (t != null) return t;
    return p.indexOf("'") == 1
        ? "${_capital(p.substring(0, 1))}'${_capital(p.substring(2))}"
        : _capital(p);
  }

  final partes = nucleo.splitMapJoin(
    RegExp(r'[-/]'),
    onMatch: (m) => m[0]!,
    onNonMatch: parte,
  );
  return '$antes$partes$despues';
}

/// "REDMAR CORDILLERA LTDA" → "Redmar Cordillera Ltda."; "LM LORETO lll" → "LM Loreto III";
/// "SERVICIO ACUÍCOLA P Y V" → "Servicio Acuícola P y V". Quita espacios sobrantes; vacío queda vacío.
String nombrePropio(String nombre) {
  final limpio = nombre.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (limpio.isEmpty) return limpio;
  final tokens = limpio.split(' ');
  return [
    for (var i = 0; i < tokens.length; i++)
      _palabra(tokens[i], i == 0, i == tokens.length - 1),
  ].join(' ');
}
