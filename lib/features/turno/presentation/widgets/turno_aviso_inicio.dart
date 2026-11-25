import 'package:flutter/material.dart';

import '../../../../core/services/user_session.dart';
import '../../data/local_turno_repository.dart';
import '../../domain/turno.dart';
import '../screens/turno_module_screen.dart';

/// Aviso en Inicio con el turno activo: "En turno · día 5 de 14 · CISNES", o
/// en ámbar "Confirma tu salida" si ya pasó la salida estimada. Sin turno
/// activo no muestra nada. Se recarga cada vez que [refrescar] notifica
/// (el HomeController, al volver de un módulo o al refrescar Inicio).
class TurnoAvisoInicio extends StatefulWidget {
  final Listenable refrescar;

  const TurnoAvisoInicio({super.key, required this.refrescar});

  @override
  State<TurnoAvisoInicio> createState() => _TurnoAvisoInicioState();
}

class _TurnoAvisoInicioState extends State<TurnoAvisoInicio> {
  final _repo = LocalTurnoRepository();
  Turno? _activo;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    widget.refrescar.addListener(_cargar);
    _cargar();
  }

  @override
  void didUpdateWidget(TurnoAvisoInicio old) {
    super.didUpdateWidget(old);
    if (old.refrescar != widget.refrescar) {
      old.refrescar.removeListener(_cargar);
      widget.refrescar.addListener(_cargar);
    }
  }

  @override
  void dispose() {
    widget.refrescar.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    _cargando = true;
    try {
      final t = await _repo.getActivo(UserSession().userId ?? '');
      if (mounted &&
          (t?.id != _activo?.id || t?.updatedAt != _activo?.updatedAt)) {
        setState(() => _activo = t);
      }
    } catch (_) {
      // Un aviso no debe romper Inicio.
    } finally {
      _cargando = false;
    }
  }

  Future<void> _abrir() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TurnoModuleScreen()));
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final t = _activo;
    if (t == null) return const SizedBox.shrink();
    final hoy = TurnoFechas.dia(DateTime.now());
    final vencido = TurnoReglas.vencido(t, hoy);
    final dia = TurnoReglas.diaDelTurno(t.ingresoFecha, hoy);
    final color = vencido ? const Color(0xFFB26A00) : kTurnoColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _abrir,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Icon(
                  vencido ? Icons.warning_amber_rounded : Icons.badge_outlined,
                  color: color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vencido
                            ? 'Confirma tu salida'
                            : 'En turno · día $dia de '
                                  '${TurnoReglas.duracion(t.ingresoFecha, t.egresoEstimado)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      Text(
                        vencido
                            ? 'Tu turno terminaba el '
                                  '${TurnoFechas.legible(t.egresoEstimado)}'
                            : [
                                t.areaNombre ?? 'Área',
                                'sale ${TurnoFechas.legible(t.egresoEstimado)}',
                              ].join(' · '),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
