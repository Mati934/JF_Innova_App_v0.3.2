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
import 'core/services/connectivity_service.dart';
import 'core/services/user_session.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/sync/services/sync_service.dart';
import 'shared/widgets/animated_splash.dart';

import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart'; // Generado por flutterfire CLI

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CLEAN CODE: OOM Prevention
  PaintingBinding.instance.imageCache.maximumSize = 30;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 1024 * 1024 * 15;

  // 1. Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Interceptar errores síncronos de Flutter
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // 3. Interceptar errores asíncronos (Isolates, Futures no manejados, etc.)
  PlatformDispatcher.instance.onError = (error, stack) {
    // Errores de red durante token refresh de Supabase no son fatales
    // (ocurren cuando el dispositivo pierde conexión momentáneamente)
    final errorStr = error.toString();
    final esErrorDeRed =
        error is SocketException ||
        errorStr.contains('Failed host lookup') ||
        errorStr.contains('Connection refused') ||
        errorStr.contains('AuthRetryableFetchException') ||
        errorStr.contains('SocketException');

    if (esErrorDeRed) {
      debugPrint('📴 Error de red ignorado (no fatal): $errorStr');
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
      return true;
    }

    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // 4. Inicializar Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // 5. Inicializar servicio de conectividad
  await ConnectivityService().init();

  // 6. Registrar auto-sync cuando vuelve la conexión
  ConnectivityService().onReconnect(() {
    debugPrint("🔄 Auto-sync al recuperar conexión...");
    SyncService()
        .sincronizarTodo()
        .then((count) {
          if (count > 0) {
            debugPrint(
              "✅ Auto-sync completado: $count registros sincronizados",
            );
          }
        })
        .catchError((e) {
          debugPrint("⚠️ Auto-sync falló: $e");
        });
  });

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
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      final event = data.event;
      final session = data.session;

      debugPrint("🔐 [AuthGate] Evento detectado: $event");

      if ((event == AuthChangeEvent.initialSession ||
              event == AuthChangeEvent.signedIn) &&
          session != null) {
        // Pre-carga la sesión local para que el splash muestre el logo
        // de la empresa correcta desde el primer frame (cuando hay caché).
        try {
          await UserSession().loadFromSQLite(session.user.id);
        } catch (e) {
          debugPrint("⚠️ [AuthGate] Pre-carga UserSession falló: $e");
        }

        if (mounted) setState(() => _isLoading = true);

        try {
          await SyncService().hidratarContextoInicial(session.user.id);
          if (mounted) setState(() => _isLoading = false);
        } catch (e) {
          debugPrint("⚠️ [AuthGate] Error durante la inicialización: $e");

          final String errorStr = e.toString();
          final esErrorDeRed =
              e is SocketException ||
              e is HttpException ||
              errorStr.contains('Failed host lookup') ||
              errorStr.contains('Connection refused');

          final esErrorDeSeguridad =
              e is AuthException ||
              errorStr.contains('42501') ||
              errorStr.contains('Unauthorized') ||
              errorStr.contains('JWT');

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

          if (esErrorDeSeguridad) {
            debugPrint(
              "🛑 [AuthGate] Token zombie detectado. Revocando acceso por seguridad.",
            );
            await Supabase.instance.client.auth.signOut();
          } else if (esErrorDeRed && existePerfilLocal) {
            debugPrint(
              "🌐 [AuthGate] Modo Offline activado: Sin red, pero perfil local válido.",
            );
          } else {
            debugPrint(
              "🛑 [AuthGate] App inutilizable: Sin internet y sin perfil local.",
            );
            await Supabase.instance.client.auth.signOut();
          }

          if (mounted) setState(() => _isLoading = false);
        }
      } else if (event == AuthChangeEvent.signedOut || session == null) {
        UserSession().clear();
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AnimatedSplash();
    }

    final session = Supabase.instance.client.auth.currentSession;
    return session != null ? const HomeScreen() : const LoginScreen();
  }
}
