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

  @override
  void initState() {
    super.initState();
    _verificarTicketExistente();
  }

  Future<void> _verificarTicketExistente() async {
    try {
      final existente = await _repo.getTicketAutomaticoDeInspeccion(
        widget.inspeccionId,
      );
      if (existente != null) {
        _yaExisteMensaje =
            'Ya existe un ticket generado para esta inspección '
            '(${existente.codigoTicket ?? existente.id}). '
            'No se puede generar otro automático desde la misma inspección.';
      } else {
        final conteo = await _repo.contarObservacionesPotenciales(
          widget.inspeccionId,
        );
        _cantidadNoCumple = conteo.noCumple;
        _cantidadFotosConObservacion = conteo.fotosConObservacion;
      }
    } catch (e) {
      // Si falla la verificación, se deja continuar; el backend igual lo bloquea.
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
      final ticket = await _repo.generarDesdeInspeccion(
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ticket generado.')));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TicketDetailScreen(ticketId: ticket.id),
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
      body: _verificando
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
                      'Se armará automáticamente con los "No Cumple" y las fotos con '
                      'observación de esta inspección. Cada uno quedará como un ítem '
                      'independiente para ir subsanando por separado.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                    label: Text(_guardando ? 'Generando…' : 'Generar ticket'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
