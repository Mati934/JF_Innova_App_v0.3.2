import 'dart:io';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// =============================================================================
/// HALLAZGO CARD (Tarjeta de Hallazgo reutilizable)
/// =============================================================================
///
/// Tarjeta autocontenida para capturar un hallazgo: número correlativo,
/// título, detalle y una foto de evidencia. Diseñada para reutilizarse en
/// cualquier módulo que necesite registrar observaciones con evidencia,
/// al estilo de `QuestionCard`.
class HallazgoCard extends StatefulWidget {
  /// Número correlativo del hallazgo (1, 2, 3...).
  final int numero;

  final String tituloInicial;
  final String detalleInicial;

  /// Foto de evidencia ya capturada (si existe).
  final File? fotoInicial;

  final ValueChanged<String> onTituloChanged;
  final ValueChanged<String> onDetalleChanged;
  final VoidCallback onTomarFoto;
  final VoidCallback? onQuitarFoto;
  final VoidCallback onEliminar;

  const HallazgoCard({
    super.key,
    required this.numero,
    this.tituloInicial = '',
    this.detalleInicial = '',
    this.fotoInicial,
    required this.onTituloChanged,
    required this.onDetalleChanged,
    required this.onTomarFoto,
    this.onQuitarFoto,
    required this.onEliminar,
  });

  @override
  State<HallazgoCard> createState() => _HallazgoCardState();
}

class _HallazgoCardState extends State<HallazgoCard>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _detalleCtrl;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tituloCtrl = TextEditingController(text: widget.tituloInicial);
    _detalleCtrl = TextEditingController(text: widget.detalleInicial);
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _detalleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tieneFoto = widget.fotoInicial != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            // --- CABECERA: Número + eliminar ---
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              color: const Color(0xFFF1F5F9),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${widget.numero}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'HALLAZGO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.blueGrey.shade600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Eliminar hallazgo',
                    onPressed: widget.onEliminar,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red.shade400,
                    ),
                  ),
                ],
              ),
            ),

            // --- CUERPO ---
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _tituloCtrl,
                    onChanged: widget.onTituloChanged,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Hallazgo',
                      hintText: 'Describe brevemente el hallazgo',
                      prefixIcon: Icon(Icons.warning_amber_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _detalleCtrl,
                    onChanged: widget.onDetalleChanged,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Detalle',
                      hintText: 'Detalle / acción correctiva sugerida',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (tieneFoto) ...[
                    _buildPhotoPreview(),
                    const SizedBox(height: 10),
                  ],

                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: widget.onTomarFoto,
                      icon: Icon(
                        tieneFoto
                            ? Icons.cached_rounded
                            : Icons.add_a_photo_rounded,
                        size: 18,
                      ),
                      label: Text(
                        tieneFoto
                            ? 'Reemplazar evidencia'
                            : 'Agregar evidencia',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryBlue,
                        side: const BorderSide(color: AppTheme.primaryBlue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Image.file(
            widget.fotoInicial!,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            cacheWidth: 600,
          ),
          if (widget.onQuitarFoto != null)
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: widget.onQuitarFoto,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
