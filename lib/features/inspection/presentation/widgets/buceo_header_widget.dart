import 'package:flutter/material.dart';
import '../../domain/models/verificacion_buceo_model.dart';

class BuceoHeaderWidget extends StatelessWidget {
  final VerificacionBuceo data;
  final Function(bool?, String) onChanged;
  final Function(String) onObservationChanged;

  const BuceoHeaderWidget({
    Key? key,
    required this.data,
    required this.onChanged,
    required this.onObservationChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50, // Color de alerta suave
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "VERIFICACIONES CRÍTICAS (Bloqueantes)",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const Divider(),
            _buildSwitch(
              "Autorización Autoridad Marítima",
              data.autorizacionAutoridadMaritima,
              'aut_maritima',
            ),
            _buildSwitch(
              "Inducción Centro Cultivo",
              data.induccionCentroCultivo,
              'induccion',
            ),
            _buildSwitch(
              "Permiso de Buceo (Centro Correcto)",
              data.permisoBuceoCentroCorrecto,
              'permiso',
            ),
            _buildSwitch(
              "Plan de Contingencias",
              data.planContingenciasCentroOk,
              'plan',
            ),
            _buildSwitch(
              "Exámenes Ocupacionales Vigentes",
              data.examenesOcupacionalesVigentes,
              'examenes',
            ),

            const SizedBox(height: 10),
            TextField(
              controller: TextEditingController(
                text: data.observacionesBloqueo,
              ),
              decoration: const InputDecoration(
                labelText: "Observaciones de Bloqueo / Suspensión",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: onObservationChanged,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch(String label, bool value, String key) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      activeColor: Colors.green,
      trackColor: MaterialStateProperty.resolveWith(
        (states) => value ? Colors.green.shade200 : Colors.red.shade200,
      ),
      onChanged: (val) => onChanged(val, key),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
