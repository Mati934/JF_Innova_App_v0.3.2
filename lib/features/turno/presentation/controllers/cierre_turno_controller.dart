import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/services/user_session.dart';
import '../../data/local_turno_cierre_repository.dart';
import '../../domain/turno.dart';
import '../../domain/turno_cierre.dart';
import '../../services/turno_cierre_service.dart';

/// Estado de la pantalla "Cierre de turno": carga el borrador guardado o
/// calcula uno nuevo, guarda los cambios y genera el PDF.
class CierreTurnoController extends ChangeNotifier {
  final Turno turno;
  final TurnoCierreService _service;
  final LocalTurnoCierreRepository _repo;
  final DateTime Function() _ahora;

  CierreTurnoController({
    required this.turno,
    TurnoCierreService? service,
    LocalTurnoCierreRepository? repo,
    DateTime Function()? ahora,
  }) : _service = service ?? TurnoCierreService(),
       _repo = repo ?? LocalTurnoCierreRepository(),
       _ahora = ahora ?? DateTime.now;

  bool _disposed = false;
  bool cargando = true;
  bool calculando = false;
  bool generando = false;
  bool cambios = false;
  String? error;
  TurnoCierre? cierre;

  /// Sube cada vez que los datos cambian desde fuera de los campos (cálculo,
  /// filas agregadas o quitadas), para que los campos se redibujen.
  int version = 0;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> cargar() async {
    cargando = true;
    error = null;
    _safeNotify();
    try {
      cierre =
          await _repo.getPorTurno(turno.id) ??
          await _service.descargarDeTurno(turno.id);
      if (cierre == null) {
        cierre = await _service.nuevo(
          turno,
          hoy: TurnoFechas.dia(_ahora()),
          appVersion: await _appVersion(),
        );
        await _repo.guardar(cierre!);
      }
    } catch (e) {
      debugPrint('⚠️ Cierre de turno: $e');
      error =
          'No se pudieron leer tus datos del turno. Revisa tu conexión e '
          'inténtalo de nuevo.';
    }
    cargando = false;
    version++;
    _safeNotify();
  }

  Future<String?> recalcular() async {
    final c = cierre;
    if (c == null) return null;
    calculando = true;
    _safeNotify();
    try {
      cierre = await _service.recalcular(c);
      cambios = true;
      version++;
      await _repo.guardar(cierre!);
      return null;
    } catch (e) {
      debugPrint('⚠️ Recalcular cierre: $e');
      return 'No se pudo calcular: revisa tu conexión.';
    } finally {
      calculando = false;
      _safeNotify();
    }
  }

  void setNumero(String clave, String texto) {
    final c = cierre;
    if (c == null) return;
    cierre = c.copyWith(
      numeros: {...c.numeros, clave: int.tryParse(texto.trim())},
    );
    cambios = true;
  }

  void setCampo(String seccion, int fila, String campo, String texto) {
    final c = cierre;
    if (c == null) return;
    final filas = [...c.filasDe(seccion)];
    if (fila >= filas.length) return;
    filas[fila] = {...filas[fila], campo: texto};
    cierre = c.copyWith(filas: {...c.filas, seccion: filas});
    cambios = true;
  }

  void agregarFila(String seccion) {
    final c = cierre;
    if (c == null) return;
    cierre = c.copyWith(
      filas: {
        ...c.filas,
        seccion: [
          ...c.filasDe(seccion),
          CierreCampos.seccion(seccion).filaVacia(),
        ],
      },
    );
    cambios = true;
    version++;
    _safeNotify();
  }

  void quitarFila(String seccion, int fila) {
    final c = cierre;
    if (c == null) return;
    final filas = [...c.filasDe(seccion)]..removeAt(fila);
    cierre = c.copyWith(filas: {...c.filas, seccion: filas});
    cambios = true;
    version++;
    _safeNotify();
  }

  void setBitacora(String texto) {
    final c = cierre;
    if (c == null) return;
    cierre = c.copyWith(bitacora: texto);
    cambios = true;
  }

  /// Guarda en el teléfono y, si hay señal, en Supabase.
  Future<void> guardar() async {
    final c = cierre;
    if (c == null || !cambios) return;
    final actualizado = c.copyWith(updatedAt: _ahora());
    cierre = actualizado;
    await _repo.guardar(actualizado);
    cambios = false;
    _safeNotify();
    final subido = await _service.subir(actualizado);
    // Si cambió de id (otro celular ya tenía un cierre del turno) y nadie
    // editó mientras tanto, se sigue con el nuevo.
    if (subido != null && subido.id != actualizado.id && !cambios) {
      cierre = subido;
      _safeNotify();
    }
  }

  /// Null si se generó; si no, el motivo.
  Future<String?> generarPdf({required String area}) async {
    final c = cierre;
    if (c == null) return 'No hay cierre para generar.';
    generando = true;
    _safeNotify();
    try {
      cambios = true;
      await guardar();
      await _service.guardarContactos(cierre!, c.usuarioId);
      cierre = await _service.generarPdf(
        cierre!,
        profesional: UserSession().nombreCompleto ?? 'Profesional',
        area: area,
      );
      cambios = false;
      return null;
    } catch (e) {
      debugPrint('⚠️ PDF cierre de turno: $e');
      return 'No se pudo generar el PDF. Revisa tu conexión e inténtalo de '
          'nuevo (los datos quedaron guardados).';
    } finally {
      generando = false;
      _safeNotify();
    }
  }

  static Future<String?> _appVersion() async {
    try {
      return 'v${(await PackageInfo.fromPlatform()).version}';
    } catch (_) {
      return null;
    }
  }
}
