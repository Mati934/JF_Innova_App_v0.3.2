/// 📦 **ENTIDAD DE BORRADOR (Draft Entity)**
///
/// Representa una entidad maestra en estado de borrador antes del batch upload.
/// Incluye metadatos para rastrear dependencias y estado temporal.
class DraftEntity {
  final String tempId; // ID temporal único
  final String entityType; // Tipo: 'empresa', 'area', 'centro', etc.
  final Map<String, dynamic> data; // Datos del formulario
  final String? parentTempId; // ID temporal del padre (para FKs)
  final String? parentField; // Campo FK (ejemplo: 'area_id')
  final bool isNew; // Siempre true para batch creation
  final DateTime createdAt; // Timestamp de creación local

  const DraftEntity({
    required this.tempId,
    required this.entityType,
    required this.data,
    this.parentTempId,
    this.parentField,
    this.isNew = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Crea una copia con modificaciones
  DraftEntity copyWith({
    String? tempId,
    String? entityType,
    Map<String, dynamic>? data,
    String? parentTempId,
    String? parentField,
    bool? isNew,
    DateTime? createdAt,
  }) {
    return DraftEntity(
      tempId: tempId ?? this.tempId,
      entityType: entityType ?? this.entityType,
      data: data ?? Map<String, dynamic>.from(this.data),
      parentTempId: parentTempId ?? this.parentTempId,
      parentField: parentField ?? this.parentField,
      isNew: isNew ?? this.isNew,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convierte a Map para inserción en base de datos
  /// Reemplaza IDs temporales por reales usando el mapping
  Map<String, dynamic> toInsertMap(Map<String, String> tempIdMapping) {
    final insertData = Map<String, dynamic>.from(data);

    // Reemplazar FK temporal por real si existe
    if (parentTempId != null && parentField != null) {
      final realParentId = tempIdMapping[parentTempId];
      if (realParentId != null) {
        insertData[parentField!] = realParentId;
      } else {
        throw Exception(
          'No se encontró ID real para dependencia: $parentTempId → $parentField',
        );
      }
    }

    // Remover campos que no van a la BD
    insertData.remove('tempId');
    insertData.remove('entityType');
    insertData.remove('parentTempId');
    insertData.remove('parentField');

    return insertData;
  }

  /// Obtiene el nombre para mostrar en UI
  String get displayName {
    return data['nombre']?.toString() ??
        data['nombre_completo']?.toString() ??
        'Sin nombre';
  }

  /// Verifica si tiene dependencias
  bool get hasParent => parentTempId != null;

  @override
  String toString() {
    return 'DraftEntity(tempId: $tempId, type: $entityType, name: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DraftEntity && other.tempId == tempId;
  }

  @override
  int get hashCode => tempId.hashCode;
}
