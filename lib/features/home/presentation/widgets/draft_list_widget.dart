import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/home_controller.dart';
import '../../../inspection/presentation/screens/inspection_form_screen.dart';

class DraftListWidget extends StatelessWidget {
  final HomeController controller;

  const DraftListWidget({super.key, required this.controller});

  Future<void> _confirmarEliminar(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar Borrador?"),
        content: const Text("Se perderán los datos de esta inspección."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await controller.eliminarBorrador(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        if (controller.isLoadingBorradores) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // CASO 1: Lista Vacía (Solo mostramos el mensaje bonito)
        if (controller.borradores.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(30),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 50,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 10),
                Text(
                  "No tienes inspecciones en curso",
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        // CASO 2: Hay datos (Mostramos Título + Lista)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // El título ahora vive aquí dentro
            const Padding(
              padding: EdgeInsets.only(bottom: 10, left: 4),
              child: Text(
                "📝 Pendientes de subir / Borradores",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.borradores.length,
              itemBuilder: (context, index) {
                final item = controller.borradores[index];

                DateTime fecha;
                try {
                  fecha = DateTime.parse(item['fecha_realizacion']);
                } catch (e) {
                  fecha = DateTime.now();
                }

                final fmtFecha = DateFormat('dd/MM/yyyy HH:mm').format(fecha);
                final centro = item['nombre_centro'] ?? 'Sin centro asignado';

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 2,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: Icon(Icons.edit, color: Colors.orange.shade800),
                    ),
                    title: Text(
                      item['tipo_actividad'] ?? 'Inspección',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text("$centro\n$fmtFecha"),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.grey,
                      ),
                      onPressed: () => _confirmarEliminar(context, item['id']),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InspectionFormScreen(
                            activityId: item['id'],
                            tipoActividad: item['tipo_actividad'],
                            centroId: item['centro_id'],
                            nombreCentro: item['nombre_centro'],
                          ),
                        ),
                      );
                      controller.cargarBorradores();
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
