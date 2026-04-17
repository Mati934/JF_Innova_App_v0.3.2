import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/core/theme/app_theme.dart';
import 'package:jf_innova_app/features/tickets/data/repositories/local_ticket_repository.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_model.dart';
import 'package:jf_innova_app/features/tickets/presentation/controllers/ticket_controller.dart';
import 'package:jf_innova_app/features/tickets/presentation/screens/ticket_form_screen.dart';

/// Tarjeta pública que representa un registro unificado del historial
/// (Inspección o Visita Técnica).
///
/// Extraída de [history_screen.dart] para cumplir con SRP.
class HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const HistoryCard({super.key, required this.item});

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
    final inspector = item['inspector_nombre'] ?? 'Inspector';

    final tipoRaw = item['tipo_registro']?.toString() ?? 'General';
    final tipoLimpio = tipoRaw.replaceAll('INSPECCION_', '');

    final estado = item['estado']?.toString() ?? 'Desconocido';

    final numSeguimiento = item['numero_seguimiento'] as int? ?? 0;
    final esConsecutiva = numSeguimiento > 0;

    final pdfUrl = item['pdf_url'] as String?;
    final isSynced = (item['subido'] == 1);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FILA 1: TÍTULO Y FECHA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: esInspeccion
                            ? AppTheme.primaryBlue.withOpacity(0.1)
                            : Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        esInspeccion ? Icons.description : Icons.handshake,
                        color: esInspeccion
                            ? AppTheme.primaryBlue
                            : Colors.teal,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tituloCard,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: esInspeccion
                            ? AppTheme.primaryBlue
                            : Colors.teal.shade800,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fecha,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          isSynced ? 'Sincronizado' : 'Pendiente',
                          style: TextStyle(
                            fontSize: 10,
                            color: isSynced ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isSynced ? Icons.cloud_done : Icons.cloud_off,
                          size: 14,
                          color: isSynced ? Colors.green : Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(),
            ),

            // FILA 2: UBICACIÓN
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
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // FILA 3: TIPO Y ETIQUETA
            Row(
              children: [
                const Icon(
                  Icons.assignment,
                  size: 16,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  tipoLimpio,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                if (esInspeccion)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: esConsecutiva
                          ? Colors.purple.shade50
                          : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: esConsecutiva
                            ? Colors.purple.shade200
                            : Colors.teal.shade200,
                      ),
                    ),
                    child: Text(
                      esConsecutiva ? 'CONSECUTIVA' : 'INICIAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: esConsecutiva
                            ? Colors.purple.shade700
                            : Colors.teal.shade700,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      estado.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // FILA 4: INSPECTOR + CREAR TICKET + PDF
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.grey.shade200,
                  child: const Icon(Icons.person, size: 12, color: Colors.grey),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    inspector.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Botón de acceso rápido para crear un ticket vinculado
                OutlinedButton.icon(
                  icon: const Icon(
                    Icons.confirmation_number_outlined,
                    size: 13,
                  ),
                  label: const Text('Crear Ticket'),
                  onPressed: () => _navegarACrearTicket(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    side: BorderSide(
                      color: AppTheme.primaryBlue.withOpacity(0.45),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
    );
  }

  /// Navega a [TicketFormScreen] con un ticket pre-llenado vinculado a esta
  /// actividad del historial. Los campos de contexto (área, centro, embarcación)
  /// se auto-completan usando los IDs del item o consultando la BD local.
  Future<void> _navegarACrearTicket(BuildContext context) async {
    final actividadId = item['id']?.toString();
    final modulo = item['modulo']?.toString() ?? '';
    final esInspeccion = modulo == 'Inspección';

    // Intentar obtener IDs de contexto directamente desde el item de Supabase
    String? centroId = item['centro_id'] as String?;
    String? embarcacionId = item['embarcacion_id'] as String?;
    String? areaId;

    // Si no vienen del item (registros offline locales), consultar SQLite
    if (centroId == null && esInspeccion && actividadId != null) {
      try {
        final db = await DatabaseHelper.instance.database;
        final actRows = await db.query(
          'actividades_pendientes',
          where: 'id = ?',
          whereArgs: [actividadId],
        );
        if (actRows.isNotEmpty) {
          centroId = actRows.first['centro_id'] as String?;
          embarcacionId = actRows.first['embarcacion_id'] as String?;
        }
      } catch (e) {
        debugPrint('⚠️ No se pudo leer contexto local de la actividad: $e');
      }
    }

    // Derivar area_id desde el centro (siempre vía SQLite local)
    if (centroId != null) {
      try {
        final db = await DatabaseHelper.instance.database;
        final centroRows = await db.query(
          'centros',
          where: 'id = ?',
          whereArgs: [centroId],
        );
        if (centroRows.isNotEmpty) {
          areaId = centroRows.first['area_id'] as String?;
        }
      } catch (e) {
        debugPrint('⚠️ No se pudo derivar area_id desde el centro: $e');
      }
    }

    final draft = TicketModel(
      id: const Uuid().v4(),
      empresaId: '',
      areaId: areaId,
      centroId: centroId,
      embarcacionId: embarcacionId,
      actividadId: actividadId,
      categoriaId: '',
      descripcion: '',
      estado: 'Abierto',
      criticidad: 'Medio',
      solicitanteId: 'user-local',
    );

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketFormScreen(
          controller: TicketController(LocalTicketRepository()),
          ticket: draft,
        ),
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
