import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../shared/services/image_service.dart';
import '../../domain/models/mandatory_buceo_photo_slot.dart';
import '../controllers/inspection_form_controller.dart';

class MandatoryBuceoPhotosWidget extends StatelessWidget {
  final InspectionFormController controller;

  const MandatoryBuceoPhotosWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7FC),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.photo_camera_back_outlined,
                  color: Color(0xFF0059A3),
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FOTOGRAFIAS OBLIGATORIAS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0059A3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: mandatoryBuceoPhotoSlots.map((slot) {
                final photo = controller.mandatoryPhotos[slot.key];
                return _MandatoryPhotoTile(
                  slot: slot,
                  photo: photo,
                  onPick: () => _pickPhoto(context, slot.key),
                  onRemove: photo == null
                      ? null
                      : () => controller.removeMandatoryPhoto(slot.key),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _pickPhoto(BuildContext context, String key) {
    ImageService.mostrarOpciones(
      context,
      soloUna: true,
      onFotoTomada: (file) => controller.setMandatoryPhoto(key, file),
      onGaleriaSeleccionada: (files) {
        if (files.isNotEmpty) {
          controller.setMandatoryPhoto(key, files.first);
        }
      },
    );
  }
}

class _MandatoryPhotoTile extends StatelessWidget {
  final MandatoryBuceoPhotoSlot slot;
  final File? photo;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  const _MandatoryPhotoTile({
    required this.slot,
    required this.photo,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 88,
              height: 88,
              color: const Color(0xFFF3F7FA),
              child: photo == null
                  ? const Icon(
                      Icons.photo_outlined,
                      size: 28,
                      color: Color(0xFF8FBACB),
                    )
                  : Image.file(photo!, fit: BoxFit.cover, cacheWidth: 240),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A2A3D),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onPick,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: Text(
                        photo == null ? 'Agregar foto' : 'Reemplazar',
                      ),
                    ),
                    if (onRemove != null)
                      OutlinedButton.icon(
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Quitar'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
