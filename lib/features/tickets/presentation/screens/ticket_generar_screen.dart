import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/user_session.dart';
import '../../../../shared/widgets/gradient_app_bar.dart';
import '../../data/repositories/ticket_repository.dart';
import '../../domain/ticket_reglas.dart';
import 'ticket_detail_screen.dart';

/// Formulario para generar el ticket automático de una inspección de
/// buceo/embarcación (ver plan §5.1). Se invoca desde el Historial.
class TicketGenerarScreen extends StatefulWidget {
  final String inspeccionId;
  final String? numeroInforme;

  const TicketGenerarScreen({
    super.key,
    required this.inspeccionId,
    this.numeroInforme,
  });

  @override
  State<TicketGenerarScreen> createState() => _TicketGenerarScreenState();
}

class _TicketGenerarScreenState extends State<TicketGenerarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _asuntoCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _repo = TicketRepository();

  bool _conFechaLimite = false;
  DateTime? _fechaLimite;
  bool _guardando = false;
  bool _verificando = true;
  String? _yaExisteMensaje;
  int _cantidadNoCumple = 0;
  int _cantidadFotosConObservacion = 0;
  TicketGeneracionPreview? _preview;

  @override
  void initState() {
    super.initState();
    _verificarTicketExistente();
  }

  Future<void> _verificarTicketExistente() async {
    try {
      final empresaId = UserSession().empresaId;
      if (empresaId == null) {
        _yaExisteMensaje = 'No se pudo resolver la empresa activa.';
      } else {
        final preview = await _repo
            .previewGeneracionDesdeInspeccionPorHallazgos(
              widget.inspeccionId,
              empresaId,
            );
        _preview = preview;
        _cantidadNoCumple = preview.cantidadNoCumple;
        _cantidadFotosConObservacion = preview.cantidadFotosConObservacion;
      }
    } catch (e) {
      _yaExisteMensaje = 'No se pudo previsualizar la generación: $e';
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  @override
  void dispose() {
    _asuntoCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: ahora.add(const Duration(days: 7)),
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 365 * 2)),
    );
    if (elegida != null) setState(() => _fechaLimite = elegida);
  }

  Future<bool?> _confirmarGeneracionSinNoCumple() {
    final hayFotos = _cantidadFotosConObservacion > 0;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Inspección con 100% de cumplimiento'),
        content: Text(
          hayFotos
              ? 'Esta inspección tiene 100% de cumplimiento (sin "No Cumple"), '
                    'pero registra $_cantidadFotosConObservacion foto(s) con '
                    'observación. ¿Deseas generar igualmente el ticket?'
              : 'Esta inspección tiene 100% de cumplimiento y no registra fotos '
                    'con observación, por lo que el ticket se crearía sin '
                    'observaciones para subsanar. ¿Deseas generarlo de todas formas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generar igual'),
          ),
        ],
      ),
    );
  }

  Future<void> _generar() async {
    if (!_formKey.currentState!.validate()) return;
    final empresaId = UserSession().empresaId;
    final userId = UserSession().userId;
    if (empresaId == null || userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sesión no válida.')));
      return;
    }

    if (TicketReglas.debeConfirmarGeneracionSinNoCumple(
      cantidadNoCumple: _cantidadNoCumple,
    )) {
      final continuar = await _confirmarGeneracionSinNoCumple();
      if (continuar != true) return;
    }

    setState(() => _guardando = true);
    try {
      final resultado = await _repo.generarDesdeInspeccionPorHallazgos(
        inspeccionId: widget.inspeccionId,
        empresaId: empresaId,
        generadoPorId: userId,
        motivo: _motivoCtrl.text.trim(),
        asunto: _asuntoCtrl.text.trim().isEmpty
            ? null
            : _asuntoCtrl.text.trim(),
        fechaLimite: _conFechaLimite ? _fechaLimite : null,
      );
      if (!mounted) return;

      final total = resultado.totalTicketsInvolucrados;
      if (total == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se encontraron hallazgos NC para generar tickets.',
            ),
          ),
        );
        return;
      }

      final ticketNavegable = resultado.creados.isNotEmpty
          ? resultado.creados.first
          : resultado.reutilizados.first;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Proceso listo: ${resultado.creados.length} ticket(s) creados, '
            '${resultado.reutilizados.length} reutilizado(s).',
          ),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TicketDetailScreen(ticketId: ticketNavegable.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el ticket: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: Text('Generar ticket')),
      body: SafeArea(
        child: _verificando
            ? const Center(child: CircularProgressIndicator())
            : _yaExisteMensaje != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 48,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 12),
                      Text(_yaExisteMensaje!, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.numeroInforme != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Informe: ${widget.numeroInforme}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Se procesarán los "No Cumple" de la inspección con regla de '
                        'hallazgo único: 1 hallazgo = 1 ticket. Si el hallazgo ya tiene '
                        'ticket activo, se reutiliza el mismo.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_preview != null) ...[
                      _PreviewResumen(preview: _preview!),
                      const SizedBox(height: 16),
                      if (_preview!.hallazgos
                          .where((h) => h.seCrearaTicket)
                          .isNotEmpty)
                        _PreviewLista(
                          titulo: 'Se crearán tickets',
                          color: Colors.green.shade700,
                          items: _preview!.hallazgos
                              .where((h) => h.seCrearaTicket)
                              .toList(),
                        ),
                      if (_preview!.hallazgos
                          .where((h) => h.seCrearaTicket)
                          .isNotEmpty)
                        const SizedBox(height: 12),
                      if (_preview!.hallazgos
                          .where((h) => !h.seCrearaTicket)
                          .isNotEmpty)
                        _PreviewLista(
                          titulo:
                              'No se crearán porque ya existe ticket activo',
                          color: Colors.orange.shade800,
                          items: _preview!.hallazgos
                              .where((h) => !h.seCrearaTicket)
                              .toList(),
                        ),
                      if (_preview!.usaFlujoLegacySinNc) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: const Text(
                            'Esta inspección no tiene NC con item_id. Si la generas igual, '
                            'caerá al flujo legacy y se creará un ticket único por fotos con observación.',
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _asuntoCtrl,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: 'Asunto (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _motivoCtrl,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Motivo del ticket *',
                        hintText: '¿Por qué se genera este ticket?',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'El motivo es obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _conFechaLimite,
                      onChanged: (v) => setState(() => _conFechaLimite = v),
                      title: const Text('Definir fecha límite'),
                      subtitle: const Text('Desactivada por defecto'),
                      activeThumbColor: AppTheme.primaryBlue,
                    ),
                    if (_conFechaLimite)
                      ListTile(
                        leading: const Icon(Icons.event_outlined),
                        title: Text(
                          _fechaLimite == null
                              ? 'Seleccionar fecha'
                              : '${_fechaLimite!.day}/${_fechaLimite!.month}/${_fechaLimite!.year}',
                        ),
                        onTap: _elegirFecha,
                      ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _guardando ? null : _generar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.confirmation_number_outlined),
                      label: Text(
                        _guardando ? 'Procesando…' : 'Generar tickets',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PreviewResumen extends StatelessWidget {
  final TicketGeneracionPreview preview;

  const _PreviewResumen({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen previo',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 6),
          Text('Hallazgos NC detectados: ${preview.cantidadNoCumple}'),
          Text('Tickets nuevos a crear: ${preview.ticketsNuevos}'),
          Text(
            'Hallazgos con ticket activo existente: ${preview.ticketsReutilizados}',
          ),
          if (preview.cantidadFotosConObservacion > 0)
            Text(
              'Fotos con observación: ${preview.cantidadFotosConObservacion}',
            ),
        ],
      ),
    );
  }
}

class _PreviewLista extends StatelessWidget {
  final String titulo;
  final Color color;
  final List<TicketGeneracionPreviewItem> items;

  const _PreviewLista({
    required this.titulo,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(
              titulo,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
          ...items.map(
            (item) => ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Text(
                  item.numeroPregunta?.toString() ?? 'NC',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              title: Text(item.pregunta),
              subtitle: Text(
                [
                  if (item.categoria != null && item.categoria!.isNotEmpty)
                    item.categoria!,
                  if (item.observacion != null && item.observacion!.isNotEmpty)
                    item.observacion!,
                  if (item.ticketActivoExistente != null)
                    'Ticket: ${item.ticketActivoExistente!.codigoTicket ?? item.ticketActivoExistente!.id}',
                ].join(' · '),
              ),
              trailing: item.seCrearaTicket
                  ? Icon(Icons.add_circle_outline, color: color)
                  : Icon(Icons.link, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
