import 'package:flutter/material.dart';
import 'package:jf_innova_app/features/inspection/presentation/widgets/headers/buceo_header_widget.dart';
import '../../../../shared/services/image_service.dart';
import '../../../../shared/widgets/form_inputs/gallery_input.dart';
import '../controllers/inspection_form_controller.dart';
import '../widgets/question_card.dart';
import '../widgets/category_header.dart';
// IMPORTANTE: Asegúrate que esta ruta coincida con donde creaste el factory
import '../widgets/headers/inspection_header_factory.dart';

class InspectionFormScreen extends StatefulWidget {
  final String activityId;
  final String tipoActividad;
  final String? nombreCentro;
  final String? centroId;

  const InspectionFormScreen({
    super.key,
    required this.activityId,
    required this.tipoActividad,
    this.nombreCentro,
    this.centroId,
  });

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  late final InspectionFormController _controller;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    _controller = InspectionFormController(
      activityId: widget.activityId,
      tipoActividad: widget.tipoActividad,
      centroId: widget.centroId,
    );
    // IMPORTANTE: Cargamos los datos específicos (Buzos, verificaciones)
    _controller.cargarDatosEspecificos();

    _controller.addListener(_onControllerUpdate);
  }

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
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _finalizar() async {
    final exito = await _controller.finalizarInspeccion();
    if (exito && mounted) {
      setState(() => _canPop = true);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Inspección finalizada.'),
          backgroundColor: Colors.green,
        ),
      );
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
      onPopInvoked: (didPop) async {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guardando borrador...'),
            duration: Duration(milliseconds: 800),
            backgroundColor: Colors.grey,
          ),
        );
        await _controller.guardarBorrador(silent: true);
        if (mounted) {
          setState(() => _canPop = true);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Inspección en Curso', style: TextStyle(fontSize: 16)),
              Text(
                widget.nombreCentro ?? 'Ubicación registrada',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
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

    // TOTAL ITEMS = Header + Categorias + Verificaciones + Footer = N + 3
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 30),
      itemCount: categorias.length + 3,
      itemBuilder: (context, index) {
        // 1. HEADER (POSICIÓN 0): CUADRILLA
        if (index == 0) {
          return InspectionHeaderFactory.create(
            widget.tipoActividad,
            _controller,
          );
        }

        // Ajustamos índice
        final adjustedIndex = index - 1;

        // 2. ITEMS DEL FORMULARIO (POSICIONES INTERMEDIAS)
        if (adjustedIndex < categorias.length) {
          final catNombre = categorias[adjustedIndex];
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
        }

        // 3. VERIFICACIONES CRÍTICAS Y DATOS TÉCNICOS
        if (adjustedIndex == categorias.length) {
          if (widget.tipoActividad == 'INSPECCION_BUCEO') {
            // Como movimos los Datos Técnicos al Header (arriba),
            // aquí abajo SOLO dejamos las Verificaciones Críticas (Estado Faena)
            return BuceoVerificacionesWidget(controller: _controller);
          }
          return const SizedBox.shrink();
        }

        // 4. FOOTER (ÚLTIMO: Fotos Generales y Botón Guardar)
        return _buildFooter();
      },
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
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
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: _finalizar,
            icon: const Icon(Icons.check_circle),
            label: const Text('FINALIZAR INSPECCIÓN'),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}
