import 'package:flutter/material.dart';
import '../../../admin/presentation/controllers/batch_draft_controller.dart';
import '../../../admin/services/master_data_batch_service.dart';

/// 📋 **EJEMPLO DE USO DEL BATCH DRAFT CONTROLLER**
///
/// Este ejemplo muestra cómo implementar el flujo completo de Master Data Management
/// con estado temporal, dependencias y batch upload transaccional.
class BatchDraftExample extends StatefulWidget {
  @override
  _BatchDraftExampleState createState() => _BatchDraftExampleState();
}

class _BatchDraftExampleState extends State<BatchDraftExample> {
  late BatchDraftController controller;

  @override
  void initState() {
    super.initState();
    final batchService = MasterDataBatchService();
    controller = BatchDraftController(batchService);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// 🏢 **EJEMPLO: Crear Empresa → Área → Centro**
  Future<void> _ejemploEmpresaAreaCentro() async {
    try {
      // 1. Crear Empresa (entidad raíz)
      final empresaTempId = await controller.addEntity(
        entityType: 'empresa',
        data: {'nombre': 'Salmonera del Sur S.A.'},
      );

      // 2. Crear Área que pertenece a Empresa
      final areaTempId = await controller.addEntity(
        entityType: 'area',
        data: {'nombre': 'Cultivo Norte'},
        parentTempId: empresaTempId, // Si se implementa empresa_id en areas
        parentField: 'empresa_id',
      );

      // 3. Crear Centro que pertenece a Área
      await controller.addEntity(
        entityType: 'centro',
        data: {'nombre': 'Centro Punta Arenas'},
        parentTempId: areaTempId,
        parentField: 'area_id',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Empresa → Área → Centro agregados al draft')),
      );
    } catch (e) {
      _mostrarError('Error creando jerarquía: $e');
    }
  }

  /// ⛵ **EJEMPLO: Crear Contratista → Embarcación + Personal**
  Future<void> _ejemploContratistaEmbarcacionPersonal() async {
    try {
      // 1. Crear Contratista (entidad raíz)
      final contratistaTempId = await controller.addEntity(
        entityType: 'contratista',
        data: {'nombre': 'Servicios Marítimos Ltda.'},
      );

      // 2. Crear Embarcación
      await controller.addEntity(
        entityType: 'embarcacion',
        data: {
          'nombre': 'Barcaza Thunder',
          'matricula': 'TH-2024-001',
        },
        parentTempId: contratistaTempId,
        parentField: 'contratista_id',
      );

      // 3. Crear Personal Externo (Buzo)
      await controller.addEntity(
        entityType: 'personal_externo',
        data: {
          'rut': '12.345.678-9',
          'nombre_completo': 'Juan Carlos Mendoza',
          'cargo': 'Buzo Profesional',
          'matricula': 'BP-001-2024',
          'activo': 1,
        },
        parentTempId: contratistaTempId,
        parentField: 'contratista_id',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Contratista → Embarcación + Personal agregados')),
      );
    } catch (e) {
      _mostrarError('Error creando contratista: $e');
    }
  }

  /// 🚀 **EJECUTAR BATCH UPLOAD**
  Future<void> _ejecutarBatchUpload() async {
    if (controller.isEmpty) {
      _mostrarError('No hay elementos en el draft para subir');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('🚀 Batch Upload'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('¿Confirmar subida de ${controller.totalItems} elementos?'),
              SizedBox(height: 16),
              if (controller.isUploading) ...[
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Subiendo...'),
              ],
            ],
          ),
          actions: [
            if (!controller.isUploading) ...[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final success = await controller.executeBatchUpload();
                  Navigator.of(context).pop();

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🎉 Batch upload completado exitosamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    _mostrarError('Batch upload falló: ${controller.errorMessage}');
                  }
                },
                child: Text('Confirmar'),
              ),
            ],
          ],
        );
      },
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Master Data Management'),
        backgroundColor: Colors.blue,
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // === BOTONES DE EJEMPLO ===
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🎯 Ejemplos de Creación',
                             style: Theme.of(context).textTheme.titleLarge),
                        SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: Icon(Icons.business),
                          label: Text('Empresa → Área → Centro'),
                          onPressed: controller.isUploading ? null : _ejemploEmpresaAreaCentro,
                        ),
                        SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: Icon(Icons.directions_boat),
                          label: Text('Contratista → Embarcación + Personal'),
                          onPressed: controller.isUploading ? null : _ejemploContratistaEmbarcacionPersonal,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // === ESTADO ACTUAL ===
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📊 Estado del Draft',
                             style: Theme.of(context).textTheme.titleLarge),
                        SizedBox(height: 12),
                        Text('Total elementos: ${controller.totalItems}'),
                        if (controller.itemsByType.isNotEmpty) ...[
                          SizedBox(height: 8),
                          ...controller.itemsByType.entries.map((entry) =>
                            Text('• ${entry.key}: ${entry.value}')
                          ),
                        ],
                        if (controller.hasErrors) ...[
                          SizedBox(height: 8),
                          Text(
                            '⚠️ ${controller.errorMessage ?? 'Errores de validación'}',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // === LISTA DE ELEMENTOS ===
                if (controller.draftItems.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📋 Elementos en Draft',
                               style: Theme.of(context).textTheme.titleLarge),
                          SizedBox(height: 12),
                          ...controller.draftItems.map((entity) => ListTile(
                            leading: CircleAvatar(
                              child: Text(entity.entityType[0].toUpperCase()),
                              backgroundColor: _getEntityColor(entity.entityType),
                            ),
                            title: Text(entity.displayName),
                            subtitle: Text('${entity.entityType} • ${entity.tempId}'),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: controller.isUploading ? null : () {
                                controller.removeEntity(entity.tempId);
                              },
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                ],

                // === ACCIONES ===
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.upload),
                        label: Text(controller.isUploading ? 'Subiendo...' : 'Batch Upload'),
                        onPressed: (!controller.isEmpty && !controller.isUploading)
                            ? _ejecutarBatchUpload
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.clear_all),
                        label: Text('Limpiar Todo'),
                        onPressed: controller.isEmpty || controller.isUploading ? null : () {
                          controller.clearAllDrafts();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getEntityColor(String entityType) {
    switch (entityType) {
      case 'empresa':
        return Colors.purple;
      case 'area':
        return Colors.blue;
      case 'centro':
        return Colors.green;
      case 'contratista':
        return Colors.orange;
      case 'embarcacion':
        return Colors.cyan;
      case 'personal_externo':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}