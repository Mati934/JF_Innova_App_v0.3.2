import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

// IMPORTA TU NUEVO DROPDOWN Y EL CONTROLLER
import '../../../../shared/widgets/custom_dropdown.dart';
import '../../controllers/history_controller.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HistoryController(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Historial General"),
          backgroundColor: const Color(0xFF003366), // Azul corporativo
          foregroundColor: Colors.white,
        ),
        body: Consumer<HistoryController>(
          builder: (context, ctrl, _) {
            return Column(
              children: [
                // --- BARRA DE FILTROS (SOLO ADMIN) ---
                if (ctrl.esAdmin)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50, // Fondo sutil
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- FILTRO CENTRO ---
                        Expanded(
                          child: CustomDropdown(
                            label: "Filtrar Centro",
                            enableSearch: true, // ¡Buscador activado!
                            // 1. Preparamos la lista: Opción "Todos" + Nombres reales
                            items: [
                              "Todos los Centros",
                              ...ctrl.listaCentros.map(
                                (e) => e['nombre'].toString(),
                              ),
                            ],

                            // 2. Traducimos ID -> Nombre para mostrarlo seleccionado
                            value: ctrl.filtroCentroId == null
                                ? "Todos los Centros"
                                : ctrl.listaCentros.firstWhere(
                                    (e) =>
                                        e['id'].toString() ==
                                        ctrl.filtroCentroId,
                                    orElse: () => {
                                      'nombre': "Todos los Centros",
                                    },
                                  )['nombre'],

                            // 3. Traducimos Nombre -> ID al seleccionar
                            onChanged: (val) {
                              if (val == "Todos los Centros" || val == null) {
                                ctrl.setFiltroCentro(null);
                              } else {
                                final seleccionado = ctrl.listaCentros
                                    .firstWhere((e) => e['nombre'] == val);
                                ctrl.setFiltroCentro(
                                  seleccionado['id'].toString(),
                                );
                              }
                            },
                          ),
                        ),

                        const SizedBox(width: 12),

                        // --- FILTRO USUARIO ---
                        Expanded(
                          child: CustomDropdown(
                            label: "Filtrar Usuario",
                            enableSearch: true,
                            items: [
                              "Todos los Usuarios",
                              ...ctrl.listaUsuarios.map(
                                (e) => e['nombre_completo'].toString(),
                              ),
                            ],
                            value: ctrl.filtroUsuarioId == null
                                ? "Todos los Usuarios"
                                : ctrl.listaUsuarios.firstWhere(
                                    (e) =>
                                        e['id'].toString() ==
                                        ctrl.filtroUsuarioId,
                                    orElse: () => {
                                      'nombre_completo': "Todos los Usuarios",
                                    },
                                  )['nombre_completo'],
                            onChanged: (val) {
                              if (val == "Todos los Usuarios" || val == null) {
                                ctrl.setFiltroUsuario(null);
                              } else {
                                final seleccionado = ctrl.listaUsuarios
                                    .firstWhere(
                                      (e) => e['nombre_completo'] == val,
                                    );
                                ctrl.setFiltroUsuario(
                                  seleccionado['id'].toString(),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // --- LISTA DE RESULTADOS ---
                Expanded(
                  child: ctrl.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ctrl.inspections.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_toggle_off,
                                size: 60,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "No hay registros",
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 20),
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
      elevation: 2, // Sutil elevación
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FILA 1: FOLIO Y FECHA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF003366).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.description,
                        color: Color(0xFF003366),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Informe N° $folio",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF003366),
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
                          isSynced ? "Sincronizado" : "Pendiente",
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

            // FILA 2: CENTRO
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    centro,
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

            // FILA 3: TIPO
            Row(
              children: [
                const Icon(
                  Icons.assignment,
                  size: 16,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 6),
                Text(tipo, style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
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
                    etiquetaTipo,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: esConsecutiva
                          ? Colors.purple.shade700
                          : Colors.teal.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // FILA 4: DATOS EXTRA
            Row(
              children: [
                const Icon(Icons.engineering, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    contratista,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Text("|", style: TextStyle(color: Colors.grey.shade400)),
                const SizedBox(width: 10),
                const Icon(Icons.directions_boat, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    embarcacion,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // FILA 5: INSPECTOR Y BOTÓN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.grey.shade200,
                      child: const Icon(
                        Icons.person,
                        size: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      inspector.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                // Botón PDF
                PdfDownloadButton(pdfUrl: pdfUrl, isSynced: isSynced),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- BOTÓN PDF (Mantenemos tu lógica que funciona bien) ---
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
      // Si no está subido, mostramos un icono gris deshabilitado
      return const Tooltip(
        message: "Pendiente de sincronización",
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
                  "Ver PDF",
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
    return const SizedBox();
  }
}
