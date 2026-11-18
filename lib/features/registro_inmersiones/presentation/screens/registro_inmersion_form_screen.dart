import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/services/image_service.dart';
import '../../../../shared/utils/debouncer.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../../../inspection/domain/models/participante_model.dart';
import '../../../../shared/widgets/form_inputs/gallery_input.dart';
import '../../../../core/utils/rut_utils.dart';
import '../../data/repositories/local_registro_inmersion_repository.dart';
import '../../domain/models/registro_inmersion_models.dart';
import '../controllers/registro_inmersion_form_controller.dart';
import '../widgets/selector_inspeccion_buceo.dart';

export '../widgets/selector_inspeccion_buceo.dart' show kRegistroInmersionColor;

const Color _rojo = Color(0xFFC62828);

class RegistroInmersionFormScreen extends StatefulWidget {
  final String? registroId;
  final String? actividadId;
  final String origen;

  const RegistroInmersionFormScreen({
    super.key,
    this.registroId,
    this.actividadId,
    this.origen = RegistroInmersionOrigen.tarjetaInicio,
  });

  @override
  State<RegistroInmersionFormScreen> createState() =>
      _RegistroInmersionFormScreenState();
}

class _RegistroInmersionFormScreenState
    extends State<RegistroInmersionFormScreen> {
  late final RegistroInmersionFormController _ctrl;
  bool _saliendo = false;
  bool _cerrando = false;

  @override
  void initState() {
    super.initState();
    _ctrl = RegistroInmersionFormController(
      registroId: widget.registroId,
      actividadId: widget.actividadId,
      origen: widget.origen,
    )..init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _salir() async {
    if (_saliendo) return;
    _saliendo = true;
    if (!_ctrl.soloLectura) {
      await _cerrarEdicion();
      if (_ctrl.estaVacio) {
        // "Nuevo registro" sin nada escrito: no deja un borrador en blanco.
        await _ctrl.descartarSiVacio();
      } else {
        await _ctrl.guardarBorradorSilencioso();
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Quita el foco y pregunta por los excesos pendientes antes de salir o
  /// finalizar, para que el aviso no aparezca sobre otra pantalla.
  Future<void> _cerrarEdicion() async {
    _cerrando = true;
    FocusScope.of(context).unfocus();
    for (final id in _ctrl.buzosConExcesoSinPreguntar()) {
      if (!mounted) break;
      await _revisarExceso(id, forzado: true);
    }
    _cerrando = false;
  }

  Future<void> _finalizar() async {
    await _cerrarEdicion();
    if (!mounted) return;
    final falta = _ctrl.validarParaFinalizar();
    if (falta != null) {
      _snack(falta, Colors.orange.shade800);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar registro'),
        content: const Text(
          'Una vez finalizado no podrás editarlo. El número y el PDF se '
          'generan al sincronizar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final exito = await _ctrl.finalizar();
    if (!mounted) return;
    if (exito) {
      _saliendo = true;
      _snack(
        'Registro finalizado. Se sincronizará en segundo plano.',
        Colors.green,
      );
      Navigator.of(context).pop();
    } else if (_ctrl.errorMessage != null) {
      _snack(_ctrl.errorMessage!, Colors.red.shade700);
      _ctrl.clearError();
    }
  }

  void _snack(String texto, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(texto), backgroundColor: color));
  }

  /// Pregunta si se marca en rojo cuando el buzo supera la autorizada.
  Future<void> _revisarExceso(String buzoId, {bool forzado = false}) async {
    if (!forzado && _cerrando) return;
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    if (!_ctrl.debePreguntarExceso(buzoId)) return;
    final aut = RegistroInmersionCalculos.formatoMetros(_ctrl.autorizada);
    final marcar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: _rojo),
        title: const Text('Profundidad superada'),
        content: Text(
          'El buzo bajó más de la profundidad permitida ($aut m). '
          '¿Desea marcarlo en rojo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _rojo),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, marcar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _ctrl.setMarcadoRojo(buzoId, marcar == true);
  }

  Future<void> _revisarTodos() async {
    for (final id in _ctrl.buzosConExcesoSinPreguntar()) {
      if (!mounted) break;
      await _revisarExceso(id);
    }
  }

  Future<void> _vincular() async {
    FocusScope.of(context).unfocus();
    final actividadId = await elegirInspeccionBuceo(context);
    if (actividadId == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vincular a la inspección'),
        content: const Text(
          'El centro, el contratista y la fecha pasan a ser los de la '
          'inspección, y se agregan sus buzos. Después no se puede '
          'desvincular.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vincular'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final antes = _ctrl.buzos.length;
    final error = await _ctrl.vincularInspeccion(actividadId);
    if (!mounted) return;
    if (error != null) {
      _snack(error, Colors.red.shade700);
      return;
    }
    final nuevos = _ctrl.buzos.length - antes;
    _snack(
      nuevos > 0
          ? 'Vinculado. Se agregaron $nuevos buzo(s) de la cuadrilla.'
          : 'Vinculado a la inspección.',
      Colors.green,
    );
  }

  Future<void> _agregarPersona() async {
    final res = await showModalBottomSheet<_NuevaPersona>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AgregarPersonaSheet(
        disponibles: _ctrl.cuadrillaDisponible,
        buscarPorRut: _ctrl.buscarPersonalPorRut,
      ),
    );
    if (res == null) return;
    _ctrl.agregarPersona(
      nombre: res.nombre,
      rut: res.rut,
      cargo: res.cargo,
      personalId: res.personalId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: kRegistroInmersionColor,
          foregroundColor: Colors.white,
          title: const Text('Registro de inmersiones'),
        ),
        body: ListenableBuilder(
          listenable: _ctrl,
          builder: (context, _) {
            if (_ctrl.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!_ctrl.cargado) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _ctrl.errorMessage ?? 'No se pudo abrir el registro.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return _cuerpo(context);
          },
        ),
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    final r = _ctrl.registro;
    final lectura = _ctrl.soloLectura;
    final bloqueado = lectura || _ctrl.isSaving || _ctrl.isProcessingPhotos;
    // SafeArea abajo: "Ver PDF" y "Finalizar" no quedan bajo los botones de
    // navegación de Android.
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Encabezado(
              // Se reconstruye al vincular (cambian centro y N° de inspección).
              key: ValueKey(r.actividadId),
              registro: r,
              readOnly: lectura,
              onAutorizadaChanged: _ctrl.setProfundidadAutorizada,
              onAutorizadaLista: _revisarTodos,
              ctrl: _ctrl,
              onVincular: bloqueado ? null : _vincular,
            ),
            if (lectura)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  (r.correlativo ?? '').isEmpty
                      ? 'Finalizado. El número y el PDF llegan al sincronizar.'
                      : 'Finalizado (${r.correlativo}). Solo lectura.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            const SizedBox(height: 16),
            _titulo('Personas (${_ctrl.buzos.length})'),
            if (_ctrl.buzos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Agrega a las personas que bucearon.'),
              ),
            for (final b in _ctrl.buzos)
              _BuzoCard(
                key: ValueKey(b.id),
                buzo: b,
                ctrl: _ctrl,
                readOnly: bloqueado,
                onProfundidadLista: () => _revisarExceso(b.id),
              ),
            if (!lectura)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: bloqueado ? null : _agregarPersona,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Agregar persona'),
              ),
            const SizedBox(height: 16),
            _titulo('Observación general'),
            TextField(
              controller: _ctrl.observacionCtrl,
              readOnly: lectura,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Comentarios generales de la faena (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _titulo('Galería general'),
            GalleryInput(
              images: _ctrl.fotosGenerales,
              onImagesChanged: _ctrl.setFotosGenerales,
              readOnly: bloqueado,
            ),
            if (_ctrl.isProcessingPhotos)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Procesando fotos...'),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _ctrl.isSaving || _ctrl.isProcessingPhotos
                        ? null
                        : () => _ctrl.previsualizar(context),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Ver PDF'),
                  ),
                ),
                if (!lectura) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: kRegistroInmersionColor,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: bloqueado ? null : _finalizar,
                      icon: _ctrl.isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Finalizar'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _titulo(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  );
}

class _Encabezado extends StatelessWidget {
  final RegistroInmersion registro;
  final bool readOnly;
  final ValueChanged<String> onAutorizadaChanged;
  final VoidCallback onAutorizadaLista;
  final RegistroInmersionFormController ctrl;
  final VoidCallback? onVincular;
  const _Encabezado({
    super.key,
    required this.registro,
    required this.readOnly,
    required this.onAutorizadaChanged,
    required this.onAutorizadaLista,
    required this.ctrl,
    required this.onVincular,
  });

  @override
  Widget build(BuildContext context) {
    final aut = registro.profundidadAutorizadaM;
    final vinculado = registro.vinculado;
    final filas = <List<String>>[
      ['Fecha', DateFormat('dd/MM/yyyy').format(registro.fechaRealizacion)],
      [
        'Inspección',
        vinculado
            ? 'N° ${registro.numeroInspeccion ?? 'pendiente de sync'}'
            : 'Sin inspección vinculada',
      ],
      if (readOnly) ...[
        ['Centro', registro.centroNombre ?? '—'],
        ['Contratista', registro.contratistaNombre ?? '—'],
        [
          'Prof. autorizada',
          aut == null
              ? '—'
              : '${RegistroInmersionCalculos.formatoMetros(aut)} m',
        ],
      ],
    ];
    final centros = ctrl.centrosPorEtiqueta.keys.toList();
    final contratistas = ctrl.contratistas
        .map((c) => (c['nombre'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList();
    // Un valor que no está en la lista (escrito a mano o de otra empresa)
    // igual se muestra.
    final centroActual = ctrl.centroEtiquetaActual;
    if (centroActual != null && !centros.contains(centroActual)) {
      centros.insert(0, centroActual);
    }
    final contratistaActual = registro.contratistaNombre;
    if (contratistaActual != null &&
        !contratistas.contains(contratistaActual)) {
      contratistas.insert(0, contratistaActual);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F0F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final f in filas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      f[0],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Expanded(child: Text(f[1])),
                ],
              ),
            ),
          if (!readOnly && !vinculado)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: onVincular,
                icon: const Icon(Icons.link),
                label: const Text('Vincular a una inspección de buceo'),
              ),
            ),
          if (!readOnly) ...[
            const SizedBox(height: 12),
            CustomDropdown(
              label: 'Centro',
              icon: Icons.place_outlined,
              items: centros,
              value: centroActual,
              onChanged: (v) {
                if (v != null) ctrl.setCentro(v);
              },
            ),
            CustomDropdown(
              label: 'Contratista',
              icon: Icons.business_outlined,
              hintText: 'Selecciona, busca o escribe uno nuevo…',
              items: contratistas,
              value: contratistaActual,
              onChanged: (v) {
                if (v != null) ctrl.setContratista(v);
              },
              onAddNew: ctrl.setContratista,
            ),
            Focus(
              onFocusChange: (f) {
                if (!f) onAutorizadaLista();
              },
              child: TextFormField(
                initialValue: RegistroInmersionCalculos.formatoMetros(aut),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Profundidad autorizada de la faena',
                  helperText: 'Para avisar si un buzo la supera',
                  suffixText: 'm',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
                onChanged: onAutorizadaChanged,
                onFieldSubmitted: (_) => onAutorizadaLista(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BuzoCard extends StatelessWidget {
  final RegistroInmersionBuzo buzo;
  final RegistroInmersionFormController ctrl;
  final bool readOnly;
  final VoidCallback onProfundidadLista;

  const _BuzoCard({
    super.key,
    required this.buzo,
    required this.ctrl,
    required this.readOnly,
    required this.onProfundidadLista,
  });

  @override
  Widget build(BuildContext context) {
    final rojo = buzo.marcadoRojo && buzo.excede(ctrl.autorizada);
    final cargos = {...kCargosRegistroInmersion, buzo.cargo}.toList();
    final varias = buzo.inmersiones.length > 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: rojo ? _rojo : Colors.grey.shade300,
          width: rojo ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buzo.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if ((buzo.rut ?? '').isNotEmpty)
                        Text(
                          RutUtils.format(buzo.rut!),
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                    ],
                  ),
                ),
                if (!readOnly)
                  IconButton(
                    tooltip: 'Quitar persona',
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => ctrl.quitarPersona(buzo.id),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: buzo.cargo,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cargo',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final c in cargos)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: readOnly
                        ? null
                        : (v) => v == null ? null : ctrl.setCargo(buzo.id, v),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    const Text('¿Buceó?', style: TextStyle(fontSize: 12)),
                    Switch(
                      value: buzo.realizoInmersion,
                      onChanged: readOnly
                          ? null
                          : (v) => ctrl.setRealizoInmersion(buzo.id, v),
                    ),
                  ],
                ),
              ],
            ),
            if (buzo.realizoInmersion) ...[
              for (var i = 0; i < buzo.inmersiones.length; i++)
                _InmersionFields(
                  key: ValueKey(buzo.inmersiones[i].id),
                  buzo: buzo,
                  inmersion: buzo.inmersiones[i],
                  titulo: varias ? 'Inmersión ${i + 1}' : null,
                  ctrl: ctrl,
                  readOnly: readOnly,
                  rojo: rojo && buzo.inmersiones[i].excede(ctrl.autorizada),
                  onProfundidadLista: onProfundidadLista,
                ),
              if (!readOnly)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: kRegistroInmersionColor,
                      minimumSize: const Size.fromHeight(40),
                      backgroundColor: const Color(0xFFF2F6F8),
                    ),
                    onPressed: () => ctrl.agregarInmersion(buzo.id),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar otra inmersión'),
                  ),
                ),
            ],
            _EquipoYFotos(buzo: buzo, ctrl: ctrl, readOnly: readOnly),
          ],
        ),
      ),
    );
  }
}

