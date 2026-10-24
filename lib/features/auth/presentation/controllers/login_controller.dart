import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Importación obligatoria para acceder a la lógica centralizada
import '../../../sync/services/sync_service.dart';

class LoginController extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (response.user != null) {
        // LLAMADA CORRECTA AL SERVICIO EXTERNO
        await SyncService().hidratarContextoInicial(response.user!.id);
        return true;
      } else {
        _errorMessage = "No se pudo iniciar sesión.";
        return false;
      }
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = "Error inesperado de conexión.";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
