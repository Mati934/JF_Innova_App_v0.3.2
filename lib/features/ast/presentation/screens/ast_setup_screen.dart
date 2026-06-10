import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/custom_dropdown.dart';
import '../controllers/ast_setup_controller.dart';
import 'ast_form_screen.dart';

const Color _kAstColor = Color(0xFF003366);

class AstSetupScreen extends StatelessWidget {
  const AstSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AstSetupController(),
      child: const _AstSetupView(),
    );
  }
}

class _AstSetupView extends StatelessWidget {
  const _AstSetupView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AstSetupController>();
    final fechaFmt = DateFormat('dd/MM/yyyy HH:mm').format(ctrl.fecha);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kAstColor,
        foregroundColor: Colors.white,
        title: const Text('Nuevo AST'),
      ),
      body: ctrl.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Banner(),
                  const SizedBox(height: 18),
                  _Section(
                    title: 'Ubicación',
                    children: [
                      CustomDropdown(
                        label: 'Área',
                        icon: Icons.map_outlined,
                        items: ctrl.areas
                            .map((e) => (e['nombre'] ?? '').toString())
                            .toList(),
                        value: _nombrePorId(ctrl.areas, ctrl.areaId),
                        onChanged: (nombre) =>
                            ctrl.setArea(_idPorNombre(ctrl.areas, nombre)),
                      ),
                      const SizedBox(height: 12),
                      CustomDropdown(
                        label: 'Centro',
                        icon: Icons.place_outlined,
                        items: ctrl.centros
                            .map((e) => (e['nombre'] ?? '').toString())
                            .toList(),
                        value: _nombrePorId(ctrl.centros, ctrl.centroId),
                        onChanged: (nombre) =>
                            ctrl.setCentro(_idPorNombre(ctrl.centros, nombre)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Empresa',
                    children: [
                      CustomDropdown(
                        label: 'Empresa',
                        icon: Icons.business_outlined,
                        items: ctrl.contratistas
                            .map((e) => (e['nombre'] ?? '').toString())
                            .toList(),
                        value: _nombrePorId(
                          ctrl.contratistas,
                          ctrl.contratistaId,
                        ),
                        onChanged: (nombre) => ctrl.setContratista(
                          _idPorNombre(ctrl.contratistas, nombre),
                        ),
                      ),
                      const SizedBox(height: 12),
                      CustomDropdown(
                        label: 'Embarcación (opcional)',
                        icon: Icons.directions_boat_outlined,
                        items: ctrl.embarcaciones
                            .map((e) => (e['nombre'] ?? '').toString())
                            .toList(),
                        value: _nombrePorId(
                          ctrl.embarcaciones,
                          ctrl.embarcacionId,
                        ),
                        onChanged: (nombre) => ctrl.setEmbarcacion(
                          _idPorNombre(ctrl.embarcaciones, nombre),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Datos generales',
                    children: [
                      _ReadOnlyField(
                        label: 'Profesional',
                        value: ctrl.profesional.isEmpty
                            ? '—'
                            : ctrl.profesional,
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _pickFecha(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fecha',
                            prefixIcon: Icon(Icons.event),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(fechaFmt),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (ctrl.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        ctrl.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAstColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: ctrl.isSaving
                          ? null
                          : () => _comenzar(context),
                      icon: ctrl.isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: const Text('Comenzar'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Future<void> _pickFecha(BuildContext context) async {
    final ctrl = context.read<AstSetupController>();
    final picked = await showDatePicker(
      context: context,
      initialDate: ctrl.fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(ctrl.fecha),
    );
    final time = t ?? TimeOfDay.fromDateTime(ctrl.fecha);
    ctrl.setFecha(
      DateTime(picked.year, picked.month, picked.day, time.hour, time.minute),
    );
  }

  Future<void> _comenzar(BuildContext context) async {
    final ctrl = context.read<AstSetupController>();
    if (!ctrl.validarFormulario()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona área, centro y empresa para continuar.'),
        ),
      );
      return;
    }
    final ok = await ctrl.guardarBorrador();
    if (!context.mounted) return;
    if (ok && ctrl.createdInformeId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AstFormScreen(informeId: ctrl.createdInformeId!),
        ),
      );
    }
  }

  String? _nombrePorId(List<Map<String, dynamic>> lista, String? id) {
    if (id == null) return null;
    for (final e in lista) {
      if (e['id'] == id) return (e['nombre'] ?? '').toString();
    }
    return null;
  }

  String? _idPorNombre(List<Map<String, dynamic>> lista, String? nombre) {
    if (nombre == null) return null;
    for (final e in lista) {
      if ((e['nombre'] ?? '').toString() == nombre) return e['id'] as String?;
    }
    return null;
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kAstColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: const [
          Icon(Icons.health_and_safety_outlined, color: _kAstColor),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Configura el AST. El número de informe se asignará al guardar.',
              style: TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kAstColor,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      child: Text(value),
    );
  }
}
