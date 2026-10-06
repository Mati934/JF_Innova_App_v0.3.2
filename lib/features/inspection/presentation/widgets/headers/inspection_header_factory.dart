import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../controllers/inspection_form_controller.dart';
import 'buceo_header_widget.dart';

class InspectionHeaderFactory {
  static Widget create(
    String tipoActividad,
    InspectionFormController controller,
  ) {
    switch (tipoActividad) {
      case 'INSPECCION_BUCEO':
        return Column(
          children: [
            BuceoCuadrillaWidget(controller: controller),
            BuceoTecnicoWidget(controller: controller),
          ],
        );
      case 'INSPECCION_EMBARCACION':
        return Column(
          children: [
            BuceoCuadrillaWidget(controller: controller),
            EmbarcacionTecnicoWidget(controller: controller),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class EmbarcacionTecnicoWidget extends StatelessWidget {
  final InspectionFormController controller;

  const EmbarcacionTecnicoWidget({super.key, required this.controller});

  Future<void> _seleccionarHora(BuildContext context, bool isInicio) async {
    final initial = controller.getHoraInicialReloj(isInicio);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.actualizarHora(isInicio, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_boat_outlined,
                  size: 18,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Datos de la Embarcación',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Horario
          Row(
            children: [
              Expanded(
                child: _TimePickerCard(
                  label: 'Inicio Auditoría',
                  time: controller.horaInicioController.text.isEmpty
                      ? '--:--'
                      : controller.horaInicioController.text,
                  icon: Icons.play_circle_outline,
                  onTap: () => _seleccionarHora(context, true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimePickerCard(
                  label: 'Término',
                  time: controller.horaTerminoController.text.isEmpty
                      ? '--:--'
                      : controller.horaTerminoController.text,
                  icon: Icons.stop_circle_outlined,
                  onTap: () => _seleccionarHora(context, false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          TextFormField(
            controller: controller.numeroZarpeCtrl,
            decoration: _input(
              label: 'Número de Zarpe',
              icon: Icons.confirmation_number_outlined,
            ),
            onChanged: (_) => controller.guardarBorrador(silent: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller.correoEmpresaServiciosCtrl,
            decoration: _input(
              label: 'Correo Empresa de Servicios',
              icon: Icons.email_outlined,
            ),
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => controller.guardarBorrador(silent: true),
          ),
        ],
      ),
    );
  }

  InputDecoration _input({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade600),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: Colors.grey.shade50,
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
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
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
