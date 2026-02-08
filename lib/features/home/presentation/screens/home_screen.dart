import 'package:flutter/material.dart';
import '../controllers/home_controller.dart';
import '../widgets/draft_list_widget.dart'; // Importamos el widget de borradores
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../inspection/presentation/screens/inspection_setup_screen.dart';
import '../../../history/presentation/screens/history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Instanciamos el controlador aquí. Al crearse, él solito carga perfil, sync y BORRADORES.
  final HomeController _controller = HomeController();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        // Variable para saber si debemos centrar o no
        final bool estaVacio = _controller.borradores.isEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Panel de Control'),
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
          // LayoutBuilder nos da las dimensiones de la pantalla para calcular el alto
          body: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                // ConstrainedBox asegura que el scroll view tenga al menos el alto de la pantalla
                // Esto permite que el alineado "center" funcione cuando hay poco contenido
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      // AQUÍ ESTÁ LA MAGIA:
                      // Si está vacío -> MainAxisAlignment.center (Todo al medio)
                      // Si tiene datos -> MainAxisAlignment.start (Todo arriba)
                      mainAxisAlignment: estaVacio
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        // --- ESTADO DE CARGA ---
                        if (_controller.isSyncing)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Sincronizando...",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // --- LOGO ---
                        Hero(
                          tag: 'logo_app',
                          child: Image.asset(
                            'assets/images/logo_jfinnova.png',
                            height: 100,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.verified_user,
                                size: 80,
                                color: Theme.of(context).primaryColor,
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 20),
                        Text(
                          'Hola, ${_controller.nombreUsuario}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Sistema de Gestión JF Innova',
                          style: TextStyle(color: Colors.grey),
                        ),

                        // Espacio dinámico: Si está vacío, damos más aire entre texto y botón
                        SizedBox(height: estaVacio ? 50 : 30),

                        // --- BOTÓN NUEVA INSPECCIÓN ---
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const InspectionSetupScreen(),
                              ),
                            ).then((_) {
                              _controller.cargarBorradores();
                            });
                          },
                          icon: const Icon(Icons.add_circle),
                          label: const Text("Nueva Inspección"),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 55),
                            textStyle: const TextStyle(fontSize: 18),
                            // Opcional: Si quieres que el botón destaque más cuando es lo único en pantalla
                            elevation: estaVacio ? 4 : 2,
                          ),
                        ),

                        const SizedBox(height: 30),

                        // --- LISTA DE BORRADORES ---
                        // Solo mostramos el widget si hay borradores o cargando
                        // Si está vacío, no mostramos nada abajo (para que el logo quede centrado perfecto)
                        if (!estaVacio || _controller.isLoadingBorradores)
                          DraftListWidget(controller: _controller),
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

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar Sesión?'),
        content: const Text(
          'Si cierras sesión, necesitarás internet para volver a entrar.\n\n'
          'Si vas a terreno sin señal, NO cierres sesión, solo cierra la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _controller.cerrarSesion(context);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }
}
