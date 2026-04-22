import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/gradient_app_bar.dart';
import '../controllers/extintor_form_controller.dart';
import '../widgets/extintor_card.dart';

const Color _kExtintorRed = Color(0xFFC62828);

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
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: GradientAppBar(
          title: const Text('Inspección de Extintores'),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Previsualizar PDF',
              onPressed: () => ctrl.previsualizarPdf(context),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          children: [
            _Banner(extintoresCount: ctrl.extintores.length),
            const SizedBox(height: 14),

            _SectionCard(
              icon: Icons.business_center,
              title: 'Datos Generales',
              child: _SeccionFormBase(ctrl: ctrl),
            ),
            const SizedBox(height: 14),

            _SectionCard(
              icon: Icons.event,
              title: 'Fecha y Horarios',
              child: _SeccionFechas(ctrl: ctrl),
            ),
            const SizedBox(height: 14),

            _SectionCard(
              icon: Icons.checklist_rtl,
              title: 'Actividades Realizadas',
              child: _SeccionActividades(ctrl: ctrl),
            ),
            const SizedBox(height: 14),

            _ExtintoresHeader(ctrl: ctrl),
            const SizedBox(height: 8),

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
                onPesoExtintorChanged: (p) => ctrl.updatePesoExtintor(i, p),
                onFechaUltimaMantencionChanged: (f) =>
                    ctrl.updateFechaUltimaMantencion(i, f),
                onFechaProximaMantencionChanged: (f) =>
                    ctrl.updateFechaProximaMantencion(i, f),
                onEliminar: () => ctrl.eliminarExtintor(i),
                onFotoAdded: (path) => ctrl.addFotoExtintor(i, path),
                onFotoRemoved: (fotoIdx) => ctrl.removeFotoExtintor(i, fotoIdx),
              );
            }),

            const SizedBox(height: 6),
            _BotonAgregarExtintor(onPressed: ctrl.agregarExtintor),
            const SizedBox(height: 14),

            _SectionCard(
              icon: Icons.notes,
              title: 'Apuntes / Observaciones',
              child: TextField(
                controller: ctrl.observacionesCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Observaciones generales de la inspección...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ),

            if (ctrl.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ctrl.errorMessage!,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _BottomActions(ctrl: ctrl),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner
// ─────────────────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final int extintoresCount;
  const _Banner({required this.extintoresCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kExtintorRed, Color(0xFF8E1818)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _kExtintorRed.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.fire_extinguisher,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inspección de Extintores',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'VISITA-R004 · $extintoresCount extintor${extintoresCount == 1 ? '' : 'es'} en revisión',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.3,
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

// ─────────────────────────────────────────────────────────────────────────────
// Sección formulario base
// ─────────────────────────────────────────────────────────────────────────────

class _SeccionFormBase extends StatelessWidget {
  final ExtintorFormController ctrl;
  const _SeccionFormBase({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AutocompleteField(
          label: 'Empresa',
          icon: Icons.business_center,
          controller: ctrl.empresaCtrl,
          opciones: ctrl.historialEmpresas,
        ),
        const SizedBox(height: 12),
        _AutocompleteField(
          label: 'Región',
          icon: Icons.map,
          controller: ctrl.regionCtrl,
          opciones: ctrl.historialRegiones,
        ),
        const SizedBox(height: 12),
        _AutocompleteField(
          label: 'Oficina / Área',
          icon: Icons.business,
          controller: ctrl.oficinaCtrl,
          opciones: ctrl.historialCentros,
        ),
        const SizedBox(height: 12),
        _StyledInput(
          controller: ctrl.jefaturaCtrl,
          label: 'Jefatura a Cargo',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        _AutocompleteField(
          label: 'Lugar de Inspección *',
          icon: Icons.location_on_outlined,
          controller: ctrl.lugarCtrl,
          opciones: ctrl.historialLugares,
          uppercase: true,
        ),
        const SizedBox(height: 12),
        _StyledInput(
          controller: ctrl.origenCtrl,
          label: 'Origen de la Visita',
          icon: Icons.flag_outlined,
        ),
        const SizedBox(height: 12),
        _StyledInput(
          controller: ctrl.email1Ctrl,
          label: 'Correo Empresa 1',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _StyledInput(
          controller: ctrl.email2Ctrl,
          label: 'Correo Empresa 2 (Opcional)',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sección fechas
// ─────────────────────────────────────────────────────────────────────────────

class _SeccionFechas extends StatelessWidget {
  final ExtintorFormController ctrl;
  const _SeccionFechas({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DateCard(
          label: 'Fecha de Inspección',
          value: ctrl.fechaStr,
          onTap: () => ctrl.pickDate(context),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TimePickerCard(
                label: 'Inicio',
                time: ctrl.horaInicioStr,
                icon: Icons.play_circle_outline,
                onTap: () => ctrl.pickTime(context, true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimePickerCard(
                label: 'Término',
                time: ctrl.horaTerminoStr,
                icon: Icons.stop_circle_outlined,
                onTap: () => ctrl.pickTime(context, false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sección actividades
// ─────────────────────────────────────────────────────────────────────────────

class _SeccionActividades extends StatelessWidget {
  final ExtintorFormController ctrl;
  const _SeccionActividades({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActivityCheck(
          label: 'Reunión',
          icon: Icons.groups,
          value: ctrl.checkReunion,
          onChanged: (v) => ctrl.toggleCheck('reunion', v),
        ),
        _ActivityCheck(
          label: 'Instalación Señalética',
          icon: Icons.signpost,
          value: ctrl.checkSenaletica,
          onChanged: (v) => ctrl.toggleCheck('senaletica', v),
        ),
        _ActivityCheck(
          label: 'Capacitación',
          icon: Icons.school,
          value: ctrl.checkCapacitacion,
          onChanged: (v) => ctrl.toggleCheck('capacitacion', v),
        ),
        _ActivityCheck(
          label: 'Visita SSO',
          icon: Icons.health_and_safety,
          value: ctrl.checkVisitaSso,
          onChanged: (v) => ctrl.toggleCheck('visita_sso', v),
        ),
        _ActivityCheck(
          label: 'Charla(s)',
          icon: Icons.record_voice_over,
          value: ctrl.checkCharla,
          onChanged: (v) => ctrl.toggleCheck('charla', v),
        ),
        _ActivityCheck(
          label: 'Inv. Incidente',
          icon: Icons.report_problem,
          value: ctrl.checkInvestigacion,
          onChanged: (v) => ctrl.toggleCheck('investigacion', v),
        ),
        _ActivityCheck(
          label: 'Inspección SSO',
          icon: Icons.fact_check,
          value: ctrl.checkInspeccionSso,
          onChanged: (v) => ctrl.toggleCheck('inspeccion_sso', v),
        ),
        _ActivityCheck(
          label: 'Obs. Conductual',
          icon: Icons.psychology,
          value: ctrl.checkObsConductual,
          onChanged: (v) => ctrl.toggleCheck('obs_conductual', v),
        ),
        _ActivityCheck(
          label: 'Otro',
          icon: Icons.more_horiz,
          value: ctrl.checkOtro,
          onChanged: (v) => ctrl.toggleCheck('otro', v),
        ),
        if (ctrl.checkOtro)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: ctrl.otroActividadCtrl,
              decoration: InputDecoration(
                hintText: "Especifique 'Otro'",
                prefixIcon: const Icon(Icons.edit_note, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header de la lista de extintores con resumen
// ─────────────────────────────────────────────────────────────────────────────

class _ExtintoresHeader extends StatelessWidget {
  final ExtintorFormController ctrl;
  const _ExtintoresHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final total = ctrl.extintores.length;
    final completos = ctrl.extintores.where((e) => e.estaCompleto).length;
    final nc = ctrl.extintores.fold<int>(0, (s, e) => s + e.puntosNC.length);
    final progreso = total == 0 ? 0.0 : completos / total;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kExtintorRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.fire_extinguisher,
                  size: 20,
                  color: _kExtintorRed,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Extintores',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              _MiniStat(
                label: 'Listos',
                value: '$completos/$total',
                color: completos == total && total > 0
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
              const SizedBox(width: 6),
              _MiniStat(
                label: 'NC',
                value: '$nc',
                color: nc > 0 ? Colors.red.shade700 : Colors.grey.shade600,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                progreso >= 1.0
                    ? Colors.green
                    : nc > 0
                        ? _kExtintorRed
                        : AppTheme.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonAgregarExtintor extends StatelessWidget {
  final VoidCallback onPressed;
  const _BotonAgregarExtintor({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _kExtintorRed.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _kExtintorRed.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: _kExtintorRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Agregar Extintor',
                style: TextStyle(
                  color: _kExtintorRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inputs reutilizables
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _inputDecoration({
  required String label,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade600),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.6),
    ),
    filled: true,
    fillColor: Colors.grey.shade50,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

class _StyledInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  const _StyledInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label: label, icon: icon),
    );
  }
}

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
          decoration: _inputDecoration(label: label, icon: icon),
        );
      },
    );
  }
}

class _ActivityCheck extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ActivityCheck({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: value
                  ? AppTheme.primaryBlue.withValues(alpha: 0.08)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: value
                    ? AppTheme.primaryBlue.withValues(alpha: 0.4)
                    : Colors.grey.shade200,
                width: value ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: value ? AppTheme.primaryBlue : Colors.grey.shade600,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                      color: value
                          ? AppTheme.primaryBlue
                          : Colors.grey.shade800,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: value ? AppTheme.primaryBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: value
                          ? AppTheme.primaryBlue
                          : Colors.grey.shade400,
                      width: 1.6,
                    ),
                  ),
                  child: value
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section card / Date card / TimePicker
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppTheme.primaryBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.06),
                Colors.white,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: AppTheme.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_calendar,
                size: 18,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimePickerCard extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final VoidCallback onTap;

  const _TimePickerCard({
    required this.label,
    required this.time,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom actions
// ─────────────────────────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final ExtintorFormController ctrl;
  const _BottomActions({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: ctrl.isSaving
                  ? LinearGradient(colors: [
                      Colors.grey.shade400,
                      Colors.grey.shade500,
                    ])
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primaryBlue, Color(0xFF002244)],
                    ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: ctrl.isSaving
                  ? null
                  : [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: ctrl.isSaving
                    ? null
                    : () async {
                        final confirmar = await _mostrarResumen(context, ctrl);
                        if (!confirmar) return;
                        if (!context.mounted) return;
                        final ok = await ctrl.guardar(context);
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Inspección guardada correctamente',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      },
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (ctrl.isSaving)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      else
                        const Icon(Icons.save, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        ctrl.isSaving ? 'GUARDANDO…' : 'GUARDAR INSPECCIÓN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (!ctrl.isSaving) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.fire_extinguisher, color: _kExtintorRed),
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
                      'Hay extintores sin completar. ¿Deseas guardar de todas formas?',
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
