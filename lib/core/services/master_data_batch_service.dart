import 'dart:collection';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MasterDataBatchService {
  final SupabaseClient supabaseClient;

  MasterDataBatchService(this.supabaseClient);

  /// Topological Sort for Directed Acyclic Graph (DAG)
  List<String> topologicalSort(Map<String, List<String>> graph) {
    final inDegree = <String, int>{};
    final queue = Queue<String>();
    final sorted = <String>[];

    // Initialize in-degree map
    graph.forEach((node, edges) {
      inDegree.putIfAbsent(node, () => 0);
      for (final edge in edges) {
        inDegree[edge] = (inDegree[edge] ?? 0) + 1;
      }
    });

    // Add nodes with in-degree 0 to the queue
    inDegree.forEach((node, degree) {
      if (degree == 0) {
        queue.add(node);
      }
    });

    // Process the graph
    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      sorted.add(node);

      for (final neighbor in graph[node] ?? []) {
        inDegree[neighbor] = inDegree[neighbor]! - 1;
        if (inDegree[neighbor] == 0) {
          queue.add(neighbor);
        }
      }
    }

    // Check for cycles
    if (sorted.length != graph.length) {
      throw Exception('Graph contains a cycle, topological sort not possible.');
    }

    return sorted;
  }

  /// Executes an ordered batch insert into Supabase
  Future<void> executeOrderedBatchInsert(
    Map<String, dynamic> records,
    Map<String, List<String>> dependencies,
  ) async {
    final tempIdMapping = <String, String>{};
    final sortedKeys = topologicalSort(dependencies);

    // Start a transaction
    final transaction = supabaseClient.from('your_table_name');

    try {
      for (final key in sortedKeys) {
        final record = records[key];
        if (record == null) {
          throw Exception('Record for key $key not found.');
        }

        // Replace temporary IDs with real IDs in foreign key fields
        record.forEach((field, value) {
          if (value is String && tempIdMapping.containsKey(value)) {
            record[field] = tempIdMapping[value];
          }
        });

        // Insert the record into Supabase
        final response = await transaction.insert(record).execute();

        if (response.error != null) {
          throw Exception(
            'Failed to insert record for key $key: ${response.error!.message}',
          );
        }

        // Map the temporary ID to the real ID
        final realId = response.data[0]['id'];
        tempIdMapping[key] = realId;
      }
    } catch (e) {
      // Rollback logic (Supabase does not support transactions directly, so handle manually)
      throw Exception('Batch insert failed: $e');
    }
  }
}
