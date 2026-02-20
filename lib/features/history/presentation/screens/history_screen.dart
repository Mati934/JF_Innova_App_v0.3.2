import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

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
          backgroundColor: const Color(0xFF003366),
          foregroundColor: Colors.white,
        ),
        body: Consumer<HistoryController>(
          builder: (context, ctrl, _) {
            return Column(
              children: [
                // --- SECCIÓN DE FILTROS ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. FILTRO PÚBLICO: Módulo (Para todos)
                      CustomDropdown(
                        label: "Tipo de Registro",
                        enableSearch: false,
                        items: const ["Todos", "Inspección", "Visita Técnica"],
                        value: ctrl.filtroModulo ?? "Todos",
                        onChanged: (val) {
                          ctrl.setFiltroModulo(val == "Todos" ? null : val);
                        },
                      ),

                      // 2. FILTROS PRIVADOS: Solo para Admin (Apilados en un Row)
                      if (ctrl.esAdmin) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: CustomDropdown(
                                label: "Centro",
                                enableSearch: true,
                                items: [
                                  "Todos",
                                  ...ctrl.listaCentros.map(
                                    (e) => e['nombre'].toString(),
                                  ),
                                ],
                                value: ctrl.filtroCentroId == null
                                    ? "Todos"
                                    : ctrl.listaCentros.firstWhere(
                                        (e) =>
                                            e['id'].toString() ==
                                            ctrl.filtroCentroId,
                                        orElse: () => {'nombre': "Todos"},
                                      )['nombre'],
                                onChanged: (val) {
                                  if (val == "Todos" || val == null) {
                                    ctrl.setFiltroCentro(null);
                                  } else {
                                    final obj = ctrl.listaCentros.firstWhere(
                                      (e) => e['nombre'] == val,
                                    );
                                    ctrl.setFiltroCentro(obj['id'].toString());
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomDropdown(
                                label: "Usuario",
                                enableSearch: true,
                                items: [
                                  "Todos",
                                  ...ctrl.listaUsuarios.map(
                                    (e) => e['nombre_completo'].toString(),
                                  ),
                                ],
                                value: ctrl.filtroUsuarioId == null
                                    ? "Todos"
                                    : ctrl.listaUsuarios.firstWhere(
                                        (e) =>
                                            e['id'].toString() ==
                                            ctrl.filtroUsuarioId,
                                        orElse: () => {
                                          'nombre_completo': "Todos",
                                        },
                                      )['nombre_completo'],
                                onChanged: (val) {
                                  if (val == "Todos" || val == null) {
                                    ctrl.setFiltroUsuario(null);
                                  } else {
                                    final obj = ctrl.listaUsuarios.firstWhere(
                                      (e) => e['nombre_completo'] == val,
                                    );
                                    ctrl.setFiltroUsuario(obj['id'].toString());
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // --- LISTA DE RESULTADOS ---
                Expanded(
                  child: ctrl.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ctrl
                            .records
                            .isEmpty // Cambiado de 'inspections' a 'records'
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
                          itemCount: ctrl.records.length,
                          itemBuilder: (ctx, i) =>
                              _HistoryItemTile(item: ctrl.records[i]),
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

// --- WIDGET DE LA TARJETA (TILE) REFACTORIZADO ---
class _HistoryItemTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _HistoryItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final modulo = item['modulo']?.toString() ?? 'Registro';
    final esInspeccion = modulo == 'Inspección';

    final folio = item['numero_reporte']?.toString();
    final tituloCard = esInspeccion
        ? (folio != null ? "Informe N° $folio" : "Inspección s/n")
        : "Visita Técnica";

    final fechaRaw = item['fecha_realizacion'] as String?;
    final fecha = fechaRaw != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(fechaRaw))
        : '--/--/--';

    final ubicacion = item['ubicacion'] ?? 'Ubicación no especificada';
    final inspector = item['inspector_nombre'] ?? 'Inspector';

    final tipoRaw = item['tipo_registro']?.toString() ?? 'General';
    final tipoLimpio = tipoRaw.replaceAll('INSPECCION_', '');

    final estado = item['estado']?.toString() ?? 'Desconocido';

    // 🔥 RECUPERAMOS TU LÓGICA DE NEGOCIO ORIGINAL
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
                            ? const Color(0xFF003366).withOpacity(0.1)
                            : Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        esInspeccion ? Icons.description : Icons.handshake,
                        color: esInspeccion
                            ? const Color(0xFF003366)
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
                            ? const Color(0xFF003366)
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

            // FILA 3: TIPO Y ETIQUETA (AQUÍ REVERTIMOS EL DAÑO)
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

                // Renderizado condicional polimórfico
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
                      esConsecutiva ? "CONSECUTIVA" : "INICIAL",
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

            // FILA 4: INSPECTOR Y BOTÓN
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
                PdfDownloadButton(pdfUrl: pdfUrl, isSynced: isSynced),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- BOTÓN PDF (Intacto, la lógica de negocio estaba bien) ---
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
