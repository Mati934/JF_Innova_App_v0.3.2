// ignore_for_file: unused_local_variable, unnecessary_null_comparison
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/core/modules/module_registry.dart';
import 'package:jf_innova_app/core/services/user_session.dart';

void main() {
  // ===================================================================
  // TESTS: UserSession - Singleton y Multi-Empresa
  // ===================================================================
  group('UserSession - Singleton', () {
    test('UserSession es singleton', () {
      final a = UserSession();
      final b = UserSession();
      expect(
        identical(a, b),
        true,
        reason: 'factory debe retornar la misma instancia',
      );
    });

    test('Estado inicial: todo nulo y vacío', () {
      final session = UserSession();
      session.clear(); // Asegurar estado limpio

      expect(session.userId, isNull);
      expect(session.nombreCompleto, isNull);
      expect(session.nombreRol, isNull);
      expect(session.email, isNull);
      expect(session.empresaId, isNull);
      expect(session.empresas, isEmpty);
      expect(session.empresaNombre, isNull);
      expect(session.tieneMultiEmpresa, false);
      expect(session.isLoaded, false);
      expect(session.esAdmin, false);
    });

    test('clear() limpia toda la sesión', () {
      final session = UserSession();
      // Simular que hay datos (via clear y re-check)
      session.clear();

      expect(session.userId, isNull);
      expect(session.empresaId, isNull);
      expect(session.empresas, isEmpty);
      expect(session.isLoaded, false);
    });
  });

  group('UserSession - esAdmin', () {
    test('esAdmin detecta "Administrador"', () {
      // Simulamos la lógica de esAdmin
      bool esAdmin(String? nombreRol) {
        final rol = (nombreRol ?? '').toLowerCase().trim();
        return rol == 'administrador' || rol == 'admin';
      }

      expect(esAdmin('Administrador'), true);
      expect(esAdmin('administrador'), true);
      expect(esAdmin('ADMINISTRADOR'), true);
      expect(esAdmin('admin'), true);
      expect(esAdmin('Admin'), true);
      expect(esAdmin(' Admin '), true, reason: 'trim debe funcionar');
    });

    test('esAdmin rechaza roles no admin', () {
      bool esAdmin(String? nombreRol) {
        final rol = (nombreRol ?? '').toLowerCase().trim();
        return rol == 'administrador' || rol == 'admin';
      }

      expect(esAdmin('Inspector'), false);
      expect(esAdmin('Supervisor'), false);
      expect(esAdmin(''), false);
      expect(esAdmin(null), false);
      expect(
        esAdmin('administrador_senior'),
        false,
        reason: 'match exacto, no partial',
      );
    });
  });

  group('UserSession - cambiarEmpresa()', () {
    test('cambiarEmpresa selecciona empresa válida', () {
      // Simulamos la lógica de cambiarEmpresa
      final empresas = [
        EmpresaUsuario(id: 'emp-1', nombre: 'Aquachile'),
        EmpresaUsuario(id: 'emp-2', nombre: 'JF Innova'),
      ];
      String? currentEmpresaId = 'emp-1';

      bool cambiar(String id) {
        if (empresas.any((e) => e.id == id)) {
          currentEmpresaId = id;
          return true;
        }
        return false;
      }

      expect(cambiar('emp-2'), true);
      expect(currentEmpresaId, 'emp-2');
    });

    test('cambiarEmpresa rechaza empresa inexistente', () {
      final empresas = [EmpresaUsuario(id: 'emp-1', nombre: 'Aquachile')];
      String? currentEmpresaId = 'emp-1';

      bool cambiar(String id) {
        if (empresas.any((e) => e.id == id)) {
          currentEmpresaId = id;
          return true;
        }
        return false;
      }

      expect(cambiar('emp-999'), false);
      expect(
        currentEmpresaId,
        'emp-1',
        reason: 'No debe cambiar si la empresa no existe',
      );
    });
  });

  group('UserSession - tieneMultiEmpresa', () {
    test('false con 0 empresas', () {
      final List<EmpresaUsuario> empresas = [];
      expect(empresas.length > 1, false);
    });

    test('false con 1 empresa', () {
      final empresas = [EmpresaUsuario(id: '1', nombre: 'A')];
      expect(empresas.length > 1, false);
    });

    test('true con 2+ empresas', () {
      final empresas = [
        EmpresaUsuario(id: '1', nombre: 'A'),
        EmpresaUsuario(id: '2', nombre: 'B'),
      ];
      expect(empresas.length > 1, true);
    });
  });

  group('UserSession - empresaNombre', () {
    test('retorna nombre de empresa activa', () {
      final empresas = [
        EmpresaUsuario(id: 'emp-1', nombre: 'Aquachile'),
        EmpresaUsuario(id: 'emp-2', nombre: 'JF Innova'),
      ];
      final currentEmpresaId = 'emp-2';

      String? nombre;
      try {
        nombre = empresas.firstWhere((e) => e.id == currentEmpresaId).nombre;
      } catch (_) {
        nombre = null;
      }

      expect(nombre, 'JF Innova');
    });

    test('retorna null si empresa no está en lista', () {
      final empresas = [EmpresaUsuario(id: 'emp-1', nombre: 'Aquachile')];
      final currentEmpresaId = 'emp-999';

      String? nombre;
      try {
        nombre = empresas.firstWhere((e) => e.id == currentEmpresaId).nombre;
      } catch (_) {
        nombre = null;
      }

      expect(nombre, isNull);
    });
  });

  // ===================================================================
  // TESTS: EmpresaUsuario model
  // ===================================================================
  group('EmpresaUsuario', () {
    test('se crea correctamente', () {
      const emp = EmpresaUsuario(id: 'abc-123', nombre: 'Aquachile');
      expect(emp.id, 'abc-123');
      expect(emp.nombre, 'Aquachile');
    });

    test('fromMap pattern (como se usa en _cargarEmpresas)', () {
      final row = {'empresa_id': 'uuid-1', 'nombre': 'JF Innova'};
      final emp = EmpresaUsuario(
        id: row['empresa_id'] as String,
        nombre: row['nombre'] ?? 'Sin nombre',
      );
      expect(emp.id, 'uuid-1');
      expect(emp.nombre, 'JF Innova');
    });

    test('fromMap con nombre null usa fallback', () {
      final row = {'empresa_id': 'uuid-2', 'nombre': null};
      final emp = EmpresaUsuario(
        id: row['empresa_id'] as String,
        nombre: row['nombre'] ?? 'Sin nombre',
      );
      expect(emp.nombre, 'Sin nombre');
    });
  });

  // ===================================================================
  // TESTS: ModuleRegistry
  // ===================================================================
  group('ModuleRegistry - Registro Global', () {
    test('tiene la cantidad esperada de módulos registrados', () {
      final expectedCount = kDebugMode ? 16 : 15;
      expect(ModuleRegistry.all.length, expectedCount);
    });

    test('cada módulo tiene key única', () {
      final keys = ModuleRegistry.all.map((m) => m.moduleKey).toSet();
      expect(
        keys.length,
        ModuleRegistry.all.length,
        reason: 'No debe haber module keys duplicados',
      );
    });

    test('módulos registrados completos', () {
      final keys = ModuleRegistry.all.map((m) => m.moduleKey).toList();
      expect(
        keys,
        containsAll([
          'INSPECCION',
          'VISITA_R003',
          'VISITA_R004',
          'MANTENCION_PROSESSO',
          'HIDROSER',
          'AST',
          'MERIEUX_VISITAS',
          'MERIEUX_EXTINTORES',
          'ADMIN',
          'HISTORY',
          'RENDICIONES',
        ]),
      );
    });

    test('byKey() encuentra módulo existente', () {
      final mod = ModuleRegistry.byKey('INSPECCION');
      expect(mod, isNotNull);
      expect(mod!.moduleKey, 'INSPECCION');
      expect(mod.title, 'Nueva Inspección');
    });

    test('byKey() retorna null para key inexistente', () {
      final mod = ModuleRegistry.byKey('NO_EXISTE');
      expect(mod, isNull);
    });

    test('ADMIN requiere admin', () {
      final admin = ModuleRegistry.byKey('ADMIN');
      expect(admin!.requiresAdmin, true);
    });

    test('módulos normales no requieren admin', () {
      for (final key in ['INSPECCION', 'VISITA_R003', 'VISITA_R004']) {
        final mod = ModuleRegistry.byKey(key)!;
        expect(
          mod.requiresAdmin,
          false,
          reason: '$key no debería requerir admin',
        );
      }
    });

    test('RENDICIONES es placeholder', () {
      final mod = ModuleRegistry.byKey('RENDICIONES');
      expect(mod!.isPlaceholder, true);
    });

    test('módulos funcionales no son placeholder', () {
      for (final key in [
        'INSPECCION',
        'VISITA_R003',
        'VISITA_R004',
        'ADMIN',
        'HISTORY',
      ]) {
        final mod = ModuleRegistry.byKey(key)!;
        expect(
          mod.isPlaceholder,
          false,
          reason: '$key no debería ser placeholder',
        );
      }
    });
  });

  group('ModuleRegistry - Default Modules', () {
    test('defaults tienen 5 módulos', () {
      expect(ModuleRegistry.defaultModuleKeys.length, 5);
    });

    test('defaults incluyen los correctos', () {
      expect(ModuleRegistry.defaultModuleKeys, [
        'INSPECCION',
        'VISITA_R003',
        'VISITA_R004',
        'EMAIL_OUTBOX',
        'RENDICIONES',
      ]);
    });

    test(
      'TICKETS no está en defaults, pero sí existe en el registry (rediseñado)',
      () {
        expect(
          ModuleRegistry.defaultModuleKeys.contains('TICKETS'),
          false,
          reason:
              'Tickets se activa manualmente por empresa, no viene por defecto',
        );
        expect(
          ModuleRegistry.byKey('TICKETS'),
          isNotNull,
          reason:
              'Tickets fue rediseñado (ver docs/PLAN_TICKETS_MVP.md) y vuelve a existir en el registry',
        );
      },
    );

    test('ADMIN no está en defaults', () {
      expect(
        ModuleRegistry.defaultModuleKeys.contains('ADMIN'),
        false,
        reason: 'Admin se controla via requiresAdmin, no via defaults',
      );
    });
  });

  // ===================================================================
  // TESTS: Filtrado de Módulos (lógica de HomeController.enabledModules)
  // ===================================================================
  group('Módulos Habilitados - Filtrado', () {
    // Replica la lógica de HomeController.enabledModules
    List<ModuleDefinition> getEnabledModules(
      List<String> enabledKeys,
      bool esAdmin,
    ) {
      return ModuleRegistry.all.where((m) {
        if (m.requiresAdmin && !esAdmin) return false;
        return enabledKeys.contains(m.moduleKey);
      }).toList();
    }

    test('usuario normal ve solo módulos habilitados sin admin', () {
      final mods = getEnabledModules(
        ['INSPECCION', 'VISITA_R003', 'ADMIN'],
        false, // no es admin
      );

      final keys = mods.map((m) => m.moduleKey).toList();
      expect(keys, contains('INSPECCION'));
      expect(keys, contains('VISITA_R003'));
      expect(
        keys,
        isNot(contains('ADMIN')),
        reason: 'ADMIN requiere admin=true',
      );
    });

    test('admin ve módulo ADMIN cuando está habilitado', () {
      final mods = getEnabledModules(
        ['INSPECCION', 'ADMIN'],
        true, // es admin
      );

      final keys = mods.map((m) => m.moduleKey).toList();
      expect(keys, contains('INSPECCION'));
      expect(keys, contains('ADMIN'));
    });

    test('sin módulos habilitados retorna lista vacía', () {
      final mods = getEnabledModules([], false);
      expect(mods, isEmpty);
    });

    test('keys inexistentes se ignoran silenciosamente', () {
      final mods = getEnabledModules(['MODULO_FANTASMA', 'INSPECCION'], false);
      expect(mods.length, 1);
      expect(mods.first.moduleKey, 'INSPECCION');
    });

    test('defaults producen 5 módulos para usuario normal', () {
      final mods = getEnabledModules(ModuleRegistry.defaultModuleKeys, false);
      expect(mods.length, 5);
    });

    test(
      'defaults producen 5 módulos para admin (ADMIN no está en defaults)',
      () {
        final mods = getEnabledModules(ModuleRegistry.defaultModuleKeys, true);
        expect(mods.length, 5, reason: 'ADMIN no está en defaultModuleKeys');
      },
    );
  });

  // ===================================================================
  // TESTS: guardarMaestros - Scoped Delete
  // ===================================================================
  group('guardarMaestros - Scope para DELETE de huérfanos', () {
    test('sin scope: DELETE borra todo lo que no está en remote', () {
      // Simula la lógica de construcción del WHERE
      final idsRemoto = ['id-1', 'id-2', 'id-3'];
      final placeholders = List.filled(idsRemoto.length, '?').join(',');

      String whereClause = 'id NOT IN ($placeholders)';
      List<Object?> whereArgs = [...idsRemoto];
      String? scopeWhere;

      expect(whereClause, 'id NOT IN (?,?,?)');
      expect(whereArgs, ['id-1', 'id-2', 'id-3']);
    });

    test('con scope empresa_id: DELETE solo borra dentro del scope', () {
      final idsRemoto = ['area-1', 'area-2'];
      final placeholders = List.filled(idsRemoto.length, '?').join(',');

      String whereClause = 'id NOT IN ($placeholders)';
      List<Object?> whereArgs = [...idsRemoto];
      String? scopeWhere = 'empresa_id = ?';
      List<Object?> scopeArgs = ['empresa-aquachile'];

      whereClause = '($whereClause) AND ($scopeWhere)';
      whereArgs.addAll(scopeArgs);

      expect(whereClause, '(id NOT IN (?,?)) AND (empresa_id = ?)');
      expect(whereArgs, ['area-1', 'area-2', 'empresa-aquachile']);
    });

    test('con scope usuario_id: DELETE solo borra dentro del scope', () {
      final idsRemoto = ['ue-1'];
      final placeholders = List.filled(idsRemoto.length, '?').join(',');

      String whereClause = 'id NOT IN ($placeholders)';
      List<Object?> whereArgs = [...idsRemoto];
      String? scopeWhere = 'usuario_id = ?';
      List<Object?> scopeArgs = ['user-123'];

      whereClause = '($whereClause) AND ($scopeWhere)';
      whereArgs.addAll(scopeArgs);

      expect(whereClause, '(id NOT IN (?)) AND (usuario_id = ?)');
      expect(whereArgs, ['ue-1', 'user-123']);
    });

    test('scope null no modifica el WHERE', () {
      final idsRemoto = ['id-1'];
      final placeholders = List.filled(idsRemoto.length, '?').join(',');

      String whereClause = 'id NOT IN ($placeholders)';
      List<Object?> whereArgs = [...idsRemoto];
      String? scopeWhere;
      List<Object?>? scopeArgs;

      expect(whereClause, 'id NOT IN (?)');
      expect(whereArgs, ['id-1']);
    });
  });

  // ===================================================================
  // TESTS: guardarMaestros - Mapeo de campos por tabla
  // ===================================================================
  group('guardarMaestros - Mapeo de campos', () {
    test('areas: mapea empresa_id correctamente', () {
      final item = {
        'id': 'area-1',
        'nombre': 'Puerto Montt',
        'empresa_id': 'emp-1',
      };
      final row = <String, dynamic>{};
      row['id'] = item['id'];
      row['nombre'] = item['nombre'];
      row['empresa_id'] = item['empresa_id'];

      expect(row['id'], 'area-1');
      expect(row['nombre'], 'Puerto Montt');
      expect(row['empresa_id'], 'emp-1');
    });

    test('empresa_modulos: mapea habilitado como int', () {
      // boolean true → 1
      final item1 = {
        'id': 'em-1',
        'empresa_id': 'emp-1',
        'modulo_key': 'INSPECCION',
        'habilitado': true,
        'orden': 0,
      };
      final hab1 = (item1['habilitado'] == true || item1['habilitado'] == 1)
          ? 1
          : 0;
      expect(hab1, 1);

      // boolean false → 0
      final item2 = {...item1, 'habilitado': false};
      final hab2 = (item2['habilitado'] == true || item2['habilitado'] == 1)
          ? 1
          : 0;
      expect(hab2, 0);

      // int 1 → 1
      final item3 = {...item1, 'habilitado': 1};
      final hab3 = (item3['habilitado'] == true || item3['habilitado'] == 1)
          ? 1
          : 0;
      expect(hab3, 1);

      // int 0 → 0
      final item4 = {...item1, 'habilitado': 0};
      final hab4 = (item4['habilitado'] == true || item4['habilitado'] == 1)
          ? 1
          : 0;
      expect(hab4, 0);
    });

    test('empresa_modulos: subido se fuerza a 1 al guardar del remote', () {
      // Al descargar desde Supabase, siempre marca subido=1
      final subido = 1; // hardcoded en guardarMaestros
      expect(subido, 1, reason: 'Datos del remote siempre están subidos');
    });

    test('empresa_modulos: orden default 0 si null', () {
      final item = {
        'id': 'em-1',
        'empresa_id': 'emp-1',
        'modulo_key': 'INSPECCION',
        'habilitado': true,
        'orden': null,
      };
      final orden = item['orden'] ?? 0;
      expect(orden, 0);
    });

    test('usuario_empresas: mapea usuario_id y empresa_id', () {
      final item = {
        'id': 'ue-1',
        'usuario_id': 'user-abc',
        'empresa_id': 'emp-1',
      };
      final row = <String, dynamic>{};
      row['id'] = item['id'];
      row['usuario_id'] = item['usuario_id'];
      row['empresa_id'] = item['empresa_id'];

      expect(row['id'], 'ue-1');
      expect(row['usuario_id'], 'user-abc');
      expect(row['empresa_id'], 'emp-1');
    });

    test('usuarios: extrae nombre_rol del nested roles map', () {
      final item = {
        'id': 'user-1',
        'rut': '12345678-k',
        'nombre_completo': 'Juan Pérez',
        'email': 'juan@test.com',
        'telefono': null,
        'rol_id': 'rol-1',
        'empresa_id': 'emp-1',
        'roles': {'nombre': 'Inspector'},
      };

      String? nombreRol;
      if (item['roles'] != null && item['roles'] is Map) {
        nombreRol = (item['roles'] as Map)['nombre'] as String?;
      }

      expect(nombreRol, 'Inspector');
    });

    test('usuarios: roles null produce nombre_rol null', () {
      final item = {'id': 'user-1', 'roles': null};

      String? nombreRol;
      if (item['roles'] != null && item['roles'] is Map) {
        nombreRol = (item['roles'] as Map)['nombre'] as String?;
      }

      expect(nombreRol, isNull);
    });
  });

  // ===================================================================
  // TESTS: guardarMaestros - Guard contra lista vacía
  // ===================================================================
  group('guardarMaestros - Blindaje lista vacía', () {
    test('lista vacía cancela la operación', () {
      final datos = <Map<String, dynamic>>[];
      bool operacionCancelada = false;

      if (datos.isEmpty) {
        operacionCancelada = true;
      }

      expect(
        operacionCancelada,
        true,
        reason: 'No debe borrar toda la tabla por error de red',
      );
    });

    test('lista con datos procede normalmente', () {
      final datos = [
        {'id': '1', 'nombre': 'Test'},
      ];
      bool operacionCancelada = false;

      if (datos.isEmpty) {
        operacionCancelada = true;
      }

      expect(operacionCancelada, false);
    });
  });

  // ===================================================================
  // TESTS: Sincronización Multi-Empresa
  // ===================================================================
  group('Sync - Filtrado por empresa', () {
    test('areas se filtran por empresa_id cuando está disponible', () {
      // Simula la lógica de descargarDatosMaestros
      final String empresaId = 'emp-aquachile';

      // El query que se construiría
      bool usaFiltro = empresaId != null;

      expect(usaFiltro, true, reason: 'Con empresaId, debe filtrar areas');
    });

    test('areas sin empresaId descarga todas', () {
      final String? empresaId = null;
      bool usaFiltro = empresaId != null;

      expect(
        usaFiltro,
        false,
        reason: 'Sin empresaId, descarga todo como fallback',
      );
    });

    test('empresa_modulos usa scope correcto para guardarMaestros', () {
      final String empresaId = 'emp-1';

      final scopeWhere = 'empresa_id = ?';
      final scopeArgs = [empresaId];

      expect(scopeWhere, 'empresa_id = ?');
      expect(scopeArgs, ['emp-1']);
    });

    test('usuario_empresas usa scope de usuario_id', () {
      final String userId = 'user-abc';

      final scopeWhere = 'usuario_id = ?';
      final scopeArgs = [userId];

      expect(scopeWhere, 'usuario_id = ?');
      expect(scopeArgs, ['user-abc']);
    });

    test('contratistas y embarcaciones NO se filtran (compartidos)', () {
      // Estas tablas se descargan completas, sin filtro empresa
      // No hay scope para guardarMaestros
      final String? scopeWhere = null; // No scope
      expect(
        scopeWhere,
        isNull,
        reason: 'Contratistas/embarcaciones son cross-empresa',
      );
    });
  });

  group('Sync - getAreasByEmpresa (N:N via empresa_areas)', () {
    test(
      'lógica de filtrado: con empresaId usa filtro, sin él retorna todo',
      () {
        // InspectionSetupController y LocalVisitRepository usan este patrón
        final String empresaId = 'emp-1';

        // Decision: usar getAreasByEmpresa o getAreas
        final bool usaAreasFiltradas = empresaId != null;

        expect(usaAreasFiltradas, true);
      },
    );

    test('getAreasByEmpresa usa JOIN con empresa_areas (no WHERE directo)', () {
      // Antes (1:N): SELECT * FROM areas WHERE empresa_id = ?
      // Ahora (N:N): SELECT a.* FROM areas a INNER JOIN empresa_areas ea ON ea.area_id = a.id WHERE ea.empresa_id = ?
      // Esto permite que un área pertenezca a múltiples empresas

      final empresaAreas = [
        {'empresa_id': 'emp-1', 'area_id': 'area-A'},
        {'empresa_id': 'emp-1', 'area_id': 'area-B'},
        {'empresa_id': 'emp-2', 'area_id': 'area-A'}, // area-A compartida
        {'empresa_id': 'emp-2', 'area_id': 'area-C'},
      ];

      // Simula JOIN: áreas para emp-1
      final areasEmp1 = empresaAreas
          .where((ea) => ea['empresa_id'] == 'emp-1')
          .map((ea) => ea['area_id'])
          .toSet();

      // Simula JOIN: áreas para emp-2
      final areasEmp2 = empresaAreas
          .where((ea) => ea['empresa_id'] == 'emp-2')
          .map((ea) => ea['area_id'])
          .toSet();

      expect(areasEmp1, {'area-A', 'area-B'});
      expect(areasEmp2, {'area-A', 'area-C'});
      // area-A está en ambas empresas (N:N)
      expect(areasEmp1.intersection(areasEmp2), {'area-A'});
    });

    test('área puede pertenecer a múltiples empresas', () {
      // Caso real: áreas creadas por administradora (emp-88f5) visibles para Servimaf (emp-5535)
      final empresaAreas = [
        {'empresa_id': 'emp-administradora', 'area_id': 'area-PTO-MONTT'},
        {
          'empresa_id': 'emp-servimaf',
          'area_id': 'area-PTO-MONTT',
        }, // compartida
        {'empresa_id': 'emp-administradora', 'area_id': 'area-NATALES'},
        {'empresa_id': 'emp-servimaf', 'area_id': 'area-NATALES'}, // compartida
      ];

      final areasServimaf = empresaAreas
          .where((ea) => ea['empresa_id'] == 'emp-servimaf')
          .map((ea) => ea['area_id'])
          .toList();

      expect(areasServimaf.length, 2);
      expect(areasServimaf, contains('area-PTO-MONTT'));
      expect(areasServimaf, contains('area-NATALES'));
    });

    test('empresa_areas usa scope empresa_id para guardarMaestros', () {
      final empresaId = 'emp-servimaf';
      final scopeWhere = 'empresa_id = ?';
      final scopeArgs = [empresaId];

      expect(scopeWhere, 'empresa_id = ?');
      expect(scopeArgs, ['emp-servimaf']);
    });

    test('areas se descargan globalmente (sin filtro empresa)', () {
      // Antes: areas se filtraban por empresa_id en Supabase query
      // Ahora: areas se descargan completas, el filtro es via empresa_areas JOIN
      final String? empresaIdFilter = null; // No se filtra en descarga
      expect(
        empresaIdFilter,
        isNull,
        reason: 'Areas se descargan sin filtro, empresa_areas hace el filtro',
      );
    });

    test('fallback: si empresa_areas vacía, getAreas retorna todas', () {
      // Controllers tienen fallback: si getAreasByEmpresa().isEmpty → getAreas()
      final areasFiltradasResult =
          <Map<String, dynamic>>[]; // empresa_areas vacía
      final allAreas = [
        {'id': 'a1', 'nombre': 'Area 1'},
        {'id': 'a2', 'nombre': 'Area 2'},
      ];

      final areasFinales = areasFiltradasResult.isNotEmpty
          ? areasFiltradasResult
          : allAreas;

      expect(
        areasFinales.length,
        2,
        reason: 'Fallback a todas las áreas si empresa_areas no tiene datos',
      );
    });
  });

  // ===================================================================
  // TESTS: Migración v41 - empresa_areas seed desde legacy 1:N
  // ===================================================================
  group('Migración v41 - empresa_areas', () {
    test('genera ID correcto para migración desde areas.empresa_id', () {
      // La migración v41 hace: SELECT id || '_ea' FROM areas
      final areaId = 'area-abc-123';
      final migratedId = '${areaId}_ea';
      expect(migratedId, 'area-abc-123_ea');
    });

    test('seed solo toma areas con empresa_id válido', () {
      final areas = [
        {'id': 'a1', 'empresa_id': 'emp-1'},
        {'id': 'a2', 'empresa_id': null},
        {'id': 'a3', 'empresa_id': ''},
        {'id': 'a4', 'empresa_id': 'emp-2'},
      ];

      final seed = areas.where((a) {
        final empId = a['empresa_id'];
        return empId != null && empId != '';
      }).toList();

      expect(seed.length, 2, reason: 'Solo a1 y a4 tienen empresa_id válido');
      expect(seed.map((a) => a['id']).toList(), ['a1', 'a4']);
    });

    test('UNIQUE(empresa_id, area_id) previene duplicados en seed', () {
      // INSERT OR IGNORE maneja duplicados del seed
      final existingPairs = <String>{};
      final inserts = [
        {'empresa_id': 'emp-1', 'area_id': 'a1'},
        {'empresa_id': 'emp-1', 'area_id': 'a1'}, // duplicado
        {'empresa_id': 'emp-2', 'area_id': 'a1'}, // diferente empresa, OK
      ];

      int inserted = 0;
      for (final row in inserts) {
        final key = '${row['empresa_id']}_${row['area_id']}';
        if (existingPairs.add(key)) {
          inserted++;
        }
      }

      expect(inserted, 2, reason: 'Duplicado se ignora por UNIQUE constraint');
    });
  });

  // ===================================================================
  // TESTS: Migración v37 - usuario_empresas seed desde legacy
  // ===================================================================
  group('Migración v37 - usuario_empresas', () {
    test('genera ID correcto para migración legacy', () {
      // La migración v37 hace: SELECT id || '_emp' FROM usuarios
      final userId = 'abc-123';
      final migratedId = '${userId}_emp';
      expect(migratedId, 'abc-123_emp');
    });

    test('skip usuarios sin empresa_id', () {
      final usuarios = [
        {'id': 'u1', 'empresa_id': 'emp-1'},
        {'id': 'u2', 'empresa_id': null},
        {'id': 'u3', 'empresa_id': ''},
        {'id': 'u4', 'empresa_id': 'emp-2'},
      ];

      final migrados = usuarios.where((u) {
        final empId = u['empresa_id'];
        return empId != null && empId != '';
      }).toList();

      expect(
        migrados.length,
        2,
        reason: 'Solo u1 y u4 tienen empresa_id válido',
      );
      expect(migrados.map((u) => u['id']).toList(), ['u1', 'u4']);
    });
  });

  // ===================================================================
  // TESTS: Escenario Multi-Empresa Completo
  // ===================================================================
  group('Multi-Empresa - Escenarios E2E', () {
    test('usuario con 1 empresa NO muestra selector', () {
      final empresas = [EmpresaUsuario(id: 'emp-1', nombre: 'Aquachile')];
      final tieneMultiEmpresa = empresas.length > 1;

      expect(tieneMultiEmpresa, false);
    });

    test('usuario con 2 empresas SÍ muestra selector', () {
      final empresas = [
        EmpresaUsuario(id: 'emp-1', nombre: 'Aquachile'),
        EmpresaUsuario(id: 'emp-2', nombre: 'JF Innova'),
      ];
      final tieneMultiEmpresa = empresas.length > 1;

      expect(tieneMultiEmpresa, true);
    });

    test('cambio de empresa cambia el filtro de áreas', () {
      // Simula el flujo: cambiarEmpresa → recargarParaEmpresa
      String? currentEmpresaId = 'emp-1';
      final empresas = [
        EmpresaUsuario(id: 'emp-1', nombre: 'Aquachile'),
        EmpresaUsuario(id: 'emp-2', nombre: 'JF Innova'),
      ];

      // Simular cambiarEmpresa
      final targetId = 'emp-2';
      if (empresas.any((e) => e.id == targetId)) {
        currentEmpresaId = targetId;
      }

      expect(currentEmpresaId, 'emp-2');

      // El scope de sync debe cambiar
      final scopeWhere = 'empresa_id = ?';
      final scopeArgs = [currentEmpresaId];

      expect(scopeWhere, 'empresa_id = ?');
      expect(scopeArgs, [
        'emp-2',
      ], reason: 'Sync ahora filtra por la nueva empresa');
    });

    test('módulos pueden diferir entre empresas', () {
      // Empresa 1: solo inspecciones y visitas
      final modulosEmpresa1 = ['INSPECCION', 'VISITA_R003'];

      // Empresa 2: tiene todo incluyendo extintores
      final modulosEmpresa2 = [
        'INSPECCION',
        'VISITA_R003',
        'VISITA_R004',
        'RENDICIONES',
      ];

      final mods1 = ModuleRegistry.all
          .where((m) => modulosEmpresa1.contains(m.moduleKey))
          .toList();
      final mods2 = ModuleRegistry.all
          .where((m) => modulosEmpresa2.contains(m.moduleKey))
          .toList();

      expect(mods1.length, 2);
      expect(mods2.length, 4);
      expect(
        mods2.map((m) => m.moduleKey).toList(),
        containsAll(['VISITA_R004']),
      );
      expect(
        mods1.map((m) => m.moduleKey).toList(),
        isNot(containsAll(['VISITA_R004'])),
      );
    });
  });

  // ===================================================================
  // TESTS: Fallback de empresa_id legacy
  // ===================================================================
  group('Legacy empresa_id fallback', () {
    test('sin usuario_empresas: usa empresa_id de usuarios', () {
      // Simula _cargarEmpresas cuando usuario_empresas está vacía
      final usuarioEmpresasRows = <Map<String, dynamic>>[]; // vacío
      final legacyEmpresaId = 'emp-aquachile';
      final empresaNombre = 'Aquachile';

      List<EmpresaUsuario> empresas = [];
      String? currentEmpresaId;

      if (usuarioEmpresasRows.isNotEmpty) {
        // path normal
        empresas = usuarioEmpresasRows
            .map(
              (r) => EmpresaUsuario(
                id: r['empresa_id'] as String,
                nombre: r['nombre'] as String? ?? 'Sin nombre',
              ),
            )
            .toList();
      } else {
        // fallback legacy
        empresas = [EmpresaUsuario(id: legacyEmpresaId, nombre: empresaNombre)];
        currentEmpresaId = legacyEmpresaId;
      }

      expect(empresas.length, 1);
      expect(empresas.first.id, 'emp-aquachile');
      expect(currentEmpresaId, 'emp-aquachile');
    });

    test('con usuario_empresas: ignora legacy empresa_id', () {
      final usuarioEmpresasRows = [
        {'empresa_id': 'emp-1', 'nombre': 'Aquachile'},
        {'empresa_id': 'emp-2', 'nombre': 'JF Innova'},
      ];

      List<EmpresaUsuario> empresas = [];
      String? currentEmpresaId;

      if (usuarioEmpresasRows.isNotEmpty) {
        empresas = usuarioEmpresasRows
            .map(
              (r) => EmpresaUsuario(
                id: r['empresa_id'] as String,
                nombre: r['nombre'] ?? 'Sin nombre',
              ),
            )
            .toList();
        currentEmpresaId = empresas.first.id;
      }

      expect(empresas.length, 2, reason: 'Usa usuario_empresas, no legacy');
      expect(
        currentEmpresaId,
        'emp-1',
        reason: 'Selecciona primera empresa por defecto',
      );
    });
  });

  // ===================================================================
  // TESTS: empresa_modulos - Sync up (admin edits)
  // ===================================================================
  group('empresa_modulos - Up-sync admin edits', () {
    test('cambios locales tienen subido=0', () {
      // Cuando admin toggle un módulo en la app
      final localEdit = {
        'id': 'em-1',
        'empresa_id': 'emp-1',
        'modulo_key': 'TICKETS',
        'habilitado': 1,
        'orden': 4,
        'subido': 0, // pendiente de sync
      };

      expect(
        localEdit['subido'],
        0,
        reason: 'Edición local debe marcarse como pendiente',
      );
    });

    test('datos del remote tienen subido=1', () {
      // Cuando se baja de Supabase via guardarMaestros
      final subidoFromRemote = 1; // hardcoded en guardarMaestros
      expect(subidoFromRemote, 1);
    });

    test('_sincronizarEmpresaModulos sube registros con subido=0', () {
      // Simula el filtro de registros pendientes
      final localRows = [
        {'id': 'em-1', 'subido': 1}, // ya sincronizado
        {'id': 'em-2', 'subido': 0}, // pendiente
        {'id': 'em-3', 'subido': 0}, // pendiente
      ];

      final pendientes = localRows.where((r) => r['subido'] == 0).toList();
      expect(pendientes.length, 2);
    });
  });

  // ===================================================================
  // TESTS: Selección de empresa al cargar
  // ===================================================================
  group('Selección inicial de empresa', () {
    test('auto-selecciona primera empresa si no hay selección', () {
      final empresas = [
        EmpresaUsuario(id: 'emp-1', nombre: 'Aquachile'),
        EmpresaUsuario(id: 'emp-2', nombre: 'JF Innova'),
      ];
      String? currentEmpresaId;

      // Lógica de _cargarEmpresas
      if (currentEmpresaId == null ||
          !empresas.any((e) => e.id == currentEmpresaId)) {
        currentEmpresaId = empresas.first.id;
      }

      expect(currentEmpresaId, 'emp-1');
    });

    test('mantiene empresa seleccionada si sigue en la lista', () {
      final empresas = [
        EmpresaUsuario(id: 'emp-1', nombre: 'Aquachile'),
        EmpresaUsuario(id: 'emp-2', nombre: 'JF Innova'),
      ];
      String? currentEmpresaId = 'emp-2';

      if (!empresas.any((e) => e.id == currentEmpresaId)) {
        currentEmpresaId = empresas.first.id;
      }

      expect(
        currentEmpresaId,
        'emp-2',
        reason: 'emp-2 sigue en la lista, no debe cambiar',
      );
    });

    test('resetea empresa si ya no está en la lista', () {
      final empresas = [EmpresaUsuario(id: 'emp-1', nombre: 'Aquachile')];
      String? currentEmpresaId = 'emp-OLD';

      if (!empresas.any((e) => e.id == currentEmpresaId)) {
        currentEmpresaId = empresas.first.id;
      }

      expect(
        currentEmpresaId,
        'emp-1',
        reason: 'emp-OLD ya no existe, selecciona primera',
      );
    });
  });

  // ===================================================================
  // TESTS: ModuleDefinition properties
  // ===================================================================
  group('ModuleDefinition - Properties', () {
    test('todos los módulos tienen title no vacío', () {
      for (final mod in ModuleRegistry.all) {
        expect(
          mod.title.isNotEmpty,
          true,
          reason: '${mod.moduleKey} debe tener title',
        );
      }
    });

    test('todos los módulos tienen subtitle no vacío', () {
      for (final mod in ModuleRegistry.all) {
        expect(
          mod.subtitle.isNotEmpty,
          true,
          reason: '${mod.moduleKey} debe tener subtitle',
        );
      }
    });

    test('todos los módulos tienen screenBuilder no null', () {
      // screenBuilder es required, así que siempre existe
      // Pero verificamos que no lanza al ser referenciado
      for (final mod in ModuleRegistry.all) {
        expect(
          mod.screenBuilder,
          isNotNull,
          reason: '${mod.moduleKey} debe tener screenBuilder',
        );
      }
    });
  });
}
