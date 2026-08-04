import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/image_service.dart';
import '../../domain/models/ticket_item_model.dart';

/// Fila de un [TicketItemModel] dentro del detalle del ticket.
///
/// Dos estilos según el estado:
/// - Pendiente: tarjeta expandida con número + categoría (o ícono de cámara
///   si es una foto con observación), título/observación, foto original y
///   botón para adjuntar la foto de subsanación.
/// - Subsanado: tarjeta compacta pero con evidencia visible para que la etapa
///   de aprobación pueda revisar la foto de subsanación.
class TicketItemTile extends StatelessWidget {
  final TicketItemModel item;
  final bool puedeEditar;
  final bool procesando;
  final Future<void> Function(bool subsanado, File? foto) onCambiar;

  const TicketItemTile({
    super.key,
    required this.item,
    required this.puedeEditar,
    required this.procesando,
    required this.onCambiar,
  });

  bool get _esFoto => item.origenItem == TicketItemOrigen.fotoObservacion;

  Future<void> _onToggle(BuildContext context, bool nuevoValor) async {
    if (!nuevoValor) {
      await onCambiar(false, null);
      return;
    }
    ImageService.mostrarOpciones(
      context,
      soloUna: true,
      onFotoTomada: (file) => onCambiar(true, file),
      onGaleriaSeleccionada: (files) {
        if (files.isNotEmpty) onCambiar(true, files.first);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return item.subsanado ? _buildSubsanado(context) : _buildPendiente(context);
  }

  Widget _buildSubsanado(BuildContext context) {
    final titulo = item.pregunta ?? item.descripcion;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_rounded, size: 16, color: Colors.green.shade700),
              const SizedBox(width: 8),
              if (!_esFoto)
                _NumeroBadge(numero: item.numeroPregunta, subsanado: true)
              else
                Icon(
                  Icons.camera_alt_outlined,
                  size: 15,
                  color: Colors.grey.shade500,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (puedeEditar && !procesando)
                TextButton(
                  onPressed: () => onCambiar(false, null),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                    foregroundColor: Colors.grey.shade600,
                  ),
                  child: const Text('Deshacer', style: TextStyle(fontSize: 11)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Subsanado',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
            ],
          ),
          if (item.descripcion.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.descripcion,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _LabeledThumbnail(label: 'Original', url: item.fotoOriginalUrl),
              const SizedBox(width: 10),
              _LabeledThumbnail(
                label: 'Subsanación',
                url: item.fotoSubsanacionUrl,
                highlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendiente(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!_esFoto) ...[
                _NumeroBadge(numero: item.numeroPregunta),
                const SizedBox(width: 8),
                if (item.categoria != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.categoria!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ] else ...[
                Icon(
                  Icons.camera_alt_outlined,
                  size: 15,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
                Text(
                  'Foto con observación',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
              const Spacer(),
              Text(
                'Pendiente',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(width: 8),
              if (procesando)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: false,
                  activeThumbColor: AppTheme.primaryBlue,
                  onChanged: puedeEditar ? (v) => _onToggle(context, v) : null,
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (!_esFoto)
            Text(
              item.pregunta ?? 'Ítem',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          if (item.descripcion.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.descripcion,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _Thumbnail(url: item.fotoOriginalUrl),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: puedeEditar
                      ? () => _onToggle(context, true)
                      : null,
                  icon: const Icon(Icons.camera_alt_outlined, size: 14),
                  label: const Text(
                    'Foto de subsanación',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumeroBadge extends StatelessWidget {
  final int? numero;
  final bool subsanado;
  const _NumeroBadge({this.numero, this.subsanado = false});

  @override
  Widget build(BuildContext context) {
    final color = subsanado ? Colors.green.shade700 : AppTheme.primaryBlue;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        numero?.toString() ?? '–',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? url;
  const _Thumbnail({this.url});

  void _abrirEnGrande(BuildContext context) {
    if (url == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, _, _) => _FullScreenPhotoViewer(url: url!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: url != null ? () => _abrirEnGrande(context) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: url != null
              ? Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholder(),
                )
              : _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: Colors.grey.shade100,
    child: Icon(Icons.photo_outlined, color: Colors.grey.shade400),
  );
}

class _LabeledThumbnail extends StatelessWidget {
  final String label;
  final String? url;
  final bool highlight;

  const _LabeledThumbnail({
    required this.label,
    required this.url,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = highlight
        ? Colors.green.shade300
        : Colors.grey.shade300;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: highlight ? Colors.green.shade700 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: _Thumbnail(url: url),
        ),
      ],
    );
  }
}

/// Visor de foto a pantalla completa con zoom (pinch-to-zoom) para ver el
/// detalle de una foto de observación/subsanación del ticket.
class _FullScreenPhotoViewer extends StatelessWidget {
  final String url;
  const _FullScreenPhotoViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Image.network(
                  url,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 64,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
