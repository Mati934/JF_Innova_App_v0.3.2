import 'package:flutter/material.dart';
// Ajusta la ruta si es necesario
import '../../controllers/inspection_form_controller.dart';
import '../../../domain/models/participante_model.dart';

// --- WIDGET 1: CUADRILLA (Va arriba) ---
class BuceoCuadrillaWidget extends StatelessWidget {
  final InspectionFormController controller;
  const BuceoCuadrillaWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "CUADRILLA DE PERSONAL",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.blue),
                  onPressed: () => _mostrarModalAgregarBuzo(context),
                ),
              ],
            ),
          ),
          if (controller.participantes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "No hay personal registrado",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ...controller.participantes.map(
            (p) => ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  p.nombreCompleto.isNotEmpty
                      ? p.nombreCompleto.substring(0, 1)
                      : "?",
                ),
              ),
              title: Text(p.nombreCompleto),
              subtitle: Text("${p.cargo} - RUT: ${p.rut}"),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => controller.removerParticipante(p.personalId),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _mostrarModalAgregarBuzo(BuildContext context) {
    final nombreCtrl = TextEditingController();
    final rutCtrl = TextEditingController();
    final cargoNotifier = ValueNotifier<String>('Buzo');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Agregar Integrante",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: "Nombre Completo",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: rutCtrl,
              decoration: const InputDecoration(
                labelText: "RUT",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<String>(
              valueListenable: cargoNotifier,
              builder: (context, cargoActual, _) {
                return DropdownButtonFormField<String>(
                  value: cargoActual,
                  decoration: const InputDecoration(
                    labelText: "Cargo",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "Supervisor",
                      child: Text("Supervisor"),
                    ),
                    DropdownMenuItem(value: "Buzo", child: Text("Buzo")),
                    DropdownMenuItem(
                      value: "Asistente",
                      child: Text("Asistente"),
                    ),
                  ],
                  onChanged: (val) => cargoNotifier.value = val!,
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (nombreCtrl.text.isEmpty) return;
                  final nuevo = ParticipanteModel(
                    personalId: DateTime.now().millisecondsSinceEpoch
                        .toString(),
                    nombreCompleto: nombreCtrl.text,
                    rut: rutCtrl.text,
                    cargo: cargoNotifier.value,
                  );
                  controller.agregarParticipante(nuevo);
                  Navigator.pop(ctx);
                },
                child: const Text("AGREGAR"),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET 2: VERIFICACIONES (Va al final) ---
class BuceoVerificacionesWidget extends StatelessWidget {
  final InspectionFormController controller;
  const BuceoVerificacionesWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final verificaciones = controller.verificacionesBuceo;
    if (verificaciones == null) return const SizedBox.shrink();

    final isSafe = verificaciones.faenaHabilitada;

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 4, // Un poco más de sombra para destacar al final
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSafe ? Colors.green : Colors.red, width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSafe ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSafe ? Icons.check_circle : Icons.warning_amber,
                  color: isSafe ? Colors.green : Colors.red,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "ESTADO FINAL DE FAENA",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      DropdownButton<String?>(
                        value: verificaciones.estadoManual,
                        isDense: true,
                        underline: Container(),
                        isExpanded: true,
                        hint: Text(
                          isSafe
                              ? "APROBADA (Automático)"
                              : "SUSPENDIDA (Automático)",
                          style: TextStyle(
                            color: isSafe
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text("Automático"),
                          ),
                          DropdownMenuItem(
                            value: "APROBADO",
                            child: Text("Forzar APROBACIÓN"),
                          ),
                          DropdownMenuItem(
                            value: "SUSPENDIDO",
                            child: Text("Forzar SUSPENSIÓN"),
                          ),
                        ],
                        onChanged: (val) => controller.updateVerificacion(
                          (m) => m.estadoManual = val,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _SwitchItem(
            "IV. Autorización de la Faena",
            verificaciones.autorizacionAutoridadMaritima,
            (v) => controller.updateVerificacion(
              (m) => m.autorizacionAutoridadMaritima = v,
            ),
          ),
          const Divider(height: 1),
          _SwitchItem(
            "Inducción Centro de Cultivo",
            verificaciones.induccionCentroCultivo,
            (v) => controller.updateVerificacion(
              (m) => m.induccionCentroCultivo = v,
            ),
          ),
          const Divider(height: 1),
          _SwitchItem(
            "V. Permiso de Buceo (Centro Correcto)",
            verificaciones.permisoBuceoCentroCorrecto,
            (v) => controller.updateVerificacion(
              (m) => m.permisoBuceoCentroCorrecto = v,
            ),
          ),
          const Divider(height: 1),
          _SwitchItem(
            "VI. Plan de Contingencias",
            verificaciones.planContingenciasCentroOk,
            (v) => controller.updateVerificacion(
              (m) => m.planContingenciasCentroOk = v,
            ),
          ),
          const Divider(height: 1),
          _SwitchItem(
            "VII. Exámenes Ocupacionales Vigentes",
            verificaciones.examenesOcupacionalesVigentes,
            (v) => controller.updateVerificacion(
              (m) => m.examenesOcupacionalesVigentes = v,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              initialValue: verificaciones.observacionGeneral,
              decoration: const InputDecoration(
                labelText: "Observación del Prevencionista",
                prefixIcon: Icon(Icons.comment),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (val) => controller.updateVerificacion(
                (m) => m.observacionGeneral = val,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _SwitchItem(String label, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      value: value,
      activeColor: Colors.green,
      onChanged: onChanged,
    );
  }
}
