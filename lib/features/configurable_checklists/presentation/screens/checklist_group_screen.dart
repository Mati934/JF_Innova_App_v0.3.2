import 'package:flutter/material.dart';

import '../../domain/models/configurable_checklist.dart';
import '../checklist_icons.dart';
import 'generic_checklist_form_screen.dart';

/// Lista de checklists de un mismo grupo (estilo Hidroser): al tocar una
/// tarjeta se abre el formulario generico con su propio checklist_key.
class ChecklistGroupScreen extends StatelessWidget {
  final String titulo;
  final List<ConfigurableChecklist> checklists;

  const ChecklistGroupScreen({
    super.key,
    required this.titulo,
    required this.checklists,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: checklists.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final checklist = checklists[index];
          return Card(
            elevation: 1,
            child: ListTile(
              leading: Icon(checklistIconFromName(checklist.icono)),
              title: Text(checklist.nombreVisible),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      GenericChecklistFormScreen(checklist: checklist),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
