// main.dart
import 'dart:async';
import 'dart:io'; // Necesario para SocketException y HttpException
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Imports de configuración y UI
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/database/database_helper.dart'; // Para el chequeo de supervivencia offline
import 'features/home/presentation/screens/home_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/sync/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JF Innova',
      debugShowCheckedModeBanner: false,

      // Configuración de Idioma
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES')],

      // Tema de la aplicación
      theme: AppTheme.lightTheme,

      home: const AuthGate(),
    );
  }
}

// -----------------------------------------------------------------------------
// AUTH GATE REACTIVO Y OFFLINE-FIRST
// -----------------------------------------------------------------------------
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    // Escuchamos la máquina de estados de Supabase en tiempo real
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      final event = data.event;
      final session = data.session;

      debugPrint("🔐 [AuthGate] Evento detectado: $event");

      // CASO 1: Inicio de sesión nuevo o recuperación de sesión al abrir la app
      if ((event == AuthChangeEvent.initialSession ||
              event == AuthChangeEvent.signedIn) &&
          session != null) {
        if (mounted) setState(() => _isLoading = true);

        try {
          // 1. Intentamos hidratar datos frescos desde el servidor
          await SyncService().hidratarContextoInicial(session.user.id);

          if (mounted) setState(() => _isLoading = false);
        } catch (e) {
          debugPrint("⚠️ [AuthGate] Error durante la inicialización: $e");

          // 2. DIAGNÓSTICO DEL ERROR
          final String errorStr = e.toString();

          // A. ¿Es un error de red físico? (Sin internet en terreno)
          final esErrorDeRed =
              e is SocketException ||
              e is HttpException ||
              errorStr.contains('Failed host lookup') ||
              errorStr.contains('Connection refused');

          // B. ¿Es un error de seguridad? (Token zombie, expirado o revocado)
          final esErrorDeSeguridad =
              e is AuthException ||
              errorStr.contains('42501') ||
              errorStr.contains('Unauthorized') ||
              errorStr.contains('JWT');

          // 3. EVALUACIÓN DE SUPERVIVENCIA OFFLINE EN SQLITE
          bool existePerfilLocal = false;
          try {
            final db = await DatabaseHelper.instance.database;
            final localUser = await db.query(
              'usuarios',
              where: 'id = ?',
              whereArgs: [session.user.id],
              limit: 1,
            );
            existePerfilLocal = localUser.isNotEmpty;
          } catch (dbError) {
            debugPrint("🔥 [AuthGate] Error crítico leyendo SQLite: $dbError");
          }

          // 4. RESOLUCIÓN DEL CONFLICTO
          if (esErrorDeSeguridad) {
            debugPrint(
              "🛑 [AuthGate] Token zombie detectado. Revocando acceso por seguridad.",
            );
            await Supabase.instance.client.auth.signOut();
          } else if (esErrorDeRed && existePerfilLocal) {
            debugPrint(
              "🌐 [AuthGate] Modo Offline activado: Sin red, pero perfil local válido.",
            );
            // No hacemos signOut. El usuario sobrevive con los datos en caché.
          } else {
            debugPrint(
              "🛑 [AuthGate] App inutilizable: Sin internet y sin perfil local.",
            );
            // Instalación limpia en terreno sin señal. Debe loguearse con internet la primera vez.
            await Supabase.instance.client.auth.signOut();
          }

          if (mounted) setState(() => _isLoading = false);
        }
      }
      // CASO 2: Cierre de sesión intencional o token destruido
      else if (event == AuthChangeEvent.signedOut || session == null) {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel(); // Previene memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Pantalla de carga (Splash) mientras resolvemos el estado y la BD
    if (_isLoading) {
      return Scaffold(
        backgroundColor:
            AppTheme.primaryBlue, // Usa el color corporativo de tu app
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Opcional: Puedes poner tu logo aquí encima del indicador
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text(
                "Preparando entorno...",
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Renderizado final síncrono
    final session = Supabase.instance.client.auth.currentSession;
    return session != null ? const HomeScreen() : const LoginScreen();
  }
}
