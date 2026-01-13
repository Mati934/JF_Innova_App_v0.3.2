import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/models/formulario_item.dart';

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
