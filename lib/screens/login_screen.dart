import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart'; // Crearemos esto en el siguiente paso
import '../services/database_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // FUNCIÓN DE LOGIN
  Future<void> _iniciarSesion() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // 1. Autenticación (Requiere Internet)
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        // 2. ¡EL TRUCO! Antes de ir al Home, descargamos los datos críticos.
        // Como el login pasó, SABEMOS que hay internet en este milisegundo.
        await _descargarDatosIniciales(supabase);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Función auxiliar para descargar y guardar en SQLite
  Future<void> _descargarDatosIniciales(SupabaseClient supabase) async {
    try {
      final data = await supabase
          .from('formulario_items')
          .select()
          .eq('activo', true);

      if (data.isNotEmpty) {
        await DatabaseHelper.instance.guardarItemsOffline(
          List<Map<String, dynamic>>.from(data),
        );
      }
    } catch (e) {
      print("Error bajando datos iniciales: $e");
      // Opcional: Podrías impedir el login si esto falla,
      // pero generalmente dejamos pasar si ya hay datos viejos.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. LOGO O ICONO
              const Icon(
                Icons.shield_outlined,
                size: 80,
                color: Color(0xFF003366),
              ),
              const SizedBox(height: 16),
              const Text(
                'JF INNOVA',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
              ),
              const Text(
                'Gestión de Prevención',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // 2. FORMULARIO (Card blanca)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Correo Electrónico',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Busca el TextField de la contraseña y déjalo así:
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        // AGREGA ESTA LÍNEA MÁGICA:
                        onSubmitted: (_) => _iniciarSesion(),
                        // (El guion bajo significa que ignoramos el valor del texto porque ya lo tenemos en el controller)
                      ),
                      const SizedBox(height: 24),

                      // BOTÓN DE LOGIN
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _iniciarSesion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF003366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'INGRESAR',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
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
