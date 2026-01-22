import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; // IMPORTANTE
import 'package:path_provider/path_provider.dart'
    as path_provider; // IMPORTANTE
import 'package:path/path.dart' as p; // IMPORTANTE

import '../widgets/camera/multi_camera_screen.dart';
import '../../core/config/spanish_delegates.dart';

class ImageService {
  static const Color _brandColor = Color(0xFF003366);

  // --- LÓGICA DE COMPRESIÓN (NUEVO) ---
  // Clean Code: Separamos la lógica de compresión para reutilizarla
  static Future<File> _comprimirImagen(File file) async {
    try {
      final dir = await path_provider.getTemporaryDirectory();
      // Creamos un path temporal único para la imagen comprimida
      final targetPath = p.join(
        dir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
      );

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70, // Bajar calidad a 70% reduce drásticamente el peso
        minWidth: 1280, // Redimensionar (Full HD o HD suele bastar)
        minHeight: 1280,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        return File(result.path);
      }
      return file; // Si falla la compresión, devolvemos la original (fallback)
    } catch (e) {
      debugPrint('Error comprimiendo imagen: $e');
      return file;
    }
  }

  // --- CÁMARA ---
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
        // Mapeamos y comprimimos en paralelo para eficiencia
        final futures = result.map((x) => _comprimirImagen(File(x.path)));
        return await Future.wait(futures);
      }
      return [];
    } catch (e) {
      debugPrint('Error en Cámara Custom: $e');
      return [];
    }
  }

  // --- GALERÍA ---
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
          // Opcional: Filtro nativo del picker para evitar seleccionar videos pesados por error
          filterOptions: FilterOptionGroup(
            imageOption: const FilterOption(
              sizeConstraint: SizeConstraint(
                ignoreSize: true,
              ), // Cuidado con esto
            ),
          ),
        ),
      );

      if (result == null) return [];

      List<File> archivosComprimidos = [];

      // Procesamos las imágenes seleccionadas
      for (var asset in result) {
        final f = await asset.file;
        if (f != null) {
          // AQUI aplicamos la compresión antes de agregar a la lista final
          final compressed = await _comprimirImagen(f);
          archivosComprimidos.add(compressed);
        }
      }
      return archivosComprimidos;
    } catch (e) {
      debugPrint('Error en Galería: $e');
      return [];
    }
  }

  // --- MENÚ PRINCIPAL (Sin cambios lógicos, solo llamadas) ---
  static void mostrarOpciones(
    BuildContext context, {
    required Function(File) onFotoTomada,
    required Function(List<File>) onGaleriaSeleccionada,
    bool soloUna = false,
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
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.camera_alt, color: _brandColor),
              ),
              title: Text(soloUna ? 'Cámara' : 'Cámara'),
              subtitle: Text(soloUna ? 'Tomar foto' : 'Tomar varias fotos'),
              onTap: () async {
                Navigator.pop(ctx);
                final files = await _tomarFotosCustom(
                  context,
                  modoUnica: soloUna,
                );
                if (files.isNotEmpty) {
                  soloUna
                      ? onFotoTomada(files.first)
                      : onGaleriaSeleccionada(files);
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.photo_library, color: _brandColor),
              ),
              title: const Text('Galería'),
              subtitle: const Text('Seleccionar existentes'),
              onTap: () async {
                Navigator.pop(ctx);
                final files = await _seleccionarGaleria(
                  context,
                  max: soloUna ? 1 : 20,
                );
                if (files.isNotEmpty) {
                  soloUna
                      ? onFotoTomada(files.first)
                      : onGaleriaSeleccionada(files);
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
