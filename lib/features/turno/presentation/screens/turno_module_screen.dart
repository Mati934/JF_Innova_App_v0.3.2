import 'package:flutter/material.dart';

import '../../../../shared/widgets/campo_seleccion.dart';
import '../../domain/turno.dart';
import '../../domain/turno_cierre.dart';
import '../controllers/turno_controller.dart';
import 'cierre_turno_screen.dart';

const Color kTurnoColor = Color(0xFF00695C);
const Color _kVencido = Color(0xFFB26A00);

/// Tarjeta "Turno" de Inicio: turno activo (o botón para registrar el
/// ingreso) y "Mis turnos". Plan: docs/planificacion/02_en_progreso/PLAN_TURNO.md
class TurnoModuleScreen extends StatefulWidget {
  final TurnoController? controller;

  const TurnoModuleScreen({super.key, this.controller});

  @override
  State<TurnoModuleScreen> createState() => _TurnoModuleScreenState();
}

class _TurnoModuleScreenState extends State<TurnoModuleScreen> {
  late final TurnoController _c;

  @override
  void initState() {
    super.initState();
    _c = widget.controller ?? TurnoController();
    _c.cargar();
  }

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _abrirIngreso({Turno? editar}) async {
    final datos = await showModalBottomSheet<DatosIngreso>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FormularioIngreso(controller: _c, editar: editar),
    );
    if (datos == null || !mounted) return;
    final error = editar == null
        ? await _c.registrarIngreso(datos)
        : await _c.editarIngreso(datos);
    if (!mounted) return;
    _aviso(
      error ??
          (editar == null
              ? 'Ingreso registrado. ¡Buen turno!'
              : 'Turno actualizado.'),
    );
  }

  Future<void> _confirmarSalida(Turno t) async {
    final r = await showDialog<(DateTime, String?)>(
      context: context,
      builder: (_) => _DialogoSalida(turno: t, hoy: _c.hoy),
    );
    if (r == null || !mounted) return;
    final error = await _c.confirmarSalida(r.$1, observacion: r.$2);
    if (!mounted) return;
    _aviso(error ?? 'Salida confirmada. Turno cerrado.');
  }

  Future<void> _opciones(Turno t) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Opciones del turno',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _Accion(
                  icono: Icons.assignment_turned_in_outlined,
                  titulo: 'Cierre de turno',
                  detalle: 'Prepara el informe de cierre y su PDF',
                  color: kTurnoColor,
                  onTap: () => Navigator.pop(ctx, 'cierre'),
                ),
                const SizedBox(height: 8),
                _Accion(
                  icono: Icons.edit_calendar_outlined,
                  titulo: 'Editar turno',
                  detalle: 'Cambia las fechas, el área o el centro',
                  color: kTurnoColor,
                  onTap: () => Navigator.pop(ctx, 'editar'),
                ),
                const SizedBox(height: 8),
                _Accion(
                  icono: Icons.delete_outline_rounded,
                  titulo: 'Eliminar turno',
                  detalle: 'Solo si lo registraste por error',
                  color: Colors.red.shade700,
                  onTap: () => Navigator.pop(ctx, 'eliminar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (accion == 'cierre') await _abrirCierre(t);
    if (accion == 'editar') await _abrirIngreso(editar: t);
    if (accion == 'eliminar') await _eliminar(t);
  }

  Future<void> _abrirCierre(Turno t) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CierreTurnoScreen(turno: t)),
    );
    if (mounted) await _c.cargar();
  }

  Future<void> _eliminar(Turno t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoEliminar(turno: t),
    );
    if (ok != true || !mounted) return;
    await _c.eliminarActivo();
    if (mounted) _aviso('Turno eliminado.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kTurnoColor,
        foregroundColor: Colors.white,
        title: const Text('Turno'),
      ),
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          if (_c.cargando) {
            return const Center(child: CircularProgressIndicator());
          }
          final activo = _c.activo;
          return SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: _c.cargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (activo == null)
                    _SinTurno(onRegistrar: () => _abrirIngreso())
                  else
                    _TarjetaActivo(
                      turno: activo,
                      hoy: _c.hoy,
                      onSalida: () => _confirmarSalida(activo),
                      onEditar: () => _abrirIngreso(editar: activo),
                      onOpciones: () => _opciones(activo),
                    ),
                  const SizedBox(height: 28),
                  Text(
                    'Mis turnos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_c.cerrados.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Aquí aparecerán tus turnos cuando confirmes la salida.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  else
                    for (final t in _c.cerrados)
                      _FilaCerrado(
                        turno: t,
                        cierre: _c.cierres[t.id],
                        onCierre: () => _abrirCierre(t),
                        onVerPdf: (c) => abrirPdfCierre(context, c),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Sin turno activo ────────────────────────────────────────────────────────

class _SinTurno extends StatelessWidget {
  final VoidCallback onRegistrar;

  const _SinTurno({required this.onRegistrar});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: kTurnoColor.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kTurnoColor.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          children: [
            const Icon(Icons.login_rounded, size: 44, color: kTurnoColor),
            const SizedBox(height: 12),
            Text(
              'No tienes un turno activo',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Regístralo el día que llegas a tu área.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kTurnoColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: onRegistrar,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Registrar ingreso'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Turno activo ────────────────────────────────────────────────────────────

class _TarjetaActivo extends StatelessWidget {
  final Turno turno;
  final DateTime hoy;
  final VoidCallback onSalida;
  final VoidCallback onEditar;
  final VoidCallback onOpciones;

  const _TarjetaActivo({
    required this.turno,
    required this.hoy,
    required this.onSalida,
    required this.onEditar,
    required this.onOpciones,
  });

  @override
  Widget build(BuildContext context) {
    final vencido = TurnoReglas.vencido(turno, hoy);
    final color = vencido ? _kVencido : kTurnoColor;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CabeceraActivo(
            turno: turno,
            hoy: hoy,
            color: color,
            vencido: vencido,
            onOpciones: onOpciones,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (vencido) ...[
                  const _AvisoVencido(),
                  const SizedBox(height: 14),
                ],
                _Ubicacion(turno: turno),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MiniFecha(
                        icono: Icons.login_rounded,
                        etiqueta: 'Ingreso',
                        fecha: turno.ingresoFecha,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniFecha(
                        icono: Icons.logout_rounded,
                        etiqueta: 'Salida estimada',
                        fecha: turno.egresoEstimado,
                        alerta: vencido,
                      ),
                    ),
                  ],
                ),
                if (turno.observacionIngreso != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          turno.observacionIngreso!,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: onSalida,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Confirmar salida'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kTurnoColor,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: onEditar,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        label: const Text('Editar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Parte de color: estado, "Día X de N", cuánto falta y una regla con un
/// tramo por día del turno.
class _CabeceraActivo extends StatelessWidget {
  final Turno turno;
  final DateTime hoy;
  final Color color;
  final bool vencido;
  final VoidCallback onOpciones;

  const _CabeceraActivo({
    required this.turno,
    required this.hoy,
    required this.color,
    required this.vencido,
    required this.onOpciones,
  });

  @override
  Widget build(BuildContext context) {
    final dia = TurnoReglas.diaDelTurno(turno.ingresoFecha, hoy);
    final total = TurnoReglas.duracion(
      turno.ingresoFecha,
      turno.egresoEstimado,
    );
    final faltan = TurnoFechas.entre(hoy, turno.egresoEstimado);
    final resumen = vencido
        ? 'Tu turno terminaba el ${TurnoFechas.legible(turno.egresoEstimado)}'
        : faltan == 0
        ? 'Hoy es tu último día'
        : faltan == 1
        ? 'Mañana es tu último día'
        : 'Faltan $faltan días';

    return Container(
      color: color,
      padding: const EdgeInsets.fromLTRB(18, 10, 6, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: _Pastilla(
                  icono: vencido ? Icons.warning_amber_rounded : Icons.circle,
                  iconoChico: !vencido,
                  texto: vencido ? 'Sin cerrar' : 'En turno',
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: _Pastilla(
                  icono: turno.subido
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_upload_outlined,
                  texto: turno.subido ? 'Subido' : 'Sin subir',
                  tenue: true,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Opciones del turno',
                onPressed: onOpciones,
                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: 'Día $dia',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
              children: [
                TextSpan(
                  text: ' de $total',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            resumen,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _ReglaDias(dia: dia, total: total),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Text(
                  '${turno.ingresoFecha.day} ${TurnoFechas.mes(turno.ingresoFecha)}',
                  style: _estiloExtremo,
                ),
                const Spacer(),
                Text(
                  '${turno.egresoEstimado.day} ${TurnoFechas.mes(turno.egresoEstimado)}',
                  style: _estiloExtremo,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static final _estiloExtremo = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white.withValues(alpha: 0.75),
  );
}

/// Un tramo por día: los pasados llenos, hoy más alto, los que faltan tenues.
class _ReglaDias extends StatelessWidget {
  final int dia;
  final int total;

  const _ReglaDias({required this.dia, required this.total});

  @override
  Widget build(BuildContext context) {
    // Un dato malo de la base (salida antes del ingreso) no rompe la tarjeta.
    if (total < 1) return const SizedBox.shrink();
    final hoyIdx = (dia - 1).clamp(0, total - 1);
    return SizedBox(
      height: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            Expanded(
              child: Container(
                height: i == hoyIdx ? 14 : 8,
                margin: EdgeInsets.only(right: i == total - 1 ? 0 : 3),
                decoration: BoxDecoration(
                  color: i < hoyIdx
                      ? Colors.white.withValues(alpha: 0.85)
                      : i == hoyIdx
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool iconoChico;
  final bool tenue;

  const _Pastilla({
    required this.icono,
    required this.texto,
    this.iconoChico = false,
    this.tenue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: tenue ? 0.12 : 0.20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: iconoChico ? 9 : 15, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoVencido extends StatelessWidget {
  const _AvisoVencido();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kVencido.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.event_busy_rounded, color: _kVencido),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Confirma tu salida con el día en que saliste, aunque haya sido '
              'hace unos días.',
              style: TextStyle(color: _kVencido, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ubicacion extends StatelessWidget {
  final Turno turno;

  const _Ubicacion({required this.turno});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: kTurnoColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.place_outlined, color: kTurnoColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                turno.areaNombre ?? 'Área',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                turno.centroNombre ?? 'Sin centro',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniFecha extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final DateTime fecha;
  final bool alerta;

  const _MiniFecha({
    required this.icono,
    required this.etiqueta,
    required this.fecha,
    this.alerta = false,
  });

  @override
  Widget build(BuildContext context) {
    final acento = alerta ? _kVencido : Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: alerta ? _kVencido.withValues(alpha: 0.06) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: alerta
              ? _kVencido.withValues(alpha: 0.35)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 15, color: acento),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: acento,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${fecha.day} ${TurnoFechas.mes(fecha)}',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: alerta ? _kVencido : Colors.black87,
            ),
          ),
          Text(
            TurnoFechas.nombreDia(fecha),
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

/// Fila de la hoja "Opciones del turno".
class _Accion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final Color color;
  final VoidCallback onTap;

  const _Accion({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      detalle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmación de borrado con el resumen del turno que se va a borrar.
class _DialogoEliminar extends StatelessWidget {
  final Turno turno;

  const _DialogoEliminar({required this.turno});

  @override
  Widget build(BuildContext context) {
    final rojo = Colors.red.shade700;
    final ubicacion = [
      turno.areaNombre ?? 'Área',
      if (turno.centroNombre != null) turno.centroNombre!,
    ].join(' · ');
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: rojo.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: rojo,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '¿Eliminar este turno?',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Úsalo solo si lo registraste por error. No se puede deshacer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, color: kTurnoColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ubicacion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${TurnoFechas.legible(turno.ingresoFecha)} → '
                          '${TurnoFechas.legible(turno.egresoEstimado)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: rojo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sí, eliminar'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
// ── Mis turnos ──────────────────────────────────────────────────────────────

class _FilaCerrado extends StatelessWidget {
  final Turno turno;
  final TurnoCierre? cierre;
  final VoidCallback onCierre;
  final ValueChanged<TurnoCierre> onVerPdf;

  const _FilaCerrado({
    required this.turno,
    required this.cierre,
    required this.onCierre,
    required this.onVerPdf,
  });

  @override
  Widget build(BuildContext context) {
    final salida = turno.egresoFecha!;
    final dias = TurnoReglas.diasReales(turno.ingresoFecha, salida);
    final dif = TurnoReglas.diferencia(salida, turno.egresoEstimado);
    final aTiempo = dif == 'a tiempo';
    final ubicacion = [
      turno.areaNombre ?? 'Área',
      if (turno.centroNombre != null) turno.centroNombre!,
    ].join(' · ');

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${turno.ingresoFecha.day} ${TurnoFechas.mes(turno.ingresoFecha)}'
                        ' → ${salida.day} ${TurnoFechas.mes(salida)} ${salida.year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ubicacion,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$dias ${dias == 1 ? 'día' : 'días'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      dif,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: aTiempo ? Colors.green.shade700 : _kVencido,
                      ),
                    ),
                    if (!turno.subido)
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                  ],
                ),
              ],
            ),
          ),
          _PieCierre(cierre: cierre, onCierre: onCierre, onVerPdf: onVerPdf),
        ],
      ),
    );
  }
}

/// Franja inferior de cada turno de "Mis turnos": estado del cierre y su
/// acción (hacerlo, seguirlo o ver el PDF).
class _PieCierre extends StatelessWidget {
  final TurnoCierre? cierre;
  final VoidCallback onCierre;
  final ValueChanged<TurnoCierre> onVerPdf;

  const _PieCierre({
    required this.cierre,
    required this.onCierre,
    required this.onVerPdf,
  });

  @override
  Widget build(BuildContext context) {
    final c = cierre;
    final conPdf = c != null && c.generado && c.tienePdf;
    final (icono, texto, color) = conPdf
        ? (Icons.check_circle_rounded, 'Cierre con PDF', Colors.green.shade700)
        : c != null
        ? (Icons.edit_note_rounded, 'Cierre en borrador', _kVencido)
        : (
            Icons.assignment_outlined,
            'Sin cierre de turno',
            Colors.grey.shade600,
          );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 2, 6, 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          if (conPdf) ...[
            IconButton(
              tooltip: 'Editar cierre',
              visualDensity: VisualDensity.compact,
              onPressed: onCierre,
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: Colors.grey.shade600,
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: kTurnoColor),
              onPressed: () => onVerPdf(c),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Ver PDF'),
            ),
          ] else
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: kTurnoColor),
              onPressed: onCierre,
              icon: Icon(
                c == null ? Icons.add_rounded : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(c == null ? 'Hacer cierre' : 'Continuar'),
            ),
        ],
      ),
    );
  }
}

// ── Formulario de ingreso ───────────────────────────────────────────────────

/// "Hoy", "Ayer", "Mañana", "Hace 3 días", "En 5 días".
String _relativo(DateTime fecha, DateTime hoy) {
  final d = TurnoFechas.entre(hoy, fecha);
  if (d == 0) return 'Hoy';
  if (d == -1) return 'Ayer';
  if (d == 1) return 'Mañana';
  return d < 0 ? 'Hace ${-d} días' : 'En $d días';
}

class _FormularioIngreso extends StatefulWidget {
  final TurnoController controller;
  final Turno? editar;

  const _FormularioIngreso({required this.controller, this.editar});

  @override
  State<_FormularioIngreso> createState() => _FormularioIngresoState();
}

class _FormularioIngresoState extends State<_FormularioIngreso> {
  late DateTime _fecha;
  late DateTime _egreso;
  String? _areaId;
  String? _centroId;
  List<Map<String, dynamic>> _centros = const [];
  bool _cargandoCentros = false;

  TurnoController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    final e = widget.editar;
    _fecha = e?.ingresoFecha ?? _c.hoy;
    _egreso = e?.egresoEstimado ?? TurnoReglas.egresoEstimado(_fecha);
    final idsAreas = _c.areas.map((a) => a['id'].toString()).toSet();
    final area = e?.areaId ?? _c.ultimaUbicacion.areaId;
    if (area != null && idsAreas.contains(area)) {
      _areaId = area;
      _cargandoCentros = true;
      _cargarCentros(
        area,
        preseleccion: e?.centroId ?? _c.ultimaUbicacion.centroId,
      );
    }
  }

  /// Al cambiar de área se limpia el centro y se cargan los del área nueva.
  void _cambiarArea(String areaId) {
    setState(() {
      _areaId = areaId;
      _centroId = null;
      _centros = const [];
      _cargandoCentros = true;
    });
    _cargarCentros(areaId);
  }

  Future<void> _cargarCentros(String areaId, {String? preseleccion}) async {
    final centros = await _c.centrosDe(areaId);
    if (!mounted || _areaId != areaId) return;
    setState(() {
      _centros = centros;
      _cargandoCentros = false;
      if (preseleccion != null &&
          centros.any((c) => c['id'].toString() == preseleccion)) {
        _centroId = preseleccion;
      }
    });
  }

  int get _dias => TurnoReglas.duracion(_fecha, _egreso);
  bool get _egresoAutomatico =>
      TurnoFechas.entre(TurnoReglas.egresoEstimado(_fecha), _egreso) == 0;

  Future<void> _elegirIngreso() async {
    final min = _c.ingresoMinimo;
    final hoy = _c.hoy;
    final picked = await showDatePicker(
      context: context,
      // Si el turno anterior cerró hoy, min = mañana: el picker queda en hoy
      // (el form ya muestra el error y no deja guardar).
      initialDate: _fecha.isBefore(min)
          ? (min.isAfter(hoy) ? hoy : min)
          : (_fecha.isAfter(hoy) ? hoy : _fecha),
      firstDate: min.isAfter(hoy) ? hoy : min,
      lastDate: hoy,
      helpText: 'Fecha de ingreso',
    );
    if (picked == null) return;
    // La salida se mueve con el ingreso y conserva el largo elegido.
    final dias = _dias;
    setState(() {
      _fecha = TurnoFechas.dia(picked);
      _egreso = TurnoFechas.sumar(_fecha, dias - 1);
    });
  }

  Future<void> _elegirEgreso() async {
    final max = TurnoReglas.egresoEstimado(_fecha);
    final picked = await showDatePicker(
      context: context,
      initialDate: _egreso.isAfter(max) ? max : _egreso,
      firstDate: _fecha,
      lastDate: max,
      helpText: 'Salida estimada',
    );
    if (picked != null) setState(() => _egreso = TurnoFechas.dia(picked));
  }

  @override
  Widget build(BuildContext context) {
    final hoy = _c.hoy;
    final editando = widget.editar != null;
    final error =
        _c.validarFechaIngreso(_fecha, editando: widget.editar) ??
        TurnoReglas.validarEgresoEstimado(_fecha, _egreso);
    final puede = error == null && _areaId != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editando ? 'Editar turno' : 'Registrar ingreso',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Toca una fecha para cambiarla.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 18),
              _RangoTurno(
                ingreso: _fecha,
                egreso: _egreso,
                hoy: hoy,
                automatico: _egresoAutomatico,
                onIngreso: _elegirIngreso,
                onEgreso: _elegirEgreso,
                onRestablecer: () => setState(
                  () => _egreso = TurnoReglas.egresoEstimado(_fecha),
                ),
              ),
              const SizedBox(height: 22),
              CampoSeleccion<String>(
                etiqueta: 'Área',
                icono: Icons.place_outlined,
                color: kTurnoColor,
                hint: 'Elige tu área',
                valor: _areaId,
                opciones: [
                  for (final a in _c.areas)
                    OpcionSeleccion(
                      valor: a['id'].toString(),
                      titulo: a['nombre']?.toString() ?? '',
                    ),
                ],
                onChanged: (v) {
                  if (v != _areaId) _cambiarArea(v);
                },
              ),
              const SizedBox(height: 12),
              CampoSeleccion<String?>(
                etiqueta: 'Centro',
                icono: Icons.factory_outlined,
                color: kTurnoColor,
                opcional: true,
                hint: 'Sin centro',
                habilitado: _areaId != null,
                cargando: _cargandoCentros,
                ayuda: _areaId == null ? 'Primero elige el área.' : null,
                valor: _centroId,
                opciones: [
                  const OpcionSeleccion<String?>(
                    valor: null,
                    titulo: 'Sin centro',
                    subtitulo: 'No sé o cubro varios centros',
                  ),
                  for (final c in _centros)
                    OpcionSeleccion<String?>(
                      valor: c['id'].toString(),
                      titulo: c['nombre']?.toString() ?? '',
                    ),
                ],
                onChanged: (v) => setState(() => _centroId = v),
              ),
              if (error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          error,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: kTurnoColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: puede
                      ? () => Navigator.pop(
                          context,
                          DatosIngreso(
                            fecha: _fecha,
                            areaId: _areaId!,
                            centroId: _centroId,
                            egresoEstimado: _egreso,
                          ),
                        )
                      : null,
                  icon: Icon(
                    editando ? Icons.check_rounded : Icons.login_rounded,
                  ),
                  label: Text(
                    editando ? 'Guardar cambios' : 'Registrar ingreso',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ingreso → salida, con el largo del turno y la opción de volver a la
/// salida automática si se acortó.
class _RangoTurno extends StatelessWidget {
  final DateTime ingreso;
  final DateTime egreso;
  final DateTime hoy;
  final bool automatico;
  final VoidCallback onIngreso;
  final VoidCallback onEgreso;
  final VoidCallback onRestablecer;

  const _RangoTurno({
    required this.ingreso,
    required this.egreso,
    required this.hoy,
    required this.automatico,
    required this.onIngreso,
    required this.onEgreso,
    required this.onRestablecer,
  });

  @override
  Widget build(BuildContext context) {
    final dias = TurnoReglas.duracion(ingreso, egreso);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      decoration: BoxDecoration(
        color: kTurnoColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _TarjetaFecha(
                    etiqueta: 'Ingreso',
                    fecha: ingreso,
                    etiquetaChip: _relativo(ingreso, hoy),
                    onTap: onIngreso,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: kTurnoColor,
                  ),
                ),
                Expanded(
                  child: _TarjetaFecha(
                    etiqueta: 'Salida',
                    fecha: egreso,
                    etiquetaChip: automatico ? 'Automática' : 'Ajustada',
                    chipNeutro: automatico,
                    onTap: onEgreso,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                const Icon(
                  Icons.date_range_rounded,
                  size: 18,
                  color: kTurnoColor,
                ),
                Text(
                  automatico
                      ? 'Turno de $dias días'
                      : 'Turno corto de $dias ${dias == 1 ? 'día' : 'días'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kTurnoColor,
                  ),
                ),
                if (!automatico)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: kTurnoColor,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onRestablecer,
                    child: Text('Volver a ${TurnoReglas.diasTurno}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fecha grande y tocable: "25 nov / miércoles" con una etiqueta ("Hoy").
class _TarjetaFecha extends StatelessWidget {
  final String etiqueta;
  final DateTime fecha;
  final String etiquetaChip;
  final bool chipNeutro;
  final VoidCallback onTap;
  final bool bordeado;

  const _TarjetaFecha({
    required this.etiqueta,
    required this.fecha,
    required this.etiquetaChip,
    required this.onTap,
    this.chipNeutro = false,
    this.bordeado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: bordeado
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: kTurnoColor.withValues(alpha: 0.35),
                  ),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      etiqueta,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_calendar_outlined,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${fecha.day}',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      TurnoFechas.mes(fecha),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: kTurnoColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                TurnoFechas.nombreDia(fecha),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: chipNeutro
                      ? Colors.grey.shade100
                      : kTurnoColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  etiquetaChip,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: chipNeutro ? Colors.grey.shade700 : kTurnoColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Confirmar salida ────────────────────────────────────────────────────────

class _DialogoSalida extends StatefulWidget {
  final Turno turno;
  final DateTime hoy;

  const _DialogoSalida({required this.turno, required this.hoy});

  @override
  State<_DialogoSalida> createState() => _DialogoSalidaState();
}

class _DialogoSalidaState extends State<_DialogoSalida> {
  late DateTime _fecha = TurnoReglas.salidaPropuesta(widget.turno, widget.hoy);
  final _obs = TextEditingController();

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: widget.turno.ingresoFecha,
      lastDate: widget.hoy,
      helpText: 'Fecha de salida',
    );
    if (picked != null) setState(() => _fecha = TurnoFechas.dia(picked));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.turno;
    final dias = TurnoReglas.diasReales(t.ingresoFecha, _fecha);
    final dif = TurnoReglas.diferencia(_fecha, t.egresoEstimado);

    return AlertDialog(
      title: const Text('Confirmar salida'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('¿Qué día terminaste tu turno?'),
            const SizedBox(height: 12),
            _TarjetaFecha(
              etiqueta: 'Salida',
              fecha: _fecha,
              etiquetaChip: _relativo(_fecha, widget.hoy),
              onTap: _elegirFecha,
              bordeado: true,
            ),
            const SizedBox(height: 10),
            Text(
              '$dias ${dias == 1 ? 'día' : 'días'} · $dif',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: dif == 'a tiempo' ? Colors.green.shade700 : _kVencido,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _obs,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observación (opcional)',
                hintText: 'Ej. motivo de salida anticipada',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Después de confirmar, el turno ya no se puede editar.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kTurnoColor),
          onPressed: () => Navigator.pop(context, (_fecha, _obs.text)),
          child: const Text('Confirmar salida'),
        ),
      ],
    );
  }
}
