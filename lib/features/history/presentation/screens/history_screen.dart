import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/custom_dropdown.dart';
import '../../controllers/history_controller.dart';
import '../widgets/history_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HistoryController(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Historial General"),
          backgroundColor: const Color(0xFF003366),
          foregroundColor: Colors.white,
        ),
        body: Consumer<HistoryController>(
          builder: (context, ctrl, _) {
            return Column(
              children: [
                // --- SECCIÓN DE FILTROS ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. FILTRO PÚBLICO: Módulo (Para todos)
                      CustomDropdown(
                        label: "Tipo de Registro",
                        enableSearch: false,
                        items: const ["Todos", "Inspección", "Visita Técnica"],
                        value: ctrl.filtroModulo ?? "Todos",
                        onChanged: (val) {
                          ctrl.setFiltroModulo(val == "Todos" ? null : val);
                        },
                      ),

                      // 2. FILTROS PRIVADOS: Solo para Admin (Apilados en un Row)
                      if (ctrl.esAdmin) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: CustomDropdown(
                                label: "Centro",
                                enableSearch: true,
                                items: [
                                  "Todos",
                                  ...ctrl.listaCentros.map(
                                    (e) => e['nombre'].toString(),
                                  ),
                                ],
                                value: ctrl.filtroCentroId == null
                                    ? "Todos"
                                    : ctrl.listaCentros.firstWhere(
                                        (e) =>
                                            e['id'].toString() ==
                                            ctrl.filtroCentroId,
                                        orElse: () => {'nombre': "Todos"},
                                      )['nombre'],
                                onChanged: (val) {
                                  if (val == "Todos" || val == null) {
                                    ctrl.setFiltroCentro(null);
                                  } else {
                                    final obj = ctrl.listaCentros.firstWhere(
                                      (e) => e['nombre'] == val,
                                    );
                                    ctrl.setFiltroCentro(obj['id'].toString());
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomDropdown(
                                label: "Usuario",
                                enableSearch: true,
                                items: [
                                  "Todos",
                                  ...ctrl.listaUsuarios.map(
                                    (e) => e['nombre_completo'].toString(),
                                  ),
                                ],
                                value: ctrl.filtroUsuarioId == null
                                    ? "Todos"
                                    : ctrl.listaUsuarios.firstWhere(
                                        (e) =>
                                            e['id'].toString() ==
                                            ctrl.filtroUsuarioId,
                                        orElse: () => {
                                          'nombre_completo': "Todos",
                                        },
                                      )['nombre_completo'],
                                onChanged: (val) {
                                  if (val == "Todos" || val == null) {
                                    ctrl.setFiltroUsuario(null);
                                  } else {
                                    final obj = ctrl.listaUsuarios.firstWhere(
                                      (e) => e['nombre_completo'] == val,
                                    );
                                    ctrl.setFiltroUsuario(obj['id'].toString());
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // --- LISTA DE RESULTADOS ---
                Expanded(
                  child: ctrl.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ctrl.records.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_toggle_off,
                                size: 60,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "No hay registros",
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 20),
                          itemCount: ctrl.records.length,
                          itemBuilder: (ctx, i) =>
                              HistoryCard(item: ctrl.records[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
