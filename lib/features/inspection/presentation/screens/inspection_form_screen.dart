import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/services/connectivity_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/gradient_app_bar.dart';
import 'package:jf_innova_app/features/inspection/presentation/widgets/headers/buceo_header_widget.dart';
import '../../../../shared/services/image_service.dart';
import '../../../../shared/widgets/confirm_finalize_dialog.dart';
import '../../../../shared/widgets/estado_faena_warning_dialog.dart';
import '../../../../shared/widgets/form_inputs/gallery_input.dart';
import '../../../../core/errors/app_error_utils.dart';
import '../controllers/inspection_form_controller.dart';
import '../utils/inspection_error_presentation_state.dart';
import '../widgets/question_card.dart';
import '../widgets/category_header.dart';
import '../widgets/fotos_observacion_widget.dart';
import '../widgets/mandatory_buceo_photos_widget.dart';
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
  final _errorPresentationState = InspectionErrorPresentationState();
  bool _canPop = false;
  Timer? _timerVerificacion;

  void _onControllerUpdate() {
    if (_errorPresentationState.shouldHandleControllerError &&
        _controller.errorMessage != null &&
        mounted) {
      final code = AppErrorUtils.newCode(scope: 'INP');
      unawaited(
        AppErrorUtils.capture(
          Exception(_controller.errorMessage!),
          StackTrace.current,
          scope: 'INP',
          reason: 'InspectionFormScreen._onControllerUpdate',
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        AppErrorUtils.buildErrorSnackBar(
          message: _controller.errorMessage!,
          code: code,
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
    final preview = _controller.estadoFaenaPreview;
    final intolerables = _controller.totalIntolerables;
    final continuar = await showEstadoFaenaWarningDialog(
      context,
      estado: preview.estado,
      aprobada: preview.aprobada,
      detalle: intolerables > 0 && preview.aprobada
          ? 'Hay $intolerables hallazgo(s) intolerable(s) y la faena fue aprobada '
                'manualmente. Este será el estado registrado en el informe.'
          : null,
    );
    if (!continuar || !mounted) return;

    final confirmar = await showConfirmFinalizeDialog(
      context,
      title: 'Finalizar inspección',
      message:
          '¿Estás seguro de finalizar la inspección?\n\n'
          'Una vez finalizada se generará el informe PDF y no podrás volver a editarla.',
    );
    if (!confirmar || !mounted) return;
    _errorPresentationState.beginFinalization();
    final bool exito;
    try {
      exito = await _controller.finalizarInspeccion();
    } finally {
      _errorPresentationState.endFinalization();
    }
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
        final code = AppErrorUtils.newCode(scope: 'INP');
        final message =
            _controller.errorMessage ??
            'No se pudo finalizar. Error interno al guardar datos.';
        ScaffoldMessenger.of(context).showSnackBar(
          AppErrorUtils.buildErrorSnackBar(message: message, code: code),
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
      onPopInvokedWithResult: (didPop, _) {
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
            // ignore: use_build_context_synchronously
            Navigator.of(context).pop();
          }
        });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: GradientAppBar(
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Inspección en Curso',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                widget.nombreCentro ?? 'Ubicación registrada',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Previsualizar PDF',
              onPressed: () => _controller.previsualizarReporte(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          top: false,
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
        const SizedBox(height: 22),
        if (widget.tipoActividad == 'INSPECCION_BUCEO')
          MandatoryBuceoPhotosWidget(controller: _controller),
        if (widget.tipoActividad == 'INSPECCION_BUCEO')
          const SizedBox(height: 12),
        FotosConObservacionWidget(controller: _controller),
        const SizedBox(height: 18),
        // Sección "Fotos Generales"
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.collections_outlined,
                      size: 18,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Fotos Generales',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GalleryInput(
                images: _controller.fotosGenerales,
                onImagesChanged: (newFiles) =>
                    _controller.setFotosGenerales(newFiles),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        // Botón Finalizar con gradiente
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          width: double.infinity,
          height: 56,
          child: StreamBuilder<bool>(
            stream: ConnectivityService().onStatusChange,
            initialData: ConnectivityService().isOnline,
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? true;
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isOnline
                        ? [Colors.green.shade600, Colors.green.shade800]
                        : [Colors.green.shade400, Colors.green.shade600],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _finalizar,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isOnline ? Icons.check_circle : Icons.cloud_off,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isOnline
                                ? 'FINALIZAR INSPECCIÓN'
                                : 'FINALIZAR (sin conexión)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 32 + MediaQuery.of(context).padding.bottom),
      ],
    );
  }
}
