import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/turno.dart';
import '../../domain/turno_cierre.dart';
import '../controllers/cierre_turno_controller.dart';
import 'turno_module_screen.dart' show kTurnoColor;

/// Abre el PDF del cierre con el visor del sistema (como los demás módulos:
/// permite guardarlo o compartirlo). Sin archivo en el teléfono, abre la URL.
Future<void> abrirPdfCierre(BuildContext context, TurnoCierre c) async {
  final messenger = ScaffoldMessenger.of(context);
  final local = c.pdfPathLocal;
  if (!kIsWeb && local != null) {
    try {
      final archivo = File(local);
      if (archivo.existsSync()) {
        final bytes = await archivo.readAsBytes();
        await Printing.layoutPdf(
          name: 'Cierre de turno ${TurnoFechas.aTexto(c.desde)}',
          onLayout: (_) async => bytes,
        );
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Abrir PDF cierre (local): $e');
    }
  }
  try {
    final url = c.pdfUrl;
    if (url != null &&
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (e) {
    debugPrint('⚠️ Abrir PDF cierre (url): $e');
  }
  messenger.showSnackBar(
    const SnackBar(content: Text('No se pudo abrir el PDF.')),
  );
}

/// "Cierre de turno": datos calculados desde la app, editables, y el botón
/// para generar el PDF. Plan: PLAN_TURNO.md §11.
class CierreTurnoScreen extends StatefulWidget {
  final Turno turno;
  final CierreTurnoController? controller;

  const CierreTurnoScreen({super.key, required this.turno, this.controller});

  @override
  State<CierreTurnoScreen> createState() => _CierreTurnoScreenState();
}

class _CierreTurnoScreenState extends State<CierreTurnoScreen> {
  late final CierreTurnoController _c;

  @override
  void initState() {
    super.initState();
    _c = widget.controller ?? CierreTurnoController(turno: widget.turno);
    _c.cargar();
  }

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  void _aviso(String texto) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _recalcular() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Volver a calcular?'),
        content: const Text(
          'Se vuelven a leer tus inspecciones, AST y tickets. Se reemplaza lo '
          'que corregiste en las secciones automáticas; se mantienen los '
          'puertos cerrados, la bitácora, las notas de folios y EPP/Cil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kTurnoColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Calcular'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final error = await _c.recalcular();
    if (mounted) _aviso(error ?? 'Datos actualizados.');
  }

  Future<void> _generar() async {
    FocusScope.of(context).unfocus();
    final error = await _c.generarPdf(area: widget.turno.areaNombre ?? 'Área');
    if (!mounted) return;
    if (error != null) return _aviso(error);
    _aviso('PDF generado.');
    final c = _c.cierre;
    if (c != null) await abrirPdfCierre(context, c);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Guarda antes de salir para que "Mis turnos" ya vea el borrador.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _c.guardar();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F6),
        appBar: AppBar(
          backgroundColor: kTurnoColor,
          foregroundColor: Colors.white,
          title: const Text('Cierre de turno'),
          actions: [
            ListenableBuilder(
              listenable: _c,
              builder: (context, _) => (_c.cierre?.tienePdf ?? false)
                  ? IconButton(
                      tooltip: 'Ver PDF',
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      onPressed: () => abrirPdfCierre(context, _c.cierre!),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            if (_c.cargando) return const _Cargando();
            final c = _c.cierre;
            if (c == null) {
              return _Error(texto: _c.error ?? '', onReintentar: _c.cargar);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                _Cabecera(
                  cierre: c,
                  calculando: _c.calculando,
                  onRecalcular: _recalcular,
                ),
                const SizedBox(height: 12),
                _TarjetaNumeros(
                  titulo: 'Resumen del turno',
                  icono: Icons.insights_outlined,
                  campos: CierreCampos.indicadores,
                  cierre: c,
                  version: _c.version,
                  onChanged: _c.setNumero,
                ),
                const SizedBox(height: 12),
                _TarjetaNumeros(
                  titulo: 'Tickets del turno',
                  icono: Icons.confirmation_number_outlined,
                  ayuda:
                      'Tickets que creaste o cerraste en el turno y en qué '
                      'estado están hoy.',
                  campos: CierreCampos.tickets,
                  cierre: c,
                  version: _c.version,
                  onChanged: _c.setNumero,
                ),
                for (final s in CierreCampos.secciones) ...[
                  const SizedBox(height: 12),
                  _TarjetaSeccion(
                    seccion: s,
                    filas: c.filasDe(s.clave),
                    version: _c.version,
                    onCampo: (i, campo, v) => _c.setCampo(s.clave, i, campo, v),
                    onAgregar: () => _c.agregarFila(s.clave),
                    onQuitar: (i) => _c.quitarFila(s.clave, i),
                  ),
                ],
                const SizedBox(height: 12),
                _Tarjeta(
                  titulo: 'Bitácora de cierre',
                  icono: Icons.edit_note_rounded,
                  ayuda:
                      'Observaciones relevantes y coordinaciones para el '
                      'próximo turno (ingresos, logística, contactos).',
                  child: TextFormField(
                    key: ValueKey('bitacora-${_c.version}'),
                    initialValue: c.bitacora ?? '',
                    minLines: 4,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoracion('Escribe aquí'),
                    onChanged: _c.setBitacora,
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: _c,
          builder: (context, _) => _c.cierre == null
              ? const SizedBox.shrink()
              : _BarraAcciones(
                  generando: _c.generando,
                  generado: _c.cierre!.generado,
                  onGuardar: () async {
                    _c.cambios = true;
                    await _c.guardar();
                    if (mounted) _aviso('Borrador guardado.');
                  },
                  onGenerar: _generar,
                ),
        ),
      ),
    );
  }
}

InputDecoration _decoracion(String? etiqueta) => InputDecoration(
  labelText: etiqueta,
  isDense: true,
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    borderSide: const BorderSide(color: kTurnoColor, width: 1.6),
  ),
);

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: kTurnoColor),
          const SizedBox(height: 16),
          Text(
            'Juntando tus inspecciones, AST y tickets del turno…',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    ),
  );
}

class _Error extends StatelessWidget {
  final String texto;
  final VoidCallback onReintentar;

  const _Error({required this.texto, required this.onReintentar});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 44, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kTurnoColor),
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

class _Cabecera extends StatelessWidget {
  final TurnoCierre cierre;
  final bool calculando;
  final VoidCallback onRecalcular;

  const _Cabecera({
    required this.cierre,
    required this.calculando,
    required this.onRecalcular,
  });

  @override
  Widget build(BuildContext context) {
    final c = cierre;
    final dias = TurnoReglas.diasReales(c.desde, c.hasta);
    final generado = c.generado && c.pdfGeneradoAt != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
      decoration: BoxDecoration(
        color: kTurnoColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  generado
                      ? 'PDF generado el ${TurnoFechas.legible(c.pdfGeneradoAt!)}'
                      : 'Borrador',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (calculando)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: onRecalcular,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Volver a calcular'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${c.desde.day} ${TurnoFechas.mes(c.desde)} → '
            '${c.hasta.day} ${TurnoFechas.mes(c.hasta)} ${c.hasta.year}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '$dias ${dias == 1 ? 'día' : 'días'} · calculado con lo que '
            'registraste en la app. Revisa y corrige lo que haga falta.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final String? ayuda;
  final Widget? accion;
  final Widget child;

  const _Tarjeta({
    required this.titulo,
    required this.icono,
    required this.child,
    this.ayuda,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, size: 20, color: kTurnoColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?accion,
            ],
          ),
          if (ayuda != null) ...[
            const SizedBox(height: 2),
            Text(
              ayuda!,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TarjetaNumeros extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final String? ayuda;
  final List<CampoNumero> campos;
  final TurnoCierre cierre;
  final int version;
  final void Function(String clave, String texto) onChanged;

  const _TarjetaNumeros({
    required this.titulo,
    required this.icono,
    required this.campos,
    required this.cierre,
    required this.version,
    required this.onChanged,
    this.ayuda,
  });

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      titulo: titulo,
      icono: icono,
      ayuda: ayuda,
      child: LayoutBuilder(
        builder: (context, box) {
          final ancho = (box.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final f in campos)
                SizedBox(
                  width: ancho,
                  child: TextFormField(
                    key: ValueKey('${f.clave}-$version'),
                    initialValue: cierre.numeros[f.clave]?.toString() ?? '',
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: _decoracion(f.titulo),
                    onChanged: (v) => onChanged(f.clave, v),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TarjetaSeccion extends StatelessWidget {
  final SeccionCierre seccion;
  final List<FilaCierre> filas;
  final int version;
  final void Function(int fila, String campo, String valor) onCampo;
  final VoidCallback onAgregar;
  final void Function(int fila) onQuitar;

  const _TarjetaSeccion({
    required this.seccion,
    required this.filas,
    required this.version,
    required this.onCampo,
    required this.onAgregar,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      titulo: seccion.titulo,
      icono: seccion.automatica
          ? Icons.auto_awesome_outlined
          : Icons.edit_outlined,
      ayuda: seccion.ayuda,
      accion: filas.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: kTurnoColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${filas.length}',
                style: const TextStyle(
                  color: kTurnoColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (filas.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Sin registros en el turno.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          for (var i = 0; i < filas.length; i++)
            _FilaEditable(
              key: ValueKey('${seccion.clave}-$i-$version'),
              seccion: seccion,
              fila: filas[i],
              indice: i,
              onCampo: (campo, v) => onCampo(i, campo, v),
              onQuitar: () => onQuitar(i),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: kTurnoColor),
              onPressed: onAgregar,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar fila'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaEditable extends StatelessWidget {
  final SeccionCierre seccion;
  final FilaCierre fila;
  final int indice;
  final void Function(String campo, String valor) onCampo;
  final VoidCallback onQuitar;

  const _FilaEditable({
    super.key,
    required this.seccion,
    required this.fila,
    required this.indice,
    required this.onCampo,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final titulo = (fila[seccion.columnas.first.clave] ?? '').trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo.isEmpty ? 'Fila ${indice + 1}' : titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Quitar fila',
                visualDensity: VisualDensity.compact,
                onPressed: onQuitar,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth - 6;
              // Números de a tres por línea; textos cortos de a dos y los
              // largos (motivo, descripción, notas, correo) a todo el ancho.
              double ancho(ColumnaCierre c) => c.numero
                  ? (w - 20) / 3
                  : c.flex >= 3
                  ? w
                  : (w - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final col in seccion.columnas)
                    SizedBox(
                      width: ancho(col),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            col.titulo,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            initialValue: fila[col.clave] ?? '',
                            keyboardType: col.numero
                                ? TextInputType.number
                                : TextInputType.text,
                            minLines: 1,
                            maxLines: col.numero ? 1 : 4,
                            textCapitalization: TextCapitalization.sentences,
                            textAlign: col.numero
                                ? TextAlign.center
                                : TextAlign.start,
                            style: const TextStyle(fontSize: 15),
                            decoration: _decoracion(null),
                            onChanged: (v) => onCampo(col.clave, v),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BarraAcciones extends StatelessWidget {
  final bool generando;
  final bool generado;
  final VoidCallback onGuardar;
  final VoidCallback onGenerar;

  const _BarraAcciones({
    required this.generando,
    required this.generado,
    required this.onGuardar,
    required this.onGenerar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kTurnoColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: generando ? null : onGuardar,
                  child: const Text('Guardar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: kTurnoColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: generando ? null : onGenerar,
                    icon: generando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      generando
                          ? 'Generando…'
                          : generado
                          ? 'Volver a generar PDF'
                          : 'Generar PDF',
                    ),
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
