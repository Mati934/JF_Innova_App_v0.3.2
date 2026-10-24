import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/image_service.dart'; // Tu servicio existente

class GalleryInput extends StatelessWidget {
  final List<File> images;
  final Function(List<File>) onImagesChanged;
  final bool readOnly;

  /// Máximo de imágenes permitidas. `null` = sin límite.
  /// Si es `1`, fuerza modo "una sola foto" (cámara devuelve una y reemplaza).
  final int? maxImages;

  const GalleryInput({
    super.key,
    required this.images,
    required this.onImagesChanged,
    this.readOnly = false,
    this.maxImages,
  });

  bool get _alcanzoMaximo =>
      maxImages != null && maxImages != 1 && images.length >= maxImages!;

  void _addPhotos(BuildContext context) {
    final unica = maxImages == 1;
    ImageService.mostrarOpciones(
      context,
      onFotoTomada: (f) {
        if (unica) {
          onImagesChanged([f]);
        } else {
          final restante = maxImages == null
              ? null
              : maxImages! - images.length;
          if (restante != null && restante <= 0) return;
          onImagesChanged([...images, f]);
        }
      },
      onGaleriaSeleccionada: (files) {
        if (unica) {
          if (files.isNotEmpty) onImagesChanged([files.first]);
        } else if (maxImages == null) {
          onImagesChanged([...images, ...files]);
        } else {
          final restante = maxImages! - images.length;
          if (restante <= 0) return;
          onImagesChanged([...images, ...files.take(restante)]);
        }
      },
      soloUna: unica,
    );
  }

  void _removePhoto(int index) {
    final newImages = List<File>.from(images)..removeAt(index);
    onImagesChanged(newImages);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!readOnly && !_alcanzoMaximo)
          ElevatedButton.icon(
            onPressed: () => _addPhotos(context),
            icon: const Icon(Icons.camera_alt),
            label: Text(
              maxImages == 1 && images.isNotEmpty
                  ? 'Reemplazar Foto'
                  : (maxImages == 1 ? 'Agregar Foto' : 'Agregar Evidencia'),
            ),
          ),
        const SizedBox(height: 10),
        if (images.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (ctx, i) => Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 100,
                    // CLEAN CODE: Eliminamos el BoxDecoration con DecorationImage
                    // Usamos ClipRRect e Image.file directo para controlar la decodificación en RAM
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        images[i],
                        fit: BoxFit.cover,
                        cacheWidth: 250, // Decodificación ligera en RAM
                      ),
                    ),
                  ),
                  if (!readOnly)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => _removePhoto(i),
                        child: const CircleAvatar(
                          backgroundColor: Colors.red,
                          radius: 10,
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
