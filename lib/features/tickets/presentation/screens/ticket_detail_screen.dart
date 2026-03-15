import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/core/theme/app_theme.dart';
import 'package:jf_innova_app/features/tickets/domain/models/ticket_model.dart';
import 'package:jf_innova_app/features/tickets/presentation/controllers/ticket_controller.dart';
import 'package:jf_innova_app/features/tickets/presentation/screens/ticket_form_screen.dart';

class TicketDetailScreen extends StatefulWidget {
  final TicketModel ticket;
  final TicketController controller;

  const TicketDetailScreen({
    super.key,
    required this.ticket,
    required this.controller,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  late TicketModel _ticket;

  String? _empresaNombre;
  String? _areaNombre;
  String? _categoriaNombre;
  String? _solicitanteNombre;
  String? _responsableNombre;

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  TicketController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
    _resolveNames();
  }

  Future<void> _resolveNames() async {
    final db = DatabaseHelper.instance;
    final results = await Future.wait([
      db.getAllEmpresas(),
      db.getAreas(),
      db.getAllUsuarios(),
    ]);

    final empresas = results[0];
    final areas = results[1];
    final usuarios = results[2];

    await controller.loadCategorias();

    if (!mounted) return;

    setState(() {
      _empresaNombre = _findName(empresas, _ticket.empresaId);
      _areaNombre =
          _ticket.areaId != null ? _findName(areas, _ticket.areaId!) : null;
      _solicitanteNombre = _findName(
        usuarios,
        _ticket.solicitanteId,
        nameKey: 'nombre_completo',
      );
      _responsableNombre = _ticket.responsableId != null
          ? _findName(usuarios, _ticket.responsableId!,
              nameKey: 'nombre_completo')
          : null;
      _categoriaNombre = controller.categorias
          .where((c) => c.id == _ticket.categoriaId)
          .map((c) => c.nombre)
          .firstOrNull;
    });
  }

  static String? _findName(
    List<Map<String, dynamic>> list,
    String id, {
    String nameKey = 'nombre',
  }) {
    for (final item in list) {
      if (item['id'] == id) return item[nameKey] as String?;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Acciones – Tomar / Cerrar
  // ---------------------------------------------------------------------------

  Future<void> _tomarTicket() async {
    final userId = _currentUserId;
    if (userId == null) return;

    final updated = _ticket.copyWith(
      responsableId: userId,
      estado: 'En proceso',
    );

    final ok = await controller.updateTicket(updated);
    if (!mounted) return;
    if (ok) {
      setState(() => _ticket = updated);
      await _resolveNames();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket tomado con éxito.')),
      );
    }
  }

  Future<void> _cerrarTicket() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar Ticket'),
        content: const Text(
          '¿Estás seguro de que quieres cerrar este ticket? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Cerrar Ticket',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final updated = _ticket.copyWith(estado: 'Cerrado');
    final ok = await controller.updateTicket(updated);
    if (!mounted) return;
    if (ok) {
      setState(() => _ticket = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket cerrado.')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final estadoLower = _ticket.estado.toLowerCase();
    final esAbierto = estadoLower == 'abierto';
    final esEnProceso = estadoLower == 'en proceso';
    final esCerrado = estadoLower == 'cerrado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Ticket'),
        actions: [
          if (!esCerrado)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TicketFormScreen(
                      controller: controller,
                      ticket: _ticket,
                    ),
                  ),
                );
                if (mounted) {
                  await controller.loadTickets();
                  final updated = controller.tickets.firstWhere(
                    (t) => t.id == _ticket.id,
                    orElse: () => _ticket,
                  );
                  if (mounted) setState(() => _ticket = updated);
                  _resolveNames();
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildMetadataSection(),
            const SizedBox(height: 24),
            _buildDescriptionSection(context),
            const SizedBox(height: 24),
            // ── Acciones ─────────────────────────────────────────
            if (esAbierto) _buildTomarButton(context),
            if (esEnProceso) _buildCerrarButton(context),
            if (esCerrado) _buildCerradoBanner(),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Secciones
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    final bool isPending = _ticket.codigoTicket == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isPending ? 'Pendiente de Sincronización' : _ticket.codigoTicket!,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: isPending ? Colors.grey.shade400 : AppTheme.primaryBlue,
            fontStyle: isPending ? FontStyle.italic : FontStyle.normal,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _EstadoBadge(estado: _ticket.estado),
            const SizedBox(width: 12),
            _CriticidadBadge(criticidad: _ticket.criticidad),
          ],
        ),
      ],
    );
  }

  Widget _buildMetadataSection() {
    final categoriaLabel = _ticket.categoriaOtro != null
        ? 'Otro: ${_ticket.categoriaOtro}'
        : (_categoriaNombre ?? _ticket.categoriaId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Información General'),
        const SizedBox(height: 10),
        _MetaRow(
          icon: Icons.category_outlined,
          label: 'Categoría',
          value: categoriaLabel,
        ),
        if (_ticket.empresaId.isNotEmpty)
          _MetaRow(
            icon: Icons.business_outlined,
            label: 'Empresa',
            value: _empresaNombre ?? _ticket.empresaId,
          ),
        if (_ticket.areaId != null)
          _MetaRow(
            icon: Icons.location_on_outlined,
            label: 'Área',
            value: _areaNombre ?? _ticket.areaId!,
          ),
        _MetaRow(
          icon: Icons.person_outline,
          label: 'Solicitante',
          value: _solicitanteNombre ?? _ticket.solicitanteId,
        ),
        if (_ticket.responsableId != null)
          _MetaRow(
            icon: Icons.engineering_outlined,
            label: 'Responsable',
            value: _responsableNombre ?? _ticket.responsableId!,
          ),
        _MetaRow(
          icon: Icons.calendar_today_outlined,
          label: 'Fecha Tentativa de Cierre',
          value: _ticket.fechaTentativaCierre != null
              ? _formatDate(_ticket.fechaTentativaCierre!)
              : 'No definida',
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Descripción'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _ticket.descripcion,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
        ),
      ],
    );
  }

  Widget _buildTomarButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ElevatedButton.icon(
          onPressed: controller.isSaving ? null : _tomarTicket,
          icon: controller.isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.handshake_outlined),
          label: const Text('Tomar Ticket'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCerrarButton(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            children: [
              Icon(Icons.engineering_outlined,
                  size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Tomado por: ${_responsableNombre ?? 'tí'}',
                style: TextStyle(
                    color: Colors.blue.shade700, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => ElevatedButton.icon(
            onPressed: controller.isSaving ? null : _cerrarTicket,
            icon: controller.isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('Cerrar Ticket'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCerradoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Text(
            'Este ticket está cerrado.',
            style: TextStyle(
                color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// ---------------------------------------------------------------------------
// Widgets privados de apoyo
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Colors.grey.shade500,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final String estado;

  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor) = _colorsForEstado(estado.toLowerCase());
    return Chip(
      label: Text(estado),
      backgroundColor: bgColor,
      labelStyle: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  static (Color, Color) _colorsForEstado(String estado) {
    switch (estado) {
      case 'abierto':
        return (Colors.red.shade50, Colors.red.shade700);
      case 'en proceso':
      case 'en progreso':
        return (Colors.blue.shade50, Colors.blue.shade700);
      case 'resuelto':
        return (Colors.green.shade50, Colors.green.shade700);
      case 'cerrado':
        return (Colors.grey.shade100, Colors.grey.shade600);
      default:
        return (Colors.orange.shade50, Colors.orange.shade800);
    }
  }
}

class _CriticidadBadge extends StatelessWidget {
  final String criticidad;

  const _CriticidadBadge({required this.criticidad});

  @override
  Widget build(BuildContext context) {
    final color = _colorForCriticidad(criticidad.toLowerCase());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          criticidad,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  static Color _colorForCriticidad(String c) {
    switch (c) {
      case 'bajo':
        return Colors.green;
      case 'medio':
        return Colors.orange;
      case 'alto':
        return Colors.deepOrange;
      case 'intolerable':
        return Colors.red.shade800;
      default:
        return Colors.grey;
    }
  }
}
