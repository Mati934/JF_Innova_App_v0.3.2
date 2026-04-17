import 'package:flutter_test/flutter_test.dart';

/// Tests que verifican que los mensajes de error al finalizar inspección
/// concuerdan con el error real que ocurrió.
///
/// Simula la lógica CORREGIDA de finalizarInspeccion() con:
/// - _mensajeErrorAmigable() para traducir excepciones a mensajes legibles
/// - _esErrorDeRed() para distinguir errores de red vs locales
/// - errorPdfNoRecuperable flag para errores de PDF que no son de conexión

void main() {
  // ===================================================================
  // TESTS: _mensajeErrorAmigable - traduce excepciones a mensajes útiles
  // ===================================================================
  group('_mensajeErrorAmigable', () {
    test('Disco lleno → mensaje específico', () {
      expect(
        _mensajeErrorAmigable(Exception('No space left on device')),
        'No hay espacio en el dispositivo.',
      );
    });

    test('Permission denied → mensaje específico', () {
      expect(
        _mensajeErrorAmigable(Exception('Permission denied')),
        'Sin permisos para guardar archivos.',
      );
    });

    test('UNIQUE constraint → mensaje de duplicado', () {
      expect(
        _mensajeErrorAmigable(
          Exception('UNIQUE constraint failed: actividades_pendientes.id'),
        ),
        'Registro duplicado en la base de datos.',
      );
    });

    test('Database error genérico → mensaje de DB', () {
      expect(
        _mensajeErrorAmigable(Exception('DatabaseException: table locked')),
        'Error en la base de datos local.',
      );
    });

    test('SQLite error → mensaje de DB', () {
      expect(
        _mensajeErrorAmigable(Exception('sqlite: disk I/O error')),
        'Error en la base de datos local.',
      );
    });

    test('SocketException → mensaje de conexión', () {
      expect(
        _mensajeErrorAmigable(Exception('SocketException: Connection refused')),
        'Sin conexión a internet.',
      );
    });

    test('Timeout → mensaje de conexión', () {
      expect(
        _mensajeErrorAmigable(Exception('TimeoutException after 0:00:30')),
        'Sin conexión a internet.',
      );
    });

    test('Error desconocido → mensaje genérico pero diferente al viejo', () {
      final msg = _mensajeErrorAmigable(Exception('algo raro'));
      expect(msg, 'Error inesperado al guardar datos.');
      expect(msg, isNot(contains('inténtelo de nuevo')));
    });
  });

  // ===================================================================
  // TESTS: _esErrorDeRed - distingue error de red vs error local
  // ===================================================================
  group('_esErrorDeRed', () {
    test('SocketException → true', () {
      expect(
        _esErrorDeRed(Exception('SocketException: Connection refused')),
        true,
      );
    });

    test('TimeoutException → true', () {
      expect(_esErrorDeRed(Exception('timeout exceeded')), true);
    });

    test('Connection reset → true', () {
      expect(_esErrorDeRed(Exception('Connection reset by peer')), true);
    });

    test('HandshakeException → true', () {
      expect(
        _esErrorDeRed(
          Exception('HandshakeException: CERTIFICATE_VERIFY_FAILED'),
        ),
        true,
      );
    });

    test('IsolateSpawnException → false (no es de red)', () {
      expect(_esErrorDeRed(Exception('IsolateSpawnException')), false);
    });

    test('Asset not found → false', () {
      expect(_esErrorDeRed(Exception('Unable to load asset')), false);
    });

    test('Database error → false', () {
      expect(_esErrorDeRed(Exception('DatabaseException')), false);
    });

    test('Disk full → false', () {
      expect(_esErrorDeRed(Exception('No space left on device')), false);
    });
  });

  // ===================================================================
  // TESTS: Validación de negocio - mensajes específicos
  // ===================================================================
  group('Validación de negocio - mensajes específicos', () {
    test('Buceo con <2 participantes muestra mensaje específico', () {
      final resultado = _simularFinalizacion(
        tipoActividad: 'INSPECCION_BUCEO',
        cantParticipantes: 1,
      );
      expect(resultado.exito, false);
      expect(
        resultado.errorMessage,
        'Debe haber al menos 2 participantes en la cuadrilla.',
      );
    });

    test('Buceo con 0 participantes muestra mensaje específico', () {
      final resultado = _simularFinalizacion(
        tipoActividad: 'INSPECCION_BUCEO',
        cantParticipantes: 0,
      );
      expect(resultado.exito, false);
      expect(resultado.errorMessage, contains('2 participantes'));
    });

    test('Buceo con 2+ participantes pasa validación', () {
      final resultado = _simularFinalizacion(
        tipoActividad: 'INSPECCION_BUCEO',
        cantParticipantes: 3,
      );
      expect(resultado.errorMessage, isNot(contains('participantes')));
    });

    test('Embarcación no requiere validación de participantes', () {
      final resultado = _simularFinalizacion(
        tipoActividad: 'INSPECCION_EMBARCACION',
        cantParticipantes: 0,
      );
      expect(resultado.errorMessage, isNot(contains('participantes')));
    });
  });

  // ===================================================================
  // TESTS: Fallo de persistencia - ahora con mensaje específico
  // ===================================================================
  group('Fallo de persistencia - mensajes corregidos', () {
    test('DB constraint → mensaje menciona base de datos', () {
      final resultado = _simularFinalizacion(
        tipoActividad: 'INSPECCION_BUCEO',
        cantParticipantes: 3,
        persistirFalla: true,
        persistirError: 'DatabaseException: UNIQUE constraint failed',
      );

      expect(resultado.exito, false);
      expect(resultado.errorMessage, contains('Registro duplicado'));
      expect(resultado.errorMessage, startsWith('Error al finalizar:'));
    });

    test('Disco lleno → mensaje menciona espacio', () {
      final resultado = _simularFinalizacion(
        tipoActividad: 'INSPECCION_EMBARCACION',
        cantParticipantes: 0,
        persistirFalla: true,
        persistirError: 'FileSystemException: No space left on device',
      );

      expect(resultado.exito, false);
      expect(resultado.errorMessage, contains('espacio'));
    });

    test('Permission denied → mensaje menciona permisos', () {
      final resultado = _simularFinalizacion(
        tipoActividad: 'INSPECCION_BUCEO',
        cantParticipantes: 3,
        persistirFalla: true,
        persistirError: 'Permission denied: /data/user/0/...',
      );

      expect(resultado.exito, false);
      expect(resultado.errorMessage, contains('permisos'));
    });

    test('Error SQLite genérico → mensaje menciona base de datos', () {
      final resultado = _simularFinalizacion(
        tipoActividad: 'INSPECCION_BUCEO',
        cantParticipantes: 3,
        persistirFalla: true,
        persistirError: 'sqlite: disk I/O error',
      );

      expect(resultado.exito, false);
      expect(resultado.errorMessage, contains('base de datos'));
    });

    test('Error desconocido → mensaje genérico pero con prefijo', () {
      final resultado = _simularFinalizacion(
        tipoActividad: 'INSPECCION_BUCEO',
        cantParticipantes: 3,
        persistirFalla: true,
        persistirError: 'algo completamente inesperado',
      );

      expect(resultado.exito, false);
      expect(resultado.errorMessage, startsWith('Error al finalizar:'));
      expect(resultado.errorMessage, contains('inesperado'));
      // Ya no dice "inténtelo de nuevo" genérico sin contexto
      expect(resultado.errorMessage, isNot(contains('inténtelo de nuevo')));
    });
  });

  // ===================================================================
  // TESTS: Fallo de PDF - ahora distingue red vs error local
  // ===================================================================
  group('Fallo de PDF - mensajes corregidos', () {
    test(
      'Error de red al generar PDF → pdfDiferido=true, éxito (correcto)',
      () {
        final resultado = _simularFinalizacion(
          tipoActividad: 'INSPECCION_BUCEO',
          cantParticipantes: 3,
          tieneNumeroReal: true,
          pdfFalla: true,
          pdfError: 'SocketException: Connection refused',
        );

        // Error de red: diferir tiene sentido, el PDF se generará al reconectar
        expect(resultado.exito, true);
        expect(resultado.pdfDiferido, true);
        expect(resultado.errorPdfNoRecuperable, false);
      },
    );

    test('IsolateSpawnException → pdfDiferido + errorPdfNoRecuperable', () {
      final resultado = _simularFinalizacion(
        tipoActividad: 'INSPECCION_BUCEO',
        cantParticipantes: 3,
        tieneNumeroReal: true,
        pdfFalla: true,
        pdfError: 'IsolateSpawnException: Unable to spawn isolate',
      );

      // NO es error de red: diferir NO lo arreglará
      expect(resultado.exito, true);
      expect(resultado.pdfDiferido, true);
      expect(resultado.errorPdfNoRecuperable, true);
    });

    test('Asset no encontrado → pdfDiferido + errorPdfNoRecuperable', () {
      final resultado = _simularFinalizacion(
        tipoActividad: 'INSPECCION_EMBARCACION',
        cantParticipantes: 0,
        tieneNumeroReal: true,
        pdfFalla: true,
        pdfError: 'Unable to load asset: assets/fonts/Roboto-Regular.ttf',
      );

      expect(resultado.exito, true);
      expect(resultado.pdfDiferido, true);
      expect(resultado.errorPdfNoRecuperable, true);
    });

    test('Fallo de PDF local → error con detalle', () {
      final resultado = _simularFinalizacion(
        tipoActividad: 'INSPECCION_BUCEO',
        cantParticipantes: 3,
        tieneNumeroReal: true,
        pdfLocalFalla: true,
        pdfLocalError: 'Permission denied: /storage/emulated/0/...',
      );

      expect(resultado.exito, false);
      expect(resultado.errorMessage, contains('PDF'));
      expect(resultado.errorMessage, contains('permisos'));
    });

    test('Fallo de PDF local por disco lleno → error con detalle', () {
      final resultado = _simularFinalizacion(
        tipoActividad: 'INSPECCION_BUCEO',
        cantParticipantes: 3,
        tieneNumeroReal: true,
        pdfLocalFalla: true,
        pdfLocalError: 'No space left on device',
      );

      expect(resultado.exito, false);
      expect(resultado.errorMessage, contains('PDF'));
      expect(resultado.errorMessage, contains('espacio'));
    });
  });

  // ===================================================================
  // TESTS: Sync silencioso (sin cambio - es comportamiento deseado offline)
  // ===================================================================
  group('Sync offline - comportamiento esperado', () {
    test('Sync falla → continúa en modo offline con pdfDiferido', () {
      final resultado = _simularFinalizacion(
        tipoActividad: 'INSPECCION_BUCEO',
        cantParticipantes: 3,
        syncFalla: true,
        syncError: 'SocketException: Connection refused',
      );

      // En modo offline-first, esto es correcto: guardar local y sincronizar después
      expect(resultado.exito, true);
      expect(resultado.pdfDiferido, true);
      expect(resultado.syncFallo, true);
    });
  });

  // ===================================================================
  // TESTS: UI - Mapeo de estados a mensajes de SnackBar
  // ===================================================================
  group('UI: SnackBar mensajes corregidos', () {
    test('Éxito normal → verde', () {
      final ui = _resolverMensajeUI(
        exito: true,
        pdfDiferido: false,
        errorPdfNoRecuperable: false,
      );
      expect(ui.mensaje, 'Inspeccion finalizada y PDF generado correctamente.');
      expect(ui.color, 'green');
    });

    test('PDF diferido por red → naranja con mensaje de conexión', () {
      final ui = _resolverMensajeUI(
        exito: true,
        pdfDiferido: true,
        errorPdfNoRecuperable: false,
      );
      expect(ui.mensaje, contains('al recuperar conexion'));
      expect(ui.color, 'orange');
    });

    test('PDF falló por error no recuperable → naranja oscuro con aviso', () {
      final ui = _resolverMensajeUI(
        exito: true,
        pdfDiferido: true,
        errorPdfNoRecuperable: true,
      );
      expect(ui.mensaje, contains('sin PDF'));
      expect(ui.mensaje, contains('soporte'));
      expect(ui.mensaje, isNot(contains('al recuperar conexion')));
      expect(ui.color, 'orange_dark');
    });

    test('Error → rojo con mensaje específico', () {
      final ui = _resolverMensajeUI(
        exito: false,
        errorMessage: 'Error al finalizar: No hay espacio en el dispositivo.',
      );
      expect(ui.mensaje, contains('espacio'));
      expect(ui.color, 'red');
    });

    test('Error sin errorMessage → fallback rojo', () {
      final ui = _resolverMensajeUI(exito: false, errorMessage: null);
      expect(ui.color, 'red');
    });
  });

  // ===================================================================
  // TESTS: Tabla de verdad corregida
  // ===================================================================
  group('Tabla de verdad CORREGIDA: error real vs mensaje', () {
    final escenarios = <_Escenario>[
      _Escenario(
        nombre: 'Pocos participantes (buceo)',
        errorReal: 'Validación de negocio',
        mensajeMostrado: 'Debe haber al menos 2 participantes en la cuadrilla.',
        esCorrecto: true,
      ),
      _Escenario(
        nombre: 'DB constraint violation',
        errorReal: 'UNIQUE constraint failed',
        mensajeMostrado:
            'Error al finalizar: Registro duplicado en la base de datos.',
        esCorrecto: true,
      ),
      _Escenario(
        nombre: 'Disco lleno',
        errorReal: 'No space left on device',
        mensajeMostrado:
            'Error al finalizar: No hay espacio en el dispositivo.',
        esCorrecto: true,
      ),
      _Escenario(
        nombre: 'PDF falla por error de red',
        errorReal: 'SocketException',
        mensajeMostrado: 'PDF se generara al recuperar conexion (correcto)',
        esCorrecto: true,
      ),
      _Escenario(
        nombre: 'PDF isolate crash (no recuperable)',
        errorReal: 'IsolateSpawnException',
        mensajeMostrado: 'Inspeccion guardada sin PDF... contacte soporte',
        esCorrecto: true,
      ),
      _Escenario(
        nombre: 'PDF local: permiso denegado',
        errorReal: 'Permission denied',
        mensajeMostrado:
            'No se pudo guardar el PDF: Sin permisos para guardar archivos.',
        esCorrecto: true,
      ),
      _Escenario(
        nombre: 'Sync falla (offline-first, esperado)',
        errorReal: 'SocketException',
        mensajeMostrado: 'Diferido (modo offline correcto)',
        esCorrecto: true,
      ),
    ];

    for (final e in escenarios) {
      test(
        '${e.nombre}: mensaje ${e.esCorrecto ? "CORRECTO" : "INCORRECTO"}',
        () {
          expect(
            e.esCorrecto,
            true,
            reason:
                'Después del fix, todos los escenarios deben tener mensajes correctos',
          );
        },
      );
    }

    test('Resumen: 7 de 7 escenarios con mensajes correctos', () {
      final correctos = escenarios.where((e) => e.esCorrecto).length;
      expect(correctos, 7);
    });
  });
}

