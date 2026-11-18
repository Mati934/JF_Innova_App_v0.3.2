import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/user_session.dart';
import '../../data/repositories/local_registro_inmersion_repository.dart';
import '../../domain/models/registro_inmersion_models.dart';

const Color kRegistroInmersionColor = Color(0xFF00507A);

/// Muestra las inspecciones de buceo del auditor que aún no tienen registro
/// de inmersiones y retorna el `actividad_id` elegido (null si cancela).
/// Si no hay ninguna, avisa con un snackbar y retorna null.
Future<String?> elegirInspeccionBuceo(
  BuildContext context, {
  LocalRegistroInmersionRepository? repo,
}) async {
  final rows = await (repo ?? LocalRegistroInmersionRepository())
      .getInspeccionesBuceoDisponibles(UserSession().userId ?? '');
  final libres = rows.where((r) => r['registro_id'] == null).toList();
  if (!context.mounted) return null;
  if (libres.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No hay inspecciones de buceo finalizadas sin registro en este '
          'teléfono.',
        ),
      ),
    );
    return null;
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Elige la inspección de buceo',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Se cargan los buzos de su cuadrilla.'),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: libres.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => InspeccionBuceoTile(
                  row: libres[i],
                  onTap: () =>
                      Navigator.pop(ctx, libres[i]['actividad_id'].toString()),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Fila de una inspección de buceo (o de un registro sin inspección) con el
/// estado de su registro de inmersiones.
class InspeccionBuceoTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  const InspeccionBuceoTile({
    super.key,
    required this.row,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fecha = DateTime.tryParse(
      (row['fecha_realizacion'] ?? '').toString(),
    );
    final vinculado = row.containsKey('actividad_id');
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
        title: Text(
          (row['centro_nombre'] ??
                  (vinculado ? 'Centro sin nombre' : 'Sin centro'))
              .toString(),
        ),
        subtitle: Text(
          [
            if (fecha != null) DateFormat('dd/MM/yyyy').format(fecha),
            if (!vinculado)
              'Sin inspección vinculada'
            else if (numero != null)
              'Inspección N° $numero'
            else
              'N° pendiente de sync',
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
