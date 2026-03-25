import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jf_innova_app/core/theme/app_theme.dart';
import '../../services/master_data_batch_service.dart';
import '../controllers/batch_draft_controller.dart';
import 'master_data_form_modal.dart'; // Ajusta si el modal está en otra subcarpeta

class MasterDataAdminScreen extends StatefulWidget {
  const MasterDataAdminScreen({super.key});

  @override
  State<MasterDataAdminScreen> createState() => _MasterDataAdminScreenState();
}

class _MasterDataAdminScreenState extends State<MasterDataAdminScreen> {
  late final MasterDataBatchService _batchService;
  late final BatchDraftController _batchController;

  @override
  void initState() {
    super.initState();
    // Inyectamos las dependencias reales
    _batchService = MasterDataBatchService();
    _batchController = BatchDraftController(_batchService);
  }

  @override
  void dispose() {
    _batchController.dispose();
    super.dispose();
  }

  void _abrirModalCreacion(TipoFormulario tipo) {
    MasterDataFormModal.show(
      context,
      tipo: tipo,
      batchController: _batchController,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin. Datos Maestros'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: _batchController,
        builder: (context, _) {
          if (_batchController.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay modificaciones pendientes\nEl carrito está vacío.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Banner de estado/errores
              if (_batchController.errorMessage != null)
                Container(
                  color: Colors.red.shade100,
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  child: Text(
                    _batchController.errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Lista del borrador (El DAG)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _batchController.draftItems.length,
                  itemBuilder: (context, index) {
                    final item = _batchController.draftItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.primaryBlue,
                          child: Icon(
                            Icons.edit_document,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.data['nombre'] ?? 'Sin nombre',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Tipo: ${item.entityType.toUpperCase()} | TempID: ${item.tempId}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () =>
                              _batchController.removeEntity(item.tempId),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Botón Subir Batch
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _batchController.isUploading
                        ? null
                        : () async {
                            final success = await _batchController
                                .executeBatchUpload();
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Lote subido exitosamente'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                    icon: _batchController.isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(
                      _batchController.isUploading
                          ? 'Subiendo Lote...'
                          : 'Sincronizar a Supabase',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      // Botón Flotante para elegir qué entidad agregar
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (ctx) => SafeArea(
              child: Wrap(
                children: [
                  const ListTile(
                    title: Text(
                      '¿Qué deseas agregar/modificar?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.business),
                    title: const Text('Empresa'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _abrirModalCreacion(TipoFormulario.empresa);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.location_on),
                    title: const Text('Área'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _abrirModalCreacion(TipoFormulario.area);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.engineering),
                    title: const Text('Contratista'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _abrirModalCreacion(TipoFormulario.contratista);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.directions_boat),
                    title: const Text('Embarcación'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _abrirModalCreacion(TipoFormulario.embarcacion);
                    },
                  ),
                ],
              ),
            ),
          );
        },
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Añadir al Lote'),
      ),
    );
  }
}
