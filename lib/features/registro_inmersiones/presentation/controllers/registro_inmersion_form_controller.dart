import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/user_session.dart';
import '../../../ast/presentation/controllers/ast_photo_persistence_queue.dart';
import '../../../inspection/data/repositories/local_inspection_repository.dart';
import '../../../inspection/domain/models/participante_model.dart';
import '../../../sync/services/sync_service.dart';
import '../../data/repositories/local_registro_inmersion_repository.dart';
import '../../domain/models/registro_inmersion_models.dart';
import '../../domain/models/registro_inmersion_pdf_data.dart';
import '../../services/registro_inmersion_pdf_service.dart';

/// Controlador del formulario del registro de inmersiones.
///
/// Se abre de tres formas: con [registroId] (reabrir un borrador o ver uno
/// finalizado), con [actividadId] (desde el aviso al finalizar la inspección
/// o desde la lista del módulo) o sin ninguno (registro nuevo sin inspección,
/// que se puede vincular después). Si la inspección ya tiene registro
/// vigente, se reabre ese en vez de crear otro.
class RegistroInmersionFormController extends ChangeNotifier {
  final String? registroId;
  final String? actividadId;
  final String origen;
  final LocalRegistroInmersionRepository _repo;
  final SyncService? _sync;
  final Uuid _uuid = const Uuid();
  late final AstPhotoPersistenceQueue _photoQueue = AstPhotoPersistenceQueue(
    onChanged: _safeNotify,
  );

  RegistroInmersionFormController({
    this.registroId,
    this.actividadId,
    this.origen = RegistroInmersionOrigen.tarjetaInicio,
    LocalRegistroInmersionRepository? repo,
    SyncService? sync,
  }) : _repo = repo ?? LocalRegistroInmersionRepository(),
       _sync = sync;

  bool _disposed = false;
  bool isLoading = true;
  bool isSaving = false;
  bool get isProcessingPhotos => _photoQueue.isProcessing;
  String? errorMessage;

  RegistroInmersion? _registro;
  RegistroInmersion get registro => _registro!;
  bool get cargado => _registro != null;

  List<RegistroInmersionBuzo> buzos = [];
  List<RegistroInmersionFoto> fotos = [];

  /// Cuadrilla de la inspección (para agregar personas que no eran buzos).
  List<ParticipanteCuadrilla> cuadrilla = const [];

  final TextEditingController observacionCtrl = TextEditingController();
  final Set<String> _avisoExcesoMostrado = {};
  Timer? _autoGuardado;

  /// Intervalo del autoguardado del borrador (como AST e inspección).
  static const Duration intervaloAutoguardado = Duration(seconds: 20);

  bool get soloLectura =>
      cargado && registro.estadoFinal != RegistroInmersionEstado.borrador;
  double? get autorizada => _registro?.profundidadAutorizadaM;

