import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../data/repositories/local_ast_repository.dart';
import 'ast_form_screen.dart';
import 'ast_setup_screen.dart';

const Color _kAstColor = Color(0xFF003366);

/// Pantalla principal del módulo AST: lista los borradores en curso y permite
/// crear uno nuevo. Los AST finalizados salen de aquí y pasan al historial
/// general (no se duplican entre el módulo y el historial).
class AstModuleScreen extends StatefulWidget {
  const AstModuleScreen({super.key});

  @override
  State<AstModuleScreen> createState() => _AstModuleScreenState();
}

class _AstModuleScreenState extends State<AstModuleScreen> {
  final _repo = LocalAstRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getBorradores();
  }

  void _reload() {
    setState(() {
      _future = _repo.getBorradores();
    });
  }

  Future<void> _nuevo() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AstSetupScreen()));
    if (mounted) _reload();
  }

  Future<void> _abrir(String id) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AstFormScreen(informeId: id)));
    if (mounted) _reload();
  }

  Future<void> _abrirPdf(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _confirmarEliminar(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar AST'),
        content: const Text(
          '¿Eliminar este borrador? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.eliminarBorrador(id);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kAstColor,
        foregroundColor: Colors.white,
        title: const Text('AST · Análisis Seguro de Trabajo'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kAstColor,
        foregroundColor: Colors.white,
        onPressed: _nuevo,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo AST'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(child: Text('Error: ${snap.error}')),
                ],
              );
            }
            final informes = snap.data ?? const [];
            if (informes.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No tienes borradores de AST.\n\nLos AST finalizados están en el historial general.\n\nPulsa "Nuevo AST" para crear uno.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: informes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _AstCard(
                data: informes[i],
                onTap: () => _abrir(informes[i]['id'] as String),
                onVerPdf: () =>
                    _abrirPdf(informes[i]['pdf_path_local'] as String?),
                onEliminar: () =>
                    _confirmarEliminar(informes[i]['id'] as String),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AstCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onVerPdf;
  final VoidCallback onEliminar;

  const _AstCard({
    required this.data,
    required this.onTap,
    required this.onVerPdf,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final estado = (data['estado_final'] ?? 'En Progreso') as String;
    final esBorrador = estado == 'En Progreso';
    final correlativo = (data['correlativo'] ?? '') as String? ?? '';
    final fechaStr = (data['fecha_realizacion'] ?? '') as String? ?? '';
    final fecha = DateTime.tryParse(fechaStr);
    final fechaFmt = fecha != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(fecha)
        : '';
    final empresa = (data['contratista_nombre'] ?? '') as String? ?? '';
    final centro = (data['centro_nombre'] ?? '') as String? ?? '';
    final area = (data['area_nombre'] ?? '') as String? ?? '';
    final profesional = (data['profesional'] ?? '') as String? ?? '';
    final numHallazgos = (data['num_hallazgos'] as int?) ?? 0;
    final tienePdf = (data['pdf_path_local'] ?? '') != '';

    final titulo = correlativo.isNotEmpty ? correlativo : 'AST · Borrador';

    final colLeft = <Widget>[
      if (empresa.isNotEmpty) _InfoCell(icon: Icons.business, texto: empresa),
      if (area.isNotEmpty) _InfoCell(icon: Icons.map_outlined, texto: area),
    ];
    final colRight = <Widget>[
      if (centro.isNotEmpty)
        _InfoCell(icon: Icons.place_outlined, texto: centro),
      if (profesional.isNotEmpty)
        _InfoCell(icon: Icons.person_outline, texto: profesional),
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
              // --- Barra lateral de color: identifica el tipo (AST) ---
              Container(width: 6, color: _kAstColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila superior: identificador + estado
                      Row(
                        children: [
                          Expanded(child: _TituloPill(titulo: titulo)),
                          const SizedBox(width: 8),
                          _EstadoChip(estado: estado),
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
                      const SizedBox(height: 12),
                      // Información en grilla de 2 columnas
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
                      const SizedBox(height: 10),
                      Divider(height: 1, color: Colors.grey.shade200),
                      const SizedBox(height: 8),
                      // Métricas + acciones
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _MetricChip(
                                  icon: Icons.report_problem_outlined,
                                  label: numHallazgos == 1
                                      ? '1 hallazgo'
                                      : '$numHallazgos hallazgos',
                                  color: numHallazgos > 0
                                      ? const Color(0xFFE65100)
                                      : const Color(0xFF2E7D32),
                                ),
                                if (tienePdf)
                                  const _MetricChip(
                                    icon: Icons.check_circle_outline,
                                    label: 'PDF listo',
                                    color: Color(0xFF1565C0),
                                  ),
                              ],
                            ),
                          ),
                          if (tienePdf)
                            TextButton.icon(
                              onPressed: onVerPdf,
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              label: const Text('Ver PDF'),
                              style: TextButton.styleFrom(
                                foregroundColor: _kAstColor,
                              ),
                            ),
                          if (esBorrador)
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

/// Identificador del AST en forma de "pill" con icono de escudo.
class _TituloPill extends StatelessWidget {
  final String titulo;
  const _TituloPill({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kAstColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kAstColor.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_outlined, size: 15, color: _kAstColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              titulo,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: _kAstColor,
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

/// Celda de información (icono + texto) usada en la grilla de 2 columnas.
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

/// Chip de métrica con icono y color personalizable.
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

class _EstadoChip extends StatelessWidget {
  final String estado;
  const _EstadoChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (estado) {
      case 'En Seguimiento':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        break;
      case 'Cerrada':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      default:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
