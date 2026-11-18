import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/user_session.dart';
import '../../data/repositories/local_registro_inmersion_repository.dart';
import '../../domain/models/registro_inmersion_models.dart';
import 'registro_inmersion_form_screen.dart';

/// Tarjeta "Registro de inmersiones" de Inicio: lista las inspecciones de
/// buceo finalizadas del auditor en este teléfono, marcando cuáles ya tienen
/// registro. Es el camino "Más tarde" del aviso al finalizar la inspección.
class RegistroInmersionModuleScreen extends StatefulWidget {
  const RegistroInmersionModuleScreen({super.key});

  @override
  State<RegistroInmersionModuleScreen> createState() =>
      _RegistroInmersionModuleScreenState();
}

class _RegistroInmersionModuleScreenState
    extends State<RegistroInmersionModuleScreen> {
  final _repo = LocalRegistroInmersionRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _future = _repo.getInspeccionesBuceoDisponibles(UserSession().userId ?? '');
  }

  Future<void> _abrir(Map<String, dynamic> row) async {
    final registroId = row['registro_id']?.toString();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => registroId != null
            ? RegistroInmersionFormScreen(registroId: registroId)
            : RegistroInmersionFormScreen(
                actividadId: row['actividad_id'].toString(),
                origen: RegistroInmersionOrigen.tarjetaInicio,
              ),
      ),
    );
    if (mounted) setState(_cargar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kRegistroInmersionColor,
        foregroundColor: Colors.white,
        title: const Text('Registro de inmersiones'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data ?? const [];
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay inspecciones de buceo finalizadas en este teléfono.\n'
                  'El registro se hace a partir de una inspección de buceo.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Text(
                  'Elige la inspección de buceo',
                  style: Theme.of(context).textTheme.titleSmall,
                );
              }
              return _InspeccionTile(
                row: rows[i - 1],
                onTap: () => _abrir(rows[i - 1]),
              );
            },
          );
        },
      ),
    );
  }
}

class _InspeccionTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  const _InspeccionTile({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fecha = DateTime.tryParse(
      (row['fecha_realizacion'] ?? '').toString(),
    );
    final numero = numeroInspeccionValido(row['numero_reporte']);
    final estado = row['registro_estado']?.toString();
    final correlativo = row['registro_correlativo']?.toString();

    final (String label, Color color) = switch (estado) {
      null => ('Sin registro', Colors.grey.shade600),
      RegistroInmersionEstado.borrador => ('Borrador', Colors.orange.shade800),
      _ => (
        (correlativo ?? '').isEmpty ? 'Finalizado' : correlativo!,
        Colors.green.shade700,
      ),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE6F0F5),
          foregroundColor: kRegistroInmersionColor,
          child: Icon(Icons.scuba_diving),
        ),
        title: Text((row['centro_nombre'] ?? 'Centro sin nombre').toString()),
        subtitle: Text(
          [
            if (fecha != null) DateFormat('dd/MM/yyyy').format(fecha),
            numero != null ? 'Inspección N° $numero' : 'N° pendiente de sync',
          ].join('  ·  '),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(label, style: TextStyle(color: color, fontSize: 12)),
        ),
      ),
    );
  }
}
