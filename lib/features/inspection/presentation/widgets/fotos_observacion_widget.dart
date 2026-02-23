import 'package:flutter/material.dart';
import 'dart:io';
// Ajusta las rutas a tu proyecto
import '../controllers/inspection_form_controller.dart';
import '../../../../shared/widgets/camera/multi_camera_screen.dart';

class FotosConObservacionWidget extends StatelessWidget {
  final InspectionFormController controller;

  const FotosConObservacionWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CABECERA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.amber,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "FOTOGRAFÍAS CON OBSERVACIÓN",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_a_photo, color: Colors.amber),
                  onPressed: () async {
                    // 1. Recibimos el resultado como un genérico para que Dart no chille
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MultiCameraScreen(),
                      ),
                    );

                    // 2. Parseamos de forma segura de XFile a File
                    if (result != null && result is List) {
                      List<File> nuevasFotos = [];
                      for (var archivo in result) {
                        if (archivo is File) {
                          nuevasFotos.add(archivo);
                        } else {
                          // Si es un XFile, extraemos su ruta y creamos un File nativo
                          nuevasFotos.add(File(archivo.path));
                        }
                      }

                      // 3. Inyectamos a nuestro estado reactivo
                      if (nuevasFotos.isNotEmpty) {
                        controller.agregarFotosConObservacion(nuevasFotos);
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          // LISTA DE FOTOS
          if (controller.fotosConObservacion.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "No hay fotografías adicionales.",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.fotosConObservacion.length,
              itemBuilder: (context, index) {
                final item = controller.fotosConObservacion[index];
                final File file = item['file'];
                final String id = item['id'];

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // MINIATURA
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          file,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          cacheWidth: 200, // Optimización de memoria
                        ),
                      ),
                      const SizedBox(width: 12),

                      // TEXTFIELD OBSERVACIÓN
                      Expanded(
                        child: TextFormField(
                          initialValue: item['observacion'],
                          decoration: const InputDecoration(
                            hintText: "Escriba la observación aquí...",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 3,
                          minLines: 2,
                          style: const TextStyle(fontSize: 13),
                          onChanged: (val) => controller
                              .actualizarTextoFotoObservacion(id, val),
                        ),
                      ),

                      // BOTÓN ELIMINAR
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => controller.eliminarFotoObservacion(id),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
