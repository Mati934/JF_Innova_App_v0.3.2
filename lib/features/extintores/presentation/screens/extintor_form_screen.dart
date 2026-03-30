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

            // ── Actividades Realizadas ───────────────────────────
            _SeccionActividades(ctrl: ctrl),

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
                onTipoExtintorChanged: (t) => ctrl.updateTipoExtintor(i, t),
                onEliminar: () => ctrl.eliminarExtintor(i),
                onFotoAdded: (path) => ctrl.addFotoExtintor(i, path),
                onFotoRemoved: (fotoIdx) => ctrl.removeFotoExtintor(i, fotoIdx),
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

            // ── Observaciones generales ──────────────────────────
            _SeccionObservaciones(ctrl: ctrl),

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
            // Empresa (Autocomplete)
            _AutocompleteField(
              label: 'Empresa',
              icon: Icons.business_center,
              controller: ctrl.empresaCtrl,
              opciones: ctrl.historialEmpresas,
            ),
            const SizedBox(height: 12),

            // Región (Autocomplete)
            _AutocompleteField(
              label: 'Región',
              icon: Icons.map,
              controller: ctrl.regionCtrl,
              opciones: ctrl.historialRegiones,
            ),
            const SizedBox(height: 12),

            // Oficina / Área (Autocomplete)
            _AutocompleteField(
              label: 'Oficina / Área',
              icon: Icons.business,
              controller: ctrl.oficinaCtrl,
              opciones: ctrl.historialCentros,
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

            // Lugar de Inspección (Autocomplete)
            _AutocompleteField(
              label: 'Lugar de Inspección *',
              icon: Icons.location_on_outlined,
              controller: ctrl.lugarCtrl,
              opciones: ctrl.historialLugares,
              uppercase: true,
            ),
            const SizedBox(height: 12),

            // Origen de la visita
            TextField(
              controller: ctrl.origenCtrl,
              decoration: const InputDecoration(
                labelText: 'Origen de la Visita',
                prefixIcon: Icon(Icons.flag_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Correos
            TextField(
              controller: ctrl.email1Ctrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo Empresa 1',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl.email2Ctrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo Empresa 2 (Opcional)',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Fecha y horas
            Row(
              children: [
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

// ── Autocomplete reutilizable ────────────────────────────────────────────────

class _AutocompleteField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final List<String> opciones;
  final bool uppercase;

  const _AutocompleteField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.opciones,
    this.uppercase = false,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (v) => opciones
          .where((o) => o.toLowerCase().contains(v.text.toLowerCase()))
          .toList(),
      onSelected: (val) => controller.text = val,
      fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmit) {
        if (textCtrl.text.isEmpty && controller.text.isNotEmpty) {
          textCtrl.text = controller.text;
        }
        textCtrl.addListener(() {
          if (controller.text != textCtrl.text) {
            controller.text = textCtrl.text;
          }
        });
        return TextField(
          controller: textCtrl,
          focusNode: focusNode,
          textCapitalization: uppercase
              ? TextCapitalization.characters
              : TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        );
      },
    );
  }
}

// ── Sección Actividades Realizadas ───────────────────────────────────────────

class _SeccionActividades extends StatelessWidget {
  final ExtintorFormController ctrl;

  const _SeccionActividades({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actividades Realizadas',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            _CheckItem(
              'Reunión',
              ctrl.checkReunion,
              (v) => ctrl.toggleCheck('reunion', v!),
            ),
            _CheckItem(
              'Instalación Señalética',
              ctrl.checkSenaletica,
              (v) => ctrl.toggleCheck('senaletica', v!),
            ),
            _CheckItem(
              'Capacitación',
              ctrl.checkCapacitacion,
              (v) => ctrl.toggleCheck('capacitacion', v!),
            ),
            _CheckItem(
              'Visita SSO',
              ctrl.checkVisitaSso,
              (v) => ctrl.toggleCheck('visita_sso', v!),
            ),
            _CheckItem(
              'Charla(s)',
              ctrl.checkCharla,
              (v) => ctrl.toggleCheck('charla', v!),
            ),
            _CheckItem(
              'Inv. Incidente',
              ctrl.checkInvestigacion,
              (v) => ctrl.toggleCheck('investigacion', v!),
            ),
            _CheckItem(
              'Inspección SSO',
              ctrl.checkInspeccionSso,
              (v) => ctrl.toggleCheck('inspeccion_sso', v!),
            ),
            _CheckItem(
              'Obs. Conductual',
              ctrl.checkObsConductual,
              (v) => ctrl.toggleCheck('obs_conductual', v!),
            ),
            _CheckItem(
              'Otro',
              ctrl.checkOtro,
              (v) => ctrl.toggleCheck('otro', v!),
            ),
            if (ctrl.checkOtro)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 4),
                child: TextField(
                  controller: ctrl.otroActividadCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Especifique...',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _CheckItem(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: CheckboxListTile(
        title: Text(label, style: const TextStyle(fontSize: 13)),
        value: value,
        onChanged: onChanged,
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}

// ── Sección Observaciones ────────────────────────────────────────────────────

class _SeccionObservaciones extends StatelessWidget {
  final ExtintorFormController ctrl;

  const _SeccionObservaciones({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apuntes / Observaciones',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl.observacionesCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Observaciones generales de la inspección...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
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
                  final confirmar = await _mostrarResumen(context, ctrl);
                  if (!confirmar) return;
                  if (!context.mounted) return;
                  final ok = await ctrl.guardar(context);
                  if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Inspección guardada correctamente'),
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
                      'Hay extintores sin completar. Deseas guardar de todas formas?',
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
