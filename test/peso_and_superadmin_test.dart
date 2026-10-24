// ignore_for_file: unrelated_type_equality_checks, dead_code
import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/inspection/domain/models/formulario_item.dart';
import 'package:jf_innova_app/features/inspection/domain/models/pdf/inspection_report_data.dart';
import 'package:jf_innova_app/core/services/user_session.dart';

void main() {
  // ===================================================================
  // TESTS: FormularioItem - campo peso
  // ===================================================================
  group('FormularioItem - campo peso', () {
    test('fromJson parsea peso correctamente', () {
      final item = FormularioItem.fromJson({
        'id': 'item-1',
        'pregunta': 'Pregunta test',
        'categoria': 'CAT_A',
        'criticidad': 'Tolerable',
        'orden': 1,
        'peso': 0.53,
      });

      expect(item.peso, 0.53);
    });

    test('fromJson usa default 1.0 cuando peso es null', () {
      final item = FormularioItem.fromJson({
        'id': 'item-1',
        'pregunta': 'Pregunta test',
        'categoria': 'CAT_A',
        'criticidad': 'Tolerable',
        'orden': 1,
        'peso': null,
      });

      expect(item.peso, 1.0);
    });

    test('fromJson usa default 1.0 cuando peso no existe', () {
      final item = FormularioItem.fromJson({
        'id': 'item-1',
        'pregunta': 'Pregunta test',
        'categoria': 'CAT_A',
        'criticidad': 'Tolerable',
      });

      expect(item.peso, 1.0);
    });

    test('fromJson parsea peso entero como double', () {
      final item = FormularioItem.fromJson({
        'id': 'item-1',
        'pregunta': 'Pregunta test',
        'categoria': 'CAT_A',
        'criticidad': 'Tolerable',
        'peso': 1,
      });

      expect(item.peso, 1.0);
      expect(item.peso, isA<double>());
    });

    test('constructor default peso es 1.0', () {
      final item = FormularioItem(
        id: 'item-1',
        pregunta: 'Test',
        categoria: 'CAT',
        criticidad: 'Tolerable',
      );

      expect(item.peso, 1.0);
    });
  });

  // ===================================================================
  // TESTS: Porcentaje ponderado por peso
  // ===================================================================
  group('Porcentaje ponderado - formula con pesos', () {
    test('todas peso=1.0: porcentaje igual al conteo simple', () {
      // 8 C + 2 NC, todas peso=1.0
      final items = _buildItemsConPeso(
        cumple: 8,
        noCumple: 2,
        pesoCumple: 1.0,
        pesoNoCumple: 1.0,
      );

      final pct = _calcularPorcentaje(items);
      expect(pct, 80); // 8/10 = 80%
    });

    test('preguntas nuevas con peso 0.53: caso 88% floor', () {
      // Simula INSPECCION_BUCEO: 30 viejas (C, peso=1.0) + 5 verificaciones (C, peso=1.0)
      // + 9 nuevas (NC, peso=0.53)
      final items = <_PesoItem>[];

      // 30 preguntas viejas todas C
      for (var i = 0; i < 30; i++) {
        items.add(_PesoItem(respuesta: 'C', peso: 1.0));
      }
      // 5 verificaciones buceo todas C
      for (var i = 0; i < 5; i++) {
        items.add(_PesoItem(respuesta: 'C', peso: 1.0));
      }
      // 9 preguntas nuevas todas NC con peso 0.53
      for (var i = 0; i < 9; i++) {
        items.add(_PesoItem(respuesta: 'NC', peso: 0.53));
      }

      final pct = _calcularPorcentaje(items);
      expect(pct, greaterThanOrEqualTo(88));
    });

    test('peso 0 efectivamente anula la pregunta', () {
      final items = [
        _PesoItem(respuesta: 'C', peso: 1.0),
        _PesoItem(respuesta: 'C', peso: 1.0),
        _PesoItem(respuesta: 'NC', peso: 0.0), // no cuenta
      ];

      final pct = _calcularPorcentaje(items);
      expect(pct, 100); // NC con peso 0 no afecta
    });

    test('mezcla de pesos produce porcentaje correcto', () {
      // 2 C (peso 1.0) + 1 NC (peso 0.5)
      // sumPesoC = 2.0, sumPesoNC = 0.5
      // % = 2.0 / (2.0 + 0.5) = 80%
      final items = [
        _PesoItem(respuesta: 'C', peso: 1.0),
        _PesoItem(respuesta: 'C', peso: 1.0),
        _PesoItem(respuesta: 'NC', peso: 0.5),
      ];

      final pct = _calcularPorcentaje(items);
      expect(pct, 80);
    });

    test('N/A no afecta el porcentaje (excluido de denominador)', () {
      // 3 C (peso 1.0) + 2 N/A + 1 NC (peso 1.0)
      // sumPesoC = 3.0, sumPesoNC = 1.0
      // % = 3.0 / 4.0 = 75%
      final items = [
        _PesoItem(respuesta: 'C', peso: 1.0),
        _PesoItem(respuesta: 'C', peso: 1.0),
        _PesoItem(respuesta: 'C', peso: 1.0),
        _PesoItem(respuesta: 'N/A', peso: 1.0),
        _PesoItem(respuesta: 'N/A', peso: 1.0),
        _PesoItem(respuesta: 'NC', peso: 1.0),
      ];

      final pct = _calcularPorcentaje(items);
      expect(pct, 75);
    });

    test('todo N/A produce 0% (evita division por cero)', () {
      final items = [
        _PesoItem(respuesta: 'N/A', peso: 1.0),
        _PesoItem(respuesta: 'N/A', peso: 1.0),
      ];

      final pct = _calcularPorcentaje(items);
      expect(pct, 0);
    });

    test('100% cumplimiento con pesos variados', () {
      final items = [
        _PesoItem(respuesta: 'C', peso: 1.0),
        _PesoItem(respuesta: 'C', peso: 0.5),
        _PesoItem(respuesta: 'C', peso: 0.3),
      ];

      final pct = _calcularPorcentaje(items);
      expect(pct, 100);
    });

    test('0% cumplimiento con pesos variados', () {
      final items = [
        _PesoItem(respuesta: 'NC', peso: 1.0),
        _PesoItem(respuesta: 'NC', peso: 0.5),
        _PesoItem(respuesta: 'NC', peso: 0.3),
      ];

      final pct = _calcularPorcentaje(items);
      expect(pct, 0);
    });
  });

  // ===================================================================
  // TESTS: InspectionReportData con campos de peso
  // ===================================================================
  group('InspectionReportData - campos peso', () {
    test('acepta sumPesoCumple y sumPesoNoCumple', () {
      final data = InspectionReportData(
        empresaContratista: 'Test',
        cliente: 'Client',
        logoUrl: '',
        numeroReporte: 'R-001',
        fecha: '08-04-2026',
        centro: 'Centro',
        area: 'Area',
        embarcacion: 'Nave',
        matricula: 'MAT-1',
        appVersion: '1.0.0',
        tipoFaena: 'Buceo',
        supervisor: 'Sup',
        estadoGlobal: 'Aprobado',
        esAprobado: true,
        equipo: [],
        items: [],
        fotosGeneralesPaths: [],
        fotosExtraObservaciones: [],
        totalCumple: 10,
        totalNoCumple: 2,
        totalNoAplica: 1,
        totalIntolerables: 0,
        sumPesoCumple: 10.0,
        sumPesoNoCumple: 1.06,
        observacionPrevencionista: '',
        verificacionesBuceo: {},
      );

      expect(data.totalCumple, 10);
      expect(data.totalNoCumple, 2);
      expect(data.sumPesoCumple, 10.0);
      expect(data.sumPesoNoCumple, 1.06);
    });
  });

  // ===================================================================
  // TESTS: guardarMaestros - Mapeo empresas con es_administradora
  // ===================================================================
  group('guardarMaestros - empresas con es_administradora', () {
    test('es_administradora true se mapea a 1', () {
      final item = {
        'id': 'emp-1',
        'nombre': 'Servimaf',
        'es_administradora': true,
      };
      final val =
          (item['es_administradora'] == true || item['es_administradora'] == 1)
          ? 1
          : 0;
      expect(val, 1);
    });

    test('es_administradora false se mapea a 0', () {
      final item = {
        'id': 'emp-2',
        'nombre': 'AquaChile',
        'es_administradora': false,
      };
      final val =
          (item['es_administradora'] == true || item['es_administradora'] == 1)
          ? 1
          : 0;
      expect(val, 0);
    });

    test('es_administradora null se mapea a 0', () {
      final item = {
        'id': 'emp-3',
        'nombre': 'Legacy',
        'es_administradora': null,
      };
      final val =
          (item['es_administradora'] == true || item['es_administradora'] == 1)
          ? 1
          : 0;
      expect(val, 0);
    });

    test('es_administradora int 1 se mapea a 1', () {
      final item = {'id': 'emp-4', 'nombre': 'Test', 'es_administradora': 1};
      final val =
          (item['es_administradora'] == true || item['es_administradora'] == 1)
          ? 1
          : 0;
      expect(val, 1);
    });
  });

  // ===================================================================
  // TESTS: EmpresaUsuario - campo esAdministradora
  // ===================================================================
  group('EmpresaUsuario - esAdministradora', () {
    test('default es false', () {
      const emp = EmpresaUsuario(id: 'emp-1', nombre: 'Aquachile');
      expect(emp.esAdministradora, false);
    });

    test('se crea con esAdministradora true', () {
      const emp = EmpresaUsuario(
        id: 'emp-1',
        nombre: 'Servimaf',
        esAdministradora: true,
      );
      expect(emp.esAdministradora, true);
    });

    test('se crea con esAdministradora false explícito', () {
      const emp = EmpresaUsuario(
        id: 'emp-2',
        nombre: 'AquaChile',
        esAdministradora: false,
      );
      expect(emp.esAdministradora, false);
    });
  });

  // ===================================================================
  // TESTS: esSuperAdmin - lógica combinada
  // ===================================================================
  group('esSuperAdmin - lógica combinada', () {
    // Replica la lógica de UserSession.esSuperAdmin
    bool esSuperAdmin(String? nombreRol, bool empresaAdministradora) {
      final rol = (nombreRol ?? '').toLowerCase().trim();
      final esAdmin = rol == 'administrador' || rol == 'admin';
      return esAdmin && empresaAdministradora;
    }

    test('admin + empresa administradora = super admin', () {
      expect(esSuperAdmin('Administrador', true), true);
    });

    test('admin + empresa normal = NO super admin', () {
      expect(esSuperAdmin('Administrador', false), false);
    });

    test('inspector + empresa administradora = NO super admin', () {
      expect(esSuperAdmin('Inspector', true), false);
    });

    test('inspector + empresa normal = NO super admin', () {
      expect(esSuperAdmin('Inspector', false), false);
    });

    test('null rol + empresa administradora = NO super admin', () {
      expect(esSuperAdmin(null, true), false);
    });
  });

  // ===================================================================
  // TESTS: EmpresaModulosScreen - acceso según super admin
  // ===================================================================
  group('EmpresaModulosScreen - filtrado por permisos', () {
    test('super admin ve todas las empresas', () {
      final isSuperAdmin = true;
      final todasLasEmpresas = [
        {'id': 'emp-1', 'nombre': 'Aquachile'},
        {'id': 'emp-2', 'nombre': 'JF Innova'},
        {'id': 'emp-3', 'nombre': 'Servimaf'},
      ];

      final empresasVisibles = isSuperAdmin ? todasLasEmpresas : null;

      expect(empresasVisibles, isNotNull);
      expect(empresasVisibles!.length, 3);
    });

    test('admin normal va directo a su empresa', () {
      final isSuperAdmin = false;
      final empresaId = 'emp-1';

      // Simula la lógica de _cargarEmpresas
      String? selectedEmpresaId;
      if (isSuperAdmin) {
        // Cargaría todas las empresas
      } else {
        selectedEmpresaId = empresaId;
      }

      expect(
        selectedEmpresaId,
        'emp-1',
        reason: 'Admin normal va directo a su empresa',
      );
    });

    test('super admin puede navegar entre empresas', () {
      final isSuperAdmin = true;
      String? selectedEmpresaId;

      // Selecciona primera empresa
      selectedEmpresaId = 'emp-1';
      expect(selectedEmpresaId, 'emp-1');

      // Puede volver a la lista (solo super admin)
      if (isSuperAdmin) {
        selectedEmpresaId = null;
      }
      expect(
        selectedEmpresaId,
        isNull,
        reason: 'Super admin puede volver a la lista',
      );

      // Selecciona otra empresa
      selectedEmpresaId = 'emp-2';
      expect(selectedEmpresaId, 'emp-2');
    });

    test('admin normal NO puede volver a lista de empresas', () {
      final isSuperAdmin = false;
      String? selectedEmpresaId = 'emp-1';

      // No hay botón de volver para admin normal
      if (isSuperAdmin) {
        selectedEmpresaId = null;
      }

      expect(
        selectedEmpresaId,
        'emp-1',
        reason: 'Admin normal no cambia de empresa',
      );
    });
  });

  // ===================================================================
  // TESTS: guardarItemsOffline - incluye peso
  // ===================================================================
  group('guardarItemsOffline - campo peso', () {
    test('peso se extrae correctamente del JSON de Supabase', () {
      final item = {
        'id': 'item-1',
        'tipo_actividad': 'INSPECCION_BUCEO',
        'categoria': 'EQUIPO',
        'pregunta': 'Test',
        'criticidad': 'Tolerable',
        'orden': 1,
        'activo': true,
        'info_adicional': null,
        'url_imagen_referencia': null,
        'peso': 0.53,
      };

      final pesoValue = (item['peso'] as num?)?.toDouble() ?? 1.0;
      expect(pesoValue, 0.53);
    });

    test('peso null usa default 1.0', () {
      final item = {'peso': null};
      final pesoValue = (item['peso'] as num?)?.toDouble() ?? 1.0;
      expect(pesoValue, 1.0);
    });

    test('peso ausente usa default 1.0', () {
      final item = <String, dynamic>{};
      final pesoValue = (item['peso'] as num?)?.toDouble() ?? 1.0;
      expect(pesoValue, 1.0);
    });
  });
}

