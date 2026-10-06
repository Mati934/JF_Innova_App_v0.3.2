import 'dart:collection';

/// 🕸️ **GRAFO DE DEPENDENCIAS (Dependency Graph)**
///
/// Implementa un DAG (Directed Acyclic Graph) para rastrear dependencias padre-hijo
/// y calcular el orden correcto de inserción usando Topological Sort.
class DependencyGraph {
  // Mapas principales del grafo
  final Map<String, String> _nodeTypes = {};           // nodeId -> entityType
  final Map<String, Set<String>> _adjacencyList = {}; // node -> {dependencies}
  final Map<String, Set<String>> _reverseGraph = {};  // node -> {dependents}

  /// 🎯 **AGREGAR NODO AL GRAFO**
  void addNode(String nodeId, String entityType) {
    _nodeTypes[nodeId] = entityType;
    _adjacencyList[nodeId] ??= <String>{};
    _reverseGraph[nodeId] ??= <String>{};
  }

  /// 🔗 **AGREGAR DEPENDENCIA: node DEPENDE DE dependency**
  /// Ejemplo: Centro depende de Área
  void addDependency(String node, String dependency) {
    // Verificar que ambos nodos existan
    if (!_nodeTypes.containsKey(node)) {
      throw Exception('Nodo no existe: $node');
    }
    if (!_nodeTypes.containsKey(dependency)) {
      throw Exception('Nodo dependencia no existe: $dependency');
    }

    // Agregar arista: node -> dependency
    _adjacencyList[node]!.add(dependency);
    _reverseGraph[dependency]!.add(node);
  }

  /// 🗑️ **ELIMINAR NODO Y SUS DEPENDENCIAS**
  void removeNode(String nodeId) {
    if (!_nodeTypes.containsKey(nodeId)) return;

    // Limpiar todas las referencias a este nodo
    for (final dependency in _adjacencyList[nodeId]!) {
      _reverseGraph[dependency]?.remove(nodeId);
    }

    for (final dependent in _reverseGraph[nodeId]!) {
      _adjacencyList[dependent]?.remove(nodeId);
    }

    // Eliminar el nodo completamente
    _nodeTypes.remove(nodeId);
    _adjacencyList.remove(nodeId);
    _reverseGraph.remove(nodeId);
  }

  /// 🧹 **LIMPIAR GRAFO COMPLETO**
  void clear() {
    _nodeTypes.clear();
    _adjacencyList.clear();
    _reverseGraph.clear();
  }

  /// 🔍 **OBTENER DEPENDENCIAS DE UN NODO**
  Set<String> getDependencies(String nodeId) {
    return Set<String>.from(_adjacencyList[nodeId] ?? {});
  }

  /// 🔍 **OBTENER DEPENDIENTES DE UN NODO**
  Set<String> getDependents(String nodeId) {
    return Set<String>.from(_reverseGraph[nodeId] ?? {});
  }

  /// ⚡ **DETECTAR CICLOS USANDO DFS**
  /// Retorna true si hay dependencias circulares
  bool hasCycles() {
    final visited = <String>{};
    final recursionStack = <String>{};

    bool dfsHasCycle(String node) {
      if (recursionStack.contains(node)) return true; // Ciclo detectado
      if (visited.contains(node)) return false;       // Ya procesado

      visited.add(node);
      recursionStack.add(node);

      for (final dependency in _adjacencyList[node]!) {
        if (dfsHasCycle(dependency)) return true;
      }

      recursionStack.remove(node);
      return false;
    }

    // Verificar desde cada nodo no visitado
    for (final nodeId in _nodeTypes.keys) {
      if (!visited.contains(nodeId)) {
        if (dfsHasCycle(nodeId)) return true;
      }
    }

    return false;
  }

