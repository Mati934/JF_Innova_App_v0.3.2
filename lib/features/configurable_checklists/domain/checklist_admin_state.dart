import 'models/configurable_checklist.dart';

/// Un checklist visto desde el panel de administracion: puede existir dos
/// veces en `checklist_navigation_nodes` (como hijo de un grupo y como
/// tarjeta suelta), pero para el administrador es UNA sola cosa que se
/// activa o desactiva.
class ChecklistAdminItem {
  final String checklistKey;
  final String titulo;
  final String? icono;
  final ChecklistNavigationNode? groupedNode;
  final ChecklistNavigationNode? flatNode;

  const ChecklistAdminItem({
    required this.checklistKey,
    required this.titulo,
    this.icono,
    this.groupedNode,
    this.flatNode,
  });

  /// Solo se puede alternar entre agrupado y suelto si existen ambos nodos.
  bool get soportaAgrupacion => groupedNode != null && flatNode != null;

  bool get activoEnBd =>
      (groupedNode?.habilitado ?? false) || (flatNode?.habilitado ?? false);
}

/// Carpeta de administracion: un grupo (si existe) con sus checklists ya
/// deduplicados entre la version agrupada y la suelta.
class ChecklistAdminFamily {
  final String id;
  final String titulo;
  final String? icono;
  final ChecklistNavigationNode? groupNode;
  final List<ChecklistAdminItem> items;

  const ChecklistAdminFamily({
    required this.id,
    required this.titulo,
    this.icono,
    this.groupNode,
    required this.items,
  });

  bool get soportaAgrupacion =>
      groupNode != null && items.any((i) => i.soportaAgrupacion);

  bool get moduloActivoEnBd =>
      (groupNode?.habilitado ?? false) || items.any((i) => i.activoEnBd);

  bool get agrupadoEnBd => groupNode?.habilitado ?? false;
}

/// Estado editable de una carpeta en la pantalla de administracion.
class ChecklistAdminFamilyState {
  final bool moduloActivo;
  final bool agrupado;
  final Map<String, bool> checklistsActivos;

  const ChecklistAdminFamilyState({
    required this.moduloActivo,
    required this.agrupado,
    required this.checklistsActivos,
  });

  factory ChecklistAdminFamilyState.fromFamily(ChecklistAdminFamily family) {
    return ChecklistAdminFamilyState(
      moduloActivo: family.moduloActivoEnBd,
      agrupado: family.agrupadoEnBd,
      checklistsActivos: {
        for (final item in family.items) item.checklistKey: item.activoEnBd,
      },
    );
  }

  ChecklistAdminFamilyState copyWith({
    bool? moduloActivo,
    bool? agrupado,
    Map<String, bool>? checklistsActivos,
  }) {
    return ChecklistAdminFamilyState(
      moduloActivo: moduloActivo ?? this.moduloActivo,
      agrupado: agrupado ?? this.agrupado,
      checklistsActivos: checklistsActivos ?? this.checklistsActivos,
    );
  }
}

/// Agrupa los nodos crudos de una empresa en carpetas de administracion.
///
/// Un checklist que aparece como hijo de un grupo Y como nodo suelto con el
/// mismo `checklist_key` se fusiona en un solo [ChecklistAdminItem]. Los
/// sueltos que no pertenecen a ningun grupo quedan en una carpeta sin
/// `groupNode` (solo se pueden activar/desactivar).
List<ChecklistAdminFamily> buildChecklistAdminFamilies(
  List<ChecklistNavigationNode> nodes,
) {
  final grupos = nodes.where((n) => n.isGroup).toList()
    ..sort((a, b) => a.orden.compareTo(b.orden));
  final checklistNodes = nodes.where((n) => !n.isGroup).toList()
    ..sort((a, b) => a.orden.compareTo(b.orden));
  final sueltos = checklistNodes.where((n) => n.parentNodeKey == null).toList();

  final familias = <ChecklistAdminFamily>[];
  final sueltosUsados = <String>{};

  for (final grupo in grupos) {
    final hijos = checklistNodes
        .where((n) => n.parentNodeKey == grupo.key)
        .toList();
    final items = <ChecklistAdminItem>[];
    for (final hijo in hijos) {
      ChecklistNavigationNode? gemelo;
      for (final suelto in sueltos) {
        if (suelto.checklistKey == hijo.checklistKey &&
            !sueltosUsados.contains(suelto.key)) {
          gemelo = suelto;
          sueltosUsados.add(suelto.key);
          break;
        }
      }
      items.add(
        ChecklistAdminItem(
          checklistKey: hijo.checklistKey ?? hijo.key,
          titulo: hijo.titulo,
          icono: hijo.icono,
          groupedNode: hijo,
          flatNode: gemelo,
        ),
      );
    }
    familias.add(
      ChecklistAdminFamily(
        id: grupo.key,
        titulo: grupo.titulo,
        icono: grupo.icono,
        groupNode: grupo,
        items: items,
      ),
    );
  }

  final huerfanos = sueltos
      .where((n) => !sueltosUsados.contains(n.key))
      .toList();
  if (huerfanos.isNotEmpty) {
    familias.add(
      ChecklistAdminFamily(
        id: '__sueltos__',
        titulo: 'Checklists sin carpeta',
        items: huerfanos
            .map(
              (n) => ChecklistAdminItem(
                checklistKey: n.checklistKey ?? n.key,
                titulo: n.titulo,
                icono: n.icono,
                flatNode: n,
              ),
            )
            .toList(),
      ),
    );
  }

  return familias;
}

/// Traduce el estado de la carpeta a el valor `habilitado` que debe quedar
/// en cada fila de `checklist_navigation_nodes`.
///
/// Reglas: si el modulo esta apagado, todo queda apagado. Si esta encendido
/// y agrupado, se usa el grupo con sus hijos activos y se apagan los sueltos.
/// Si esta encendido y NO agrupado, se apaga el grupo y sus hijos y se
/// encienden los sueltos activos.
Map<String, bool> resolveChecklistNodeStates(
  ChecklistAdminFamily family,
  ChecklistAdminFamilyState state,
) {
  final agrupado = family.soportaAgrupacion && state.agrupado;
  final result = <String, bool>{};

  final groupNode = family.groupNode;
  if (groupNode != null) {
    result[groupNode.key] = state.moduloActivo && agrupado;
  }

  for (final item in family.items) {
    final activo =
        state.moduloActivo &&
        (state.checklistsActivos[item.checklistKey] ?? false);
    final grouped = item.groupedNode;
    final flat = item.flatNode;
    if (grouped != null) {
      result[grouped.key] = activo && agrupado;
    }
    if (flat != null) {
      // Sin nodo agrupado no hay alternativa: el suelto es la unica tarjeta.
      result[flat.key] = grouped == null ? activo : (activo && !agrupado);
    }
  }

  return result;
}
