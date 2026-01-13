import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../domain/models/formulario_item.dart';
import '../../domain/repositories/inspection_repository.dart';
import '../../data/repositories/local_inspection_repository.dart';
import '../../../../shared/services/image_service.dart';

// IMPORTA TUS NUEVOS WIDGETS
import '../../../../shared/widgets/form_inputs/gallery_input.dart';
import '../widgets/question_card.dart';

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
  late final InspectionRepository _repo;
  late Future<List<FormularioItem>> _itemsFuture;

  final Map<String, String> _respuestas = {};
  final Map<String, String> _observaciones = {};
  final Map<String, String> _criticidades = {};
  final Map<String, File> _fotosPorPregunta = {};

  // Lista simple para las fotos generales
  List<File> _fotosGenerales = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repo = LocalInspectionRepository();
    _itemsFuture = _repo.getItems(widget.tipoActividad);
  }

  // --- LÓGICA DE FOTOS INDIVIDUALES (Se mantiene aquí por ahora) ---
  void _gestionarFotoPregunta(String preguntaId) {
    ImageService.mostrarOpciones(
      context,
      soloUna: true,
      onFotoTomada: (file) =>
          setState(() => _fotosPorPregunta[preguntaId] = file),
      onGaleriaSeleccionada: (files) {
        if (files.isNotEmpty) {
          setState(() => _fotosPorPregunta[preguntaId] = files.first);
        }
      },
    );
  }

  // --- GUARDADO ---
  Future<void> _persistirDatos() async {
    List<Map<String, dynamic>> loteRespuestas = [];
    for (var entry in _respuestas.entries) {
      final itemId = entry.key;
      // Guardar foto individual si existe
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

    // Guardar fotos generales
    for (var file in _fotosGenerales) {
      await _repo.saveFoto(
        activityId: widget.activityId,
        itemId: null,
        file: XFile(file.path),
        descripcion: 'Foto General',
      );
    }
  }

  Future<void> _guardarBorrador() async {
    setState(() => _isSaving = true);
    await _persistirDatos();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('💾 Borrador guardado.')));
      setState(() => _isSaving = false);
    }
  }

  Future<void> _finalizarInspeccion(int totalItems) async {
    if (_respuestas.length < totalItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Faltan ${totalItems - _respuestas.length} respuestas.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _persistirDatos();
      if (mounted) {
        Navigator.pop(context); // Volver al Home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Inspección finalizada.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Map<String, List<FormularioItem>> _agruparPorCategoria(
    List<FormularioItem> items,
  ) {
    final Map<String, List<FormularioItem>> agrupados = {};
    for (var item in items) {
      if (!agrupados.containsKey(item.categoria))
        agrupados[item.categoria] = [];
      agrupados[item.categoria]!.add(item);
    }
    return agrupados;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inspección en Curso', style: TextStyle(fontSize: 16)),
            Text(
              widget.nombreCentro ?? 'Sin centro',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _guardarBorrador,
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<FormularioItem>>(
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final totalItems = snapshot.data!.length;
                final grupos = _agruparPorCategoria(snapshot.data!);
                final categorias = grupos.keys.toList();

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 30),
                  itemCount: categorias.length + 1, // +1 para la sección final
                  itemBuilder: (context, index) {
                    // SECCIÓN FINAL (Galería y Botón)
                    if (index == categorias.length) {
                      return Column(
                        children: [
                          const Divider(),
                          // AQUÍ USAMOS EL COMPONENTE NUEVO
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GalleryInput(
                              images: _fotosGenerales,
                              onImagesChanged: (newFiles) =>
                                  setState(() => _fotosGenerales = newFiles),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.all(16),
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                              ),
                              onPressed: () => _finalizarInspeccion(totalItems),
                              icon: const Icon(Icons.check_circle),
                              label: const Text('FINALIZAR INSPECCIÓN'),
                            ),
                          ),
                        ],
                      );
                    }

                    // SECCIONES DE PREGUNTAS
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
                                _gestionarFotoPregunta(item.id),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildCategoryHeader(String nombre) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 20, 10, 5),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_open, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(
            nombre.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
