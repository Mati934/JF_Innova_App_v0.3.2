import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/database/database_helper.dart';

class LoginController extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Retorna true si el login fue exitoso, false si falló
  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;

      // 1. Autenticación con Supabase
      final response = await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (response.user != null) {
        // 2. Descarga de datos maestros (Formularios, etc.)
        await _descargarDatosIniciales(supabase);
        return true; // Éxito
      } else {
        _errorMessage = "No se pudo iniciar sesión.";
        return false;
      }
    } on AuthException catch (e) {
      _errorMessage =
          e.message; // Error legible de Supabase (ej: Contraseña incorrecta)
      return false;
    } catch (e) {
      _errorMessage = "Error inesperado de conexión.";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _descargarDatosIniciales(SupabaseClient supabase) async {
    try {
      // Descargamos items de formulario activos para tenerlos offline
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
      debugPrint("Advertencia: No se pudieron descargar datos iniciales: $e");
      // No bloqueamos el login por esto, pero lo dejamos registrado
    }
  }
}
