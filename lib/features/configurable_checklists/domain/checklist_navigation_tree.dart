import 'models/configurable_checklist.dart';

/// Entrada de menu resuelta a partir de [ChecklistNavigationNode]: o un
/// checklist directo, o un grupo con sus checklists hijos ya resueltos.
class ChecklistMenuEntry {
  final String nodeKey;
  final String titulo;
  final String? subtitulo;
  final String? icono;
  final String? color;
  final bool isGroup;
  final ConfigurableChecklist? checklist;
  final List<ConfigurableChecklist> children;

  const ChecklistMenuEntry.single({
    required this.nodeKey,
    required this.titulo,
    this.subtitulo,
    this.icono,
    this.color,
    required this.checklist,
  }) : isGroup = false,
       children = const [];

  const ChecklistMenuEntry.group({
    required this.nodeKey,
    required this.titulo,
    this.subtitulo,
    this.icono,
    this.color,
    required this.children,
  }) : isGroup = true,
       checklist = null;
}

/// Construye el menu de Inicio a partir de los nodos de navegacion de una
/// empresa. Los nodos GROUP sin ningun checklist habilitado/resuelto se
/// omiten para no dejar tarjetas vacias.
List<ChecklistMenuEntry> buildChecklistMenu(
  List<ChecklistNavigationNode> nodes,
  Map<String, ConfigurableChecklist> checklistsByKey,
) {
  final topLevel = nodes.where((n) => n.parentNodeKey == null).toList()
    ..sort((a, b) => a.orden.compareTo(b.orden));
  final entries = <ChecklistMenuEntry>[];

  for (final node in topLevel) {
    if (node.nodeType == 'CHECKLIST') {
      final checklist = checklistsByKey[node.checklistKey];
      if (checklist == null) continue;
      entries.add(
        ChecklistMenuEntry.single(
          nodeKey: node.key,
          titulo: node.titulo,
          subtitulo: checklist.subtitulo,
          icono: node.icono,
          color: node.color,
          checklist: checklist,
        ),
      );
      continue;
    }

    if (node.nodeType == 'GROUP') {
      final children =
          nodes
              .where(
                (n) => n.parentNodeKey == node.key && n.nodeType == 'CHECKLIST',
              )
              .toList()
            ..sort((a, b) => a.orden.compareTo(b.orden));
      final resolved = children
          .map((n) => checklistsByKey[n.checklistKey])
          .whereType<ConfigurableChecklist>()
          .toList();
      if (resolved.isEmpty) continue;
      entries.add(
        ChecklistMenuEntry.group(
          nodeKey: node.key,
          titulo: node.titulo,
          icono: node.icono,
          color: node.color,
          children: resolved,
        ),
      );
    }
  }

  return entries;
}
