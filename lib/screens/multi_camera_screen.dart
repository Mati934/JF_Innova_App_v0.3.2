import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class MultiCameraScreen extends StatefulWidget {
  // Si es true, toma una foto y se cierra sola.
  // Si es false, deja tomar varias y hay que darle al check.
  final bool modoUnica;

  const MultiCameraScreen({super.key, this.modoUnica = false});

  @override
  State<MultiCameraScreen> createState() => _MultiCameraScreenState();
}

class _MultiCameraScreenState extends State<MultiCameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  // Lista temporal de fotos en esta sesión
  final List<XFile> _fotosTomadas = [];
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    _iniciarCamara();
  }

  Future<void> _iniciarCamara() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first, // Usa la trasera por defecto
      ResolutionPreset.medium, // Calidad media para no llenar la memoria
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.jpeg
          : ImageFormatGroup.bgra8888,
    );

    _initializeControllerFuture = _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto() async {
    if (_isTakingPicture ||
        _controller == null ||
        !_controller!.value.isInitialized)
      return;

    setState(() => _isTakingPicture = true);

    try {
      HapticFeedback.mediumImpact(); // Vibración
      final image = await _controller!.takePicture();

      _fotosTomadas.add(image);

      // --- LÓGICA DE MODO ÚNICA ---
      if (widget.modoUnica) {
        // Si solo pedimos una, cerramos inmediato devolviendo la foto en una lista
        if (mounted) {
          Navigator.pop(context, _fotosTomadas);
        }
        return;
      }
      // ----------------------------

      setState(() {
        _isTakingPicture = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto #${_fotosTomadas.length} capturada'),
            duration: const Duration(milliseconds: 600),
            backgroundColor: Colors.green.withOpacity(0.8),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error tomando foto: $e");
      setState(() => _isTakingPicture = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _controller != null) {
            return Stack(
              children: [
                // 1. Vista Previa de la Cámara
                Center(child: CameraPreview(_controller!)),

                // 2. Controles (Botones)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black45,
                    // EL SAFE AREA ES CLAVE AQUÍ PARA QUE NO TE TAPE LOS BOTONES
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 30,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Botón Salir / Cancelar
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 30,
                              ),
                              onPressed: () =>
                                  Navigator.pop(context, <XFile>[]),
                            ),

                            // DISPARADOR
                            GestureDetector(
                              onTap: _tomarFoto,
                              child: Container(
                                height: 70,
                                width: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  color: _isTakingPicture
                                      ? Colors.grey
                                      : Colors.white24,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.camera,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),

                            // Botón Finalizar (Solo visible en modo múltiple)
                            if (!widget.modoUnica)
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: Colors.greenAccent,
                                      size: 40,
                                    ),
                                    onPressed: _fotosTomadas.isNotEmpty
                                        ? () => Navigator.pop(
                                            context,
                                            _fotosTomadas,
                                          )
                                        : null,
                                  ),
                                  if (_fotosTomadas.isNotEmpty)
                                    Positioned(
                                      top: -5,
                                      right: -5,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${_fotosTomadas.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            else
                              // Espacio vacío para equilibrar visualmente en modo única
                              const SizedBox(width: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Indicador de carga si está procesando la foto
                if (_isTakingPicture)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