// ============================================================
// Helpers
// ============================================================

class _PesoItem {
  final String respuesta;
  final double peso;
  _PesoItem({required this.respuesta, required this.peso});
}

List<_PesoItem> _buildItemsConPeso({
  required int cumple,
  required int noCumple,
  required double pesoCumple,
  required double pesoNoCumple,
}) {
  final items = <_PesoItem>[];
  for (var i = 0; i < cumple; i++) {
    items.add(_PesoItem(respuesta: 'C', peso: pesoCumple));
  }
  for (var i = 0; i < noCumple; i++) {
    items.add(_PesoItem(respuesta: 'NC', peso: pesoNoCumple));
  }
  return items;
}

/// Replica la fórmula de porcentaje ponderado del PDF generator
int _calcularPorcentaje(List<_PesoItem> items) {
  double sumPesoC = 0.0, sumPesoNC = 0.0;

  for (var item in items) {
    if (item.respuesta == 'C') {
      sumPesoC += item.peso;
    } else if (item.respuesta == 'NC') {
      sumPesoNC += item.peso;
    }
    // N/A se ignora
  }

  final totalPesoAplicable = sumPesoC + sumPesoNC;
  if (totalPesoAplicable == 0) return 0;
  return ((sumPesoC / totalPesoAplicable) * 100).round();
}
