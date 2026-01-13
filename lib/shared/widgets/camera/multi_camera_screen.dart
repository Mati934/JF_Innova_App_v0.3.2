import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class MultiCameraScreen extends StatefulWidget {
  final bool modoUnica;

  const MultiCameraScreen({super.key, this.modoUnica = false});

  @override
  State<MultiCameraScreen> createState() => _MultiCameraScreenState();
}

class _MultiCameraScreenState extends State<MultiCameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  // Estado del flash
  FlashMode _currentFlashMode = FlashMode.off;

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
      cameras.first,
      ResolutionPreset.medium, // Calidad media para velocidad
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.jpeg
          : ImageFormatGroup.bgra8888,
    );

    _initializeControllerFuture = _controller!.initialize().then((_) {
      if (!mounted) return;
      // 1. IMPORTANTE: Forzamos el flash apagado al iniciar
      _controller!.setFlashMode(FlashMode.off);
      setState(() {});
    });
  }

  // Nuevo método para cambiar el flash
  Future<void> _toggleFlash() async {
    if (_controller == null) return;

    FlashMode newMode;
    if (_currentFlashMode == FlashMode.off) {
      newMode = FlashMode.auto; // O FlashMode.torch si quieres linterna fija
    } else {
      newMode = FlashMode.off;
    }

    await _controller!.setFlashMode(newMode);
    setState(() => _currentFlashMode = newMode);
  }

  IconData _getFlashIcon() {
    switch (_currentFlashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
      case FlashMode.torch:
        return Icons.flash_on;
    }
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
      HapticFeedback.mediumImpact();
      // Al estar el flash en OFF, esto debería ser mucho más rápido
      final image = await _controller!.takePicture();

      _fotosTomadas.add(image);

      if (widget.modoUnica) {
        if (mounted) {
          Navigator.pop(context, _fotosTomadas);
        }
        return;
      }

      setState(() => _isTakingPicture = false);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto #${_fotosTomadas.length} capturada'),
            duration: const Duration(milliseconds: 600),
            backgroundColor: Colors.green.withValues(alpha: 0.8),
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
                // 1. Vista Previa (Ocupa toda la pantalla)
                SizedBox.expand(child: CameraPreview(_controller!)),

                // 2. Botón de Flash (Arriba a la derecha)
                Positioned(
                  top: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: IconButton(
                        onPressed: _toggleFlash,
                        icon: Icon(
                          _getFlashIcon(),
                          color: _currentFlashMode == FlashMode.off
                              ? Colors.white
                              : Colors.yellow,
                          size: 30,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Controles Inferiores
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black45,
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

                            // Botón Check (Confirmar)
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
                              const SizedBox(width: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

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
