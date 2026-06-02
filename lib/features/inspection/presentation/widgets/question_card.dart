import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/models/formulario_item.dart';

// =============================================================================
// QUESTION CARD (Tarjeta de Pregunta Optimizada)
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
  final VoidCallback? onTomarFotoTap;

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
    this.onTomarFotoTap,
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
  void didUpdateWidget(QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincroniza la criticidad SOLO si el prop externo cambió Y el usuario
    // no había hecho una selección propia (es decir, el estado local aún
    // coincide con el prop anterior, no con una selección del usuario).
    if (oldWidget.criticidadInicial != widget.criticidadInicial &&
        _criticidadActual == oldWidget.criticidadInicial) {
      setState(() => _criticidadActual = widget.criticidadInicial);
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
    final tieneInfo =
        (widget.item.infoAdicional != null &&
            widget.item.infoAdicional!.isNotEmpty) ||
        (widget.item.urlImagenReferencia != null &&
            widget.item.urlImagenReferencia!.isNotEmpty);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // Sombra suave para separar tarjetas del fondo
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- CABECERA: Categoría, Info y Foto ---
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              color: const Color(0xFFF1F5F9), // Gris azulado suave
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          widget.item.categoria.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.blueGrey.shade600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        // ICONO DE INFORMACIÓN (Hitbox generosa de 45x40)
                        if (tieneInfo)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _mostrarMensajeInformativo(
                              context,
                              widget.item.infoAdicional ?? '',
                            ),
                            child: Container(
                              width: 45,
                              height: 40,
                              margin: const EdgeInsets.only(left: 4),
                              alignment: Alignment.centerLeft,
                              child: Icon(
                                Icons.info_rounded,
                                color: const Color(
                                  0xFFE2B93B,
                                ).withValues(alpha: 0.9),
                                size: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Botón circular de cámara
                  if (widget.onTomarFotoTap != null)
                    _buildCircularIconButton(
                      icon: widget.fotoInicial != null
                          ? Icons.check_circle
                          : Icons.add_a_photo_rounded,
                      color: widget.fotoInicial != null
                          ? Colors.green
                          : const Color(0xFF003366),
                      onTap: widget.onTomarFotoTap!,
                      hasPhoto: widget.fotoInicial != null,
                    ),
                ],
              ),
            ),

            // --- CUERPO: Pregunta, Foto Preview y Selectores ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.pregunta,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (widget.fotoInicial != null) _buildPhotoPreview(),

                  // Selector de Respuesta
                  Row(
                    children: [
                      _buildModernOption('C', 'CUMPLE', Colors.green.shade600),
                      const SizedBox(width: 8),
                      _buildModernOption(
                        'NC',
                        'NO CUMPLE',
                        Colors.red.shade600,
                      ),
                      const SizedBox(width: 8),
                      _buildModernOption(
                        'N/A',
                        'N/A',
                        Colors.blueGrey.shade400,
                      ),
                    ],
                  ),

                  // --- FOOTER: Comentar y Criticidad ---
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => setState(
                          () => _mostrarObservacion = !_mostrarObservacion,
                        ),
                        icon: Icon(
                          _mostrarObservacion
                              ? Icons.visibility_off_outlined
                              : Icons.comment_bank_outlined,
                          size: 20,
                          color: const Color(0xFF003366),
                        ),
                        label: Text(
                          _mostrarObservacion ? 'Cerrar' : 'Comentar',
                          style: const TextStyle(
                            color: Color(0xFF003366),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (esNC) _buildCriticidadBadge(),
                    ],
                  ),

                  if (_mostrarObservacion) _buildModernTextField(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES PARA MANTENER CLEAN CODE ---

  Widget _buildCircularIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool hasPhoto = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: hasPhoto ? color.withValues(alpha: 0.1) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: hasPhoto ? color : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _buildModernOption(String codigo, String label, Color color) {
    final isSelected = _estadoSeleccionado == codigo;
    return Expanded(
      child: InkWell(
        onTap: () => _seleccionar(codigo),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.blueGrey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.file(
          widget.fotoInicial!,
          fit: BoxFit.cover,
          cacheWidth: 400, // RAM Optimization intocable
        ),
      ),
    );
  }

  Widget _buildCriticidadBadge() {
    // 🟢 HELPER DE COLORES DINÁMICOS (Semáforo)
    Color getColor(String nivel) {
      if (nivel == 'Intolerable') return const Color.fromARGB(255, 222, 68, 7);
      if (nivel == 'Moderado') return const Color.fromARGB(255, 248, 164, 8);
      return const Color.fromARGB(255, 159, 250, 13); // Tolerable
    }

    Color getBgColor(String nivel) {
      if (nivel == 'Intolerable') return Colors.red.shade50;
      if (nivel == 'Moderado') return Colors.orange.shade50;
      return const Color.fromARGB(255, 227, 255, 239); // Tolerable
    }

    // Asegurar que el valor actual sea válido
    final valorSeguro = _nivelesCriticidad.contains(_criticidadActual)
        ? _criticidadActual
        : _nivelesCriticidad[0];

    final colorPrincipal = getColor(valorSeguro);
    final colorFondo = getBgColor(valorSeguro);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorPrincipal.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: DropdownButton<String>(
        value: valorSeguro,
        underline: const SizedBox(),
        icon: Icon(Icons.arrow_drop_down, color: colorPrincipal),
        dropdownColor: Colors.white, // Fondo del menú desplegable
        items: _nivelesCriticidad.map((v) {
          final colorOpcion = getColor(v);
          return DropdownMenuItem(
            value: v,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Un pequeño punto de color al lado de la palabra en la lista
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: colorOpcion,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  v,
                  style: TextStyle(
                    color: colorOpcion,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (v) {
          if (v != null) {
            setState(() => _criticidadActual = v);
            widget.onCriticidadChanged(v);
          }
        },
      ),
    );
  }

  Widget _buildModernTextField() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: _obsController,
        onChanged: widget.onObservacionChanged,
        maxLines: 2,
        decoration: InputDecoration(
          hintText: 'Escribe una observación...',
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  // --- LÓGICA DEL MENSAJE INFORMATIVO FLOTANTE (Optimizado y Moderno) ---
  void _mostrarMensajeInformativo(BuildContext context, String mensaje) {
    final urlImagen = widget.item.urlImagenReferencia;
    final tieneImagen = urlImagen != null && urlImagen.isNotEmpty;

    if (tieneImagen) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 40,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón de cerrar en la esquina superior derecha
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),

                // Imagen centrada con indicador de carga
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        urlImagen,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return SizedBox(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                                color: const Color(0xFFE2B93B),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(
                              height: 120,
                              child: Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white54,
                                  size: 40,
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),
                ),

                // Texto del infoAdicional
                if (mensaje.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Text(
                      mensaje,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        letterSpacing: 0.2,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // Comportamiento original: SnackBar flotante
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.70,
          left: 20,
          right: 20,
        ),
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFE2B93B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mensaje,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
