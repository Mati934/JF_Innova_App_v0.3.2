import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:jf_innova_app/core/theme/app_theme.dart';
// NOTE: Tickets temporalmente ocultos (se reactivarán a futuro).
// Se conservan los archivos del módulo en lib/features/tickets/.

/// Tarjeta pública que representa un registro unificado del historial
/// (Inspección o Visita Técnica).
///
/// Extraída de [history_screen.dart] para cumplir con SRP.
class HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool showEmpresa;

  const HistoryCard({super.key, required this.item, this.showEmpresa = false});

  @override
  Widget build(BuildContext context) {
    final modulo = item['modulo']?.toString() ?? 'Registro';
    final esInspeccion = modulo == 'Inspección';

    final folio = item['numero_reporte']?.toString();
    final tituloCard = esInspeccion
        ? (folio != null ? 'Informe N° $folio' : 'Inspección s/n')
        : 'Visita Técnica';

    final fechaRaw = item['fecha_realizacion'] as String?;
    final fecha = fechaRaw != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(fechaRaw))
        : '--/--/--';

    final ubicacion = item['ubicacion'] ?? 'Ubicación no especificada';
    final inspectorRaw = item['inspector_nombre']?.toString().trim();
    final tieneInspector = inspectorRaw != null && inspectorRaw.isNotEmpty;
    final inspector = tieneInspector ? inspectorRaw : 'Sin asignar';
    final empresaNombre = item['empresa_nombre']?.toString();

    final tipoRaw = item['tipo_registro']?.toString() ?? 'General';
    final tipoLimpio = tipoRaw.replaceAll('INSPECCION_', '');

    final estado = item['estado']?.toString() ?? 'Desconocido';

    final numSeguimiento = item['numero_seguimiento'] as int? ?? 0;
    final esConsecutiva = numSeguimiento > 0;

    final pdfUrl = item['pdf_url'] as String?;
    final isSynced = (item['subido'] == 1);

    final accent = esInspeccion ? AppTheme.primaryBlue : Colors.teal.shade700;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header coloreado con icono + título + estado sync
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    esInspeccion ? Icons.description : Icons.handshake,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tituloCard,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: accent,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fecha,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _SyncBadge(isSynced: isSynced),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ubicación
                Row(
                  children: [
                    Icon(
                      esInspeccion ? Icons.location_on : Icons.business,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ubicacion,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Chips: tipo + estado/etiqueta (la empresa se muestra junto al inspector)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniChip(
                      icon: Icons.assignment,
                      label: tipoLimpio,
                      color: Colors.blue.shade700,
                    ),
                    if (esInspeccion)
                      _MiniChip(
                        icon: esConsecutiva ? Icons.repeat : Icons.flag,
                        label: esConsecutiva ? 'CONSECUTIVA' : 'INICIAL',
                        color: esConsecutiva
                            ? Colors.purple.shade700
                            : Colors.teal.shade700,
                      )
                    else
                      _MiniChip(
                        icon: Icons.label_outline,
                        label: estado.toUpperCase(),
                        color: Colors.indigo.shade600,
                      ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 10),

                // Inspector + (empresa, solo admin) + PDF
                Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.grey.shade200,
                      child: Icon(
                        Icons.person,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              inspector.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: tieneInspector
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade500,
                                fontStyle: tieneInspector
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                                letterSpacing: 0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showEmpresa &&
                              empresaNombre != null &&
                              empresaNombre.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: _EmpresaTag(label: empresaNombre),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _PdfDownloadButton(
                      pdfUrl: pdfUrl,
                      pdfPathLocal: item['pdf_path_local'] as String?,
                      isSynced: isSynced,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  final bool isSynced;
  const _SyncBadge({required this.isSynced});

  @override
  Widget build(BuildContext context) {
    final color = isSynced ? Colors.green.shade600 : Colors.orange.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSynced ? Icons.cloud_done : Icons.cloud_off,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isSynced ? 'OK' : 'Pend.',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tag compacto para mostrar la empresa junto al inspector (vista admin)
// ---------------------------------------------------------------------------

class _EmpresaTag extends StatelessWidget {
  final String label;
  const _EmpresaTag({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Colors.deepPurple.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apartment, size: 10, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget privado: botón de descarga/visualización del PDF
// ---------------------------------------------------------------------------

class _PdfDownloadButton extends StatefulWidget {
  final String? pdfUrl;
  final String? pdfPathLocal;
  final bool isSynced;

  const _PdfDownloadButton({
    required this.pdfUrl,
    this.pdfPathLocal,
    required this.isSynced,
  });

  @override
  State<_PdfDownloadButton> createState() => _PdfDownloadButtonState();
}

class _PdfDownloadButtonState extends State<_PdfDownloadButton> {
  bool _isOpening = false;

  Future<void> _abrirPdf() async {
    if (widget.pdfUrl == null) return;

    setState(() => _isOpening = true);

    try {
      final uri = Uri.parse(widget.pdfUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el PDF')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error abriendo PDF: $e');
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  Future<void> _abrirPdfLocal() async {
    if (widget.pdfPathLocal == null) return;

    setState(() => _isOpening = true);

    try {
      final file = File(widget.pdfPathLocal!);
      if (await file.exists()) {
        final uri = Uri.file(widget.pdfPathLocal!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo abrir el PDF local')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Archivo PDF no encontrado')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error abriendo PDF local: $e');
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSynced) {
      return const Tooltip(
        message: 'Pendiente de sincronización',
        child: Icon(Icons.cloud_off, color: Colors.grey),
      );
    }

    if (_isOpening) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (widget.pdfUrl != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _abrirPdf,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Ver PDF',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // PDF local provisional (generado offline, pendiente de sync)
    if (widget.pdfPathLocal != null && widget.pdfPathLocal!.isNotEmpty) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _abrirPdfLocal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.picture_as_pdf,
                  color: Colors.orange.shade700,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'PDF Local',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Sin PDF ni local ni remoto: mostrar indicador pendiente
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_top, size: 16, color: Colors.amber.shade700),
          const SizedBox(width: 4),
          Text(
            'PDF Pendiente',
            style: TextStyle(
              fontSize: 11,
              color: Colors.amber.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
