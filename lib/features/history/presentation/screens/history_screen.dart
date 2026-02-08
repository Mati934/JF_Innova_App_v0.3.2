import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../controllers/history_controller.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HistoryController(),
      child: Scaffold(
        appBar: AppBar(title: const Text("Historial General")),
        body: Consumer<HistoryController>(
          builder: (context, ctrl, _) {
            return Column(
              children: [
                // --- BARRA DE FILTROS (SOLO ADMIN) ---
                if (ctrl.esAdmin)
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey[200],
                    child: Row(
                      children: [
                        // Filtro Centro
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text("Filtrar Centro"),
                            value: ctrl.filtroCentroId,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text("Todos los Centros"),
                              ),
                              ...ctrl.listaCentros.map(
                                (c) => DropdownMenuItem(
                                  value: c['id'].toString(),
                                  child: Text(
                                    c['nombre'],
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: ctrl.setFiltroCentro,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Filtro Usuario
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text("Filtrar Usuario"),
                            value: ctrl.filtroUsuarioId,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text("Todos los Usuarios"),
                              ),
                              ...ctrl.listaUsuarios.map(
                                (u) => DropdownMenuItem(
                                  value: u['id'].toString(),
                                  child: Text(
                                    u['nombre_completo'],
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: ctrl.setFiltroUsuario,
                          ),
                        ),
                      ],
                    ),
                  ),

                // --- LISTA DE RESULTADOS ---
                Expanded(
                  child: ctrl.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: ctrl.inspections.length,
                          itemBuilder: (ctx, i) =>
                              _HistoryItemTile(item: ctrl.inspections[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// --- WIDGET DE LA TARJETA (TILE) ---
class _HistoryItemTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _HistoryItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final folio = item['numero_reporte']?.toString() ?? 'Borrador';
    final fechaRaw = item['fecha_realizacion'] as String?;
    final fecha = fechaRaw != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(fechaRaw))
        : '--/--/--';

    final centro = item['centro_nombre'] ?? 'Centro S/N';
    final contratista = item['contratista_nombre'] ?? 'Sin contratista';
    final embarcacion = item['embarcacion_nombre'] ?? 'Sin nave';
    final inspector = item['inspector_nombre'] ?? 'Inspector';
    final tipoRaw = item['tipo_actividad']?.toString() ?? 'GENERAL';
    final tipo = tipoRaw.replaceAll('INSPECCION_', '');

    final numSeguimiento = item['numero_seguimiento'] as int? ?? 0;
    final esConsecutiva = numSeguimiento > 0;
    final etiquetaTipo = esConsecutiva ? "CONSECUTIVA" : "INICIAL";

    final pdfUrl = item['pdf_url'] as String?;
    final isSynced = (item['subido'] == 1);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FILA 1: FOLIO Y FECHA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Informe N°$folio",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blueGrey,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      fecha,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isSynced ? Icons.cloud_done : Icons.cloud_off,
                      size: 18,
                      color: isSynced ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),

            // FILA 2: CENTRO
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    centro,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // FILA 3: TIPO
            Row(
              children: [
                const Icon(
                  Icons.assignment,
                  size: 16,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 4),
                Text(tipo, style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: esConsecutiva
                        ? Colors.purple.shade100
                        : Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: esConsecutiva ? Colors.purple : Colors.teal,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    etiquetaTipo,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: esConsecutiva
                          ? Colors.purple.shade900
                          : Colors.teal.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // FILA 4: DATOS EXTRA
            Row(
              children: [
                const Icon(Icons.engineering, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    contratista,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                const Text("|", style: TextStyle(color: Colors.grey)),
                const SizedBox(width: 10),
                const Icon(Icons.directions_boat, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    embarcacion,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // FILA 5: INSPECTOR Y BOTÓN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          inspector.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // AQUÍ USAMOS EL BOTÓN PERSONALIZADO
                PdfDownloadButton(pdfUrl: pdfUrl, isSynced: isSynced),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- CLASE DEL BOTÓN PDF (FUERA DE LAS OTRAS CLASES) ---
class PdfDownloadButton extends StatefulWidget {
  final String? pdfUrl;
  final bool isSynced;

  const PdfDownloadButton({
    super.key,
    required this.pdfUrl,
    required this.isSynced,
  });

  @override
  State<PdfDownloadButton> createState() => _PdfDownloadButtonState();
}

class _PdfDownloadButtonState extends State<PdfDownloadButton> {
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
            const SnackBar(content: Text("No se pudo abrir el PDF")),
          );
        }
      }
    } catch (e) {
      debugPrint("Error abriendo PDF: $e");
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSynced) {
      return const Icon(Icons.cloud_off, color: Colors.grey);
    }
    if (_isOpening) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (widget.pdfUrl != null) {
      return IconButton(
        icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
        onPressed: _abrirPdf,
        tooltip: "Ver PDF",
      );
    }
    return const Icon(Icons.description, color: Colors.grey);
  }
}
