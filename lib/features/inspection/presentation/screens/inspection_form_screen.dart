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
          // --- AQUÍ COMIENZA LO NUEVO: EL BOTÓN PDF ---
          actions: [
            // Solo mostramos el botón si el controlador ya cargó y no está guardando
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              tooltip: 'Previsualizar PDF',
              onPressed: () {
                // Llamamos a la función que creamos en el controlador
                _controller.previsualizarReporte(context);
              },
            ),
            const SizedBox(width: 8), // Un pequeño espacio al final
          ],
          // --- AQUÍ TERMINA LO NUEVO ---
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

    // CAMBIO 1: Aumentamos el total a +4 (Header + Profundidad + Categorías + Verif + Footer)
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 30),
      itemCount: categorias.length + 4,
      itemBuilder: (context, index) {
        // 1. HEADER (POSICIÓN 0) - SE QUEDA IGUAL
        if (index == 0) {
          return InspectionHeaderFactory.create(
            widget.tipoActividad,
            _controller,
          );
        }

        // CAMBIO 2: NUEVO BLOQUE PARA LA PROFUNDIDAD (POSICIÓN 1)
        // Esto hace que aparezca justo debajo del Header
        if (index == 1) {
          if (widget.tipoActividad == 'INSPECCION_BUCEO') {
            return _buildSeccionProfundidad(_controller);
          }
          // Si no es buceo, devolvemos un espacio vacío para no romper el índice
          return const SizedBox.shrink();
        }

        // CAMBIO 3: AJUSTE MATEMÁTICO
        // Antes restabas 1. Ahora restas 2 porque tienes 2 elementos arriba (Header y Profundidad)
        final adjustedIndex = index - 2;

        // 2. ITEMS DEL FORMULARIO (CATEGORÍAS)
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

        // 3. VERIFICACIONES CRÍTICAS (AL FINAL DE LAS CATEGORÍAS)
        if (adjustedIndex == categorias.length) {
          if (widget.tipoActividad == 'INSPECCION_BUCEO') {
            // CAMBIO 4: AQUÍ LO QUITAMOS
            // Ya no llamamos a _buildSeccionProfundidad aquí, solo dejamos las verificaciones
            return BuceoVerificacionesWidget(controller: _controller);
          }
          return const SizedBox.shrink();
        }

        // 4. FOOTER (FOTOS GENERALES Y BOTÓN)
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

  Widget _buildSeccionProfundidad(InspectionFormController controller) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.waves, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  "Parámetros de la Faena",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Nivel de Buceo / Faena',
                border: OutlineInputBorder(),
              ),
              value: controller.verificacionesBuceo?.nivelBuceo,
              items: [
                'Superficie',
                'Básico (20m)',
                'Intermedio (36m)',
                '20m & 36m',
                'No realizada',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) {
                controller.updateVerificacion((v) {
                  v.nivelBuceo = val;
                  if (val == 'Básico (20m)')
                    v.profundidadMaxima = 20;
                  else if (val == 'Intermedio (36m)')
                    v.profundidadMaxima = 36;
                  else
                    v.profundidadMaxima = 0;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              // Clave para que se refresque cuando cambias el dropdown
              key: ValueKey(controller.verificacionesBuceo?.profundidadMaxima),
              initialValue: controller.verificacionesBuceo?.profundidadMaxima
                  ?.toString(),
              decoration: const InputDecoration(
                labelText: 'Profundidad Máxima Alcanzada',
                suffixText: 'metros',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vertical_align_bottom),
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) {
                controller.updateVerificacion((v) {
                  v.profundidadMaxima = int.tryParse(val) ?? 0;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
