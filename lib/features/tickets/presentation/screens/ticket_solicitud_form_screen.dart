import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/user_session.dart';
import '../../../../shared/widgets/gradient_app_bar.dart';
import '../../data/repositories/ticket_repository.dart';

/// Formulario de solicitud manual (ticket sin inspección asociada).
/// Solo el motivo es obligatorio (ver plan §5.2 y decisión 22).
class TicketSolicitudFormScreen extends StatefulWidget {
  const TicketSolicitudFormScreen({super.key});

  @override
  State<TicketSolicitudFormScreen> createState() =>
      _TicketSolicitudFormScreenState();
}

class _TicketSolicitudFormScreenState extends State<TicketSolicitudFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _asuntoCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _repo = TicketRepository();

  bool _conFechaLimite = false;
  DateTime? _fechaLimite;
  bool _guardando = false;

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
    if (elegida != null) {
      setState(() => _fechaLimite = elegida);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final empresaId = UserSession().empresaId;
    final userId = UserSession().userId;
    if (empresaId == null || userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sesión no válida.')));
      return;
    }

    setState(() => _guardando = true);
    try {
      await _repo.crearSolicitud(
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
      ).showSnackBar(const SnackBar(content: Text('Solicitud creada.')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la solicitud: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: Text('Nueva solicitud')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _asuntoCtrl,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Asunto (opcional)',
                hintText: 'Título corto para identificar el ticket en la lista',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _motivoCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Motivo / descripción *',
                hintText: 'Describe con detalle lo que se requiere',
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
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_guardando ? 'Creando…' : 'Crear solicitud'),
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
