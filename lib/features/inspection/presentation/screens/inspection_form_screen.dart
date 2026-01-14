import 'package:flutter/material.dart';
import '../../../../shared/services/image_service.dart';
import '../../../../shared/widgets/form_inputs/gallery_input.dart';
import '../controllers/inspection_form_controller.dart';
import '../widgets/question_card.dart';
import '../widgets/category_header.dart';

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
    // 1. Inicializamos el controlador
    _controller = InspectionFormController(
      activityId: widget.activityId,
      tipoActividad: widget.tipoActividad,
      centroId: widget.centroId,
    );

    // 2. Listener Manual para redibujar (Reemplaza al ListenableBuilder)
    // Esto es más seguro porque controlamos exactamente cuándo empieza y termina
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    // Escuchamos cambios del controlador.
    // Si hay mensaje de error, lo mostramos y limpiamos.
    if (_controller.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.errorMessage!),
          backgroundColor: Colors.orange,
        ),
      );
      _controller.clearError();
    }

    // Forzamos el redibujado de la pantalla
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // 3. ORDEN CRÍTICO DE LIMPIEZA
    // Primero dejamos de escuchar (evita el crash _dependents.isEmpty)
    _controller.removeListener(_onControllerUpdate);
    // Luego matamos el controlador
    _controller.dispose();
    super.dispose();
  }

  // Lógica de Finalizar
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
      // YA NO USAMOS ListenableBuilder AQUÍ
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Guardando cambios..."),
          ],
        ),
      );
    }

    final grupos = _controller.agruparPorCategoria();
    final categorias = grupos.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 30),
      itemCount: categorias.length + 1,
      itemBuilder: (context, index) {
        if (index == categorias.length) {
          return _buildFooter();
        }

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
            "Fotos Generales (Opcional)",
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
