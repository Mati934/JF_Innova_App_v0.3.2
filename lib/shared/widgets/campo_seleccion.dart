import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Una opción de [CampoSeleccion]. `valor` puede ser null (ej. "Sin centro").
class OpcionSeleccion<T> {
  final T valor;
  final String titulo;
  final String? subtitulo;

  const OpcionSeleccion({
    required this.valor,
    required this.titulo,
    this.subtitulo,
  });
}

/// Lista desplegable que abre una hoja inferior con las opciones (con
/// buscador si son muchas). Trabaja con valores (ids), no con textos, así que
/// dos opciones con el mismo nombre no se confunden.
///
/// Versión 2 de [CustomDropdown]; se estrenó en el módulo Turno.
class CampoSeleccion<T> extends StatelessWidget {
  final String etiqueta;
  final IconData icono;
  final List<OpcionSeleccion<T>> opciones;
  final T? valor;
  final ValueChanged<T> onChanged;

  /// Color de acento del módulo (borde, ícono, marca de seleccionado).
  final Color color;
  final String hint;

  /// Se muestra bajo el campo (ej. "Primero elige el área").
  final String? ayuda;
  final bool habilitado;
  final bool cargando;
  final bool opcional;

  /// Null: buscador solo si hay más de 8 opciones.
  final bool? buscador;

  const CampoSeleccion({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.opciones,
    required this.valor,
    required this.onChanged,
    this.color = AppTheme.primaryBlue,
    this.hint = 'Selecciona',
    this.ayuda,
    this.habilitado = true,
    this.cargando = false,
    this.opcional = false,
    this.buscador,
  });

  OpcionSeleccion<T>? get _actual {
    for (final o in opciones) {
      if (o.valor == valor) return o;
    }
    return null;
  }

  Future<void> _abrir(BuildContext context) async {
    final elegida = await showModalBottomSheet<OpcionSeleccion<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _HojaOpciones<T>(
        titulo: etiqueta,
        opciones: opciones,
        valor: valor,
        color: color,
        buscador: buscador ?? opciones.length > 8,
      ),
    );
    if (elegida != null) onChanged(elegida.valor);
  }

  @override
  Widget build(BuildContext context) {
    final actual = _actual;
    final activo = habilitado && !cargando;
    final conValor = actual != null;
    final borde = !habilitado
        ? Colors.grey.shade200
        : conValor
        ? color.withValues(alpha: 0.45)
        : Colors.grey.shade300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: habilitado ? Colors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: activo ? () => _abrir(context) : null,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borde, width: conValor ? 1.5 : 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (habilitado ? color : Colors.grey).withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icono,
                      size: 22,
                      color: habilitado ? color : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: etiqueta,
                            children: [
                              if (opcional)
                                TextSpan(
                                  text: '  · opcional',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          actual?.titulo ?? hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: conValor
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: conValor && habilitado
                                ? Colors.black87
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (cargando)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.unfold_more_rounded,
                      color: habilitado ? color : Colors.grey.shade300,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (ayuda != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              ayuda!,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }
}

class _HojaOpciones<T> extends StatefulWidget {
  final String titulo;
  final List<OpcionSeleccion<T>> opciones;
  final T? valor;
  final Color color;
  final bool buscador;

  const _HojaOpciones({
    required this.titulo,
    required this.opciones,
    required this.valor,
    required this.color,
    required this.buscador,
  });

  @override
  State<_HojaOpciones<T>> createState() => _HojaOpcionesState<T>();
}

class _HojaOpcionesState<T> extends State<_HojaOpciones<T>> {
  String _filtro = '';

  static String _sinTildes(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u');

  @override
  Widget build(BuildContext context) {
    final q = _sinTildes(_filtro.trim());
    final lista = q.isEmpty
        ? widget.opciones
        : widget.opciones
              .where((o) => _sinTildes(o.titulo).contains(q))
              .toList();
    final alto = MediaQuery.sizeOf(context).height;

    // useSafeArea del sheet solo cuida arriba: abajo, la barra de navegación
    // del teléfono tapaba las últimas opciones.
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: alto * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  widget.titulo,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (widget.buscador)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _filtro = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar',
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              Flexible(
                child: lista.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Sin resultados para "${_filtro.trim()}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: lista.length,
                        itemBuilder: (_, i) => _FilaOpcion<T>(
                          opcion: lista[i],
                          seleccionada: lista[i].valor == widget.valor,
                          color: widget.color,
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

class _FilaOpcion<T> extends StatelessWidget {
  final OpcionSeleccion<T> opcion;
  final bool seleccionada;
  final Color color;

  const _FilaOpcion({
    required this.opcion,
    required this.seleccionada,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: seleccionada
            ? color.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pop(context, opcion),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opcion.titulo,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: seleccionada
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: seleccionada ? color : Colors.black87,
                        ),
                      ),
                      if (opcion.subtitulo != null)
                        Text(
                          opcion.subtitulo!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  seleccionada
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: seleccionada ? color : Colors.grey.shade300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
