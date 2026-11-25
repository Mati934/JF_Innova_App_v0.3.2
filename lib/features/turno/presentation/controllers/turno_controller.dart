import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/services/user_session.dart';
import '../../../sync/services/sync_service.dart';
import '../../data/local_turno_cierre_repository.dart';
import '../../data/local_turno_repository.dart';
import '../../domain/turno.dart';
import '../../domain/turno_cierre.dart';

/// Datos del formulario de ingreso (nuevo o edición del turno activo).
class DatosIngreso {
  final DateTime fecha;
  final String areaId;
  final String? centroId;

  /// Null: la automática (ingreso + 13).
  final DateTime? egresoEstimado;

  const DatosIngreso({
    required this.fecha,
    required this.areaId,
    this.centroId,
    this.egresoEstimado,
  });

  DateTime get egreso =>
      TurnoFechas.dia(egresoEstimado ?? TurnoReglas.egresoEstimado(fecha));
}

/// Estado de la pantalla Turno: turno activo, turnos cerrados y acciones.
class TurnoController extends ChangeNotifier {
  final LocalTurnoRepository _repo;
  final LocalTurnoCierreRepository _cierres;
  final DatabaseHelper _dbHelper;
  final DateTime Function() _ahora;
  final String? Function() _usuarioId;
  final String? Function() _empresaId;
  final Future<void> Function() _sincronizar;

  TurnoController({
    LocalTurnoRepository? repo,
    LocalTurnoCierreRepository? cierresRepo,
    DatabaseHelper? dbHelper,
    DateTime Function()? ahora,
    String? Function()? usuarioId,
    String? Function()? empresaId,
    Future<void> Function()? sincronizar,
  }) : _repo = repo ?? LocalTurnoRepository(),
       _cierres = cierresRepo ?? LocalTurnoCierreRepository(),
       _dbHelper = dbHelper ?? DatabaseHelper.instance,
       _ahora = ahora ?? DateTime.now,
       _usuarioId = usuarioId ?? (() => UserSession().userId),
       _empresaId = empresaId ?? (() => UserSession().empresaId),
       _sincronizar =
           sincronizar ?? (() => SyncService().sincronizarTodo().then((_) {}));

  bool _disposed = false;
  bool cargando = true;
  Turno? activo;
  List<Turno> cerrados = const [];

  /// Cierre de turno (borrador o generado) por id de turno.
  Map<String, TurnoCierre> cierres = const {};
  List<Map<String, dynamic>> areas = const [];
  DateTime? ultimaSalida;
  ({String? areaId, String? centroId}) ultimaUbicacion = (
    areaId: null,
    centroId: null,
  );

  DateTime get hoy => TurnoFechas.dia(_ahora());
  String get _uid => _usuarioId() ?? '';

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> cargar() async {
    final uid = _uid;
    final r = await (
      _repo.getActivo(uid),
      _repo.getCerrados(uid),
      _cargarAreas(),
      _repo.getUltimaSalida(uid),
      _repo.getUltimaUbicacion(uid),
      _cierres.getPorUsuario(uid),
    ).wait;
    activo = r.$1;
    cerrados = r.$2;
    areas = r.$3;
    ultimaSalida = r.$4;
    ultimaUbicacion = r.$5;
    cierres = r.$6;
    cargando = false;
    _safeNotify();
  }

  /// Áreas de la empresa activa; si no tiene asignadas, todas.
  Future<List<Map<String, dynamic>>> _cargarAreas() async {
    final empresaId = _empresaId();
    if (empresaId != null && empresaId.isNotEmpty) {
      final propias = await _dbHelper.getAreasByEmpresa(empresaId);
      if (propias.isNotEmpty) return propias;
    }
    return _dbHelper.getAreas();
  }

  Future<List<Map<String, dynamic>>> centrosDe(String areaId) =>
      _dbHelper.getCentros(areaId);

  /// Primer día elegible como ingreso (el form lo usa en el selector).
  DateTime get ingresoMinimo =>
      TurnoReglas.ingresoMinimo(hoy, ultimaSalida: ultimaSalida);

  /// Null si la fecha de ingreso sirve. Al editar, dejar la misma fecha
  /// siempre sirve (un turno vencido de 20 días debe poder corregir el área).
  String? validarFechaIngreso(DateTime fecha, {Turno? editando}) {
    if (editando != null &&
        TurnoFechas.entre(editando.ingresoFecha, fecha) == 0) {
      return null;
    }
    return TurnoReglas.validarIngreso(fecha, hoy, ultimaSalida: ultimaSalida);
  }

