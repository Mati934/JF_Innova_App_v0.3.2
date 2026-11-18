import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../screens/merieux_visita_form_screen.dart' show kMerieuxAzul;

/// Tarjeta de borrador Merieux (compartida por los 2 submódulos: Visitas y
/// Extintores). Mismo "Diseño A · barra lateral" usado en AST
/// (`_AstCard`/`ast_module_screen.dart`): franja de color + pill
/// identificador + grilla de 2 columnas + chips de métricas + acciones.
class MerieuxBorradorCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final IconData icono;
  final String tituloFallback;

  /// Chip adicional específico del submódulo (ej. tipo de checklist o
  /// cantidad de extintores).
  final Widget? chipExtra;

  final VoidCallback onTap;
  final VoidCallback? onVerPdf;
  final VoidCallback onEliminar;

  const MerieuxBorradorCard({
    super.key,
    required this.data,
    required this.icono,
    required this.tituloFallback,
    required this.onTap,
    required this.onEliminar,
    this.chipExtra,
    this.onVerPdf,
  });

  @override
  Widget build(BuildContext context) {
    final correlativo = (data['correlativo'] ?? '') as String? ?? '';
    final fechaStr = (data['fecha_realizacion'] ?? '') as String? ?? '';
    final fecha = DateTime.tryParse(fechaStr);
    final fechaFmt = fecha != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(fecha)
        : '';
    final profesional = (data['profesional'] ?? '') as String? ?? '';
    final region = (data['region'] ?? '') as String? ?? '';
    final area = (data['area'] ?? '') as String? ?? '';
    final jefatura = (data['jefatura_a_cargo'] ?? '') as String? ?? '';
    final origen = (data['origen_actividad'] ?? '') as String? ?? '';
    final pdfPathLocal = data['pdf_path_local'] as String?;
    final tienePdf = (pdfPathLocal ?? '').isNotEmpty;

    final titulo = correlativo.isNotEmpty ? correlativo : tituloFallback;

    final colLeft = <Widget>[
      if (profesional.isNotEmpty)
        _InfoCell(icon: Icons.person_outline, texto: profesional),
      if (region.isNotEmpty) _InfoCell(icon: Icons.map_outlined, texto: region),
    ];
    final colRight = <Widget>[
      if (area.isNotEmpty)
        _InfoCell(icon: Icons.business_outlined, texto: area),
      if (jefatura.isNotEmpty)
        _InfoCell(icon: Icons.supervisor_account_outlined, texto: jefatura),
    ];

    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: kMerieuxAzul),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _TituloPill(titulo: titulo, icono: icono),
                          ),
                        ],
                      ),
                      if (fechaFmt.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.event,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              fechaFmt,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (colLeft.isNotEmpty || colRight.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: colLeft,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: colRight,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Divider(height: 1, color: Colors.grey.shade200),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (origen.isNotEmpty)
                                  _MetricChip(
                                    icon: Icons.flag_outlined,
                                    label: origen,
                                    color: const Color(0xFF546E7A),
                                  ),
                                if (chipExtra != null) chipExtra!,
                                if (tienePdf)
                                  const _MetricChip(
                                    icon: Icons.check_circle_outline,
                                    label: 'PDF listo',
                                    color: Color(0xFF1565C0),
                                  ),
                              ],
                            ),
                          ),
                          if (tienePdf && onVerPdf != null)
                            TextButton.icon(
                              onPressed: onVerPdf,
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              label: const Text('Ver PDF'),
                              style: TextButton.styleFrom(
                                foregroundColor: kMerieuxAzul,
                              ),
                            ),
                          IconButton(
                            onPressed: onEliminar,
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red.shade400,
                            tooltip: 'Eliminar borrador',
                          ),
                        ],
                      ),
                    ],
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

class _TituloPill extends StatelessWidget {
  final String titulo;
  final IconData icono;
  const _TituloPill({required this.titulo, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kMerieuxAzul.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kMerieuxAzul.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 15, color: kMerieuxAzul),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              titulo,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: kMerieuxAzul,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String texto;
  const _InfoCell({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
