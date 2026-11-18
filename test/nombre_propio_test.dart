import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/core/utils/nombre_propio.dart';

// Mismos casos que el dashboard (jf_innova_web: dashboard-jfinnova/src/utils/nombres.test.ts).
// Si se agrega uno aquí, agregarlo allá.
const casos = <String, String>{
  'REDMAR CORDILLERA LTDA': 'Redmar Cordillera Ltda.',
  'SER. MARITIMOS SAN CRISTOBAL SPA': 'Ser. Marítimos San Cristóbal SpA',
  'SERVICIO ACUÍCOLA P Y V': 'Servicio Acuícola P y V',
  'TRANS. Y SERV. MJL SPA': 'Trans. y Serv. MJL SpA',
  'Viejo lobo de mar limitada': 'Viejo Lobo de Mar Ltda.',
  'LM LORETO lll': 'LM Loreto III',
  'PUNTA BLANCA IV': 'Punta Blanca IV',
  'RIO MALLECO': 'Río Malleco',
  'SERVICIO A&A SPA': 'Servicio A&A SpA',
  'NAVIERA PROP LTDA.': 'Naviera Prop Ltda.',
  'SERVICIO JM S.A': 'Servicio JM S.A.',
  'TRANSPORTES LACAO S.A': 'Transportes Lacao S.A.',
  'SOCIEDAD PESQUERA GLACIARES Y CIA LTDA.':
      'Sociedad Pesquera Glaciares y Cía. Ltda.',
  'L/M VICTORIA I': 'L/M Victoria I',
  'Embarcación L/M Norgina II': 'Embarcación L/M Norgina II',
  'EMP. SERV. MARIT. Y ACUL. BRISA AUSTRAL. LTDA':
      'Emp. Serv. Marít. y Acul. Brisa Austral. Ltda.',
  "GLADY'S": "Glady's",
  'SERRANO-TAHUENAHUEC': 'Serrano-Tahuenahuec',
  'LAS GUAITECAS 2': 'Las Guaitecas 2',
  'MAR DE TERAO II': 'Mar de Terao II',
  'DOÑA ORFILIA': 'Doña Orfilia',
  'SERV. ACUICOLA JM ROV SPA': 'Serv. Acuícola JM ROV SpA',
  'Serv. Itd Kamar Ltda': 'Serv. ITD Kamar Ltda.',
  '  PUERTO   RED 4 ': 'Puerto Red 4',
  'N/A': 'N/A',
  'EMBARCACION SAN FRANCISCO': 'Embarcación San Francisco',
  'VICTOR GABRIEL II': 'Víctor Gabriel II',
  'BAHIA TRANQUILO1': 'Bahía Tranquilo1',
  'BASE ELENA/ISLOTE': 'Base Elena/Islote',
  "O'HIGGINS": "O'Higgins",
  'AquaChile': 'AquaChile',
  'LOS RIOS I': 'Los Ríos I',
};

void main() {
  group('nombrePropio', () {
    casos.forEach((entrada, salida) {
      test(
        '"$entrada" → "$salida"',
        () => expect(nombrePropio(entrada), salida),
      );
    });
    test('aplicarla dos veces da lo mismo', () {
      for (final salida in casos.values) {
        expect(nombrePropio(salida), salida);
      }
    });
    test('vacío queda vacío', () => expect(nombrePropio('   '), ''));
  });
}
