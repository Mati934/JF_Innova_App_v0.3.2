import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../widget/camera/multi_camera_screen.dart';
import '../../core/config/spanish_delegates.dart';

class ImageService {
  static const Color _brandColor = Color(0xFF003366);

  // Método interno para abrir nuestra cámara personalizada
  static Future<List<File>> _tomarFotosCustom(
    BuildContext context, {
    bool modoUnica = false,
  }) async {
    try {
      final List<XFile>? result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiCameraScreen(modoUnica: modoUnica),
        ),
      );

      if (result != null && result.isNotEmpty) {
        return result.map((x) => File(x.path)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error en Cámara Custom: $e');
      return [];
    }
  }

  // Método para la galería (WeChat Picker)
  static Future<List<File>> _seleccionarGaleria(
    BuildContext context, {
    int max = 20,
  }) async {
    try {
      final List<AssetEntity>? result = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(
          maxAssets: max,
          requestType: RequestType.image,
          themeColor: _brandColor,
          textDelegate: const SpanishAssetPickerTextDelegate(),
        ),
      );

      if (result == null) return [];

      List<File> archivos = [];
      for (var asset in result) {
        final f = await asset.file;
        if (f != null) archivos.add(f);
      }
      return archivos;
    } catch (e) {
      debugPrint('Error en Galería: $e');
      return [];
    }
  }

  // --- MENÚ PRINCIPAL ---
  static void mostrarOpciones(
    BuildContext context, {
    required Function(File) onFotoTomada,
    required Function(List<File>) onGaleriaSeleccionada,
    bool soloUna = false, // Parámetro clave para definir comportamiento
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),

            // OPCIÓN 1: CÁMARA
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.camera_alt, color: _brandColor),
              ),
              // Cambiamos el texto dinámicamente
              title: Text(soloUna ? 'Cámara' : 'Cámara'),
              subtitle: Text(soloUna ? 'Tomar foto' : 'Tomar varias fotos'),
              onTap: () async {
                Navigator.pop(ctx);

                // Llamamos a la cámara pasando el modo
                final files = await _tomarFotosCustom(
                  context,
                  modoUnica: soloUna,
                );

                if (files.isNotEmpty) {
                  if (soloUna) {
                    onFotoTomada(files.first);
                  } else {
                    onGaleriaSeleccionada(files);
                  }
                }
              },
            ),
            const Divider(),

            // OPCIÓN 2: GALERÍA
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.photo_library, color: _brandColor),
              ),
              title: const Text('Galería'),
              subtitle: const Text('Seleccionar existentes'),
              onTap: () async {
                Navigator.pop(ctx);
                // Si es solo una, limitamos la selección a 1
                final files = await _seleccionarGaleria(
                  context,
                  max: soloUna ? 1 : 20,
                );

                if (files.isNotEmpty) {
                  if (soloUna) {
                    onFotoTomada(files.first);
                  } else {
                    onGaleriaSeleccionada(files);
                  }
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
