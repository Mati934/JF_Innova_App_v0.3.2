import 'dart:convert';

import 'package:path/path.dart' as path;

class AstEvidenceSyncItem {
  const AstEvidenceSyncItem({
    required this.localPath,
    required this.storagePath,
    required this.tipo,
    required this.posicion,
    this.hallazgoId,
  });

  final String localPath;
  final String storagePath;
  final String tipo;
  final int posicion;
  final String? hallazgoId;
}

List<AstEvidenceSyncItem> buildAstEvidenceSyncPlan({
  required String informeId,
  required Object? fotosGeneralesJson,
  required List<Map<String, dynamic>> hallazgos,
}) {
  final items = <AstEvidenceSyncItem>[];
  final generales = _decodePaths(fotosGeneralesJson);

  for (var index = 0; index < generales.length; index++) {
    final localPath = generales[index];
    items.add(
      AstEvidenceSyncItem(
        localPath: localPath,
        storagePath:
            'ast/$informeId/general_${index + 1}${_safeExtension(localPath)}',
        tipo: 'general',
        posicion: index + 1,
      ),
    );
  }

  for (final hallazgo in hallazgos) {
    final localPath = hallazgo['foto_path']?.toString();
    final hallazgoId = hallazgo['id']?.toString();
    if (localPath == null || localPath.isEmpty || hallazgoId == null) continue;
    items.add(
      AstEvidenceSyncItem(
        localPath: localPath,
        storagePath:
            'ast/$informeId/hallazgo_$hallazgoId${_safeExtension(localPath)}',
        tipo: 'hallazgo',
        posicion: (hallazgo['numero'] as num?)?.toInt() ?? 0,
        hallazgoId: hallazgoId,
      ),
    );
  }

  return items;
}

List<String> _decodePaths(Object? value) {
  if (value == null) return const [];
  try {
    final decoded = value is String ? jsonDecode(value) : value;
    if (decoded is! List) return const [];
    return decoded
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
}

String _safeExtension(String localPath) {
  final extension = path.extension(localPath).toLowerCase();
  return const {'.jpg', '.jpeg', '.png', '.webp'}.contains(extension)
      ? extension
      : '.jpg';
}
