import 'package:flutter/material.dart';

import '../../../../core/services/user_session.dart';
import '../../data/repositories/local_registro_inmersion_repository.dart';
import '../../domain/models/registro_inmersion_models.dart';
import '../widgets/selector_inspeccion_buceo.dart';
import 'registro_inmersion_form_screen.dart';

/// Tarjeta "Registro de inmersiones" de Inicio: lista los registros sin
/// inspección y las inspecciones de buceo finalizadas del auditor en este
/// teléfono, marcando cuáles ya tienen registro. "Nuevo registro" pregunta si
/// se vincula a una inspección (carga sus buzos) o se hace sin inspección.
class RegistroInmersionModuleScreen extends StatefulWidget {
  const RegistroInmersionModuleScreen({super.key});

  @override
  State<RegistroInmersionModuleScreen> createState() =>
      _RegistroInmersionModuleScreenState();
}

class _RegistroInmersionModuleScreenState
    extends State<RegistroInmersionModuleScreen> {
  final _repo = LocalRegistroInmersionRepository();
  late Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)> _future;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    final uid = UserSession().userId ?? '';
    _future = (
      _repo.getRegistrosSinInspeccion(uid),
      _repo.getInspeccionesBuceoDisponibles(uid),
    ).wait;
  }

  Future<void> _nuevo() async {
    final vincular = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo registro de inmersiones'),
        content: const Text(
          '¿Deseas vincularlo a una inspección de buceo? Así se cargan solos '
          'los buzos de la cuadrilla. También puedes vincularlo después.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Sin inspección'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vincular'),
          ),
        ],
      ),
    );
    if (vincular == null || !mounted) return;
    String? actividadId;
    if (vincular) {
      actividadId = await elegirInspeccionBuceo(context, repo: _repo);
      if (actividadId == null || !mounted) return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegistroInmersionFormScreen(
          actividadId: actividadId,
          origen: RegistroInmersionOrigen.tarjetaInicio,
        ),
      ),
    );
    if (mounted) setState(_cargar);
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kRegistroInmersionColor,
        foregroundColor: Colors.white,
        onPressed: _nuevo,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo registro'),
      ),
      body:
          FutureBuilder<
            (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
          >(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final (sueltos, inspecciones) =
                  snap.data ?? (const <Map<String, dynamic>>[], const []);
              if (sueltos.isEmpty && inspecciones.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Todavía no hay registros ni inspecciones de buceo en '
                      'este teléfono.\nUsa "Nuevo registro" para empezar.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final titulo = Theme.of(context).textTheme.titleSmall;
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                children: [
                  if (sueltos.isNotEmpty) ...[
                    Text('Registros sin inspección', style: titulo),
                    for (final r in sueltos)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: InspeccionBuceoTile(
                          row: r,
                          onTap: () => _abrir(r),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (inspecciones.isNotEmpty) ...[
                    Text('Inspecciones de buceo', style: titulo),
                    for (final r in inspecciones)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: InspeccionBuceoTile(
                          row: r,
                          onTap: () => _abrir(r),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
    );
  }
}