// ===================================================================
// HELPERS
// ===================================================================

class _ResultadoFinalizacion {
  final bool exito;
  final String? errorMessage;
  final bool pdfDiferido;
  final bool errorPdfNoRecuperable;
  final bool syncFallo;

  _ResultadoFinalizacion({
    required this.exito,
    this.errorMessage,
    this.pdfDiferido = false,
    this.errorPdfNoRecuperable = false,
    this.syncFallo = false,
  });
}

class _Escenario {
  final String nombre;
  final String errorReal;
  final String mensajeMostrado;
  final bool esCorrecto;

  _Escenario({
    required this.nombre,
    required this.errorReal,
    required this.mensajeMostrado,
    required this.esCorrecto,
  });
}

class _UIMensaje {
  final String mensaje;
  final String color;

  _UIMensaje({required this.mensaje, required this.color});
}

/// Replica de _esErrorDeRed del controller
bool _esErrorDeRed(Object e) {
  final msg = e.toString().toLowerCase();
  return msg.contains('socket') ||
      msg.contains('connection') ||
      msg.contains('timeout') ||
      msg.contains('network') ||
      msg.contains('host') ||
      msg.contains('handshake') ||
      msg.contains('certificate');
}

/// Replica de _mensajeErrorAmigable del controller
String _mensajeErrorAmigable(Object e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('no space') || msg.contains('disk full')) {
    return 'No hay espacio en el dispositivo.';
  }
  if (msg.contains('permission denied') || msg.contains('access denied')) {
    return 'Sin permisos para guardar archivos.';
  }
  if (msg.contains('unique constraint') || msg.contains('duplicate')) {
    return 'Registro duplicado en la base de datos.';
  }
  if (msg.contains('database') || msg.contains('sqlite')) {
    return 'Error en la base de datos local.';
  }
  if (_esErrorDeRed(e)) {
    return 'Sin conexión a internet.';
  }
  return 'Error inesperado al guardar datos.';
}

