import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;

// Imports de tu arquitectura
import '../../domain/models/formulario_item.dart';
import '../../domain/repositories/inspection_repository.dart';
import '../../data/repositories/local_inspection_repository.dart';
import 'package:jf_innova_app/shared/services/image_service.dart';
import 'package:jf_innova_app/features/inspection/presentation/widgets/question_card.dart'; // <--- AQUÍ IMPORTAMOS LA TARJETA QUE MOVISTE

class InspectionFormScreen extends StatefulWidget {
  final String activityId;
  final String tipoActividad;
  final String? nombreCentro;

  const InspectionFormScreen({
    super.key,
    required this.activityId,
    required this.tipoActividad,
    this.nombreCentro,
  });

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  // Inyección del repositorio local (Offline-First)
  late final InspectionRepository _repo;

  late Future<List<FormularioItem>> _itemsFuture;

  final Map<String, String> _respuestas = {};
  final Map<String, String> _observaciones = {};
  final Map<String, String> _criticidades = {};

  final Map<String, File> _fotosPorPregunta = {};
  final List<File> _fotosGenerales = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repo = LocalInspectionRepository();
    _itemsFuture = _repo.getItems(widget.tipoActividad);
  }

  Future<bool> _onWillPop() async {
    await _guardarBorradorYSalir();
    return true;
  }

  Future<void> _guardarBorradorYSalir() async {
    setState(() => _isSaving = true);
    try {
      await _persistirDatosEnLocalAdaptado();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('💾 Progreso guardado en borrador.')),
        );
      }
    } catch (e) {
      debugPrint("Error guardando borrador: $e");
    }
  }

  // --- GESTIÓN DE FOTOS ---
  void _gestionarFotos({String? preguntaId}) {
    final bool esIndividual = preguntaId != null;

    ImageService.mostrarOpciones(
      context,
      soloUna: esIndividual,
      onFotoTomada: (file) {
        setState(() {
          if (preguntaId != null) {
            _fotosPorPregunta[preguntaId] = file;
          } else {
            _fotosGenerales.add(file);
          }
        });
      },
      onGaleriaSeleccionada: (files) {
        setState(() {
          if (preguntaId != null) {
            _fotosPorPregunta[preguntaId] = files.first;
          } else {
            _fotosGenerales.addAll(files);
          }
        });
      },
    );
  }

  void _removerFotoGeneral(int index) {
    setState(() => _fotosGenerales.removeAt(index));
  }

  // --- LOGICA DE GUARDADO ---
  Future<void> _persistirDatosEnLocalAdaptado() async {
    List<Map<String, dynamic>> loteRespuestas = [];

    for (var entry in _respuestas.entries) {
      final itemId = entry.key;

      if (_fotosPorPregunta.containsKey(itemId)) {
        await _repo.saveFoto(
          activityId: widget.activityId,
          itemId: itemId,
          file: XFile(_fotosPorPregunta[itemId]!.path),
          descripcion: 'Evidencia item $itemId',
        );
      }

      loteRespuestas.add({
        'actividad_id': widget.activityId,
        'item_id': itemId,
        'estado': entry.value,
        'observacion': _observaciones[itemId],
        'criticidad_registrada': _criticidades[itemId] ?? 'Tolerable',
      });
    }

    await _repo.saveRespuestasBatch(loteRespuestas);

    for (var file in _fotosGenerales) {
      await _repo.saveFoto(
        activityId: widget.activityId,
        itemId: null,
        file: XFile(file.path),
        descripcion: 'Foto General',
      );
    }
  }

  Future<void> _finalizarInspeccion(int totalItems) async {
    // 1. Validar que todo esté respondido
    if (_respuestas.length < totalItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Faltan ${totalItems - _respuestas.length} preguntas.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Validar comentarios obligatorios en NC
    for (var entry in _respuestas.entries) {
      if (entry.value == 'NC') {
        if ((_observaciones[entry.key] ?? '').trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ Comentario obligatorio en respuestas NO CUMPLE.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);
    try {
      await _persistirDatosEnLocalAdaptado();

      if (mounted) {
        // --- AQUÍ ESTABA EL ERROR DE PANTALLA NEGRA ---
        Navigator.pop(context); // Solo 1 pop para volver al Dashboard

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Guardado exitosamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, List<FormularioItem>> _agruparPorCategoria(
    List<FormularioItem> items,
  ) {
    final Map<String, List<FormularioItem>> agrupados = {};
    for (var item in items) {
      if (!agrupados.containsKey(item.categoria)) {
        agrupados[item.categoria] = [];
      }
      agrupados[item.categoria]!.add(item);
    }
    return agrupados;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        // Sin backgroundColor hardcodeado, usa el del tema
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Inspección en Curso',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Centro: ${widget.nombreCentro ?? "No especificado"}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: _isSaving
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<List<FormularioItem>>(
                  future: _itemsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Sin items.'));
                    }

                    final totalItems = snapshot.data!.length;
                    final grupos = _agruparPorCategoria(snapshot.data!);
                    final categorias = grupos.keys.toList();

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: categorias.length + 1,
                      itemBuilder: (context, index) {
                        if (index == categorias.length) {
                          return Column(
                            children: [
                              _buildGeneralGallerySection(),
                              _buildBottomBar(totalItems),
                            ],
                          );
                        }
                        final catNombre = categorias[index];
                        final items = grupos[catNombre]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCategoryHeader(catNombre),
                            ...items.map(
                              (item) => QuestionCard(
                                key: ValueKey(item.id),
                                item: item,
                                respuestaInicial: _respuestas[item.id],
                                observacionInicial: _observaciones[item.id],
                                criticidadInicial:
                                    _criticidades[item.id] ?? item.criticidad,
                                fotoInicial: _fotosPorPregunta[item.id],
                                onRespuestaChanged: (v) =>
                                    setState(() => _respuestas[item.id] = v),
                                onObservacionChanged: (v) =>
                                    _observaciones[item.id] = v,
                                onCriticidadChanged: (v) =>
                                    setState(() => _criticidades[item.id] = v),
                                onTomarFotoTap: () =>
                                    _gestionarFotos(preguntaId: item.id),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String nombre) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 20, 10, 5),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
        // Usamos colores del tema o gradiente suave
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_open, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nombre.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralGallerySection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📸 Galería General',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _gestionarFotos(preguntaId: null),
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Agregar Fotos'),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (_fotosGenerales.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _fotosGenerales.length,
              itemBuilder: (context, index) {
                final file = _fotosGenerales[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(file, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _removerFotoGeneral(index),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(int totalItems) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 55),
          backgroundColor: Colors.green.shade700,
        ),
        onPressed: () => _finalizarInspeccion(totalItems),
        icon: const Icon(Icons.check_circle, color: Colors.white),
        label: const Text(
          'FINALIZAR INSPECCIÓN',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
