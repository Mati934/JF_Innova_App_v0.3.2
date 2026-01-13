import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../inspection/presentation/screens/inspection_setup_screen.dart';
import '../../../sync/services/sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = Supabase.instance.client.auth.currentUser;
  final _syncService = SyncService();

  String _nombreUsuario = 'Cargando...';
  bool _actualizandoDatos = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
    _sincronizarDatosSilencioso();
  }

  // Carga inicial sin molestar al usuario
  Future<void> _sincronizarDatosSilencioso() async {
    if (!mounted) return;
    setState(() => _actualizandoDatos = true);
    await _syncService.descargarDatosMaestros();
    if (mounted) setState(() => _actualizandoDatos = false);
  }

  Future<void> _cargarPerfil() async {
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('usuarios')
          .select('nombre_completo')
          .eq('id', user!.id)
          .single()
          .timeout(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _nombreUsuario = data['nombre_completo'] ?? user!.email;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _nombreUsuario = user?.email ?? 'Usuario');
    }
  }

  Future<void> _cerrarSesion() async {
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

    if (confirmar != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      // Ignorar error de red
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // --- LÓGICA DE SINCRONIZACIÓN ROBUSTA ---
  // El parámetro 'silencioso' permite reusar la función sin mostrar SnackBar (ej: al volver de inspección)
  Future<void> _ejecutarSincronizacion({bool silencioso = false}) async {
    if (_actualizandoDatos) return;

    setState(() => _actualizandoDatos = true);

    if (!silencioso) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 15),
              Text('Conectando con la nube...'),
            ],
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }

    try {
      final subidos = await _syncService.sincronizarTodo();

      // CORRECCIÓN AQUÍ: Quitamos el 'await'
      if (mounted) setState(() {});

      if (!mounted) return;

      if (!silencioso) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (subidos > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ¡Listo! Se subieron $subidos inspecciones.'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        } else {
          final pendientes = await _contarInspeccionesPendientes();
          if (pendientes == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('👍 Todo sincronizado. No hay datos pendientes.'),
                backgroundColor: Colors.blueGrey,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ No se pudo subir. Revisa tu conexión.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted && !silencioso) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizandoDatos = false);
    }
  }

  Future<int> _contarInspeccionesPendientes() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM actividades_pendientes WHERE subido = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar toma el color del AppTheme automáticamente
      appBar: AppBar(
        title: const Text('Panel de Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar ahora',
            // Llamada explícita indicando que NO es silenciosa
            onPressed: () => _ejecutarSincronizacion(silencioso: false),
          ),
          IconButton(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout),
            tooltip: 'Salir',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_actualizandoDatos)
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Conectando...",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),

              // --- LOGO CORPORATIVO (HERO) ---
              Hero(
                tag: 'logo_app',
                child: Image.asset(
                  'assets/images/logo_jfinnova.png',
                  height: 120, // Tamaño ajustado
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback por si la imagen no carga
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
                'Hola, $_nombreUsuario',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Sistema de Gestión JF Innova',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 50),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InspectionSetupScreen(),
                    ),
                  ).then((_) {
                    // AL VOLVER:
                    // 1. Refrescamos para que salga el aviso de "Pendiente"
                    setState(() {});
                    // 2. Intentamos subir silenciosamente
                    _ejecutarSincronizacion(silencioso: true);
                  });
                },
                icon: const Icon(Icons.add_circle),
                label: const Text("Nueva Inspección"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),

              const SizedBox(height: 15),

              FutureBuilder<int>(
                future: _contarInspeccionesPendientes(),
                builder: (context, snapshot) {
                  final conteo = snapshot.data ?? 0;
                  if (conteo > 0) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Tienes $conteo inspección(es) pendiente(s) de subir.\nPresiona sincronizar ↗️ cuando tengas señal.",
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
