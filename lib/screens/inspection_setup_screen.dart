import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import 'inspection_form_screen.dart';

class InspectionSetupScreen extends StatefulWidget {
  const InspectionSetupScreen({super.key});

  @override
  State<InspectionSetupScreen> createState() => _InspectionSetupScreenState();
}

class _InspectionSetupScreenState extends State<InspectionSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper.instance;
  final _syncService = SyncService();

  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _centros = [];
  List<Map<String, dynamic>> _contratistas = [];
  List<Map<String, dynamic>> _embarcaciones = [];

  String? _areaId;
  String? _centroId;
  String? _estadoPuerto = 'ABIERTO';
  String? _actividadPuertoCerrado;
  String? _tipoActividad;
  String? _contratistaId;
  String? _embarcacionId;

  final List<String> _tiposInspeccion = [
    'INSPECCION_BUCEO',
    'INSPECCION_EMBARCACION',
  ];
  final List<String> _estadosPuerto = ['ABIERTO', 'CERRADO'];
  final List<String> _opcionesPuertoCerrado = [
    'PRE_INSPECCION',
    'CHARLAS_SEGURIDAD',
    'LIMPIEZA_PLAYA',
    'SIN_ACTIVIDAD',
    'OTRAS_LABORES',
  ];

  @override
  void initState() {
    super.initState();
    _cargarListasIniciales();
  }

  Future<void> _cargarListasIniciales() async {
    final areas = await _dbHelper.getAreas();
    final contratistas = await _dbHelper.getContratistas();
    if (mounted) {
      setState(() {
        _areas = areas;
        _contratistas = contratistas;
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarCentros(String areaId) async {
    final centros = await _dbHelper.getCentros(areaId);
    setState(() {
      _centroId = null;
      _centros = centros;
    });
  }

  Future<void> _cargarEmbarcaciones(String contratistaId) async {
    final naves = await _dbHelper.getEmbarcaciones(contratistaId);
    setState(() {
      _embarcacionId = null;
      _embarcaciones = naves;
    });
  }

  Future<void> _crearActividad() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final newActivityId = const Uuid().v4();

      final bool esInspeccionCompleta =
          _estadoPuerto == 'ABIERTO' ||
          (_estadoPuerto == 'CERRADO' &&
              _actividadPuertoCerrado == 'PRE_INSPECCION');

      final String tipoFinal = esInspeccionCompleta
          ? _tipoActividad!
          : 'BITACORA';

      String? obs = _estadoPuerto == 'CERRADO'
          ? 'Puerto Cerrado: $_actividadPuertoCerrado'
          : null;

      // Obtenemos el nombre del centro para pasarlo a la siguiente pantalla
      final nombreCentroSeleccionado = _centros.firstWhere(
        (c) => c['id'] == _centroId,
        orElse: () => {'nombre': 'Centro Desconocido'},
      )['nombre'];

      final datosActividad = {
        'id': newActivityId,
        'usuario_id': userId,
        'centro_id': _centroId,
        'fecha_realizacion': DateTime.now().toIso8601String(),
        'puerto_abierto': _estadoPuerto == 'ABIERTO' ? 1 : 0,
        'tipo_actividad': tipoFinal,
        'observaciones_generales': obs,
        'contratista_id': esInspeccionCompleta ? _contratistaId : null,
        'embarcacion_id': esInspeccionCompleta ? _embarcacionId : null,
        'estado_final': 'En Seguimiento',
        'subido': 0,
      };

      await _dbHelper.saveActividadOffline(datosActividad);

      _syncService.sincronizarTodo().catchError(
        (e) => debugPrint("Sync background error: $e"),
      );

      if (mounted) {
        if (esInspeccionCompleta) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => InspectionFormScreen(
                activityId: newActivityId,
                tipoActividad: tipoFinal,
                nombreCentro: nombreCentroSeleccionado,
              ),
            ),
          );
        } else {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Bitácora guardada localmente.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando actividad: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool mostrarFormularioCompleto =
        _estadoPuerto == 'ABIERTO' ||
        (_estadoPuerto == 'CERRADO' &&
            _actividadPuertoCerrado == 'PRE_INSPECCION');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración Faena'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              // Asegura que no se meta en el notch o barra inferior
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                        '📍 Ubicación y Estado',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 15),

                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Área / Región',
                          border: OutlineInputBorder(),
                        ),
                        value: _areaId,
                        items: _areas
                            .map(
                              (x) => DropdownMenuItem(
                                value: x['id'] as String,
                                child: Text(
                                  x['nombre'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() => _areaId = v);
                          if (v != null) _cargarCentros(v);
                        },
                        validator: (v) => v == null ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 15),

                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          // CAMBIO SOLICITADO
                          labelText: 'Centro de Trabajo',
                          border: OutlineInputBorder(),
                        ),
                        value: _centroId,
                        items: _centros
                            .map(
                              (x) => DropdownMenuItem(
                                value: x['id'] as String,
                                child: Text(
                                  x['nombre'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _centroId = v),
                        validator: (v) => v == null ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 15),

                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Condición de Puerto',
                          border: const OutlineInputBorder(),
                          fillColor: _estadoPuerto == 'CERRADO'
                              ? Colors.red.shade50
                              : null,
                          filled: _estadoPuerto == 'CERRADO',
                        ),
                        value: _estadoPuerto,
                        items: _estadosPuerto
                            .map(
                              (x) => DropdownMenuItem(value: x, child: Text(x)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          _estadoPuerto = v;
                          _actividadPuertoCerrado = null;
                        }),
                      ),

                      if (_estadoPuerto == 'CERRADO') ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '⚠️ Puerto Cerrado',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Actividad Realizada',
                                  border: OutlineInputBorder(),
                                ),
                                value: _actividadPuertoCerrado,
                                items: _opcionesPuertoCerrado
                                    .map(
                                      (x) => DropdownMenuItem(
                                        value: x,
                                        child: Text(
                                          x.replaceAll('_', ' '),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _actividadPuertoCerrado = v),
                                validator: (v) =>
                                    v == null ? 'Requerido' : null,
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (mostrarFormularioCompleto) ...[
                        const SizedBox(height: 30),
                        const Divider(),
                        const Text(
                          '📋 Datos Técnicos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF003366),
                          ),
                        ),
                        const SizedBox(height: 15),

                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de Inspección',
                            border: OutlineInputBorder(),
                          ),
                          value: _tipoActividad,
                          items: _tiposInspeccion
                              .map(
                                (x) => DropdownMenuItem(
                                  value: x,
                                  child: Text(
                                    x,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _tipoActividad = v;
                            _contratistaId = null;
                            _embarcacionId = null;
                            _embarcaciones = [];
                          }),
                          validator: (v) => v == null ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 15),

                        if (_tipoActividad != null) ...[
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: _tipoActividad == 'INSPECCION_BUCEO'
                                  ? 'Empresa de Buceo'
                                  : 'Naviera',
                              border: const OutlineInputBorder(),
                            ),
                            value: _contratistaId,
                            items: _contratistas
                                .map(
                                  (x) => DropdownMenuItem(
                                    value: x['id'] as String,
                                    child: Text(
                                      x['nombre'],
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() => _contratistaId = v);
                              if (v != null) _cargarEmbarcaciones(v);
                            },
                            validator: (v) => v == null ? 'Requerido' : null,
                          ),
                          const SizedBox(height: 15),

                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Embarcación',
                              border: OutlineInputBorder(),
                            ),
                            value:
                                _embarcaciones.any(
                                  (e) => e['id'] == _embarcacionId,
                                )
                                ? _embarcacionId
                                : null,
                            items: _embarcaciones
                                .map(
                                  (x) => DropdownMenuItem(
                                    value: x['id'] as String,
                                    child: Text(
                                      x['nombre'],
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _embarcacionId = v),
                          ),
                        ],
                      ],

                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _crearActividad,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mostrarFormularioCompleto
                                ? const Color(0xFF003366)
                                : Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  mostrarFormularioCompleto
                                      ? Icons.assignment
                                      : Icons.save,
                                ),
                          label: Text(
                            _isSaving
                                ? 'GUARDANDO...'
                                : (mostrarFormularioCompleto
                                      ? 'COMENZAR INSPECCIÓN'
                                      : 'GUARDAR BITÁCORA'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // COLCHÓN PARA QUE EL BOTÓN NO QUEDE PEGADO AL BORDE INFERIOR
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
