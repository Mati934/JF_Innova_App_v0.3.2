import 'package:flutter/material.dart';

import '../../domain/models/extintor_grid_controller.dart';
import '../../domain/models/prosesso_extintor_state.dart';

class ProsessoExtintorCard extends StatelessWidget {
  final ExtintorGridController controller;
  final int index;
  final ExtintorProsessoState extintor;

  const ProsessoExtintorCard({
    super.key,
    required this.controller,
    required this.index,
    required this.extintor,
  });

  @override
  Widget build(BuildContext context) {
    final completo = extintor.estaCompleto;
    final conNc = extintor.puntosNC.isNotEmpty;
    final color = conNc
        ? Colors.red
        : completo
        ? Colors.green
        : Colors.orange;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => controller.toggleExpandido(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color,
                    child: Text(
                      '${extintor.numero}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          extintor.tipo?.isNotEmpty == true
                              ? '${extintor.tipo} - ${extintor.peso ?? ""}${extintor.kg ?? ""}'
                              : 'Extintor #${extintor.numero}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${extintor.puntosCompletados}/${extintor.totalPuntos} puntos · Cert: ${extintor.certificado ?? "-"}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    extintor.expandido ? Icons.expand_less : Icons.expand_more,
                  ),
                ],
              ),
            ),
          ),
          if (extintor.expandido) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: _AccionesRow(
                puedeClonarse: index > 0,
                onTodoCumple: () => controller.marcarTodoCumple(index),
                onClonar: () => controller.clonarDelAnterior(index),
                onDuplicar: () => controller.duplicarExtintor(index),
                onEliminar: () => _confirmarEliminar(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                children: [
                  _metadataGrid(),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Checklist',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...extintor.puntos.map(_buildPunto),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Observaciones',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                    controller:
                        TextEditingController(
                            text: extintor.observaciones ?? '',
                          )
                          ..selection = TextSelection.collapsed(
                            offset: (extintor.observaciones ?? '').length,
                          ),
                    onChanged: (v) => controller.updateObservaciones(index, v),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metadataGrid() {
    Widget tf(
      String label,
      String? value,
      void Function(String) onChanged, {
      TextInputType? kb,
      double flex = 1,
    }) {
      final c = TextEditingController(text: value ?? '');
      c.selection = TextSelection.collapsed(offset: (value ?? '').length);
      return Expanded(
        flex: (flex * 10).round(),
        child: TextField(
          controller: c,
          keyboardType: kb,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13),
          onChanged: onChanged,
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            tf(
              'Planta',
              extintor.planta,
              (v) => controller.updatePlanta(index, v),
            ),
            const SizedBox(width: 8),
            tf(
              'Ubicación',
              extintor.ubicacion,
              (v) => controller.updateUbicacion(index, v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            tf(
              'Sector',
              extintor.ubicacionSector,
              (v) => controller.updateSector(index, v),
            ),
            const SizedBox(width: 8),
            tf(
              'Ubicación 2',
              extintor.ubicacion2,
              (v) => controller.updateUbic2(index, v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            tf(
              'Certificado',
              extintor.certificado,
              (v) => controller.updateCertificado(index, v),
              flex: 1.4,
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 7,
              child: _AnioPickerField(
                value: extintor.anio,
                onChanged: (a) =>
                    controller.updateAnio(index, a?.toString() ?? ''),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 10,
              child: _TipoExtintorField(
                value: extintor.tipo,
                onChanged: (v) => controller.updateTipo(index, v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            tf(
              'Peso',
              extintor.peso,
              (v) => controller.updatePeso(index, v),
              kb: TextInputType.number,
              flex: 0.8,
            ),
            const SizedBox(width: 8),
            tf(
              'Unidad',
              extintor.kg,
              (v) => controller.updateKg(index, v),
              flex: 0.7,
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 15,
              child: _FechaVencField(
                value: extintor.fechaVencimiento,
                onChanged: (s) => controller.updateFechaVenc(index, s),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPunto(PuntoProsessoState p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(p.pregunta, style: const TextStyle(fontSize: 13)),
          ),
          _estadoBtn(p, EstadoPuntoProsesso.cumple, 'C', Colors.green),
          _estadoBtn(p, EstadoPuntoProsesso.noCumple, 'NC', Colors.red),
          _estadoBtn(p, EstadoPuntoProsesso.noAplica, 'N/A', Colors.grey),
        ],
      ),
    );
  }

  Widget _estadoBtn(
    PuntoProsessoState p,
    EstadoPuntoProsesso target,
    String label,
    Color color,
  ) {
    final selected = p.estado == target;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.bold,
          ),
        ),
        selected: selected,
        selectedColor: color,
        backgroundColor: color.withValues(alpha: 0.1),
        onSelected: (_) => controller.responderPunto(index, p.itemId, target),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Future<void> _confirmarEliminar(BuildContext context) async {
    const rojo = Color(0xFFC8102E);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: rojo),
            const SizedBox(width: 8),
            Text('Eliminar Extintor #${extintor.numero}'),
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
            style: ElevatedButton.styleFrom(backgroundColor: rojo),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok == true) controller.eliminarExtintor(index);
  }
}

/// Selector de a\u00f1o (de fabricaci\u00f3n / certificado) basado en bottom sheet.
/// Reemplaza al input num\u00e9rico para evitar errores de tipeo.
class _AnioPickerField extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _AnioPickerField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final selected = await _pickYear(context, current: value);
        if (selected != null) onChanged(selected);
      },
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'A\u00f1o',
          border: OutlineInputBorder(),
          isDense: true,
          suffixIcon: Icon(Icons.arrow_drop_down, size: 22),
        ),
        child: Text(
          value?.toString() ?? '',
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Future<int?> _pickYear(BuildContext context, {int? current}) {
    final actual = DateTime.now().year;
    // Rango razonable para extintores: \u00faltimos 25 a\u00f1os hasta 2 a\u00f1os adelante.
    final years = List<int>.generate(28, (i) => actual + 2 - i);
    return showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Selecciona el año',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: years.length,
                    itemBuilder: (_, i) {
                      final y = years[i];
                      final selected = y == current;
                      return ListTile(
                        dense: true,
                        title: Text(y.toString()),
                        trailing: selected
                            ? const Icon(Icons.check, color: Colors.red)
                            : null,
                        onTap: () => Navigator.pop(ctx, y),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Selector de fecha de vencimiento (solo MES y AÑO).
/// Persiste el string como `MM/yyyy`. Mantiene compatibilidad de lectura
/// con el formato anterior `dd/MM/yyyy` (lo normaliza al re-seleccionar).
class _FechaVencField extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const _FechaVencField({required this.value, required this.onChanged});

  /// Acepta `MM/yyyy` o legacy `dd/MM/yyyy`.
  ({int month, int year})? _parse(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split('/');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]);
      final y = int.tryParse(parts[1]);
      if (m == null || y == null) return null;
      if (m < 1 || m > 12) return null;
      return (month: m, year: y);
    }
    if (parts.length == 3) {
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (m == null || y == null) return null;
      if (m < 1 || m > 12) return null;
      return (month: m, year: y);
    }
    return null;
  }

  String _format(int month, int year) =>
      '${month.toString().padLeft(2, '0')}/$year';

  static const _meses = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  @override
  Widget build(BuildContext context) {
    final actual = _parse(value);
    return InkWell(
      onTap: () async {
        final picked = await _pickMonthYear(
          context,
          currentMonth: actual?.month,
          currentYear: actual?.year,
        );
        if (picked != null) onChanged(_format(picked.month, picked.year));
      },
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'F. Vencimiento',
          border: OutlineInputBorder(),
          isDense: true,
          suffixIcon: Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(
          actual == null ? '' : '${_meses[actual.month - 1]} ${actual.year}',
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Future<({int month, int year})?> _pickMonthYear(
    BuildContext context, {
    int? currentMonth,
    int? currentYear,
  }) {
    final hoy = DateTime.now();
    int year = currentYear ?? hoy.year;
    int? month = currentMonth;
    return showModalBottomSheet<({int month, int year})>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Selecciona mes y año',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => setSt(() => year--),
                        ),
                        Text(
                          year.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => setSt(() => year++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.2,
                      children: List.generate(12, (i) {
                        final m = i + 1;
                        final selected = m == month;
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            month = m;
                            Navigator.pop(ctx, (month: m, year: year));
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFC8102E)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFFC8102E)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _meses[i],
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Selector de tipo de extintor: PQS / CO2 / Otro (con campo libre).
class _TipoExtintorField extends StatefulWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const _TipoExtintorField({required this.value, required this.onChanged});

  @override
  State<_TipoExtintorField> createState() => _TipoExtintorFieldState();
}

class _TipoExtintorFieldState extends State<_TipoExtintorField> {
  static const _opcionesFijas = ['PQS', 'CO2'];
  late final TextEditingController _otroCtrl;
  late String _seleccion; // 'PQS' | 'CO2' | 'Otro'

  @override
  void initState() {
    super.initState();
    final v = (widget.value ?? '').trim();
    if (v.isEmpty) {
      _seleccion = 'PQS';
      _otroCtrl = TextEditingController();
    } else if (_opcionesFijas.contains(v.toUpperCase())) {
      _seleccion = v.toUpperCase();
      _otroCtrl = TextEditingController();
    } else {
      _seleccion = 'Otro';
      _otroCtrl = TextEditingController(text: v);
    }
  }

  @override
  void didUpdateWidget(covariant _TipoExtintorField old) {
    super.didUpdateWidget(old);
    final nuevo = (widget.value ?? '').trim();
    final actual = _seleccion == 'Otro' ? _otroCtrl.text.trim() : _seleccion;
    if (nuevo != actual) {
      if (nuevo.isEmpty) {
        _seleccion = 'PQS';
        _otroCtrl.text = '';
      } else if (_opcionesFijas.contains(nuevo.toUpperCase())) {
        _seleccion = nuevo.toUpperCase();
        _otroCtrl.text = '';
      } else {
        _seleccion = 'Otro';
        _otroCtrl.text = nuevo;
      }
    }
  }

  @override
  void dispose() {
    _otroCtrl.dispose();
    super.dispose();
  }

  void _emitir() {
    final v = _seleccion == 'Otro' ? _otroCtrl.text.trim() : _seleccion;
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final mostrarTexto = _seleccion == 'Otro';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _seleccion,
          isDense: true,
          decoration: const InputDecoration(
            labelText: 'Tipo',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: const [
            DropdownMenuItem(value: 'PQS', child: Text('PQS')),
            DropdownMenuItem(value: 'CO2', child: Text('CO2')),
            DropdownMenuItem(value: 'Otro', child: Text('Otro')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _seleccion = v);
            _emitir();
          },
        ),
        if (mostrarTexto) ...[
          const SizedBox(height: 6),
          TextField(
            controller: _otroCtrl,
            decoration: const InputDecoration(
              labelText: 'Especificar',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (_) => _emitir(),
          ),
        ],
      ],
    );
  }
}

/// Fila de acciones rápidas (estilo extintores module).
class _AccionesRow extends StatelessWidget {
  final bool puedeClonarse;
  final VoidCallback onTodoCumple;
  final VoidCallback onClonar;
  final VoidCallback onDuplicar;
  final VoidCallback onEliminar;

  const _AccionesRow({
    required this.puedeClonarse,
    required this.onTodoCumple,
    required this.onClonar,
    required this.onDuplicar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    const rojo = Color(0xFFC8102E);
    return Row(
      children: [
        Expanded(
          child: _ProsessoPill(
            icon: Icons.check_circle_outline,
            label: 'Todo Cumple',
            color: Colors.green.shade700,
            onTap: onTodoCumple,
          ),
        ),
        const SizedBox(width: 6),
        if (puedeClonarse) ...[
          Expanded(
            child: _ProsessoPill(
              icon: Icons.copy_all_outlined,
              label: 'Igual anterior',
              color: Colors.blue.shade700,
              onTap: onClonar,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: _ProsessoPill(
            icon: Icons.content_copy_outlined,
            label: 'Replicar datos',
            color: Colors.deepPurple.shade400,
            onTap: onDuplicar,
          ),
        ),
        const SizedBox(width: 6),
        _ProsessoPill(
          icon: Icons.delete_outline,
          label: '',
          color: rojo,
          onTap: onEliminar,
          iconOnly: true,
        ),
      ],
    );
  }
}

class _ProsessoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool iconOnly;

  const _ProsessoPill({
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
          height: 34,
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
