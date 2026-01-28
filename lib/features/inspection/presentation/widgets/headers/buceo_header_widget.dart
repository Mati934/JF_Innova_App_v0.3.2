import 'package:flutter/material.dart';
// Ajusta la ruta si es necesario
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
            // 1. Normalizamos el texto para no pelear con mayúsculas
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
                  // ... (El leading/avatar se queda igual con 'esBuzo') ...
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
                      // 4. CAMBIAMOS EL IF AQUÍ: Usamos 'llevaControlSalud' en vez de 'esBuzo'
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
                      // ... (Botón eliminar se queda igual)
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
                  // CAMPO MATRICULA NUEVO
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
                      personalId: const Uuid()
                          .v4(), // ✅ PONER ESTO (Genera un ID real tipo a0eebc...)
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
          "Detalles Técnicos (Compresores y Equipos)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        leading: const Icon(Icons.build_circle_outlined, color: Colors.orange),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. N° INFORME (Arriba, ancho completo)
                TextFormField(
                  controller: controller.numeroInformeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "N° Informe",
                    hintText: "Ej: 08",
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                ),

                const Divider(height: 30),

                const Text(
                  "HORARIO AUDITORÍA",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        Colors.grey, // Mismo color gris que los otros títulos
                  ),
                ),
                const SizedBox(height: 8),

                // 2. HORA INICIO y 3. HORA TÉRMINO
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: controller.horaInicioController,
                        readOnly: true,
                        onTap: () => _seleccionarHora(context, true),
                        decoration: const InputDecoration(
                          labelText: "Inicio",
                          hintText: "--:--",
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.access_time, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 3. HORA TÉRMINO
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: controller.horaTerminoController,
                        readOnly: true,
                        onTap: () => _seleccionarHora(context, false),
                        decoration: const InputDecoration(
                          labelText: "Término",
                          hintText: "--:--",
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.access_time_filled, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),

                const Divider(height: 30), // --- LÍNEA SEPARADORA
                // -----------------------------------------------------------
                // --- SUPERVISOR ---
                const Text(
                  "SUPERVISOR DE BUCEO",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _TextInput(
                        "Nombre",
                        verificaciones.supervisorNombre,
                        (v) => controller.updateVerificacion(
                          (m) => m.supervisorNombre = v,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TextInput(
                        "RUT",
                        verificaciones.supervisorRut,
                        (v) => controller.updateVerificacion(
                          (m) => m.supervisorRut = v,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),

                // --- COMPRESOR 1 ---
                const Text(
                  "COMPRESOR 1",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                _TextInput(
                  "N° Matrícula",
                  verificaciones.compresor1Matricula,
                  (v) => controller.updateVerificacion(
                    (m) => m.compresor1Matricula = v,
                  ),
                ),
                const SizedBox(height: 8),
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
                    const SizedBox(width: 10),
                    // NUEVO: VIGENCIA P.H.
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
                const SizedBox(height: 8),
                _TextInput(
                  "N° Buzos",
                  verificaciones.compresor1BuzosCargo?.toString(),
                  (v) => controller.updateVerificacion(
                    (m) => m.compresor1BuzosCargo = int.tryParse(v),
                  ),
                  isNumber: true,
                ),
                const Divider(height: 30),

                // --- COMPRESOR 2 (Opcional) ---
                const Text(
                  "COMPRESOR 2",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                _TextInput(
                  "N° Matrícula",
                  verificaciones.compresor2Matricula,
                  (v) => controller.updateVerificacion(
                    (m) => m.compresor2Matricula = v,
                  ),
                ),
                const SizedBox(height: 8),
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
                    const SizedBox(width: 10),
                    // NUEVO: VIGENCIA P.H.
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
                const SizedBox(height: 8),
                _TextInput(
                  "N° Buzos",
                  verificaciones.compresor2BuzosCargo?.toString(),
                  (v) => controller.updateVerificacion(
                    (m) => m.compresor2BuzosCargo = int.tryParse(v),
                  ),
                  isNumber: true,
                ),

                // (YA NO ESTÁ EL CERTIFICADO DE INSPECCIÓN AQUÍ)
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Lógica para mostrar el reloj
  Future<void> _seleccionarHora(BuildContext context, bool isInicio) async {
    final initial = controller.getHoraInicialReloj(isInicio);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          // Opcional: Forzar 24h
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
  }) {
    return TextFormField(
      initialValue: val,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
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
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          val != null ? "${val.day}/${val.month}/${val.year}" : "Seleccionar",
          style: TextStyle(color: val != null ? Colors.black : Colors.grey),
        ),
      ),
    );
  }
}
