import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/extintor_form_controller.dart';
import '../widgets/extintor_card.dart';

class ExtintorFormScreen extends StatelessWidget {
  final Map<String, dynamic>? borrador;

  const ExtintorFormScreen({super.key, this.borrador});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExtintorFormController(borradorInicial: borrador),
      child: const _ExtintorFormView(),
    );
  }
}

class _ExtintorFormView extends StatelessWidget {
  const _ExtintorFormView();

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<ExtintorFormController>(context);

    if (ctrl.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 15),
                Text('Guardando borrador...'),
              ],
            ),
            duration: Duration(milliseconds: 800),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await ctrl.guardarBorradorSilencioso();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Inspección de Extintores'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Previsualizar PDF',
              onPressed: () => ctrl.previsualizarPdf(context),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            // ── Formulario base ──────────────────────────────────
            _SeccionFormBase(ctrl: ctrl),

            // ── Extintores ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.fire_extinguisher,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Extintores (${ctrl.extintores.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Resumen rápido
                  _ResumenChip(extintores: ctrl.extintores),
                ],
              ),
            ),

            ...List.generate(ctrl.extintores.length, (i) {
              final e = ctrl.extintores[i];
              return ExtintorCard(
                key: ValueKey(e.localId),
                extintor: e,
                index: i,
                puedeClonarse: i > 0,
                onResponder: (estado, itemId) =>
                    ctrl.responderPunto(i, itemId, estado),
                onObservacion: (obs, itemId) =>
                    ctrl.updateObservacion(i, itemId, obs),
                onTodoCumple: () => ctrl.marcarTodoCumple(i),
                onClonar: () => ctrl.clonarDelAnterior(i),
                onMatriculaChanged: (m) => ctrl.updateMatricula(i, m),
              );
            }),

            // ── Botón agregar extintor ───────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: ctrl.agregarExtintor,
                icon: const Icon(Icons.add),
                label: const Text('Agregar Extintor'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: AppTheme.primaryBlue,
                  side: BorderSide(color: AppTheme.primaryBlue),
                ),
              ),
            ),

            // ── Error ────────────────────────────────────────────
            if (ctrl.errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  ctrl.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),

        // ── Botón guardar flotante ───────────────────────────────
        bottomNavigationBar: _BottomActions(ctrl: ctrl),
      ),
    );
  }
}

// ── Sección formulario base ──────────────────────────────────────────────────

class _SeccionFormBase extends StatelessWidget {
  final ExtintorFormController ctrl;

  const _SeccionFormBase({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lugar (Autocomplete)
            Autocomplete<String>(
              optionsBuilder: (v) => ctrl.historialLugares
                  .where((l) => l.toLowerCase().contains(v.text.toLowerCase()))
                  .toList(),
              onSelected: (val) => ctrl.lugarCtrl.text = val,
              fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmit) {
                // Sincronizar con el TextEditingController del controller
                if (textCtrl.text.isEmpty && ctrl.lugarCtrl.text.isNotEmpty) {
                  textCtrl.text = ctrl.lugarCtrl.text;
                }
                textCtrl.addListener(() {
                  if (ctrl.lugarCtrl.text != textCtrl.text) {
                    ctrl.lugarCtrl.text = textCtrl.text;
                  }
                });
                return TextField(
                  controller: textCtrl,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Lugar de Inspección *',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Jefatura
            TextField(
              controller: ctrl.jefaturaCtrl,
              decoration: const InputDecoration(
                labelText: 'Jefatura a Cargo',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Fecha y horas
            Row(
              children: [
                // Fecha
                Expanded(
                  child: _CampoFechaHora(
                    icon: Icons.calendar_today,
                    label: ctrl.fechaStr,
                    onTap: () => ctrl.pickDate(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CampoFechaHora(
                    icon: Icons.access_time,
                    label: 'Inicio: ${ctrl.horaInicioStr}',
                    onTap: () => ctrl.pickTime(context, true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CampoFechaHora(
                    icon: Icons.access_time_filled,
                    label: 'Fin: ${ctrl.horaTerminoStr}',
                    onTap: () => ctrl.pickTime(context, false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoFechaHora extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CampoFechaHora({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Resumen rápido ───────────────────────────────────────────────────────────

class _ResumenChip extends StatelessWidget {
  final List extintores;

  const _ResumenChip({required this.extintores});

  @override
  Widget build(BuildContext context) {
    final completos = extintores.where((e) => e.estaCompleto).length;
    final total = extintores.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: completos == total && total > 0
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: completos == total && total > 0
              ? Colors.green.shade300
              : Colors.orange.shade300,
        ),
      ),
      child: Text(
        '$completos/$total completos',
        style: TextStyle(
          fontSize: 11,
          color: completos == total && total > 0
              ? Colors.green.shade800
              : Colors.orange.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Bottom actions ────────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final ExtintorFormController ctrl;

  const _BottomActions({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: ctrl.isSaving
              ? null
              : () async {
                  // Mostrar resumen antes de guardar
                  final confirmar = await _mostrarResumen(context, ctrl);
                  if (!confirmar) return;
                  if (!context.mounted) return;
                  final ok = await ctrl.guardar(context);
                  if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Inspección guardada correctamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                },
          icon: ctrl.isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save),
          label: Text(ctrl.isSaving ? 'Guardando...' : 'Guardar Inspección'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<bool> _mostrarResumen(
    BuildContext context,
    ExtintorFormController ctrl,
  ) async {
    final extintores = ctrl.extintores;
    final totalExtintores = extintores.length;
    final extintoresCompletos = extintores.where((e) => e.estaCompleto).length;
    final totalNC = extintores.fold<int>(0, (s, e) => s + e.puntosNC.length);

    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.fire_extinguisher, color: Colors.red),
                SizedBox(width: 8),
                Text('Resumen de Inspección'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ResumenFila(
                  label: 'Total extintores',
                  valor: '$totalExtintores',
                ),
                _ResumenFila(
                  label: 'Inspeccionados',
                  valor: '$extintoresCompletos / $totalExtintores',
                  color: extintoresCompletos == totalExtintores
                      ? Colors.green
                      : Colors.orange,
                ),
                _ResumenFila(
                  label: 'No Conformidades',
                  valor: '$totalNC',
                  color: totalNC > 0 ? Colors.red : Colors.green,
                ),
                if (extintoresCompletos < totalExtintores)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '⚠️ Hay extintores sin completar. ¿Deseas guardar de todas formas?',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Revisar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Confirmar y Guardar'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _ResumenFila extends StatelessWidget {
  final String label;
  final String valor;
  final Color? color;

  const _ResumenFila({required this.label, required this.valor, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
