import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/cronograma_operativo_controller.dart';

class CronogramaEmpresasScreen extends StatefulWidget {
  const CronogramaEmpresasScreen({super.key});

  @override
  State<CronogramaEmpresasScreen> createState() =>
      _CronogramaEmpresasScreenState();
}

class _CronogramaEmpresasScreenState extends State<CronogramaEmpresasScreen> {
  late final CronogramaOperativoController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CronogramaOperativoController()..cargarMes();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Cronograma'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildPeriodHeader(),
              if (_controller.error != null) _buildError(),
              Expanded(
                child: _controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () =>
                            _controller.cargarMes(_controller.periodoDesde),
                        child: _buildTaskList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodHeader() {
    final month = _controller.periodoDesde;
    return Material(
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Mes anterior',
              onPressed: () =>
                  _controller.cargarMes(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'Qué me toca este mes',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    _monthName(month),
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              onPressed: () =>
                  _controller.cargarMes(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      color: Colors.orange.shade50,
      child: Text(
        _controller.error!,
        style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
      ),
    );
  }

  Widget _buildTaskList() {
    if (_controller.tareas.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: const [
          Icon(Icons.event_available_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Center(child: Text('No tienes tareas programadas este mes.')),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _controller.tareas.length,
      itemBuilder: (context, index) =>
          _buildTaskCard(_controller.tareas[index]),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final planTask = _map(task['cronograma_plan_tareas']);
    final type = _map(planTask['cronograma_tipos_tarea']);
    final company = _map(
      _map(planTask['cronograma_planes'])['cronograma_clientes_empresas'],
    );
    final state = task['estado']?.toString() ?? 'PROGRAMADA';
    final taskId = task['id']?.toString() ?? '';
    final title = planTask['nombre']?.toString() ?? 'Tarea de cronograma';
    final companyName = company['nombre']?.toString() ?? 'Empresa cliente';
    final target = type['target_module_key']?.toString();
    final date = DateTime.tryParse(task['fecha_programada']?.toString() ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stateIcon(state),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        companyName,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      if (date != null)
                        Text(
                          'Programada para ${_dateName(date)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                    ],
                  ),
                ),
                _statusChip(state),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _actionButton(taskId, state)),
                if (state == 'TOMADA' || state == 'EN_PROGRESO')
                  IconButton(
                    tooltip: 'Soltar tarea',
                    onPressed: () =>
                        _run(() => _controller.soltar(taskId), 'soltar'),
                    icon: const Icon(Icons.back_hand_outlined),
                  ),
                IconButton(
                  tooltip: 'Ver historial',
                  onPressed: () => _showHistory(taskId, title),
                  icon: const Icon(Icons.history),
                ),
                if (target != null && target.isNotEmpty)
                  IconButton(
                    tooltip: 'Abrir módulo destino',
                    onPressed: () => _showMessage('Módulo destino: $target'),
                    icon: const Icon(Icons.open_in_new),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String id, String state) {
    if (state == 'PROGRAMADA' || state == 'VENCIDA') {
      return ElevatedButton.icon(
        onPressed: () => _run(() => _controller.tomar(id), 'tomar'),
        icon: const Icon(Icons.pan_tool_outlined),
        label: const Text('Tomar tarea'),
      );
    }
    if (state == 'TOMADA') {
      return ElevatedButton.icon(
        onPressed: () => _run(() => _controller.iniciar(id), 'iniciar'),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Iniciar'),
      );
    }
    if (state == 'EN_PROGRESO') {
      return ElevatedButton.icon(
        onPressed: () => _showCompleteDialog(id),
        icon: const Icon(Icons.check),
        label: const Text('Completar'),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _run(Future<bool> Function() action, String verb) async {
    final ok = await action();
    if (!mounted) return;
    _showMessage(
      ok
          ? 'Tarea actualizada.'
          : 'No se pudo $verb: puede que otro usuario ya la haya tomado.',
    );
  }

  Future<void> _showCompleteDialog(String id) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Completar tarea'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Qué se realizó',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Completar'),
          ),
        ],
      ),
    );
    if (ok == true)
      await _run(() => _controller.completar(id, controller.text), 'completar');
  }

  Future<void> _showHistory(String id, String title) async {
    final history = await _controller.historial(id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 12),
            if (history.isEmpty) const Text('Sin eventos registrados.'),
            ...history.map(
              (event) => ListTile(
                leading: const Icon(Icons.fiber_manual_record, size: 12),
                title: Text(event['accion']?.toString() ?? ''),
                subtitle: Text(event['created_at']?.toString() ?? ''),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String _monthName(DateTime value) =>
      '${_months[value.month - 1]} ${value.year}';

  String _dateName(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';

  static const _months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  Widget _stateIcon(String state) => CircleAvatar(
    radius: 18,
    backgroundColor: _stateColor(state).withValues(alpha: 0.12),
    child: Icon(_stateIconData(state), color: _stateColor(state), size: 20),
  );

  Widget _statusChip(String state) => Chip(
    label: Text(state, style: const TextStyle(fontSize: 11)),
    side: BorderSide.none,
    backgroundColor: _stateColor(state).withValues(alpha: 0.12),
    labelStyle: TextStyle(
      color: _stateColor(state),
      fontWeight: FontWeight.w700,
    ),
  );

  Color _stateColor(String state) => switch (state) {
    'COMPLETADA' => Colors.green,
    'VENCIDA' => Colors.red,
    'EN_PROGRESO' => Colors.amber.shade800,
    'TOMADA' => AppTheme.primaryBlue,
    _ => Colors.blueGrey,
  };

  IconData _stateIconData(String state) => switch (state) {
    'COMPLETADA' => Icons.check_circle_outline,
    'VENCIDA' => Icons.warning_amber_outlined,
    'EN_PROGRESO' => Icons.play_circle_outline,
    'TOMADA' => Icons.person_outline,
    _ => Icons.event_outlined,
  };
}