class _InmersionFields extends StatelessWidget {
  final RegistroInmersionBuzo buzo;
  final Inmersion inmersion;
  final String? titulo;
  final RegistroInmersionFormController ctrl;
  final bool readOnly;
  final bool rojo;
  final VoidCallback onProfundidadLista;

  const _InmersionFields({
    super.key,
    required this.buzo,
    required this.inmersion,
    required this.titulo,
    required this.ctrl,
    required this.readOnly,
    required this.rojo,
    required this.onProfundidadLista,
  });

  Future<void> _pickHora(BuildContext context, {required bool inicio}) async {
    final actual = inicio ? inmersion.horaInicio : inmersion.horaTermino;
    final min = RegistroInmersionCalculos.minutosDelDia(actual);
    final picked = await showTimePicker(
      context: context,
      initialTime: min == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: min ~/ 60, minute: min % 60),
    );
    if (picked == null) return;
    if (inicio) {
      ctrl.setHoraInicio(buzo.id, inmersion.id, picked);
    } else {
      ctrl.setHoraTermino(buzo.id, inmersion.id, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiempo = inmersion.tiempoMin;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titulo != null)
            Row(
              children: [
                Text(
                  titulo!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (!readOnly)
                  IconButton(
                    tooltip: 'Quitar inmersión',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () =>
                        ctrl.quitarInmersion(buzo.id, inmersion.id),
                  ),
              ],
            ),
          Focus(
            onFocusChange: (f) {
              if (!f) onProfundidadLista();
            },
            child: TextFormField(
              initialValue: RegistroInmersionCalculos.formatoMetros(
                inmersion.profundidadMaximaM,
              ),
              readOnly: readOnly,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                color: rojo ? _rojo : null,
                fontWeight: rojo ? FontWeight.bold : null,
              ),
              decoration: InputDecoration(
                labelText: 'Profundidad máxima',
                border: const OutlineInputBorder(),
                suffixText: 'm',
                enabledBorder: rojo
                    ? const OutlineInputBorder(
                        borderSide: BorderSide(color: _rojo),
                      )
                    : null,
              ),
              onChanged: (v) => ctrl.setProfundidad(buzo.id, inmersion.id, v),
              onFieldSubmitted: (_) => onProfundidadLista(),
            ),
          ),
          const SizedBox(height: 8),
          // Desde · Hasta · Tiempo ocupan todo el ancho, en tercios.
          Row(
            children: [
              Expanded(
                child: _HoraField(
                  label: 'Desde',
                  valor: inmersion.horaInicio,
                  onTap: readOnly
                      ? null
                      : () => _pickHora(context, inicio: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HoraField(
                  label: 'Hasta',
                  valor: inmersion.horaTermino,
                  onTap: readOnly
                      ? null
                      : () => _pickHora(context, inicio: false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tiempo',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  child: Text(
                    tiempo == null ? '—' : '$tiempo min',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HoraField extends StatelessWidget {
  final String label;
  final String? valor;
  final VoidCallback? onTap;
  const _HoraField({required this.label, required this.valor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.schedule, size: 18),
          suffixIconConstraints: const BoxConstraints(minWidth: 32),
        ),
        child: Text((valor ?? '').isEmpty ? '--:--' : valor!),
      ),
    );
  }
}

class _EquipoYFotos extends StatelessWidget {
  final RegistroInmersionBuzo buzo;
  final RegistroInmersionFormController ctrl;
  final bool readOnly;
  const _EquipoYFotos({
    required this.buzo,
    required this.ctrl,
    required this.readOnly,
  });

  void _tomar(BuildContext context, String tipo) {
    ImageService.mostrarOpciones(
      context,
      soloUna: true,
      onFotoTomada: (File f) => ctrl.setFotoBuzo(buzo.id, tipo, f),
      onGaleriaSeleccionada: (List<File> files) {
        if (files.isNotEmpty) ctrl.setFotoBuzo(buzo.id, tipo, files.first);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final conFotos = RegistroInmersionFotoTipo.porBuzo
        .where((t) => ctrl.fotoBuzo(buzo.id, t) != null)
        .length;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        title: Text(
          'Fotos, equipo y nota'
          '${conFotos > 0 ? ' · $conFotos foto(s)' : ''}',
          style: const TextStyle(fontSize: 14),
        ),
        children: [
          Row(
            children: [
              for (final tipo in RegistroInmersionFotoTipo.porBuzo)
                Expanded(
                  child: _FotoSlot(
                    etiqueta: RegistroInmersionFotoTipo.etiqueta(tipo),
                    foto: ctrl.fotoBuzo(buzo.id, tipo),
                    onTap: readOnly ? null : () => _tomar(context, tipo),
                    onQuitar: readOnly
                        ? null
                        : () => ctrl.quitarFotoBuzo(buzo.id, tipo),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const _Subtitulo('Profundímetro'),
          Row(
            children: [
              Expanded(
                child: _texto(
                  'Marca',
                  buzo.profundimetroMarca,
                  (v) => ctrl.setProfundimetroMarca(buzo.id, v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _texto(
                  'N° de serie',
                  buzo.profundimetroSerie,
                  (v) => ctrl.setProfundimetroSerie(buzo.id, v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _Subtitulo('Registrador (Sensus Ultra)'),
          _texto(
            'N° de serie',
            buzo.dispositivoSerie,
            (v) => ctrl.setDispositivoSerie(buzo.id, v),
          ),
          const SizedBox(height: 12),
          _texto(
            'Nota adicional',
            buzo.nota,
            (v) => ctrl.setNota(buzo.id, v),
            maxLines: 2,
            maxLength: 300,
          ),
        ],
      ),
    );
  }

  Widget _texto(
    String label,
    String? inicial,
    ValueChanged<String> onChanged, {
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextFormField(
      initialValue: inicial ?? '',
      readOnly: readOnly,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }
}

class _Subtitulo extends StatelessWidget {
  final String texto;
  const _Subtitulo(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      texto,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade800,
      ),
    ),
  );
}

class _FotoSlot extends StatelessWidget {
  final String etiqueta;
  final File? foto;
  final VoidCallback? onTap;
  final VoidCallback? onQuitar;
  const _FotoSlot({
    required this.etiqueta,
    required this.foto,
    this.onTap,
    this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.antiAlias,
                child: foto == null
                    ? Icon(
                        Icons.add_a_photo_outlined,
                        color: Colors.grey.shade600,
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(foto!, fit: BoxFit.cover),
                          if (onQuitar != null)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: InkWell(
                                onTap: onQuitar,
                                child: const CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Colors.black54,
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            etiqueta,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _NuevaPersona {
  final String nombre;
  final String? rut;
  final String cargo;
  final String? personalId;
  const _NuevaPersona({
    required this.nombre,
    required this.cargo,
    this.rut,
    this.personalId,
  });
}

/// Agregar una persona: de la cuadrilla de la inspección o por RUT (busca en
/// el personal registrado, igual que la cuadrilla de la inspección de buceo,
/// y completa el nombre).
class _AgregarPersonaSheet extends StatefulWidget {
  final List<ParticipanteCuadrilla> disponibles;
  final Future<ParticipanteModel?> Function(String rut) buscarPorRut;
  const _AgregarPersonaSheet({
    required this.disponibles,
    required this.buscarPorRut,
  });

  @override
  State<_AgregarPersonaSheet> createState() => _AgregarPersonaSheetState();
}

class _AgregarPersonaSheetState extends State<_AgregarPersonaSheet> {
  final _nombre = TextEditingController();
  final _rut = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 400);
  String _cargo = 'Buzo';
  String? _rutError;
  String? _personalId;
  bool _encontrado = false;

  @override
  void dispose() {
    _debouncer.cancel();
    _nombre.dispose();
    _rut.dispose();
    super.dispose();
  }

  void _onRut(String val) {
    final n = RutUtils.normalize(val);
    setState(() {
      _rutError = n.length >= 8 && !RutUtils.isValid(val)
          ? 'RUT inválido'
          : null;
      if (_encontrado) {
        // Cambió el RUT: lo autocompletado ya no corresponde.
        _encontrado = false;
        _personalId = null;
        _nombre.clear();
      }
    });
    if (n.length < 8 || !RutUtils.isValid(val)) return;
    _debouncer.run(() async {
      final p = await widget.buscarPorRut(val);
      if (!mounted || p == null) return;
      if (RutUtils.normalize(_rut.text) != RutUtils.normalize(p.rut)) return;
      setState(() {
        _nombre.text = p.nombreCompleto;
        _personalId = p.personalId;
        _encontrado = true;
        if (kCargosRegistroInmersion.contains(p.cargo)) _cargo = p.cargo;
      });
    });
  }

  Future<void> _agregar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) return;
    final rut = RutUtils.normalize(_rut.text);
    if (rut.isNotEmpty && !RutUtils.isValid(_rut.text)) {
      setState(() => _rutError = 'RUT inválido');
      return;
    }
    if (rut.isNotEmpty && _personalId == null) {
      // Tocó "Agregar" antes de que terminara la búsqueda por RUT.
      _debouncer.cancel();
      _personalId = (await widget.buscarPorRut(_rut.text))?.personalId;
      if (!mounted) return;
    }
    Navigator.pop(
      context,
      _NuevaPersona(
        nombre: nombre,
        rut: rut.isEmpty ? null : rut,
        cargo: _cargo,
        personalId: _personalId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Agregar persona',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              CustomDropdown(
                label: 'Cargo',
                items: kCargosRegistroInmersion,
                value: _cargo,
                enableSearch: false,
                onChanged: (v) => setState(() => _cargo = v ?? 'Buzo'),
              ),
              if (widget.disponibles.isNotEmpty) ...[
                const _Subtitulo('De la cuadrilla de la inspección'),
                for (final p in widget.disponibles)
                  Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(p.nombre),
                      subtitle: Text(
                        [
                          p.rol,
                          if ((p.rut ?? '').isNotEmpty) RutUtils.format(p.rut),
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.add),
                      onTap: () => Navigator.pop(
                        context,
                        _NuevaPersona(
                          nombre: p.nombre,
                          rut: p.rut,
                          cargo: _cargo,
                          personalId: p.personalId,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const _Subtitulo('Otra persona'),
              ],
              TextField(
                controller: _rut,
                inputFormatters: [RutInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'RUT (busca y completa)',
                  hintText: '12.345.678-9',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: const OutlineInputBorder(),
                  errorText: _rutError,
                  helperText: _encontrado
                      ? 'Encontrado en el personal registrado'
                      : null,
                  suffixIcon: _encontrado
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
                onChanged: _onRut,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kRegistroInmersionColor,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _agregar,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Agregar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