  Future<void> init() async {
    isLoading = true;
    _safeNotify();
    try {
      RegistroInmersionCompleto? completo;
      var esNuevo = false;
      if (registroId != null) {
        completo = await _repo.getCompleto(registroId!);
      } else if (actividadId != null) {
        final vigente = await _repo.getRegistroVigentePorActividad(
          actividadId!,
        );
        if (vigente != null) {
          completo = await _repo.getCompleto(vigente['id'].toString());
        }
      }

      final actId = completo?.registro.actividadId ?? actividadId;
      final base = actId == null ? null : await _repo.cargarInspeccion(actId);
      cuadrilla = base?.cuadrilla ?? const [];
      await _cargarListas();

      if (completo == null && registroId != null) {
        errorMessage = 'El registro ya no está en este teléfono.';
        return;
      }
      if (completo == null && actId == null) {
        completo = RegistroInmersionCompleto(
          registro: LocalRegistroInmersionRepository.nuevoSinInspeccion(
            usuarioId: UserSession().userId,
            empresaId: UserSession().empresaId,
          ),
          buzos: const [],
          fotos: const [],
        );
        esNuevo = true;
      } else if (completo == null) {
        if (base == null) {
          errorMessage =
              'No se encontró la inspección de buceo en este teléfono.';
          return;
        }
        completo = LocalRegistroInmersionRepository.nuevoDesdeInspeccion(
          base: base,
          origen: origen,
          usuarioId: UserSession().userId,
          empresaId: UserSession().empresaId,
        );
        esNuevo = true;
      } else if (base != null &&
          completo.registro.estadoFinal == RegistroInmersionEstado.borrador) {
        // El N° de la inspección pudo llegar con el sync después de crear
        // el borrador.
        completo.registro.numeroInspeccion ??= base.numeroInspeccion;
      }

      _registro = completo.registro;
      buzos = List.of(completo.buzos);
      fotos = List.of(completo.fotos);
      observacionCtrl.text = registro.observacionGeneral;
      for (final b in buzos) {
        if (b.excede(autorizada)) _avisoExcesoMostrado.add(b.id);
      }
      if (!soloLectura) {
        // Un registro nuevo queda guardado de inmediato: si la app se cierra
        // (ej. al abrir la cámara), aparece en borradores.
        if (esNuevo) await _repo.guardar(registro, buzos, fotos);
        _autoGuardado = Timer.periodic(
          intervaloAutoguardado,
          (_) => guardarBorradorSilencioso(),
        );
      }
    } catch (e, st) {
      errorMessage = 'Error cargando el registro: $e';
      debugPrint('❌ $errorMessage\n$st');
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  // --- INSPECCIÓN VINCULADA -------------------------------------------------

  /// Listas desplegables del encabezado (maestros locales).
  List<Map<String, dynamic>> centros = const [];
  List<Map<String, dynamic>> contratistas = const [];

  Future<void> _cargarListas() async {
    try {
      centros = await _repo.getCentrosEmpresa(UserSession().empresaId);
      contratistas = await _repo.getContratistas();
    } catch (e) {
      debugPrint('⚠️ No se pudieron cargar centros/contratistas: $e');
    }
  }

  /// Centro elegido de la lista (por nombre visible).
  /// Etiqueta visible -> centro. Hay centros con el mismo nombre en
  /// distintas zonas (ej. "JESUS 5" en Aysén y en Melinka): esos llevan la
  /// zona en la etiqueta para no guardar el `centro_id` equivocado.
  Map<String, Map<String, dynamic>> get centrosPorEtiqueta {
    final cuenta = <String, int>{};
    for (final c in centros) {
      final n = (c['nombre'] ?? '').toString();
      cuenta[n] = (cuenta[n] ?? 0) + 1;
    }
    final out = <String, Map<String, dynamic>>{};
    for (final c in centros) {
      final n = (c['nombre'] ?? '').toString();
      if (n.isEmpty) continue;
      final area = (c['area_nombre'] ?? '').toString();
      var etiqueta = (cuenta[n] ?? 0) > 1 && area.isNotEmpty ? '$n · $area' : n;
      if (out.containsKey(etiqueta)) etiqueta = '$etiqueta (${c['id']})';
      out[etiqueta] = c;
    }
    return out;
  }

  /// Etiqueta del centro actual (por id); si no está en la lista, su nombre.
  String? get centroEtiquetaActual {
    final id = _registro?.centroId;
    if (id != null) {
      for (final e in centrosPorEtiqueta.entries) {
        if (e.value['id']?.toString() == id) return e.key;
      }
    }
    return _registro?.centroNombre;
  }

  /// Centro elegido de la lista (por etiqueta visible).
  void setCentro(String etiqueta) {
    final c = centrosPorEtiqueta[etiqueta];
    if (c == null) return;
    registro
      ..centroId = c['id']?.toString()
      ..centroNombre = (c['nombre'] ?? '').toString();
    _safeNotify();
  }

  /// Contratista de la lista o escrito a mano (sin id).
  void setContratista(String nombre) {
    final t = nombre.trim();
    if (t.isEmpty) return;
    final clave = t.toLowerCase();
    final c = contratistas
        .where(
          (c) => (c['nombre'] ?? '').toString().trim().toLowerCase() == clave,
        )
        .firstOrNull;
    registro
      ..contratistaId = c?['id']?.toString()
      ..contratistaNombre = c?['nombre']?.toString() ?? t;
    _safeNotify();
  }

  /// Busca a la persona en el personal registrado (mismo buscador por RUT que
  /// la cuadrilla de la inspección de buceo).
  Future<ParticipanteModel?> buscarPersonalPorRut(String rut) async {
    try {
      return await LocalInspectionRepository().getPersonalByRut(rut);
    } catch (e) {
      debugPrint('⚠️ Error buscando RUT: $e');
      return null;
    }
  }

  /// Vincula el borrador a una inspección de buceo: copia centro,
  /// contratista, fecha y N° de la inspección, y agrega los buzos de la
  /// cuadrilla que no estén. Retorna el mensaje de error o null si resultó.
  Future<String?> vincularInspeccion(String nuevaActividadId) async {
    if (soloLectura) return 'El registro ya está finalizado.';
    if (registro.vinculado) return 'El registro ya está vinculado.';
    try {
      final vigente = await _repo.getRegistroVigentePorActividad(
        nuevaActividadId,
      );
      if (vigente != null && vigente['id'].toString() != registro.id) {
        return 'Esa inspección ya tiene su registro de inmersiones.';
      }
      final base = await _repo.cargarInspeccion(nuevaActividadId);
      if (base == null) {
        return 'No se encontró la inspección de buceo en este teléfono.';
      }
      registro
        ..actividadId = base.actividadId
        ..centroId = base.centroId
        ..centroNombre = base.centroNombre ?? registro.centroNombre
        ..contratistaId = base.contratistaId
        ..contratistaNombre = base.contratistaNombre
        ..numeroInspeccion = base.numeroInspeccion
        ..fechaRealizacion = base.fecha ?? registro.fechaRealizacion;
      cuadrilla = base.cuadrilla;
      buzos.addAll(
        LocalRegistroInmersionRepository.buzosDesdeCuadrilla(
          cuadrilla: base.cuadrilla,
          registroId: registro.id,
          horaInicio: _horaActual(),
          yaEstan: buzos,
        ),
      );
      _safeNotify();
      if (!await guardarBorradorSilencioso()) {
        return 'Quedó vinculado, pero no se pudo guardar todavía. '
            'Se reintenta solo en unos segundos.';
      }
      return null;
    } catch (e, st) {
      debugPrint('❌ Error vinculando inspección: $e\n$st');
      return 'No se pudo vincular la inspección: $e';
    }
  }

  // --- BUZOS -----------------------------------------------------------------

  RegistroInmersionBuzo? _buzo(String id) {
    for (final b in buzos) {
      if (b.id == id) return b;
    }
    return null;
  }

  Inmersion? _inmersion(String buzoId, String inmersionId) {
    final b = _buzo(buzoId);
    if (b == null) return null;
    for (final i in b.inmersiones) {
      if (i.id == inmersionId) return i;
    }
    return null;
  }

  /// Personas de la cuadrilla que todavía no están en el registro.
  List<ParticipanteCuadrilla> get cuadrillaDisponible {
    final usados = buzos.map((b) => b.personalId).whereType<String>().toSet();
    final nombres = buzos.map((b) => b.nombre.trim().toLowerCase()).toSet();
    return cuadrilla
        .where(
          (p) =>
              !usados.contains(p.personalId) &&
              !nombres.contains(p.nombre.trim().toLowerCase()),
        )
        .toList();
  }

  /// Borrador sin inspección y sin nada escrito (se descarta al salir).
  bool get estaVacio =>
      cargado &&
      !soloLectura &&
      !registro.vinculado &&
      buzos.isEmpty &&
      fotos.isEmpty &&
      (registro.centroNombre ?? '').isEmpty &&
      (registro.contratistaNombre ?? '').isEmpty &&
      registro.profundidadAutorizadaM == null &&
      observacionCtrl.text.trim().isEmpty;

  Future<void> descartarSiVacio() async {
    if (!estaVacio) return;
    _autoGuardado?.cancel();
    await _repo.eliminarBorrador(registro.id);
  }

  void agregarPersona({
    required String nombre,
    String? rut,
    String cargo = 'Buzo',
    String? personalId,
  }) {
    final buzoId = _uuid.v4();
    final buceo = cargo == 'Buzo' || cargo == 'Buzo de emergencia';
    buzos.add(
      RegistroInmersionBuzo(
        id: buzoId,
        registroId: registro.id,
        personalId: personalId,
        nombre: nombre.trim(),
        rut: rut,
        cargo: cargo,
        // Un buzo de emergencia normalmente no baja; si bajó, se cambia.
        realizoInmersion: cargo == 'Buzo',
        orden: buzos.length,
        inmersiones: buceo
            ? [
                Inmersion(
                  id: _uuid.v4(),
                  buzoId: buzoId,
                  registroId: registro.id,
                  horaInicio: _horaActual(),
                ),
              ]
            : [],
      ),
    );
    _safeNotify();
  }

  void quitarPersona(String buzoId) {
    buzos.removeWhere((b) => b.id == buzoId);
    fotos.removeWhere((f) => f.buzoId == buzoId);
    _avisoExcesoMostrado.remove(buzoId);
    _safeNotify();
  }

  void setCargo(String buzoId, String cargo) {
    _buzo(buzoId)?.cargo = cargo;
    _safeNotify();
  }

  void setRealizoInmersion(String buzoId, bool valor) {
    final b = _buzo(buzoId);
    if (b == null) return;
    b.realizoInmersion = valor;
    if (valor && b.inmersiones.isEmpty) {
      b.inmersiones.add(
        Inmersion(
          id: _uuid.v4(),
          buzoId: buzoId,
          registroId: registro.id,
          horaInicio: _horaActual(),
        ),
      );
    }
    _revisarExceso(b);
    _safeNotify();
  }

  void setNota(String buzoId, String v) => _buzo(buzoId)?.nota = v;
  void setProfundimetroMarca(String buzoId, String v) =>
      _buzo(buzoId)?.profundimetroMarca = v;
  void setProfundimetroSerie(String buzoId, String v) =>
      _buzo(buzoId)?.profundimetroSerie = v;
  void setDispositivoSerie(String buzoId, String v) {
    final b = _buzo(buzoId);
    if (b == null) return;
    b.dispositivoSerie = v;
    b.dispositivoTipo = v.trim().isEmpty ? null : kDispositivoSensusUltra;
  }

  // --- INMERSIONES -------------------------------------------------------------

  void agregarInmersion(String buzoId) {
    final b = _buzo(buzoId);
    if (b == null) return;
    b.inmersiones.add(
      Inmersion(
        id: _uuid.v4(),
        buzoId: buzoId,
        registroId: registro.id,
        orden: b.inmersiones.length + 1,
      ),
    );
    _safeNotify();
  }

  void quitarInmersion(String buzoId, String inmersionId) {
    final b = _buzo(buzoId);
    if (b == null || b.inmersiones.length <= 1) return;
    b.inmersiones.removeWhere((i) => i.id == inmersionId);
    _revisarExceso(b);
    _safeNotify();
  }

  void setProfundidad(String buzoId, String inmersionId, String texto) {
    final inm = _inmersion(buzoId, inmersionId);
    if (inm == null) return;
    inm.profundidadMaximaM = RegistroInmersionCalculos.parseMetros(texto);
    _revisarExceso(_buzo(buzoId)!);
    _safeNotify();
  }

  void setHoraInicio(String buzoId, String inmersionId, TimeOfDay hora) {
    final inm = _inmersion(buzoId, inmersionId);
    if (inm == null) return;
    final nueva = _formatHora(hora);
    if (nueva != inm.horaInicio) inm.horaInicioEditada = true;
    inm.horaInicio = nueva;
    _safeNotify();
  }

  void setHoraTermino(String buzoId, String inmersionId, TimeOfDay hora) {
    final inm = _inmersion(buzoId, inmersionId);
    if (inm == null) return;
    inm.horaTermino = _formatHora(hora);
    _safeNotify();
  }

  // --- EXCESO DE PROFUNDIDAD -----------------------------------------------------

  /// La inspección no la captura: la ingresa el auditor. Vacío o 0 = sin dato.
  void setProfundidadAutorizada(String texto) {
    final v = RegistroInmersionCalculos.parseMetros(texto);
    registro.profundidadAutorizadaM = (v == null || v <= 0) ? null : v;
    for (final b in buzos) {
      _revisarExceso(b);
    }
    _safeNotify();
  }

  /// Buzos que superan la autorizada y aún no se les preguntó.
  List<String> buzosConExcesoSinPreguntar() => buzos
      .where(
        (b) => b.excede(autorizada) && !_avisoExcesoMostrado.contains(b.id),
      )
      .map((b) => b.id)
      .toList();

  /// True una sola vez cuando el buzo pasa a superar la profundidad
  /// autorizada: la pantalla pregunta si se marca en rojo.
  bool debePreguntarExceso(String buzoId) {
    final b = _buzo(buzoId);
    if (b == null || !b.excede(autorizada)) return false;
    return _avisoExcesoMostrado.add(buzoId);
  }

  void setMarcadoRojo(String buzoId, bool valor) {
    _buzo(buzoId)?.marcadoRojo = valor;
    _safeNotify();
  }

  void _revisarExceso(RegistroInmersionBuzo b) {
    if (!b.excede(autorizada)) {
      _avisoExcesoMostrado.remove(b.id);
      b.marcadoRojo = false;
    }
  }

  // --- FOTOS ---------------------------------------------------------------------

  File? fotoBuzo(String buzoId, String tipo) {
    for (final f in fotos) {
      if (f.buzoId == buzoId && f.tipo == tipo && f.localPath != null) {
        final file = File(f.localPath!);
        return file.existsSync() ? file : null;
      }
    }
    return null;
  }

  Future<void> setFotoBuzo(String buzoId, String tipo, File origen) =>
      _photoQueue.track(_persistirFotoBuzo(buzoId, tipo, origen));

  Future<void> _persistirFotoBuzo(
    String buzoId,
    String tipo,
    File origen,
  ) async {
    final ruta = await _persistirFoto(origen, '${tipo.toLowerCase()}_$buzoId');
    fotos.removeWhere((f) => f.buzoId == buzoId && f.tipo == tipo);
    fotos.add(
      RegistroInmersionFoto(
        id: _uuid.v4(),
        registroId: registro.id,
        buzoId: buzoId,
        tipo: tipo,
        localPath: ruta,
      ),
    );
    _safeNotify();
    await _guardarSinEsperarFotos();
  }

  void quitarFotoBuzo(String buzoId, String tipo) {
    fotos.removeWhere((f) => f.buzoId == buzoId && f.tipo == tipo);
    _safeNotify();
  }

  List<File> get fotosGenerales => fotos
      .where((f) => f.tipo == RegistroInmersionFotoTipo.general)
      .map((f) => File(f.localPath ?? ''))
      .where((f) => f.existsSync())
      .toList();

  Future<void> setFotosGenerales(List<File> nuevas) =>
      _photoQueue.track(_persistirFotosGenerales(nuevas));

  Future<void> _persistirFotosGenerales(List<File> nuevas) async {
    final generales = <RegistroInmersionFoto>[];
    for (var i = 0; i < nuevas.length; i++) {
      final ruta = await _persistirFoto(nuevas[i], 'general');
      RegistroInmersionFoto? previa;
      for (final f in fotos) {
        if (f.tipo == RegistroInmersionFotoTipo.general &&
            f.localPath == ruta) {
          previa = f;
        }
      }
      generales.add(
        (previa ??
              RegistroInmersionFoto(
                id: _uuid.v4(),
                registroId: registro.id,
                tipo: RegistroInmersionFotoTipo.general,
                localPath: ruta,
              ))
          ..posicion = i + 1,
      );
    }
    fotos
      ..removeWhere((f) => f.tipo == RegistroInmersionFotoTipo.general)
      ..addAll(generales);
    _safeNotify();
    await _guardarSinEsperarFotos();
  }

  Future<String> _persistirFoto(File origen, String prefijo) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/registro_inmersion_img');
    if (origen.path.startsWith(folder.path)) return origen.path;
    if (!await folder.exists()) await folder.create(recursive: true);
    final destino =
        '${folder.path}/${DateTime.now().millisecondsSinceEpoch}_$prefijo.jpg';
    await origen.copy(destino);
    return destino;
  }

  // --- GUARDAR / FINALIZAR ----------------------------------------------------------

  /// Mensaje de lo que falta para finalizar, o null si está completo.
  String? validarParaFinalizar() {
    if (buzos.isEmpty) return 'Agrega al menos una persona.';
    for (final b in buzos) {
      if (b.nombre.trim().isEmpty) return 'Hay una persona sin nombre.';
      if (!b.realizoInmersion) continue;
      if (b.inmersiones.isEmpty ||
          b.inmersiones.first.profundidadMaximaM == null) {
        return 'Falta la profundidad máxima de ${b.nombre}.';
      }
    }
    return null;
  }

  void _volcar(String estado) {
    registro.observacionGeneral = observacionCtrl.text.trim();
    registro.estadoFinal = estado;
  }

  Future<bool> guardarBorradorSilencioso() async {
    if (!cargado || soloLectura || isSaving) return false;
    await _photoQueue.waitUntilIdle();
    return _guardarSinEsperarFotos();
  }

  /// Guardado del borrador sin esperar la cola de fotos (se llama desde la
  /// propia cola, al terminar de copiar una foto).
  Future<bool> _guardarSinEsperarFotos() async {
    if (_disposed || !cargado || soloLectura || isSaving) return false;
    try {
      _volcar(RegistroInmersionEstado.borrador);
      await _repo.guardar(registro, buzos, fotos);
      return true;
    } catch (e) {
      debugPrint('⚠️ Error guardando borrador de inmersiones: $e');
      return false;
    }
  }

  /// Finaliza: queda listo para subir. El número (RI-NNNN) lo asigna
  /// Supabase y el PDF se genera en el sync, con los dos números reales.
  Future<bool> finalizar() async {
    if (!cargado || soloLectura || isSaving) return false;
    final falta = validarParaFinalizar();
    if (falta != null) {
      errorMessage = falta;
      _safeNotify();
      return false;
    }
    _autoGuardado?.cancel();
    await _photoQueue.waitUntilIdle();
    isSaving = true;
    errorMessage = null;
    _safeNotify();
    try {
      _volcar(RegistroInmersionEstado.finalizado);
      await _repo.guardar(registro, buzos, fotos);
      unawaited((_sync ?? SyncService()).sincronizarTodo());
      return true;
    } catch (e, st) {
      registro.estadoFinal = RegistroInmersionEstado.borrador;
      _autoGuardado = Timer.periodic(
        intervaloAutoguardado,
        (_) => guardarBorradorSilencioso(),
      );
      errorMessage = 'Error finalizando el registro: $e';
      debugPrint('❌ $errorMessage\n$st');
      return false;
    } finally {
      isSaving = false;
      _safeNotify();
    }
  }

  Future<void> previsualizar(BuildContext context) async {
    if (!cargado) return;
    try {
      await _photoQueue.waitUntilIdle();
      registro.observacionGeneral = observacionCtrl.text.trim();
      final data = buildRegistroInmersionPdfData(
        registro: registro,
        buzos: buzos,
        fotos: fotos,
        auditor: UserSession().nombreCompleto ?? '',
        existe: (p) => File(p).existsSync(),
      );
      final bytes = await const RegistroInmersionPdfService().generar(
        data,
        empresaId: registro.empresaId,
      );
      if (!context.mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Registro de inmersiones ${data.correlativo}',
      );
    } catch (e) {
      errorMessage = 'Error generando el PDF: $e';
      _safeNotify();
    }
  }

  void clearError() {
    errorMessage = null;
    _safeNotify();
  }

  String _horaActual() => _formatHora(TimeOfDay.now());

  static String _formatHora(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _autoGuardado?.cancel();
    observacionCtrl.dispose();
    super.dispose();
  }
}
