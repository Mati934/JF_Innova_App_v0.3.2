import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart'; // <--- 1. IMPORTAR ESTO
import '../../../../core/database/database_helper.dart';
import '../../../home/presentation/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // <--- 2. AGREGAR ESTA FUNCIÓN AQUÍ (Antes del build)
  Future<String> _getVersion() async {
    final info = await PackageInfo.fromPlatform();
    // Esto devolverá algo como: "Versión 0.6.0 (15)"
    return "v${info.version} (b${info.buildNumber})";
  }

  Future<void> _iniciarSesion() async {
    // ... (Tu código de iniciar sesión sigue IGUAL, no lo toques) ...
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        await _descargarDatosIniciales(supabase);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _descargarDatosIniciales(SupabaseClient supabase) async {
    // ... (Tu código sigue igual) ...
    try {
      final data = await supabase
          .from('formulario_items')
          .select()
          .eq('activo', true)
          .order('orden');
      if (data.isNotEmpty) {
        await DatabaseHelper.instance.guardarItemsOffline(
          List<Map<String, dynamic>>.from(data),
        );
      }
    } catch (e) {
      debugPrint("Error bajando datos iniciales: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // ... (La Card del Formulario sigue igual) ...
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Correo Electrónico',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        onSubmitted: (_) => _iniciarSesion(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _iniciarSesion,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text('INGRESAR'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // <--- 3. PEGA ESTO AQUÍ AL FINAL (Debajo de la Card)
              const SizedBox(height: 30),
              FutureBuilder<String>(
                future: _getVersion(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  return Text(
                    "Versión instalada: ${snapshot.data}",
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
