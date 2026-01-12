import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart' show XFile; // Solo para guardar

import '../models/formulario_item.dart';
import '../repositories/inspection_repository.dart';
import '../repositories/local_inspection_repository.dart';
import '../services/image_service.dart';

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
  final InspectionRepository _repo = LocalInspectionRepository();

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

  Future<void> _confirmarEliminacion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar Inspección?'),
        content: const Text(
          'Se eliminarán todas las respuestas y fotos de esta sesión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar Definitivamente'),
          ),
        ],
      ),
    );

    if (confirmar == true) await _eliminarActividadYSalir();
  }

  Future<void> _eliminarActividadYSalir() async {
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('actividades')
          .delete()
          .eq('id', widget.activityId)
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint("Error eliminando: $e");
    }
    if (mounted) Navigator.of(context).pop();
  }

  // --- GESTIÓN DE FOTOS CENTRALIZADA ---
  void _gestionarFotos({String? preguntaId}) {
    // Si preguntaId NO es null, significa que es para una pregunta -> SOLO UNA FOTO
    final bool esIndividual = preguntaId != null;

    ImageService.mostrarOpciones(
      context,
      soloUna:
          esIndividual, // <--- AQUÍ LE DECIMOS AL SERVICIO CÓMO COMPORTARSE

      onFotoTomada: (file) {
        setState(() {
          if (preguntaId != null) {
            _fotosPorPregunta[preguntaId] = file;
          } else {
            // Si llegamos aquí desde la cámara general (raro, pero posible), agregamos
            _fotosGenerales.add(file);
          }
        });
      },
      onGaleriaSeleccionada: (files) {
        setState(() {
          if (preguntaId != null) {
            // Si era individual, tomamos solo la primera
            _fotosPorPregunta[preguntaId] = files.first;
          } else {
            // Si es general, agregamos todas
            _fotosGenerales.addAll(files);
          }
        });
      },
    );
  }

  void _removerFotoGeneral(int index) {
    setState(() => _fotosGenerales.removeAt(index));
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
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _onWillPop();
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Inspección en Curso',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Centro de Trabajo: ${widget.nombreCentro ?? "No especificado"}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF003366),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Descartar',
              onPressed: _isSaving ? null : _confirmarEliminacion,
            ),
          ],
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
                                // AQUÍ USAMOS LA FUNCIÓN:
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
        gradient: const LinearGradient(
          colors: [Color(0xFF003366), Color(0xFF00509E)],
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
              const Text(
                '📸 Galería General',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
              ),
              ElevatedButton.icon(
                // null = FOTOS GENERALES = RÁFAGA
                onPressed: () => _gestionarFotos(preguntaId: null),
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Agregar Fotos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Usa el botón para agregar múltiples fotos.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
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
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
    if (_respuestas.length < totalItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Faltan ${totalItems - _respuestas.length} preguntas.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
        Navigator.pop(context);
        Navigator.pop(context);
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
}

// =============================================================================
// QUESTION CARD (Tarjeta de Pregunta)
// =============================================================================
class QuestionCard extends StatefulWidget {
  final FormularioItem item;
  final String? respuestaInicial;
  final String? observacionInicial;
  final String criticidadInicial;
  final File? fotoInicial;

  final Function(String) onRespuestaChanged;
  final Function(String) onObservacionChanged;
  final Function(String) onCriticidadChanged;
  final VoidCallback onTomarFotoTap;

  const QuestionCard({
    super.key,
    required this.item,
    this.respuestaInicial,
    this.observacionInicial,
    required this.criticidadInicial,
    this.fotoInicial,
    required this.onRespuestaChanged,
    required this.onObservacionChanged,
    required this.onCriticidadChanged,
    required this.onTomarFotoTap,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard>
    with AutomaticKeepAliveClientMixin {
  String? _estadoSeleccionado;
  late String _criticidadActual;
  bool _mostrarObservacion = false;
  late TextEditingController _obsController;

  final List<String> _nivelesCriticidad = [
    'Tolerable',
    'Moderado',
    'Intolerable',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _estadoSeleccionado = widget.respuestaInicial;
    _criticidadActual = widget.criticidadInicial;
    _obsController = TextEditingController(text: widget.observacionInicial);
    if (widget.observacionInicial?.isNotEmpty ?? false) {
      _mostrarObservacion = true;
    }
  }

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  void _seleccionar(String estado) {
    setState(() {
      _estadoSeleccionado = estado;
      if (estado == 'NC') _mostrarObservacion = true;
    });
    widget.onRespuestaChanged(estado);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final esNC = _estadoSeleccionado == 'NC';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.pregunta,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onTomarFotoTap,
                  icon: Icon(
                    widget.fotoInicial != null
                        ? Icons.check_circle
                        : Icons.add_a_photo,
                    color: widget.fotoInicial != null
                        ? Colors.green
                        : Colors.blueGrey,
                  ),
                ),
              ],
            ),
            if (widget.fotoInicial != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  height: 100,
                  width: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(widget.fotoInicial!, fit: BoxFit.cover),
                  ),
                ),
              ),
            Row(
              children: [
                _buildOptionBtn('C', 'CUMPLE', Colors.green),
                const SizedBox(width: 8),
                _buildOptionBtn('NC', 'NO CUMPLE', Colors.red),
                const SizedBox(width: 8),
                _buildOptionBtn('N/A', 'N/A', Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => setState(
                    () => _mostrarObservacion = !_mostrarObservacion,
                  ),
                  icon: Icon(
                    _mostrarObservacion ? Icons.expand_less : Icons.add_comment,
                    color: const Color(0xFF003366),
                    size: 18,
                  ),
                  label: Text(
                    _mostrarObservacion ? 'Ocultar' : 'Añadir Comentario',
                    style: const TextStyle(
                      color: Color(0xFF003366),
                      fontSize: 13,
                    ),
                  ),
                ),
                if (esNC)
                  DropdownButton<String>(
                    value: _nivelesCriticidad.contains(_criticidadActual)
                        ? _criticidadActual
                        : _nivelesCriticidad[0],
                    items: _nivelesCriticidad
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(
                              v,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _criticidadActual = v);
                        widget.onCriticidadChanged(v);
                      }
                    },
                  ),
              ],
            ),
            if (_mostrarObservacion)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextField(
                  controller: _obsController,
                  onChanged: widget.onObservacionChanged,
                  decoration: InputDecoration(
                    hintText: esNC ? 'Observación.' : 'Comentario',
                    filled: true,
                    fillColor: esNC ? Colors.red.shade50 : Colors.grey.shade50,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionBtn(String codigo, String label, Color color) {
    final isSelected = _estadoSeleccionado == codigo;
    return Expanded(
      child: GestureDetector(
        onTap: () => _seleccionar(codigo),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
