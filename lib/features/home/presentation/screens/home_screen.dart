import 'package:flutter/material.dart';
import 'package:jf_innova_app/core/theme/app_theme.dart';
import '../controllers/home_controller.dart';
import '../widgets/draft_list_widget.dart';
import '../widgets/module_selector_grid.dart'; // <--- IMPORTA TU NUEVO WIDGET
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../inspection/presentation/screens/inspection_setup_screen.dart';
import '../../../history/presentation/screens/history_screen.dart';
import '../../../visits/presentation/screens/visit_form_screen.dart'; // Importa la pantalla de visitas
import '../../../tickets/presentation/screens/ticket_list_screen.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeController _controller = HomeController();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final bool estaVacio = _controller.borradores.isEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Panel de Control'),
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'Historial e Informes',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistoryScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: _controller.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.sync),
                tooltip: 'Sincronizar ahora',
                onPressed: _controller.isSyncing
                    ? null
                    : () async {
                        await _controller.ejecutarSincronizacion();
                        if (mounted && _controller.syncMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_controller.syncMessage!),
                              backgroundColor: _controller.isError
                                  ? Colors.red
                                  : Colors.green.shade700,
                            ),
                          );
                        }
                      },
              ),
              IconButton(
                onPressed: () => _cerrarSesion(context),
                icon: const Icon(Icons.logout),
                tooltip: 'Salir',
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      // Si no hay borradores, centramos verticalmente
                      mainAxisAlignment: estaVacio
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        if (_controller.isSyncing)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "Sincronizando datos...",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // LOGO
                        Hero(
                          tag: 'logo_app',
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/logo_jfinnova.png',
                              height:
                                  100, // Un poco más chico para dar espacio a la grilla
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.verified_user,
                                  size: 80,
                                  color: AppTheme.primaryBlue,
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          'Hola, ${_controller.nombreUsuario}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Sistema de Gestión JF Innova',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),

                        SizedBox(height: estaVacio ? 50 : 20),

                        _buildTicketsPanel(context),

                        SizedBox(height: estaVacio ? 26 : 16),

                        // --- AQUÍ ESTÁ EL CAMBIO: LA NUEVA GRILLA ---
                        ModuleSelectorGrid(
                          onInspeccionTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const InspectionSetupScreen(),
                              ),
                            ).then((_) => _controller.cargarBorradores());
                          },
                          onVisitaTap: () {
                            // Navegación al nuevo módulo
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const VisitFormScreen(),
                              ),
                            ).then((_) => _controller.cargarBorradores());
                          },
                          onRendicionTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Próximamente...")),
                            );
                          },
                        ),

                        // --------------------------------------------
                        const SizedBox(height: 40),

                        DraftListWidget(controller: _controller),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Panel de acceso rápido al módulo de Tickets
  // ---------------------------------------------------------------------------

  Widget _buildTicketsPanel(BuildContext context) {
    final count = _controller.ticketsAbiertos;
    final hasTickets = count > 0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TicketListScreen()),
        ).then((_) => _controller.cargarNotificacionesTickets()),
        child: Ink(
          decoration: BoxDecoration(
            color: hasTickets ? Colors.red.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasTickets ? Colors.red.shade200 : Colors.grey.shade200,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasTickets
                        ? Colors.red.shade100
                        : AppTheme.primaryBlue.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.confirmation_number_outlined,
                    color:
                        hasTickets ? Colors.red.shade700 : AppTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tickets',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        hasTickets
                            ? '$count ticket(s) abierto(s)'
                            : 'Sin tickets pendientes',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasTickets) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ... (Tu método _cerrarSesion se mantiene igual) ...
  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('¿Cerrar Sesión?'),
          ],
        ),
        content: const Text(
          'Si cierras sesión, necesitarás internet para volver a entrar.\n\n'
          '⚠️ Si vas a terreno sin señal, NO cierres sesión, solo cierra la app.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      if (mounted) {
        await _controller.cerrarSesion(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }
}
