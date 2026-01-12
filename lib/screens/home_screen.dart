import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_helper.dart';
import '../services/sync_service.dart';
import 'login_screen.dart';
import 'inspection_setup_screen.dart';

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

  // Descarga datos maestros si hay internet, si no, no molesta.
  Future<void> _sincronizarDatosSilencioso() async {
    setState(() => _actualizandoDatos = true);
    // Llamamos al método nuevo que baja TODO (Areas, Centros, Preguntas, etc)
    await _syncService.descargarDatosMaestros();
    if (mounted) setState(() => _actualizandoDatos = false);
  }

  Future<void> _cargarPerfil() async {
    if (user == null) return;
    // Intentamos leer el perfil localmente o de memoria si falla la red
    // Nota: Para una app offline real, deberíamos guardar el nombre en SQLite también.
    // Por ahora, si falla, mostramos el email que viene en la sesión local.
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
    // Advertencia al usuario antes de salir
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
      // Ignoramos error de red al salir, forzamos salida local
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // Lógica para disparar la sincronización
  // Busca la función _ejecutarSincronizacion dentro de _HomeScreenState
  // y reemplázala con esta:

  Future<void> _ejecutarSincronizacion() async {
    setState(() => _actualizandoDatos = true);

    // Feedback inicial
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sincronizando inspecciones... ☁️'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      // Ahora 'subidos' es SOLO el número de inspecciones (actividades)
      final subidos = await _syncService.sincronizarTodo();

      if (mounted) {
        // Borramos SnackBar anterior
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (subidos > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Éxito. Se subieron $subidos inspecciones.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '👍 Todo actualizado. No había inspecciones nuevas.',
              ),
              backgroundColor: Colors.blueGrey,
            ),
          );
        }
        setState(() {}); // Refresca el contador visual
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizandoDatos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Panel de Control'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar ahora',
            onPressed: _ejecutarSincronizacion,
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

              const Icon(
                Icons.verified_user,
                size: 64,
                color: Color(0xFF003366),
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
                  ).then((_) => setState(() {}));
                },
                icon: const Icon(Icons.add_circle),
                label: const Text("Nueva Inspección"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // INFORMACIÓN DE PENDIENTES (CORREGIDA)
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
                              // AQUÍ ESTÁ EL CAMBIO DE TEXTO
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

  // --- LÓGICA CORREGIDA PARA CONTAR INSPECCIONES (NO RESPUESTAS) ---
  Future<int> _contarInspeccionesPendientes() async {
    final db = await DatabaseHelper.instance.database;

    // Contamos IDs de actividad únicos en la tabla de respuestas pendientes
    // Usamos 'DISTINCT' para que si una inspección tiene 50 respuestas, cuente como 1.
    final result = await db.rawQuery(
      'SELECT COUNT(DISTINCT actividad_id) as count FROM inspeccion_respuestas_pendientes WHERE subido = 0',
    );

    // También podríamos chequear fotos, pero generalmente van juntas.
    // Si quieres ser muy estricto, podrías hacer un UNION, pero esto suele bastar.

    return Sqflite.firstIntValue(result) ?? 0;
  }
}