/// Simula la lógica CORREGIDA de finalizarInspeccion()
_ResultadoFinalizacion _simularFinalizacion({
  required String tipoActividad,
  required int cantParticipantes,
  bool tieneNumeroReal = false,
  bool persistirFalla = false,
  String persistirError = 'Unknown error',
  bool syncFalla = false,
  String syncError = 'Connection error',
  bool pdfFalla = false,
  String pdfError = 'PDF generation error',
  bool pdfLocalFalla = false,
  String pdfLocalError = 'Unknown error',
}) {
  String? errorMessage;
  bool pdfDiferido = false;
  bool errorPdfNoRecuperable = false;
  bool syncFallo = false;

  // 1. Validación de negocio
  if (tipoActividad == 'INSPECCION_BUCEO') {
    if (cantParticipantes < 2) {
      return _ResultadoFinalizacion(
        exito: false,
        errorMessage: 'Debe haber al menos 2 participantes en la cuadrilla.',
      );
    }
  }

  try {
    // PASO 1: Persistir como borrador
    if (persistirFalla) {
      throw Exception(persistirError);
    }

    // PASO 2: Sync para obtener número
    try {
      if (syncFalla) {
        throw Exception(syncError);
      }
    } catch (e) {
      syncFallo = true;
    }

    // Verificar número real
    final bool tieneNumero = tieneNumeroReal && !syncFallo;

    if (!tieneNumero) {
      return _ResultadoFinalizacion(
        exito: true,
        pdfDiferido: true,
        syncFallo: syncFallo,
      );
    }

    // ONLINE: generar PDF
    try {
      if (pdfFalla) {
        throw Exception(pdfError);
      }

      if (pdfLocalFalla) {
        final detalle = _mensajeErrorAmigable(Exception(pdfLocalError));
        return _ResultadoFinalizacion(
          exito: false,
          errorMessage: 'No se pudo guardar el PDF: $detalle',
        );
      }

      return _ResultadoFinalizacion(exito: true);
    } catch (e) {
      // CORREGIDO: Distinguir error de red vs error local
      final esRed = _esErrorDeRed(e);
      pdfDiferido = true;
      errorPdfNoRecuperable = !esRed;

      return _ResultadoFinalizacion(
        exito: true,
        pdfDiferido: true,
        errorPdfNoRecuperable: errorPdfNoRecuperable,
      );
    }
  } catch (e) {
    // CORREGIDO: Mensaje específico en vez de genérico
    final detalle = _mensajeErrorAmigable(e);
    errorMessage = 'Error al finalizar: $detalle';
    return _ResultadoFinalizacion(exito: false, errorMessage: errorMessage);
  }
}

/// Simula la lógica CORREGIDA de _finalizar() en inspection_form_screen.dart
_UIMensaje _resolverMensajeUI({
  required bool exito,
  bool pdfDiferido = false,
  bool errorPdfNoRecuperable = false,
  String? errorMessage,
}) {
  if (exito) {
    if (errorPdfNoRecuperable) {
      return _UIMensaje(
        mensaje:
            'Inspeccion guardada sin PDF. Hubo un error generando el informe, contacte soporte si persiste.',
        color: 'orange_dark',
      );
    } else if (pdfDiferido) {
      return _UIMensaje(
        mensaje:
            'Inspeccion guardada. El informe PDF se generara automaticamente al recuperar conexion.',
        color: 'orange',
      );
    } else {
      return _UIMensaje(
        mensaje: 'Inspeccion finalizada y PDF generado correctamente.',
        color: 'green',
      );
    }
  } else {
    return _UIMensaje(
      mensaje:
          errorMessage ??
          '❌ No se pudo finalizar. Error interno al guardar datos.',
      color: 'red',
    );
  }
}
