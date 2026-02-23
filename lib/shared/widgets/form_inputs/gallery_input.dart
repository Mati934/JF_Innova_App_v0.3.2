import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/image_service.dart'; // Tu servicio existente

class GalleryInput extends StatelessWidget {
  final List<File> images;
  final Function(List<File>) onImagesChanged;
  final bool readOnly;

  const GalleryInput({
    super.key,
    required this.images,
    required this.onImagesChanged,
    this.readOnly = false,
  });

  void _addPhotos(BuildContext context) {
    ImageService.mostrarOpciones(
      context,
      onFotoTomada: (f) {
        onImagesChanged([...images, f]);
      },
      onGaleriaSeleccionada: (files) {
        onImagesChanged([...images, ...files]);
      },
      soloUna: false,
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
        if (!readOnly)
          ElevatedButton.icon(
            onPressed: () => _addPhotos(context),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Agregar Evidencia'),
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
