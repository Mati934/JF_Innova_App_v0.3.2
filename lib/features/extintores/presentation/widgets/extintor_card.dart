import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/form_inputs/gallery_input.dart';
import '../../domain/models/extintor_state.dart';
import 'punto_extintor_row.dart';

const Color _kExtintorRed = Color(0xFFC62828);

/// Tarjeta de un extintor (rediseñada).
/// - Header limpio con nº, matrícula y progreso visual.
/// - Acciones rápidas (Todo Cumple / Igual al anterior / Eliminar) en pills.
/// - Contenido expandible organizado en subsecciones:
///   "Datos del Extintor" (grid 2 cols) · "Checklist" · "Foto".
class ExtintorCard extends StatefulWidget {
  final ExtintorState extintor;
  final int index;
  final bool puedeClonarse;
  final void Function(EstadoExtintor e, String itemId) onResponder;
  final void Function(String obs, String itemId) onObservacion;
  final VoidCallback onTodoCumple;
  final VoidCallback onClonar;
  final void Function(String matricula) onMatriculaChanged;
  final void Function(String tipoExtintor) onTipoExtintorChanged;
  final void Function(String pesoExtintor) onPesoExtintorChanged;
  final void Function(String fechaUltimaMantencion)
      onFechaUltimaMantencionChanged;
  final void Function(String fechaProximaMantencion)
      onFechaProximaMantencionChanged;
  final VoidCallback onEliminar;
  final void Function(String path) onFotoAdded;
  final void Function(int fotoIndex) onFotoRemoved;

  const ExtintorCard({
    super.key,
    required this.extintor,
    required this.index,
    required this.puedeClonarse,
    required this.onResponder,
    required this.onObservacion,
    required this.onTodoCumple,
    required this.onClonar,
    required this.onMatriculaChanged,
    required this.onTipoExtintorChanged,
    required this.onPesoExtintorChanged,
    required this.onFechaUltimaMantencionChanged,
    required this.onFechaProximaMantencionChanged,
    required this.onEliminar,
    required this.onFotoAdded,
    required this.onFotoRemoved,
  });

  @override
  State<ExtintorCard> createState() => _ExtintorCardState();
}

class _ExtintorCardState extends State<ExtintorCard> {
  late final TextEditingController _matriculaCtrl;
  late final TextEditingController _tipoExtintorCtrl;
  late final TextEditingController _pesoExtintorCtrl;
  late final TextEditingController _fechaUltimaCtrl;
  late final TextEditingController _fechaProximaCtrl;

  bool _expanded = false;

