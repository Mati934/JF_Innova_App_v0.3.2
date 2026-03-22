import 'package:flutter/material.dart';
import 'package:jf_innova_app/shared/services/image_service.dart';
import 'package:jf_innova_app/shared/utils/debouncer.dart';
import '../../controllers/inspection_form_controller.dart';
import '../../../domain/models/participante_model.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../../../../../shared/widgets/custom_dropdown.dart';

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
    // 1. Lógica dinámica de cargos según el tipo de inspección
    final bool esEmbarcacion =
        controller.tipoActividad == 'INSPECCION_EMBARCACION';

    final List<String> listaCargos = esEmbarcacion
        ? ["Patrón", "Maquinista", "Tripulante", "Cocinero", "Otro"]
        : ["Supervisor", "Buzo", "Asistente"];

    final String cargoInicial =
        listaCargos.first; // Toma el primero por defecto

    final nombreCtrl = TextEditingController();
    final rutCtrl = TextEditingController();
    final matriculaCtrl = TextEditingController();
    final cargoNotifier = ValueNotifier<String>(
      cargoInicial,
    ); // 👈 Usa el dinámico

    // CONTROL DE INTEGRIDAD: Guardamos el ID histórico si lo encontramos
    String? existingPersonalId;
    final debouncer = Debouncer(milliseconds: 500);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Vital para modales con teclado
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (ctx) {
        final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
        final systemBarHeight = MediaQuery.of(ctx).padding.bottom;

        return SingleChildScrollView(
          // <-- SOLUCIÓN VISUAL: Ahora es scrollable
          child: Padding(
            padding: EdgeInsets.only(
              bottom: keyboardHeight > 0
                  ? keyboardHeight + 20
                  : systemBarHeight + 20,
              top: 25,
              left: 24,
              right: 24,
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
                const SizedBox(height: 25),
                const Text(
                  "Agregar Integrante",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003366),
                  ),
                ),
                const SizedBox(height: 25),

                // FILA RUT Y MATRÍCULA (El RUT va primero por lógica de UX)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: rutCtrl,
                        decoration: InputDecoration(
                          labelText: "RUT (Búsqueda auto)",
                          hintText: "12.345.678-9",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.badge_outlined),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (val) {
                          // <-- SOLUCIÓN LÓGICA: Debouncer + Autocompletado
                          debouncer.run(() async {
                            final encontrado = await controller
                                .buscarBuzoPorRut(val);
                            if (encontrado != null) {
                              nombreCtrl.text = encontrado.nombreCompleto;
                              matriculaCtrl.text = encontrado.matricula;
                              // Evitamos setear un cargo vacío que rompa el Dropdown
                              if (listaCargos.contains(encontrado.cargo)) {
                                cargoNotifier.value = encontrado.cargo;
                              }
                              existingPersonalId = encontrado
                                  .personalId; // Reciclamos el UUID histórico
                              debugPrint(
                                "✅ Buzo histórico encontrado y mapeado: ${encontrado.personalId}",
                              );
                            } else {
                              existingPersonalId =
                                  null; // Es un buzo realmente nuevo
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: matriculaCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "N° Matrícula",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // CAMPO NOMBRE
                TextField(
                  controller: nombreCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Nombre Completo",
                    hintText: "Ej: Juan Pérez",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 15),

                ValueListenableBuilder<String>(
                  valueListenable: cargoNotifier,
                  builder: (context, cargoActual, _) {
                    return CustomDropdown(
                      label: "Cargo",
                      items: listaCargos, // 👈 INYECTA LA LISTA DINÁMICA
                      value: cargoActual,
                      onChanged: (val) {
                        if (val != null) cargoNotifier.value = val;
                      },
                    );
                  },
                ),
                const SizedBox(height: 30),

                // BOTÓN DE ACCIÓN
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (nombreCtrl.text.trim().isEmpty ||
                          rutCtrl.text.trim().isEmpty)
                        return;

                      // LÓGICA SENIOR: Reutilizamos ID si existe, sino generamos uno
                      final nuevoId = existingPersonalId ?? const Uuid().v4();

                      final nuevo = ParticipanteModel(
                        personalId: nuevoId,
                        nombreCompleto: nombreCtrl.text.trim(),
                        rut: rutCtrl.text.trim(),
                        cargo: cargoNotifier.value,
                        matricula: matriculaCtrl.text.trim(),
                        contratistaId: controller.contratistaId, // <--- USAR CONTRATISTA DEL CONTROLLER
                        condicionesOptimas: true,
                      );

                      controller.agregarParticipante(nuevo);
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      "AGREGAR AL EQUIPO",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 200),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- WIDGET 2 ACTUALIZADO: AHORA CON FOTOS, COMENTARIOS Y GALERÍA ---
class BuceoVerificacionesWidget extends StatelessWidget {
  final InspectionFormController controller;
  const BuceoVerificacionesWidget({super.key, required this.controller});

  // CLEAN CODE: Helper para no repetir la lógica del ImageService 5 veces
  void _capturarEvidencia(
    BuildContext context,
    String nombreBase,
    Function(String) onRutaGuardada,
  ) {
    ImageService.mostrarOpciones(
      context,
      soloUna: true, // Solo necesitamos una evidencia por ítem crítico
      onFotoTomada: (File foto) {
        // Llamamos al NUEVO método del controlador que solo guarda
        controller.guardarFotoDetalleBuceo(foto, nombreBase, onRutaGuardada);
      },
      onGaleriaSeleccionada: (List<File> fotos) {
        if (fotos.isNotEmpty) {
          controller.guardarFotoDetalleBuceo(
            fotos.first,
            nombreBase,
            onRutaGuardada,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final verificaciones = controller.verificacionesBuceo;
    if (verificaciones == null) return const SizedBox.shrink();

    final isSafe = verificaciones.faenaHabilitada;

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSafe ? Colors.green : Colors.red,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // CABECERA ESTADO (Se mantiene igual tu código original de UI)
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
                            style: TextStyle(fontWeight: FontWeight.bold),
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

              // 🟢 LISTA DE CHECKS (Conectados al ImageService)
              _DetailedCheckItem(
                label: "IV. Autorización de la Faena",
                value: verificaciones.autorizacionAutoridadMaritima,
                obs: verificaciones.obsAutorizacion,
                imgPath: verificaciones.imgAutorizacion,
                onChanged: (v) => controller.updateVerificacion(
                  (m) => m.autorizacionAutoridadMaritima = v,
                ),
                onObsChanged: (v) =>
                    controller.updateVerificacion((m) => m.obsAutorizacion = v),
                onCameraTap: () => _capturarEvidencia(
                  context,
                  "autorizacion",
                  (path) => controller.updateVerificacion(
                    (m) => m.imgAutorizacion = path,
                  ),
                ),
              ),
              const Divider(height: 1),

              _DetailedCheckItem(
                label: "V. Inducción Centro de Cultivo",
                value: verificaciones.induccionCentroCultivo,
                obs: verificaciones.obsInduccion,
                imgPath: verificaciones.imgInduccion,
                onChanged: (v) => controller.updateVerificacion(
                  (m) => m.induccionCentroCultivo = v,
                ),
                onObsChanged: (v) =>
                    controller.updateVerificacion((m) => m.obsInduccion = v),
                onCameraTap: () => _capturarEvidencia(
                  context,
                  "induccion",
                  (path) => controller.updateVerificacion(
                    (m) => m.imgInduccion = path,
                  ),
                ),
              ),
              const Divider(height: 1),

              _DetailedCheckItem(
                label: "VI. Permiso de Buceo",
                value: verificaciones.permisoBuceoCentroCorrecto,
                obs: verificaciones.obsPermiso,
                imgPath: verificaciones.imgPermiso,
                onChanged: (v) => controller.updateVerificacion(
                  (m) => m.permisoBuceoCentroCorrecto = v,
                ),
                onObsChanged: (v) =>
                    controller.updateVerificacion((m) => m.obsPermiso = v),
                onCameraTap: () => _capturarEvidencia(
                  context,
                  "permiso",
                  (path) =>
                      controller.updateVerificacion((m) => m.imgPermiso = path),
                ),
              ),
              const Divider(height: 1),

              _DetailedCheckItem(
                label: "VII. Plan de Contingencias",
                value: verificaciones.planContingenciasCentroOk,
                obs: verificaciones.obsPlan,
                imgPath: verificaciones.imgPlan,
                onChanged: (v) => controller.updateVerificacion(
                  (m) => m.planContingenciasCentroOk = v,
                ),
                onObsChanged: (v) =>
                    controller.updateVerificacion((m) => m.obsPlan = v),
                onCameraTap: () => _capturarEvidencia(
                  context,
                  "plan",
                  (path) =>
                      controller.updateVerificacion((m) => m.imgPlan = path),
                ),
              ),
              const Divider(height: 1),

              _DetailedCheckItem(
                label: "VIII. Exámenes Ocupacionales",
                value: verificaciones.examenesOcupacionalesVigentes,
                obs: verificaciones.obsExamenes,
                imgPath: verificaciones.imgExamenes,
                onChanged: (v) => controller.updateVerificacion(
                  (m) => m.examenesOcupacionalesVigentes = v,
                ),
                onObsChanged: (v) =>
                    controller.updateVerificacion((m) => m.obsExamenes = v),
                onCameraTap: () => _capturarEvidencia(
                  context,
                  "examenes",
                  (path) => controller.updateVerificacion(
                    (m) => m.imgExamenes = path,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

        // TARJETA DE OBSERVACIONES GENERALES (Tu código original)
        Card(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "OBSERVACIONES GENERALES",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: verificaciones.observacionGeneral,
                  decoration: const InputDecoration(
                    hintText: "Escriba aquí...",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (val) => controller.updateVerificacion(
                    (m) => m.observacionGeneral = val,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// 🟢 WIDGET HELPER NUEVO: MANEJA LA LÓGICA DE EXPANSIÓN Y FOTOS
class _DetailedCheckItem extends StatefulWidget {
  final String label;
  final bool value;
  final String? obs;
  final String? imgPath;
  final Function(bool) onChanged;
  final Function(String) onObsChanged;
  final VoidCallback onCameraTap;

  const _DetailedCheckItem({
    required this.label,
    required this.value,
    this.obs,
    this.imgPath,
    required this.onChanged,
    required this.onObsChanged,
    required this.onCameraTap,
  });

  @override
  State<_DetailedCheckItem> createState() => _DetailedCheckItemState();
}

class _DetailedCheckItemState extends State<_DetailedCheckItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final hasData =
        (widget.obs != null && widget.obs!.isNotEmpty) ||
        (widget.imgPath != null);

    return Column(
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          // El título ocupa la mayor parte
          title: Text(
            widget.label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          // Switch a la derecha
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicador visual si hay info oculta (un puntito azul)
              if (hasData && !_isExpanded)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
              Switch(
                value: widget.value,
                activeColor: Colors.green,
                onChanged: widget.onChanged,
              ),
            ],
          ),
          // Al tocar el texto o el espacio vacío, expandimos/colapsamos
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          // Icono para indicar que se puede expandir (a la izquierda del título)
          leading: Icon(
            _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: Colors.grey,
          ),
        ),

        // ZONA DE DETALLES (Se muestra si está expandido)
        if (_isExpanded)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            color: Colors.grey.shade50, // Fondo sutil para diferenciar
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CAMPO DE TEXTO
                    Expanded(
                      child: TextFormField(
                        initialValue: widget.obs,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: "Observación / Justificación",
                          isDense: true,
                          border: OutlineInputBorder(),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        maxLines: 2,
                        onChanged: widget.onObsChanged,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // BOTÓN DE CÁMARA O MINIATURA
                    GestureDetector(
                      onTap: widget.onCameraTap,
                      child:
                          widget.imgPath != null && widget.imgPath!.isNotEmpty
                          ? Stack(
                              alignment: Alignment.topRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(widget.imgPath!),
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    cacheWidth: 150,
                                  ),
                                ),
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.refresh,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.blue,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
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
                        readOnly: true,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: "N° Informe",
                          hintText: "Auto",
                          isDense: true,
                          filled: true,
                          fillColor: Color(0xFFF0F0F0),
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
                      child: TextFormField(
                        // 1. CONECTAMOS AL CONTROLADOR (Para que se llene solo)
                        controller: controller.supervisorNombreController,
                        decoration: const InputDecoration(
                          labelText: "Nombre Supervisor",
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.engineering, size: 20),
                        ),
                        // 2. GUARDAMOS MANUALMENTE (Por si el usuario edita el texto a mano)
                        onChanged: (val) => controller.updateVerificacion(
                          (m) => m.supervisorNombre = val,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        // 1. CONECTAMOS AL CONTROLADOR
                        controller: controller.supervisorRutController,
                        decoration: const InputDecoration(
                          labelText: "RUT Supervisor",
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        // 2. GUARDAMOS MANUALMENTE
                        onChanged: (val) => controller.updateVerificacion(
                          (m) => m.supervisorRut = val,
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
          lastDate: DateTime(2100),
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
