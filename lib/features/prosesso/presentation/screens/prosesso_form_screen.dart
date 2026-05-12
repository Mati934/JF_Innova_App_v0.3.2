import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../domain/models/prosesso_extintor_state.dart';
import '../controllers/prosesso_form_controller.dart';
import '../widgets/prosesso_extintor_card.dart';

class ProsessoFormScreen extends StatefulWidget {
  final Map<String, dynamic>? borradorInicial;
  const ProsessoFormScreen({super.key, this.borradorInicial});

  @override
  State<ProsessoFormScreen> createState() => _ProsessoFormScreenState();
}

class _ProsessoFormScreenState extends State<ProsessoFormScreen> {
  late final ProsessoFormController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ProsessoFormController(borradorInicial: widget.borradorInicial);
    _ctrl.addListener(_onCtrl);
  }

  void _onCtrl() => setState(() {});

  @override
  void dispose() {
    _ctrl.removeListener(_onCtrl);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFC8102E)),
            SizedBox(width: 8),
            Expanded(child: Text('Finalizar inspección')),
          ],
        ),
        content: const Text(
          '¿Estás seguro que deseas finalizar la inspección?\n\n'
          'Una vez finalizada se asignará el N° de certificado y se '
          'generarán los PDFs definitivos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC8102E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    if (!mounted) return;
    final ok = await _ctrl.guardar(context);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servicio guardado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } else if (_ctrl.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_ctrl.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ctrl.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: !_ctrl.isSaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          await _ctrl.guardarBorradorSilencioso();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mantención de Extintores'),
          backgroundColor: const Color(0xFFC8102E),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Vista previa Registro',
              icon: const Icon(Icons.description),
              onPressed: _ctrl.isSaving
                  ? null
                  : () => _ctrl.previsualizarRegistro(context),
            ),
            IconButton(
              tooltip: 'Vista previa Certificado',
              icon: const Icon(Icons.workspace_premium),
              onPressed: _ctrl.isSaving
                  ? null
                  : () => _ctrl.previsualizarCertificado(context),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildCabecera(),
            const SizedBox(height: 12),
            _buildFirma(),
            const SizedBox(height: 12),
            _buildResumenChips(),
            const SizedBox(height: 8),
            ..._ctrl.extintores.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ProsessoExtintorCard(
                  controller: _ctrl,
                  index: e.key,
                  extintor: e.value,
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'addExt',
              onPressed: _ctrl.agregarExtintor,
              backgroundColor: Colors.grey.shade800,
              icon: const Icon(Icons.add),
              label: const Text('Extintor'),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'saveExt',
              onPressed: _ctrl.isSaving ? null : _guardar,
              backgroundColor: const Color(0xFFC8102E),
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
          ],
        ),
      ),
    );
  }

  Widget _buildFirma() {
    final hasFirma = _ctrl.signatureImage != null;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Firma del Técnico',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (hasFirma)
                  TextButton.icon(
                    onPressed: _ctrl.clearSignature,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Limpiar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showSignatureDialog,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: hasFirma
                        ? const Color(0xFFC8102E)
                        : Colors.grey.shade400,
                    width: hasFirma ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: hasFirma ? Colors.white : Colors.grey.shade50,
                ),
                child: hasFirma
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.memory(
                            _ctrl.signatureImage!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    : Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app, color: Colors.grey.shade500),
                            const SizedBox(width: 8),
                            Text(
                              'Toca aquí para firmar',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignatureDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: SizedBox(
          width: double.infinity,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: Signature(
                  controller: _ctrl.signatureController,
                  backgroundColor: Colors.white,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _ctrl.signatureController.clear(),
                      icon: const Icon(Icons.clear),
                      tooltip: 'Borrar',
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC8102E),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final sig = await _ctrl.signatureController
                            .toPngBytes();
                        if (sig != null) _ctrl.setSignatureImage(sig);
                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);
                      },
                      child: const Text('Confirmar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCabecera() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Datos del Servicio',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl.clienteCtrl,
              decoration: const InputDecoration(
                labelText: 'Cliente *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl.direccionCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl.certNumeroCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nº Certificado',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _ctrl.pickFechaServicio(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha Servicio',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(_ctrl.fechaStr),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenChips() {
    final total = _ctrl.extintores.length;
    final completos = _ctrl.extintores.where((e) => e.estaCompleto).length;
    final conNc = _ctrl.extintores
        .where(
          (e) => e.puntos.any((p) => p.estado == EstadoPuntoProsesso.noCumple),
        )
        .length;
    return Wrap(
      spacing: 8,
      children: [
        Chip(
          label: Text('Total: $total'),
          backgroundColor: Colors.blueGrey.shade100,
        ),
        Chip(
          label: Text('Completos: $completos'),
          backgroundColor: Colors.green.shade100,
        ),
        Chip(
          label: Text('Con NC: $conNc'),
          backgroundColor: Colors.red.shade100,
        ),
      ],
    );
  }
}