  /// 🎯 **ORDENAMIENTO TOPOLÓGICO (Kahn's Algorithm)**
  /// Retorna lista ordenada donde las dependencias aparecen antes que los dependientes
  List<String> topologicalSort() {
    if (hasCycles()) {
      throw Exception('No se puede ordenar: el grafo contiene ciclos');
    }

    // Copiar el grafo para no modificar el original
    final inDegree = <String, int>{};
    final adjListCopy = <String, Set<String>>{};

    // Inicializar in-degree y copia del grafo
    for (final nodeId in _nodeTypes.keys) {
      inDegree[nodeId] = 0;
      adjListCopy[nodeId] = Set<String>.from(_adjacencyList[nodeId]!);
    }

    // Calcular in-degree (cuántas dependencias tiene cada nodo)
    for (final nodeId in _nodeTypes.keys) {
      for (final dependency in adjListCopy[nodeId]!) {
        inDegree[dependency] = (inDegree[dependency] ?? 0) + 1;
      }
    }

    // Cola de nodos sin dependencias (in-degree = 0)
    final queue = Queue<String>();
    for (final nodeId in inDegree.keys) {
      if (inDegree[nodeId] == 0) {
        queue.add(nodeId);
      }
    }

    final result = <String>[];

    // Algoritmo de Kahn
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      result.add(current);

      // Procesar todas las dependencias del nodo actual
      for (final dependency in adjListCopy[current]!) {
        inDegree[dependency] = inDegree[dependency]! - 1;

        // Si el nodo ya no tiene dependencias sin procesar, agregarlo a la cola
        if (inDegree[dependency] == 0) {
          queue.add(dependency);
        }
      }
    }

    // Verificación final: todos los nodos deben estar en el resultado
    if (result.length != _nodeTypes.length) {
      throw Exception('Error en ordenamiento topológico: posible ciclo no detectado');
    }

    return result.reversed.toList(); // Revertir para tener dependencias primero
  }

  /// 📊 **OBTENER ESTADÍSTICAS DEL GRAFO**
  Map<String, dynamic> getStats() {
    final typeCount = <String, int>{};
    for (final type in _nodeTypes.values) {
      typeCount[type] = (typeCount[type] ?? 0) + 1;
    }

    return {
      'totalNodes': _nodeTypes.length,
      'totalEdges': _adjacencyList.values.fold(0, (sum, set) => sum + set.length),
      'nodesByType': typeCount,
      'hasCycles': hasCycles(),
    };
  }

  /// 🎨 **REPRESENTACIÓN TEXTUAL DEL GRAFO**
  String toDotFormat() {
    final buffer = StringBuffer();
    buffer.writeln('digraph DependencyGraph {');
    buffer.writeln('  rankdir=LR;');

    // Nodos con etiquetas
    for (final entry in _nodeTypes.entries) {
      final nodeId = entry.key;
      final type = entry.value;
      buffer.writeln('  "$nodeId" [label="$type\\n$nodeId"];');
    }

    // Aristas (dependencias)
    for (final entry in _adjacencyList.entries) {
      final node = entry.key;
      for (final dependency in entry.value) {
        buffer.writeln('  "$node" -> "$dependency";');
      }
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  /// 🔍 **VALIDAR INTEGRIDAD DEL GRAFO**
  bool isValid() {
    // Verificar que todos los nodos en adjacencyList están en nodeTypes
    for (final nodeId in _adjacencyList.keys) {
      if (!_nodeTypes.containsKey(nodeId)) return false;
    }

    // Verificar que adjacencyList y reverseGraph son consistentes
    for (final entry in _adjacencyList.entries) {
      final node = entry.key;
      for (final dependency in entry.value) {
        if (!_reverseGraph[dependency]!.contains(node)) return false;
      }
    }

    return !hasCycles();
  }

  @override
  String toString() {
    final stats = getStats();
    return 'DependencyGraph(nodes: ${stats['totalNodes']}, '
           'edges: ${stats['totalEdges']}, '
           'hasCycles: ${stats['hasCycles']})';
  }
}