import 'package:flutter/material.dart';
import '../../controllers/inspection_form_controller.dart';
import '../../../domain/models/participante_model.dart';
import 'package:uuid/uuid.dart';

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
          ...controller.participantes.map((p) {
            final cargoLower = p.cargo.toLowerCase();
            final esBuzo = p.cargo.toLowerCase().contains('buzo');
            final llevaControlSalud =
                cargoLower.contains('buzo') ||
                cargoLower.contains('asistente') ||
                cargoLower.contains('supervisor');
            return Column(
              children: [
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: esBuzo
                        ? Colors.blue.shade100
                        : Colors.grey.shade200,
                    child: Icon(
                      esBuzo ? Icons.scuba_diving : Icons.person,
                      size: 20,
                      color: Colors.black54,
                    ),
                  ),
                  title: Text(
                    p.nombreCompleto,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${p.cargo} - RUT: ${p.rut}\nMatrícula: ${p.matricula}",
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (llevaControlSalud) ...[
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Cond. OK",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                              ),
                            ),
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: p.condicionesOptimas,
                                activeColor: Colors.green,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onChanged: (val) =>
                                    controller.toggleCondicionesBuzo(
                                      p.personalId,
                                      val ?? false,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                      ],
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () =>
                            controller.removerParticipante(p.personalId),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _mostrarModalAgregarBuzo(BuildContext context) {
    final nombreCtrl = TextEditingController();
    final rutCtrl = TextEditingController();
    final matriculaCtrl = TextEditingController();
    final cargoNotifier = ValueNotifier<String>('Buzo');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (ctx) {
        final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
        final systemBarHeight = MediaQuery.of(ctx).padding.bottom;

        return Padding(
          padding: EdgeInsets.only(
            bottom: keyboardHeight + systemBarHeight + 20,
            top: 25,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Agregar Integrante",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: "Nombre Completo",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: rutCtrl,
                      decoration: const InputDecoration(
                        labelText: "RUT",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: matriculaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "N° Matrícula",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              ValueListenableBuilder<String>(
                valueListenable: cargoNotifier,
                builder: (context, cargoActual, _) {
                  return DropdownButtonFormField<String>(
                    value: cargoActual,
                    decoration: const InputDecoration(
                      labelText: "Cargo",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work_outline),
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
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (nombreCtrl.text.isEmpty) return;

                    final nuevo = ParticipanteModel(
                      personalId: const Uuid().v4(),
                      nombreCompleto: nombreCtrl.text,
                      rut: rutCtrl.text,
                      cargo: cargoNotifier.value,
                      matricula: matriculaCtrl.text,
                      condicionesOptimas: true,
                    );

                    controller.agregarParticipante(nuevo);
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    "AGREGAR AL EQUIPO",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
      elevation: 4,
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
            "V. Inducción Centro de Cultivo",
            verificaciones.induccionCentroCultivo,
            (v) => controller.updateVerificacion(
              (m) => m.induccionCentroCultivo = v,
            ),
          ),
          const Divider(height: 1),
          _SwitchItem(
            "VI. Permiso de Buceo (Centro Correcto)",
            verificaciones.permisoBuceoCentroCorrecto,
            (v) => controller.updateVerificacion(
              (m) => m.permisoBuceoCentroCorrecto = v,
            ),
          ),
          const Divider(height: 1),
          _SwitchItem(
            "VII. Plan de Contingencias",
            verificaciones.planContingenciasCentroOk,
            (v) => controller.updateVerificacion(
              (m) => m.planContingenciasCentroOk = v,
            ),
          ),
          const Divider(height: 1),
          _SwitchItem(
            "VIII. Exámenes Ocupacionales Vigentes",
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

class BuceoTecnicoWidget extends StatelessWidget {
  final InspectionFormController controller;
  const BuceoTecnicoWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final verificaciones = controller.verificacionesBuceo;
    if (verificaciones == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: ExpansionTile(
        title: const Text(
          "Detalles Técnicos y Responsables",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        leading: const Icon(Icons.assignment_ind_outlined, color: Colors.blue),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. DATOS DEL INFORME
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: controller.numeroInformeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "N° Informe",
                          hintText: "Ej: 01",
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.confirmation_number),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "HORARIO AUDITORÍA",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                InkWell(
                                  onTap: () => _seleccionarHora(context, true),
                                  child: Text(
                                    controller.horaInicioController.text.isEmpty
                                        ? "--:--"
                                        : controller.horaInicioController.text,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                const Text("-"),
                                InkWell(
                                  onTap: () => _seleccionarHora(context, false),
                                  child: Text(
                                    controller
                                            .horaTerminoController
                                            .text
                                            .isEmpty
                                        ? "--:--"
                                        : controller.horaTerminoController.text,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const Divider(height: 30, thickness: 1),

                // -----------------------------------------------------------
                // 🟢 SECCIÓN CORREGIDA: CONEXIÓN DIRECTA A CONTROLADORES
                // -----------------------------------------------------------
                const Text(
                  "PERSONAL DEL CENTRO",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),

                // CAMPO 1: ENCARGADO (Usamos el controller, NO _TextInput)
                TextFormField(
                  controller: controller
                      .encargadoCentroController, // <--- ESTA ES LA CLAVE
                  decoration: const InputDecoration(
                    labelText: "Encargado de Centro",
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person, size: 20),
                  ),
                ),

                const SizedBox(height: 10),

                // CAMPO 2: SUPERVISOR (Usamos el controller, NO _TextInput)
                TextFormField(
                  controller: controller
                      .supervisorCentroController, // <--- ESTA ES LA CLAVE
                  decoration: const InputDecoration(
                    labelText: "Supervisor de Centro",
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                ),

                // -----------------------------------------------------------
                const Divider(height: 30, thickness: 1),

                // 3. PERSONAL CONTRATISTA (BUCEO)
                const Text(
                  "PERSONAL CONTRATISTA (EMPRESA BUCEO)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TextInput(
                        "Nombre Supervisor",
                        verificaciones.supervisorNombre,
                        (v) => controller.updateVerificacion(
                          (m) => m.supervisorNombre = v,
                        ),
                        icon: Icons.engineering,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TextInput(
                        "RUT Supervisor",
                        verificaciones.supervisorRut,
                        (v) => controller.updateVerificacion(
                          (m) => m.supervisorRut = v,
                        ),
                      ),
                    ),
                  ],
                ),

                const Divider(height: 30, thickness: 1),

                // 4. EQUIPOS Y COMPRESORES
                const Text(
                  "EQUIPOS Y COMPRESORES",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),

                // COMPRESOR 1
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Compresor N°1",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _TextInput(
                        "Matrícula",
                        verificaciones.compresor1Matricula,
                        (v) => controller.updateVerificacion(
                          (m) => m.compresor1Matricula = v,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: _DateInput(
                              context,
                              "Vigencia",
                              verificaciones.compresor1Vigencia,
                              (v) => controller.updateVerificacion(
                                (m) => m.compresor1Vigencia = v,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: _DateInput(
                              context,
                              "Vigencia P.H.",
                              verificaciones.compresor1VigenciaPH,
                              (v) => controller.updateVerificacion(
                                (m) => m.compresor1VigenciaPH = v,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      _TextInput(
                        "N° Buzos a cargo",
                        verificaciones.compresor1BuzosCargo?.toString(),
                        (v) => controller.updateVerificacion(
                          (m) => m.compresor1BuzosCargo = int.tryParse(v),
                        ),
                        isNumber: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // COMPRESOR 2
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Compresor N°2 (Opcional)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _TextInput(
                        "Matrícula",
                        verificaciones.compresor2Matricula,
                        (v) => controller.updateVerificacion(
                          (m) => m.compresor2Matricula = v,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: _DateInput(
                              context,
                              "Vigencia",
                              verificaciones.compresor2Vigencia,
                              (v) => controller.updateVerificacion(
                                (m) => m.compresor2Vigencia = v,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: _DateInput(
                              context,
                              "Vigencia P.H.",
                              verificaciones.compresor2VigenciaPH,
                              (v) => controller.updateVerificacion(
                                (m) => m.compresor2VigenciaPH = v,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      _TextInput(
                        "N° Buzos a cargo",
                        verificaciones.compresor2BuzosCargo?.toString(),
                        (v) => controller.updateVerificacion(
                          (m) => m.compresor2BuzosCargo = int.tryParse(v),
                        ),
                        isNumber: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- MÉTODOS AUXILIARES DENTRO DE LA CLASE ---

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

  Widget _TextInput(
    String label,
    String? val,
    Function(String) onChanged, {
    bool isNumber = false,
    IconData? icon,
  }) {
    return TextFormField(
      initialValue: val,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      ),
      onChanged: onChanged,
    );
  }

  Widget _DateInput(
    BuildContext context,
    String label,
    DateTime? val,
    Function(DateTime) onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          initialDate: val ?? DateTime.now(),
        );
        if (date != null) onChanged(date);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(
          val != null ? "${val.day}/${val.month}/${val.year}" : "-",
          style: TextStyle(
            color: val != null ? Colors.black : Colors.grey,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
