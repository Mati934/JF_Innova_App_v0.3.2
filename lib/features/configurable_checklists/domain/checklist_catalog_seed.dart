/// Catalogo tecnico de los 5 checklists de "Herramientas y Equipos" y las
/// reglas para derivar sus nodos de navegacion por empresa. Se usa tanto
/// desde el SQL de siembra (supabase_seed_checklists_herramientas_grupo_v1.sql)
/// como desde el panel de administracion, para poder habilitarlo a una
/// empresa nueva sin escribir SQL cada vez.
class HerramientasChecklistDef {
  final String checklistKey;
  final String permissionKey;
  final String titulo;
  final String icono;
  final String color;
  final int ordenAgrupado;
  final int ordenSuelto;

  const HerramientasChecklistDef({
    required this.checklistKey,
    required this.permissionKey,
    required this.titulo,
    required this.icono,
    required this.color,
    required this.ordenAgrupado,
    required this.ordenSuelto,
  });
}

const herramientasChecklistCatalog = <HerramientasChecklistDef>[
  HerramientasChecklistDef(
    checklistKey: 'chq_herramientas_manuales',
    permissionKey: 'checklist.chq_herramientas_manuales',
    titulo: 'Herramientas Manuales',
    icono: 'handyman',
    color: '#8D6E63',
    ordenAgrupado: 1,
    ordenSuelto: 51,
  ),
  HerramientasChecklistDef(
    checklistKey: 'chq_soldadora_arco',
    permissionKey: 'checklist.chq_soldadora_arco',
    titulo: 'Soldadora al Arco',
    icono: 'local_fire_department',
    color: '#F9A825',
    ordenAgrupado: 2,
    ordenSuelto: 52,
  ),
  HerramientasChecklistDef(
    checklistKey: 'chq_taladro_destornillador',
    permissionKey: 'checklist.chq_taladro_destornillador',
    titulo: 'Taladro Destornillador',
    icono: 'hardware',
    color: '#546E7A',
    ordenAgrupado: 3,
    ordenSuelto: 53,
  ),
  HerramientasChecklistDef(
    checklistKey: 'chq_esmeril_angular',
    permissionKey: 'checklist.chq_esmeril_angular',
    titulo: 'Esmeril Angular',
    icono: 'construction',
    color: '#455A64',
    ordenAgrupado: 4,
    ordenSuelto: 54,
  ),
  HerramientasChecklistDef(
    checklistKey: 'chq_extension_electrica',
    permissionKey: 'checklist.chq_extension_electrica',
    titulo: 'Extensión Eléctrica',
    icono: 'electrical_services',
    color: '#EF6C00',
    ordenAgrupado: 5,
    ordenSuelto: 55,
  ),
];

/// Mismo criterio usado en el SQL: primeros 8 caracteres hexadecimales del
/// id de la empresa (sin guiones), para que node_key (PK global) no choque
/// entre empresas distintas.
String empresaNodeSuffix(String empresaId) {
  final compact = empresaId.replaceAll('-', '');
  return compact.length <= 8 ? compact : compact.substring(0, 8);
}

/// Filas listas para upsert en checklist_navigation_nodes: 1 grupo + 5 hijos
/// (habilitados) + 5 nodos sueltos equivalentes (deshabilitados), para que
/// el admin elija despues como mostrarlos.
List<Map<String, dynamic>> buildHerramientasNavigationRows(String empresaId) {
  final suffix = empresaNodeSuffix(empresaId);
  final groupKey = 'grp_chq_herramientas_$suffix';
  final rows = <Map<String, dynamic>>[
    {
      'node_key': groupKey,
      'empresa_id': empresaId,
      'parent_node_key': null,
      'node_type': 'GROUP',
      'checklist_key': null,
      'permission_key': 'checklist.grupo_herramientas',
      'titulo': 'Herramientas y Equipos',
      'icono': 'build_circle',
      'color': '#5D4037',
      'orden': 50,
      'habilitado': true,
    },
  ];

  for (final def in herramientasChecklistCatalog) {
    rows.add({
      'node_key': 'nod_${def.checklistKey}_$suffix',
      'empresa_id': empresaId,
      'parent_node_key': groupKey,
      'node_type': 'CHECKLIST',
      'checklist_key': def.checklistKey,
      'permission_key': def.permissionKey,
      'titulo': def.titulo,
      'icono': def.icono,
      'color': def.color,
      'orden': def.ordenAgrupado,
      'habilitado': true,
    });
    rows.add({
      'node_key': 'nod_flat_${def.checklistKey}_$suffix',
      'empresa_id': empresaId,
      'parent_node_key': null,
      'node_type': 'CHECKLIST',
      'checklist_key': def.checklistKey,
      'permission_key': def.permissionKey,
      'titulo': def.titulo,
      'icono': def.icono,
      'color': def.color,
      'orden': def.ordenSuelto,
      'habilitado': false,
    });
  }

  return rows;
}

const herramientasChecklistCapacidades = <String>[
  'ver',
  'crear',
  'editar_borrador',
  'finalizar',
];

List<String> resolveEmpresaUserIds({
  required String empresaId,
  required List<Map<String, dynamic>> legacyUsers,
  required List<Map<String, dynamic>> empresaLinks,
}) {
  final ids = <String>{};
  for (final user in legacyUsers) {
    if (user['empresa_id'] == empresaId && user['id'] != null) {
      ids.add(user['id'].toString());
    }
  }
  for (final link in empresaLinks) {
    if (link['empresa_id'] == empresaId && link['usuario_id'] != null) {
      ids.add(link['usuario_id'].toString());
    }
  }
  return ids.toList()..sort();
}

/// Filas listas para upsert en checklist_permission_grants: le da a cada
/// usuario de la empresa las 4 capacidades sobre los 5 checklists.
List<Map<String, dynamic>> buildHerramientasPermissionGrantRows({
  required String empresaId,
  required List<String> usuarioIds,
}) {
  final rows = <Map<String, dynamic>>[];
  for (final usuarioId in usuarioIds) {
    for (final def in herramientasChecklistCatalog) {
      for (final capacidad in herramientasChecklistCapacidades) {
        rows.add({
          'empresa_id': empresaId,
          'checklist_key': def.checklistKey,
          'usuario_id': usuarioId,
          'capacidad': capacidad,
        });
      }
    }
  }
  return rows;
}