  /// Null si se guardó; si no, el motivo.
  Future<String?> registrarIngreso(DatosIngreso d) async {
    if (activo != null) {
      return 'Ya tienes un turno activo: confirma tu salida primero.';
    }
    final error = TurnoReglas.validarIngreso(
      d.fecha,
      hoy,
      ultimaSalida: ultimaSalida,
    );
    if (error != null) return error;
    final errorEgreso = TurnoReglas.validarEgresoEstimado(d.fecha, d.egreso);
    if (errorEgreso != null) return errorEgreso;
    final ahora = _ahora();
    final fecha = TurnoFechas.dia(d.fecha);
    await _repo.guardar(
      Turno(
        id: const Uuid().v4(),
        usuarioId: _uid,
        empresaId: _empresaId(),
        areaId: d.areaId,
        centroId: d.centroId,
        estado: TurnoEstado.activo,
        ingresoFecha: fecha,
        egresoEstimado: d.egreso,
        egresoFecha: null,
        extraordinario: false,
        observacionIngreso: null,
        observacionEgreso: null,
        ingresoRegistradoAt: ahora,
        egresoRegistradoAt: null,
        appVersion: await _appVersion(),
        createdAt: ahora,
        updatedAt: ahora,
      ),
    );
    await _trasCambio();
    return null;
  }

  /// Corrige el turno activo (fechas, área y centro).
  Future<String?> editarIngreso(DatosIngreso d) async {
    final t = activo;
    if (t == null) return 'No hay un turno activo para editar.';
    final error = validarFechaIngreso(d.fecha, editando: t);
    if (error != null) return error;
    final errorEgreso = TurnoReglas.validarEgresoEstimado(d.fecha, d.egreso);
    if (errorEgreso != null) return errorEgreso;
    final fecha = TurnoFechas.dia(d.fecha);
    await _repo.guardar(
      Turno(
        id: t.id,
        usuarioId: t.usuarioId,
        empresaId: t.empresaId,
        areaId: d.areaId,
        centroId: d.centroId,
        estado: TurnoEstado.activo,
        ingresoFecha: fecha,
        egresoEstimado: d.egreso,
        egresoFecha: null,
        extraordinario: t.extraordinario,
        observacionIngreso: t.observacionIngreso,
        observacionEgreso: null,
        ingresoRegistradoAt: t.ingresoRegistradoAt,
        egresoRegistradoAt: null,
        appVersion: await _appVersion(),
        createdAt: t.createdAt,
        updatedAt: _ahora(),
      ),
    );
    await _trasCambio();
    return null;
  }

  /// Cierra el turno activo con la fecha real de salida. Después queda en
  /// solo lectura.
  Future<String?> confirmarSalida(DateTime fecha, {String? observacion}) async {
    final t = activo;
    if (t == null) return 'No hay un turno activo.';
    final error = TurnoReglas.validarSalida(fecha, t, hoy);
    if (error != null) return error;
    final ahora = _ahora();
    await _repo.guardar(
      Turno(
        id: t.id,
        usuarioId: t.usuarioId,
        empresaId: t.empresaId,
        areaId: t.areaId,
        centroId: t.centroId,
        estado: TurnoEstado.cerrado,
        ingresoFecha: t.ingresoFecha,
        egresoEstimado: t.egresoEstimado,
        egresoFecha: TurnoFechas.dia(fecha),
        extraordinario: t.extraordinario,
        observacionIngreso: t.observacionIngreso,
        observacionEgreso: _limpio(observacion),
        ingresoRegistradoAt: t.ingresoRegistradoAt,
        egresoRegistradoAt: ahora,
        appVersion: await _appVersion(),
        createdAt: t.createdAt,
        updatedAt: ahora,
      ),
    );
    await _trasCambio();
    return null;
  }

  /// Borra el turno activo (registrado por error).
  Future<void> eliminarActivo() async {
    final t = activo;
    if (t == null) return;
    await _repo.eliminar(t.id);
    await _trasCambio();
  }

  Future<void> _trasCambio() async {
    await cargar();
    // Sube en segundo plano; al terminar se recarga para mostrar "Subido".
    unawaited(
      _sincronizar()
          .catchError((Object e) => debugPrint('⚠️ Sync turno: $e'))
          .whenComplete(() {
            if (!_disposed) cargar();
          }),
    );
  }

  static String? _limpio(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static Future<String?> _appVersion() async {
    try {
      return 'v${(await PackageInfo.fromPlatform()).version}';
    } catch (_) {
      return null;
    }
  }
}
