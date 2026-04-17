import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/services/connectivity_service.dart';
import 'package:jf_innova_app/features/inspection/presentation/widgets/headers/buceo_header_widget.dart';
import '../../../../shared/services/image_service.dart';
import '../../../../shared/widgets/form_inputs/gallery_input.dart';
import '../controllers/inspection_form_controller.dart';
import '../widgets/question_card.dart';
import '../widgets/category_header.dart';
import '../widgets/fotos_observacion_widget.dart';
import '../widgets/headers/inspection_header_factory.dart';

class InspectionFormScreen extends StatefulWidget {
  final String activityId;
  final String tipoActividad;
  final String? nombreCentro;
  final String? centroId;
  final String? numeroInformeInicial;

  const InspectionFormScreen({
    super.key,
    required this.activityId,
    required this.tipoActividad,
    this.nombreCentro,
    this.centroId,
    this.numeroInformeInicial,
  });

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  late final InspectionFormController _controller;
  bool _canPop = false;
  Timer? _timerVerificacion;

  void _onControllerUpdate() {
    if (_controller.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.errorMessage!),
          backgroundColor: Colors.orange,
        ),
      );
      _controller.clearError();
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _controller = InspectionFormController(
      activityId: widget.activityId,
      tipoActividad: widget.tipoActividad,
      centroId: widget.centroId,
    );

    if (widget.numeroInformeInicial != null) {
      _controller.numeroInformeController.text = widget.numeroInformeInicial!;
    }

    // ELIMINADO: _controller.cargarDatosEspecificos() porque ya se llama en el _init() del Controller

    _controller.addListener(_onControllerUpdate);

    _timerVerificacion = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      final texto = _controller.numeroInformeController.text;
      if (texto.isEmpty || texto.startsWith("~")) {
        await _controller.recargarNumeroDesdeDB();
      }
    });
  }

  @override
  void dispose() {
    _timerVerificacion?.cancel();
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _finalizar() async {
    final exito = await _controller.finalizarInspeccion();
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      if (exito) {
        setState(() => _canPop = true);
        Navigator.pop(context);

        final String mensaje;
        final Color color;
        final int duracion;

        if (_controller.errorPdfNoRecuperable) {
          mensaje =
              'Inspeccion guardada sin PDF. Hubo un error generando el informe, contacte soporte si persiste.';
          color = Colors.orange.shade900;
          duracion = 6;
        } else if (_controller.pdfDiferido) {
          mensaje =
              'Inspeccion guardada. El informe PDF se generara automaticamente al recuperar conexion.';
          color = Colors.orange.shade700;
          duracion = 5;
        } else {
          mensaje = 'Inspeccion finalizada y PDF generado correctamente.';
          color = Colors.green;
          duracion = 3;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: color,
            duration: Duration(seconds: duracion),
          ),
        );
      } else {
        // El error ya se muestra via el listener, pero reforzamos con color rojo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _controller.errorMessage ??
                  '❌ No se pudo finalizar. Error interno al guardar datos.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        _controller.clearError();
      }
    }
  }

  void _tomarFoto(String itemId) {
    ImageService.mostrarOpciones(
      context,
      soloUna: true,
      onFotoTomada: (file) => _controller.setFotoPregunta(itemId, file),
      onGaleriaSeleccionada: (files) {
        if (files.isNotEmpty) _controller.setFotoPregunta(itemId, files.first);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      // 1. LE QUITAMOS EL 'async' AQUÍ
      onPopInvoked: (didPop) {
        if (didPop) return;

        // 2. MOSTRAR MENSAJE INSTANTÁNEO
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guardando borrador...'),
            duration: Duration(milliseconds: 1500),
            backgroundColor: Colors.blueGrey,
          ),
        );

        // 3. FIRE AND FORGET: Disparamos el guardado SIN 'await'.
        // Esto manda a SQLite a trabajar sin congelar la UI.
        _controller.guardarBorrador(silent: true);

        // 4. PREPARAMOS LA SALIDA
        setState(() => _canPop = true);

        // 5. SALIDA INMEDIATA: Forzamos la animación de retroceder en el siguiente frame.
        Future.delayed(Duration.zero, () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Mantiene el fondo limpio
        appBar: AppBar(
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.4),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF003366),
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Inspección en Curso',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                widget.nombreCentro ?? 'Ubicación registrada',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey.shade500,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              tooltip: 'Previsualizar PDF',
              onPressed: () => _controller.previsualizarReporte(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildListaPreguntas(),
        ),
      ),
    );
  }

  Widget _buildListaPreguntas() {
    if (_controller.isSaving) {
      return const Center(child: CircularProgressIndicator());
    }

    final grupos = _controller.agruparPorCategoria();
    final categorias = grupos.keys.toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 1. HEADER
        SliverToBoxAdapter(
          child: InspectionHeaderFactory.create(
            widget.tipoActividad,
            _controller,
          ),
        ),

        // 2. DETECTOR DE FALLO DE BASE DE DATOS (Te salvará la vida en desarrollo)
        if (categorias.isEmpty && !_controller.isLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 48,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No hay preguntas descargadas para:\n${widget.tipoActividad}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Sincroniza los datos maestros o revisa la versión de tu BD.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 3. PREGUNTAS (Sin matemáticas raras de índices)
        if (categorias.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final catNombre = categorias[index];
              final items = grupos[catNombre]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CategoryHeader(nombre: catNombre),
                  ...items.map(
                    (item) => QuestionCard(
                      key: ValueKey(item.id),
                      item: item,
                      respuestaInicial: _controller.respuestas[item.id],
                      observacionInicial: _controller.observaciones[item.id],
                      criticidadInicial:
                          _controller.criticidades[item.id] ?? item.criticidad,
                      fotoInicial: _controller.fotosPorPregunta[item.id],
                      onRespuestaChanged: (val) =>
                          _controller.setRespuesta(item.id, val),
                      onObservacionChanged: (val) =>
                          _controller.setObservacion(item.id, val),
                      onCriticidadChanged: (val) =>
                          _controller.setCriticidad(item.id, val),
                      onTomarFotoTap: () => _tomarFoto(item.id),
                    ),
                  ),
                ],
              );
            }, childCount: categorias.length),
          ),

        // 4. VERIFICACIONES DE BUCEO
        if (widget.tipoActividad == 'INSPECCION_BUCEO')
          SliverToBoxAdapter(
            child: BuceoVerificacionesWidget(controller: _controller),
          ),

        // 5. FOOTER
        SliverToBoxAdapter(child: _buildFooter()),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const SizedBox(height: 20),
        FotosConObservacionWidget(controller: _controller),
        const Divider(height: 40),
        const Padding(
          padding: EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            "Fotos Generales",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GalleryInput(
            images: _controller.fotosGenerales,
            onImagesChanged: (newFiles) =>
                _controller.setFotosGenerales(newFiles),
          ),
        ),
        Container(
          margin: const EdgeInsets.all(16),
          width: double.infinity,
          height: 55,
          child: StreamBuilder<bool>(
            stream: ConnectivityService().onStatusChange,
            initialData: ConnectivityService().isOnline,
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? true;
              return ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOnline
                      ? Colors.green.shade700
                      : Colors.green.shade700.withOpacity(0.65),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _finalizar,
                icon: Icon(isOnline ? Icons.check_circle : Icons.cloud_off),
                label: Text(
                  isOnline
                      ? 'FINALIZAR INSPECCIÓN'
                      : 'FINALIZAR (sin conexión)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}
