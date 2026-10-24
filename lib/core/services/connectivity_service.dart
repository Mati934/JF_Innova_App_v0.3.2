import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Servicio singleton para monitorear el estado de conectividad.
/// Permite suscribirse a cambios de conexión y dispara callbacks automáticos.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Callbacks que se ejecutan cuando vuelve la conexión
  final List<VoidCallback> _onReconnectCallbacks = [];

  /// Callbacks que se ejecutan cuando se pierde la conexión
  final List<VoidCallback> _onDisconnectCallbacks = [];

  /// Stream controller para notificar cambios de estado
  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChange => _statusController.stream;

  /// Inicializa el servicio y comienza a escuchar cambios
  Future<void> init() async {
    // Verificar estado inicial
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    // Escuchar cambios
    _subscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    debugPrint("📡 ConnectivityService inicializado. Online: $_isOnline");
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _updateStatus(results);

    if (!wasOnline && _isOnline) {
      // Transición: offline -> online
      debugPrint(
        "🌐 Conexión restaurada. Ejecutando ${_onReconnectCallbacks.length} callbacks...",
      );
      for (var callback in _onReconnectCallbacks) {
        try {
          callback();
        } catch (e) {
          debugPrint("⚠️ Error en callback de reconexión: $e");
        }
      }
    } else if (wasOnline && !_isOnline) {
      // Transición: online -> offline
      debugPrint(
        "📴 Conexión perdida. Ejecutando ${_onDisconnectCallbacks.length} callbacks...",
      );
      for (var callback in _onDisconnectCallbacks) {
        try {
          callback();
        } catch (e) {
          debugPrint("⚠️ Error en callback de desconexión: $e");
        }
      }
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final newStatus =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (_isOnline != newStatus) {
      _isOnline = newStatus;
      _statusController.add(_isOnline);
      debugPrint("📡 Estado de conexión: ${_isOnline ? 'ONLINE' : 'OFFLINE'}");
    }
  }

  /// Registra un callback que se ejecutará cuando vuelva la conexión
  void onReconnect(VoidCallback callback) {
    _onReconnectCallbacks.add(callback);
  }

  /// Remueve un callback de reconexión
  void removeOnReconnect(VoidCallback callback) {
    _onReconnectCallbacks.remove(callback);
  }

  /// Registra un callback que se ejecutará cuando se pierda la conexión
  void onDisconnect(VoidCallback callback) {
    _onDisconnectCallbacks.add(callback);
  }

  /// Remueve un callback de desconexión
  void removeOnDisconnect(VoidCallback callback) {
    _onDisconnectCallbacks.remove(callback);
  }

  /// Verifica activamente si hay conexión (útil antes de operaciones críticas)
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
    return _isOnline;
  }

  /// Limpia recursos
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
    _onReconnectCallbacks.clear();
    _onDisconnectCallbacks.clear();
  }
}