  static final DateFormat _fmtFecha = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _expanded = widget.extintor.expandido;
    _matriculaCtrl = TextEditingController(
      text: widget.extintor.matricula ?? '',
    );
    _matriculaCtrl
        .addListener(() => widget.onMatriculaChanged(_matriculaCtrl.text));
    _tipoExtintorCtrl = TextEditingController(
      text: widget.extintor.tipoExtintor ?? '',
    );
    _tipoExtintorCtrl.addListener(
      () => widget.onTipoExtintorChanged(_tipoExtintorCtrl.text),
    );
    _pesoExtintorCtrl = TextEditingController(
      text: widget.extintor.pesoExtintor ?? '',
    );
    _pesoExtintorCtrl.addListener(
      () => widget.onPesoExtintorChanged(_pesoExtintorCtrl.text),
    );
    _fechaUltimaCtrl = TextEditingController(
      text: widget.extintor.fechaUltimaMantencion ?? '',
    );
    _fechaUltimaCtrl.addListener(
      () => widget.onFechaUltimaMantencionChanged(_fechaUltimaCtrl.text),
    );
    _fechaProximaCtrl = TextEditingController(
      text: widget.extintor.fechaProximaMantencion ?? '',
    );
    _fechaProximaCtrl.addListener(
      () => widget.onFechaProximaMantencionChanged(_fechaProximaCtrl.text),
    );
  }

  @override
  void didUpdateWidget(ExtintorCard old) {
    super.didUpdateWidget(old);
    _syncCtrl(_matriculaCtrl, old.extintor.matricula, widget.extintor.matricula);
    _syncCtrl(
      _tipoExtintorCtrl,
      old.extintor.tipoExtintor,
      widget.extintor.tipoExtintor,
    );
    _syncCtrl(
      _pesoExtintorCtrl,
      old.extintor.pesoExtintor,
      widget.extintor.pesoExtintor,
    );
    _syncCtrl(
      _fechaUltimaCtrl,
      old.extintor.fechaUltimaMantencion,
      widget.extintor.fechaUltimaMantencion,
    );
    _syncCtrl(
      _fechaProximaCtrl,
      old.extintor.fechaProximaMantencion,
      widget.extintor.fechaProximaMantencion,
    );
  }

  void _syncCtrl(TextEditingController c, String? oldVal, String? newVal) {
    if (oldVal != newVal && c.text != (newVal ?? '')) {
      c.text = newVal ?? '';
    }
  }

  @override
  void dispose() {
    _fechaProximaCtrl.dispose();
    _fechaUltimaCtrl.dispose();
    _pesoExtintorCtrl.dispose();
    _tipoExtintorCtrl.dispose();
    _matriculaCtrl.dispose();
    super.dispose();
  }

  DateTime? _parseFecha(String s) {
    if (s.isEmpty) return null;
    try {
      return _fmtFecha.parseStrict(s);
    } catch (_) {
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _pickFecha(TextEditingController ctrl) async {
    final initial = _parseFecha(ctrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Selecciona la fecha',
    );
    if (picked == null) return;
    ctrl.text = _fmtFecha.format(picked);
  }

  Color _borderColor(ExtintorState e) {
    if (e.puntosNC.isNotEmpty) return _kExtintorRed.withValues(alpha: 0.5);
    if (e.estaCompleto) return Colors.green.withValues(alpha: 0.5);
    return Colors.grey.shade200;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.extintor;
    final completados = e.puntosCompletados;
    final total = e.totalPuntos;
    final progreso = total > 0 ? completados / total : 0.0;
    final hayNC = e.puntosNC.isNotEmpty;
    final completo = e.estaCompleto;

    final accentColor = hayNC
        ? _kExtintorRed
        : completo
            ? Colors.green.shade700
            : AppTheme.primaryBlue;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(e), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentColor,
                              accentColor.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '#${widget.index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (e.matricula ?? '').isEmpty
                                  ? 'Sin matrícula'
                                  : e.matricula!,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: (e.matricula ?? '').isEmpty
                                    ? Colors.grey.shade500
                                    : AppTheme.primaryBlue,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  hayNC
                                      ? Icons.warning_amber_rounded
                                      : completo
                                          ? Icons.check_circle
                                          : Icons.pending_actions,
                                  size: 13,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hayNC
                                      ? '${e.puntosNC.length} NC'
                                      : completo
                                          ? 'Completo'
                                          : 'En revisión',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$completados/$total',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                value: progreso,
                                strokeWidth: 3,
                                backgroundColor: Colors.grey.shade200,
                                valueColor:
                                    AlwaysStoppedAnimation(accentColor),
                              ),
                            ),
                            Text(
                              '${(progreso * 100).round()}%',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _AccionPill(
                          icon: Icons.check_circle_outline,
                          label: 'Todo Cumple',
                          color: Colors.green.shade700,
                          onTap: widget.onTodoCumple,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (widget.puedeClonarse)
                        Expanded(
                          child: _AccionPill(
                            icon: Icons.copy_all_outlined,
                            label: 'Igual anterior',
                            color: AppTheme.primaryBlue,
                            onTap: widget.onClonar,
                          ),
                        ),
                      const SizedBox(width: 6),
                      _AccionPill(
                        icon: Icons.delete_outline,
                        label: '',
                        color: _kExtintorRed,
                        onTap: () => _confirmarEliminar(context),
                        iconOnly: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(height: 1, color: Colors.grey.shade200),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                  child: const _SubSectionHeader(
                    icon: Icons.description_outlined,
                    title: 'Datos del Extintor',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _MiniInput(
                              controller: _matriculaCtrl,
                              label: 'Matrícula',
                              icon: Icons.badge_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MiniInput(
                              controller: _tipoExtintorCtrl,
                              label: 'Tipo (PQS/CO2…)',
                              icon: Icons.category_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniInput(
                              controller: _pesoExtintorCtrl,
                              label: 'Peso (kg)',
                              icon: Icons.scale_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MiniInput(
                              controller: _fechaUltimaCtrl,
                              label: 'Últ. mantención',
                              icon: Icons.history,
                              readOnly: true,
                              onTap: () => _pickFecha(_fechaUltimaCtrl),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _MiniInput(
                        controller: _fechaProximaCtrl,
                        label: 'Próx. mantención',
                        icon: Icons.event_available,
                        readOnly: true,
                        onTap: () => _pickFecha(_fechaProximaCtrl),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                  child: _SubSectionHeader(
                    icon: Icons.checklist,
                    title: 'Checklist ($completados/$total)',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: List.generate(e.puntos.length, (i) {
                      final punto = e.puntos[i];
                      return PuntoExtintorRow(
                        key: ValueKey('${e.localId}_${punto.itemId}'),
                        punto: punto,
                        numero: i + 1,
                        onEstadoChanged: (estado) =>
                            widget.onResponder(estado, punto.itemId),
                        onObservacionChanged: (obs) =>
                            widget.onObservacion(obs, punto.itemId),
                      );
                    }),
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                  child: const _SubSectionHeader(
                    icon: Icons.photo_camera_outlined,
                    title: 'Foto del Extintor',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  child: GalleryInput(
                    maxImages: 1,
                    images: e.fotoPaths.map((p) => File(p)).toList(),
                    onImagesChanged: (newFiles) {
                      final newPaths = newFiles.map((f) => f.path).toSet();
                      final oldPaths = e.fotoPaths.toSet();
                      for (int i = e.fotoPaths.length - 1; i >= 0; i--) {
                        if (!newPaths.contains(e.fotoPaths[i])) {
                          widget.onFotoRemoved(i);
                        }
                      }
                      for (final f in newFiles) {
                        if (!oldPaths.contains(f.path)) {
                          widget.onFotoAdded(f.path);
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarEliminar(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _kExtintorRed),
            const SizedBox(width: 8),
            Text('Eliminar Extintor #${widget.index + 1}'),
          ],
        ),
        content: const Text(
          '¿Seguro que deseas eliminar este extintor? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kExtintorRed),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmar == true) widget.onEliminar();
  }
}

class _SubSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SubSectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryBlue),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _MiniInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;

  const _MiniInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(icon, size: 16, color: Colors.grey.shade600),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppTheme.primaryBlue,
            width: 1.4,
          ),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}

class _AccionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool iconOnly;

  const _AccionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: iconOnly ? 10 : 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              if (!iconOnly) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
