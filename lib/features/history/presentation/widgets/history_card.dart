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
    final tipoRegistro = item['tipo_registro']?.toString() ?? '';
    final esInspeccion = modulo == 'Inspección';

    final folio = item['numero_reporte']?.toString();

    // Configuración visual por módulo. Cada módulo puede personalizar
    // título, icono y color de acento. Los demás siguen el comportamiento
    // genérico (Inspección / Visita Técnica).
    final cfg = HistoryCardConfig.resolve(
      modulo: modulo,
      tipoRegistro: tipoRegistro,
      folio: folio,
    );

    final fechaRaw = item['fecha_realizacion'] as String?;
    final fecha = fechaRaw != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(fechaRaw))
        : '--/--/--';

    final ubicacion = item['ubicacion'] ?? 'Ubicación no especificada';
    final inspectorRaw = item['inspector_nombre']?.toString().trim();
    final tieneInspector = inspectorRaw != null && inspectorRaw.isNotEmpty;
    final inspector = tieneInspector ? inspectorRaw : 'Sin asignar';
    final empresaNombre = item['empresa_nombre']?.toString();

    final tipoRaw = tipoRegistro.isEmpty ? 'General' : tipoRegistro;
    final tipoLimpio =
        cfg.tipoChipLabel ?? tipoRaw.replaceAll('INSPECCION_', '');

    final estado = item['estado']?.toString() ?? 'Desconocido';
    final estadoLabel = HistoryCardConfig.estadoLabel(modulo, estado);

    final numSeguimiento = item['numero_seguimiento'] as int? ?? 0;
    final esConsecutiva = numSeguimiento > 0;

    final pdfUrl = item['pdf_url'] as String?;
    final pdfCertUrl = item['pdf_certificado_url'] as String?;
    final pdfCertPathLocal = item['pdf_certificado_path_local'] as String?;
    final isSynced = (item['subido'] == 1);
    final tieneCertificado =
        (pdfCertUrl != null && pdfCertUrl.isNotEmpty) ||
        (pdfCertPathLocal != null && pdfCertPathLocal.isNotEmpty);

    final accent = cfg.accent;

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
                  child: Icon(cfg.icon, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cfg.titulo,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: accent,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.event,
                            size: 12,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            fecha,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (cfg.folioLabel != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                cfg.folioLabel!,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ],
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
                // Bloque info: ubicaci\u00f3n + inspector en panel suave.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        icon: esInspeccion
                            ? Icons.location_on_outlined
                            : Icons.business_outlined,
                        iconColor: accent,
                        label: 'Ubicaci\u00f3n',
                        value: ubicacion.toString(),
                        valueBold: true,
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.person_outline,
                        iconColor: Colors.grey.shade600,
                        label: 'Inspector',
                        value: inspector,
                        valueItalic: !tieneInspector,
                        valueDimmed: !tieneInspector,
                        trailing:
                            (showEmpresa &&
                                empresaNombre != null &&
                                empresaNombre.isNotEmpty)
                            ? _EmpresaTag(label: empresaNombre)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Chips de tipo + estado.
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniChip(
                      icon: Icons.assignment,
                      label: tipoLimpio,
                      color: accent,
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
                        label: estadoLabel.toUpperCase(),
                        color: Colors.indigo.shade600,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 10),
                // Acciones: botones de descarga (registro + opcional certificado).
                Row(
                  children: [
                    Expanded(
                      child: _PdfDownloadButton(
                        pdfUrl: pdfUrl,
                        pdfPathLocal: item['pdf_path_local'] as String?,
                        isSynced: isSynced,
                        label: tieneCertificado ? 'Registro' : 'Ver PDF',
                        accentColor: accent,
                        expanded: true,
                      ),
                    ),
                    if (tieneCertificado) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PdfDownloadButton(
                          pdfUrl: pdfCertUrl,
                          pdfPathLocal: pdfCertPathLocal,
                          isSynced: isSynced,
                          label: 'Certificado',
                          accentColor: Colors.deepPurple,
                          expanded: true,
                        ),
                      ),
                    ],
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

/// Configuración visual de la tarjeta de historial según el módulo.
///
/// Permite personalizar título, icono y color de acento por tipo de
/// registro. Si se quiere agregar un nuevo módulo (p. ej. una nueva línea
/// de servicio), basta con extender [resolve] con un nuevo `case`.
class HistoryCardConfig {
  final String titulo;
  final IconData icon;
  final Color accent;

  /// Si se define, reemplaza el chip de tipo (por defecto se calcula a
  /// partir de `tipo_registro`).
  final String? tipoChipLabel;

  /// Folio/número de informe mostrado como pill junto a la fecha en el header.
  final String? folioLabel;

  const HistoryCardConfig({
    required this.titulo,
    required this.icon,
    required this.accent,
    this.tipoChipLabel,
    this.folioLabel,
  });

  /// Etiqueta de estado mostrada en la tarjeta. Para AST, el estado interno
  /// `En Seguimiento` (que dispara el correlativo) se muestra como
  /// `Finalizado`, más claro para el usuario.
  static String estadoLabel(String modulo, String estado) {
    if (modulo == 'AST' && estado == 'En Seguimiento') return 'Finalizado';
    return estado;
  }

  static HistoryCardConfig resolve({
    required String modulo,
    required String tipoRegistro,
    String? folio,
  }) {
    final folioPill = (folio != null && folio.isNotEmpty) ? 'N° $folio' : null;
    if (tipoRegistro == 'MANTENCION_PROSESSO' ||
        modulo == 'Mantención de Extintores') {
      return HistoryCardConfig(
        titulo: 'Mantención de Extintores',
        icon: Icons.fire_extinguisher,
        accent: const Color(0xFFC8102E),
        tipoChipLabel: 'PROSESSO',
        folioLabel: folioPill,
      );
    }

    // AST (Análisis Seguro de Trabajo) — azul corporativo, icono escudo.
    if (modulo == 'AST') {
      return HistoryCardConfig(
        titulo: folio != null && folio.isNotEmpty ? folio : 'AST',
        icon: Icons.shield_outlined,
        accent: const Color(0xFF003366),
        tipoChipLabel: 'AST',
        folioLabel: folioPill,
      );
    }

    // Inspección clásica.
    if (modulo == 'Inspección') {
      return HistoryCardConfig(
        titulo: folio != null && folio.isNotEmpty
            ? 'Informe N° $folio'
            : 'Inspección s/n',
        icon: Icons.description,
        accent: AppTheme.primaryBlue,
      );
    }

    // Default: visita técnica genérica.
    return HistoryCardConfig(
      titulo: 'Visita Técnica',
      icon: Icons.handshake,
      accent: Colors.teal.shade700,
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

/// Fila de informaci\u00f3n: icono + label + valor (con `trailing` opcional).
/// Usado en el panel de info de la tarjeta de historial.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool valueBold;
  final bool valueItalic;
  final bool valueDimmed;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueBold = false,
    this.valueItalic = false,
    this.valueDimmed = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
                  fontStyle: valueItalic ? FontStyle.italic : FontStyle.normal,
                  color: valueDimmed
                      ? Colors.grey.shade500
                      : Colors.grey.shade800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
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
  final String label;
  final Color accentColor;

  /// Si es true, el botón se renderiza centrado con padding mayor para usarse
  /// dentro de un `Expanded` (estilo CTA).
  final bool expanded;

  const _PdfDownloadButton({
    required this.pdfUrl,
    this.pdfPathLocal,
    required this.isSynced,
    this.label = 'Ver PDF',
    this.accentColor = Colors.red,
    this.expanded = false,
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
            padding: EdgeInsets.symmetric(
              horizontal: widget.expanded ? 14 : 12,
              vertical: widget.expanded ? 9 : 6,
            ),
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.accentColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: widget.expanded
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              mainAxisSize: widget.expanded
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf, color: widget.accentColor, size: 18),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: widget.expanded ? 13 : 12,
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
            padding: EdgeInsets.symmetric(
              horizontal: widget.expanded ? 14 : 10,
              vertical: widget.expanded ? 9 : 6,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              mainAxisAlignment: widget.expanded
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              mainAxisSize: widget.expanded
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                Icon(
                  Icons.picture_as_pdf,
                  color: Colors.orange.shade700,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${widget.label} (local)',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: widget.expanded ? 12.5 : 11,
                    ),
                    overflow: TextOverflow.ellipsis,
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
