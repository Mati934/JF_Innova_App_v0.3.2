import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/empresa_logo_service.dart';
import '../../../core/services/user_session.dart';
import '../domain/models/pdf/inspection_report_data.dart';
import '../domain/models/buceo_verificacion_model.dart';
import 'pdf_generator_service.dart';

/// Genera PDFs diferidos para inspecciones que se finalizaron offline.
/// Se invoca desde SyncService después de que el numero_informe real
/// haya sido asignado por el trigger de Supabase.
class DeferredPdfService {
  final _dbHelper = DatabaseHelper.instance;
  final _supabase = Supabase.instance.client;

  /// Genera el PDF para una actividad que fue finalizada sin PDF.
  /// Retorna true si el PDF se generó y subió correctamente.
  Future<bool> generarPdfDiferido(String activityId) async {
    try {
      final db = await _dbHelper.database;

      // 1. Leer la actividad
      final rows = await db.query(
        'actividades_pendientes',
        where: 'id = ?',
        whereArgs: [activityId],
      );
      if (rows.isEmpty) return false;

      final row = rows.first;
      final String? numeroReporte = row['numero_reporte']?.toString();
      if (numeroReporte == null || numeroReporte.isEmpty) {
        debugPrint("⚠️ [PDF Diferido] Sin numero_reporte para $activityId");
        return false;
      }

      final String tipoActividad = row['tipo_actividad'] as String;
      debugPrint(
        "📄 [PDF Diferido] Generando para $activityId ($tipoActividad) N.$numeroReporte",
      );

      // 2. Construir DTO desde SQLite
      final reportData = await _buildReportDataFromDatabase(db, row);

      // 3. Cargar fonts y logo (rootBundle funciona en main thread)
      final fontReg = await rootBundle.load(
        "assets/fonts/OpenSans-Regular.ttf",
      );
      final fontBold = await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");
      final fontItalic = await rootBundle.load(
        "assets/fonts/OpenSans-Italic.ttf",
      );

      Uint8List? logoBytes;
      try {
        logoBytes = await EmpresaLogoService.instance.getLogoForActiveEmpresa(
          fallbackAsset: 'assets/images/aquachileporfin3.png',
        );
      } catch (e) {
        debugPrint("⚠️ [PDF Diferido] No se pudo cargar el logo: $e");
      }

      // 4. Generar PDF en isolate
      final params = PdfIsolateParams(
        data: reportData,
        fontRegular: fontReg.buffer.asUint8List(),
        fontBold: fontBold.buffer.asUint8List(),
        fontItalic: fontItalic.buffer.asUint8List(),
        logoBytes: logoBytes,
      );

      final pdfBytes = await compute(generatePdfEntryPoint, params);
      debugPrint(
        "✅ [PDF Diferido] PDF generado (${pdfBytes.lengthInBytes / 1024} KB)",
      );

      // 5. Guardar localmente
      final directory = await getApplicationDocumentsDirectory();
      final nombreArchivo = "reporte_$numeroReporte.pdf";
      final localFile = File('${directory.path}/$nombreArchivo');
      await localFile.writeAsBytes(pdfBytes);

      // 6. Subir a Supabase Storage
      final pathStorage = "$activityId/$nombreArchivo";
      await _supabase.storage
          .from('reportes')
          .uploadBinary(
            pathStorage,
            pdfBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final pdfUrl = _supabase.storage
          .from('reportes')
          .getPublicUrl(pathStorage);

      // 7. Actualizar URLs en SQLite y Supabase
      await db.update(
        'actividades_pendientes',
        {'pdf_url': pdfUrl, 'pdf_path_local': null},
        where: 'id = ?',
        whereArgs: [activityId],
      );

      await _supabase
          .from('actividades')
          .update({'pdf_url': pdfUrl})
          .eq('id', activityId);

      debugPrint("✅ [PDF Diferido] Completado: $pdfUrl");
      return true;
    } catch (e) {
      debugPrint("🔥 [PDF Diferido] Error para $activityId: $e");
      return false;
    }
  }

  /// Construye el InspectionReportData completo leyendo solo de SQLite.
  /// Replica la lógica de InspectionFormController._buildReportData().
  Future<InspectionReportData> _buildReportDataFromDatabase(
    dynamic db,
    Map<String, dynamic> activityRow,
  ) async {
    final String activityId = activityRow['id'] as String;
    final String tipoActividad = activityRow['tipo_actividad'] as String;
    final String numeroReporte =
        activityRow['numero_reporte']?.toString() ?? "S/N";
    final int numeroSeguimiento =
        (activityRow['numero_seguimiento'] as int?) ?? 0;
    final bool esConsecutiva = numeroSeguimiento == 1;

    // --- Version app ---
    String versionApp = "v1.0.0";
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      versionApp = "v${packageInfo.version}";
    } catch (_) {}

    // --- Nombres de entidades ---
    String nombreCliente = "S/N";
    String nombreEmpresaContratista = "S/N";
    String nombreCentro = "CENTRO S/N";
    String nombreArea = "AREA S/N";
    String nombreEmbarcacion = "NAVE S/N";
    String matriculaEmbarcacion = "S/N";

    // Nombre del profesional
    String nombreProfesional = "USUARIO APP";
    final usuarioId = activityRow['usuario_id'] as String?;
    if (usuarioId != null) {
      final userLocal = await db.query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [usuarioId],
        limit: 1,
      );
      if (userLocal.isNotEmpty &&
          userLocal.first['nombre_completo']?.toString().trim().isNotEmpty ==
              true) {
        nombreProfesional = userLocal.first['nombre_completo'].toString();
      } else {
        final currentUser = _supabase.auth.currentUser;
        if (currentUser != null) {
          final meta = currentUser.userMetadata;
          nombreProfesional =
              meta?['nombre_completo'] ??
              meta?['full_name'] ??
              currentUser.email ??
              "USUARIO APP";
        }
      }
    }

    // Centro → Area → Empresa (cliente)
    final centroId = activityRow['centro_id'] as String?;
    if (centroId != null) {
      final resCentro = await db.query(
        'centros',
        where: 'id = ?',
        whereArgs: [centroId],
      );
      if (resCentro.isNotEmpty) {
        nombreCentro = resCentro.first['nombre'] as String;
        final areaId = resCentro.first['area_id'] as String;
        final resArea = await db.query(
          'areas',
          where: 'id = ?',
          whereArgs: [areaId],
        );
        if (resArea.isNotEmpty) {
          nombreArea = resArea.first['nombre'] as String;
          if (resArea.first['empresa_id'] != null) {
            final resCliente = await db.query(
              'empresas',
              where: 'id = ?',
              whereArgs: [resArea.first['empresa_id']],
            );
            if (resCliente.isNotEmpty) {
              nombreCliente = resCliente.first['nombre'] as String;
            }
          }
        }
      }
    }

    // Contratista
    final contratistaId = activityRow['contratista_id'] as String?;
    if (contratistaId != null) {
      final res = await db.query(
        'contratistas',
        where: 'id = ?',
        whereArgs: [contratistaId],
      );
      if (res.isNotEmpty) {
        nombreEmpresaContratista = res.first['nombre'] as String;
      }
    }

    // Embarcación
    final embarcacionId = activityRow['embarcacion_id'] as String?;
    if (embarcacionId != null) {
      final res = await db.query(
        'embarcaciones',
        where: 'id = ?',
        whereArgs: [embarcacionId],
      );
      if (res.isNotEmpty) {
        nombreEmbarcacion = res.first['nombre']?.toString() ?? "NAVE S/N";
        matriculaEmbarcacion = res.first['matricula']?.toString() ?? "S/N";
      }
    }

    // --- Items del formulario + Respuestas ---
    final itemsDb = await db.query(
      'formulario_items',
      where: 'tipo_actividad = ? AND activo = 1',
      whereArgs: [tipoActividad],
      orderBy: 'orden ASC',
    );

    final respuestasDb = await db.query(
      'inspeccion_respuestas_pendientes',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );

    // Indexar respuestas por item_id
    final Map<String, Map<String, dynamic>> respuestasMap = {};
    for (var r in respuestasDb) {
      respuestasMap[r['item_id'] as String] = r;
    }

    // Fotos por pregunta
    final fotosDb = await db.query(
      'fotos_pendientes',
      where: 'actividad_id = ?',
      whereArgs: [activityId],
    );

    // Indexar fotos: item_id → [local_path]
    final Map<String, List<String>> fotosPorItem = {};
    final List<String> fotosGeneralesPaths = [];
    final List<Map<String, String>> fotosExtraPaths = [];

    // Obtener set de IDs de items del formulario
    final Set<String> itemIds = itemsDb
        .map<String>((i) => i['id'] as String)
        .toSet();

    for (var foto in fotosDb) {
      final itemId = foto['item_id'] as String?;
      final localPath = foto['local_path'] as String?;
      if (localPath == null) continue;

      if (itemId == null) {
        // Foto general
        fotosGeneralesPaths.add(localPath);
      } else if (itemIds.contains(itemId)) {
        // Foto de pregunta
        fotosPorItem.putIfAbsent(itemId, () => []).add(localPath);
      } else {
        // Foto con observación (item_id no coincide con formulario_items)
        final desc = foto['descripcion'] as String? ?? '';
        fotosExtraPaths.add({'path': localPath, 'observacion': desc});
      }
    }

    // Procesar items y conteos
    int countC = 0, countNC = 0, countNA = 0, countIntolerables = 0;
    double sumPesoC = 0.0, sumPesoNC = 0.0;
    final List<InspectionItemDto> itemsProcesados = [];

    for (var item in itemsDb) {
      final itemId = item['id'] as String;
      final resp = respuestasMap[itemId];
      final respuesta = resp?['estado']?.toString() ?? 'N/A';
      final observacion = resp?['observacion']?.toString() ?? '';
      final criticidad =
          resp?['criticidad_registrada']?.toString() ??
          item['criticidad']?.toString() ??
          'Tolerable';
      final peso = (item['peso'] as num?)?.toDouble() ?? 1.0;

      if (respuesta == 'C') {
        countC++;
        sumPesoC += peso;
      } else if (respuesta == 'NC') {
        countNC++;
        sumPesoNC += peso;
        if (criticidad == 'Intolerable') countIntolerables++;
      } else if (respuesta == 'N/A') {
        countNA++;
      }

      final List<String> fotosPaths = fotosPorItem[itemId] ?? [];

      itemsProcesados.add(
        InspectionItemDto(
          categoria: item['categoria']?.toString() ?? '',
          pregunta: item['pregunta']?.toString() ?? '',
          respuesta: respuesta,
          criticidad: criticidad,
          comentario: observacion,
          orden: item['orden'] as int? ?? 0,
          fotosPaths: fotosPaths,
        ),
      );
    }

    // --- Verificaciones ---
    BuceoVerificacionModel? verificacionesBuceo;
    Map<String, String?> safetyPhotosPaths = {};
    Map<String, String?> safetyObservations = {};
    String? encargadoCentro;
    String supervisorNombre = "No asignado";
    String? horaInicio;
    String? horaTermino;
    String? compresor1Matricula,
        compresor1Vigencia,
        compresor1PH,
        compresor1Buzos;
    String? compresor2Matricula,
        compresor2Vigencia,
        compresor2PH,
        compresor2Buzos;
    String observacionPrevencionista = "Sin observaciones.";
    String? correoEmpresaServicios;
    String? numeroZarpe;

    if (tipoActividad == 'INSPECCION_BUCEO') {
      final vRows = await db.query(
        'verificaciones_buceo',
        where: 'actividad_id = ?',
        whereArgs: [activityId],
      );
      if (vRows.isNotEmpty) {
        verificacionesBuceo = BuceoVerificacionModel.fromMap(vRows.first);

        safetyPhotosPaths = {
          'IV': verificacionesBuceo.imgAutorizacion,
          'V': verificacionesBuceo.imgInduccion,
          'VI': verificacionesBuceo.imgPermiso,
          'VII': verificacionesBuceo.imgPlan,
          'VIII': verificacionesBuceo.imgExamenes,
        };
        safetyObservations = {
          'IV': verificacionesBuceo.obsAutorizacion,
          'V': verificacionesBuceo.obsInduccion,
          'VI': verificacionesBuceo.obsPermiso,
          'VII': verificacionesBuceo.obsPlan,
          'VIII': verificacionesBuceo.obsExamenes,
        };
        encargadoCentro = verificacionesBuceo.encargadoCentro;
        supervisorNombre =
            verificacionesBuceo.supervisorNombre ?? "No asignado";
        horaInicio = verificacionesBuceo.horaInicio;
        horaTermino = verificacionesBuceo.horaTermino;
        observacionPrevencionista =
            verificacionesBuceo.observacionGeneral ?? "Sin observaciones.";

        compresor1Matricula = verificacionesBuceo.compresor1Matricula;
        compresor1Vigencia = _fmtDate(verificacionesBuceo.compresor1Vigencia);
        compresor1PH = _fmtDate(verificacionesBuceo.compresor1VigenciaPH);
        compresor1Buzos = verificacionesBuceo.compresor1BuzosCargo?.toString();
        compresor2Matricula = verificacionesBuceo.compresor2Matricula;
        compresor2Vigencia = _fmtDate(verificacionesBuceo.compresor2Vigencia);
        compresor2PH = _fmtDate(verificacionesBuceo.compresor2VigenciaPH);
        compresor2Buzos = verificacionesBuceo.compresor2BuzosCargo?.toString();

        // Sumar verificaciones al conteo
        final criticas = [
          verificacionesBuceo.autorizacionAutoridadMaritima,
          verificacionesBuceo.induccionCentroCultivo,
          verificacionesBuceo.permisoBuceoCentroCorrecto,
          verificacionesBuceo.planContingenciasCentroOk,
          verificacionesBuceo.examenesOcupacionalesVigentes,
        ];
        for (var cumple in criticas) {
          if (cumple) {
            countC++;
            sumPesoC += 1.0;
          } else {
            countNC++;
            sumPesoNC += 1.0;
          }
        }
      }
    } else if (tipoActividad == 'INSPECCION_EMBARCACION') {
      final vRows = await db.query(
        'verificaciones_embarcacion',
        where: 'actividad_id = ?',
        whereArgs: [activityId],
      );
      if (vRows.isNotEmpty) {
        correoEmpresaServicios = vRows.first['correo_empresa']?.toString();
        numeroZarpe = vRows.first['numero_zarpe']?.toString();
        horaInicio = vRows.first['hora_inicio']?.toString();
        horaTermino = vRows.first['hora_termino']?.toString();
      }
    }

    // --- Participantes ---
    final partRows = await db.rawQuery(
      '''
      SELECT pe.nombre_completo, pe.rut, pe.cargo, pe.matricula, ap.condiciones_optimas
      FROM actividad_participantes ap
      INNER JOIN personal_externo pe ON pe.id = ap.personal_id
      WHERE ap.actividad_id = ?
    ''',
      [activityId],
    );

    final List<PersonalDto> equipoDto = partRows.map<PersonalDto>((p) {
      final condiciones = (p['condiciones_optimas'] as int?) == 1;
      return PersonalDto(
        nombre: p['nombre_completo']?.toString() ?? '',
        rut: p['rut']?.toString() ?? '',
        cargo: p['cargo']?.toString() ?? '',
        matricula: (p['matricula']?.toString().isEmpty ?? true)
            ? "-"
            : p['matricula'].toString(),
        rolEnFaena: condiciones ? "Optima" : "NO APTO",
      );
    }).toList();

    // --- Lógica de aprobación ---
    bool aprobadoFinal = true;
    String estadoGlobalFinal = "FINALIZADA";

    if (tipoActividad == 'INSPECCION_BUCEO') {
      aprobadoFinal =
          countIntolerables == 0 &&
          (verificacionesBuceo?.faenaHabilitada ?? true);
      estadoGlobalFinal = aprobadoFinal ? "HABILITADA" : "SUSPENDIDA";
    } else {
      aprobadoFinal = true;
      estadoGlobalFinal = "REALIZADA";
    }

    // --- Fecha ---
    final fechaStr = activityRow['fecha']?.toString();
    String fechaFormateada;
    if (fechaStr != null && fechaStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(fechaStr);
        fechaFormateada =
            "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
      } catch (_) {
        fechaFormateada = fechaStr;
      }
    } else {
      final now = DateTime.now();
      fechaFormateada =
          "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    }

    return InspectionReportData(
      empresaProveedor:
          (UserSession().empresaNombre ?? 'JF INNOVA').toUpperCase(),
      appVersion: versionApp,
      esConsecutiva: esConsecutiva,
      empresaContratista: nombreEmpresaContratista,
      cliente: nombreCliente,
      logoUrl: "",
      numeroReporte: numeroReporte,
      fecha: fechaFormateada,
      centro: nombreCentro,
      area: nombreArea,
      embarcacion: nombreEmbarcacion,
      matricula: matriculaEmbarcacion,
      numeroZarpe: numeroZarpe ?? "S/N",
      safetyPhotosPaths: safetyPhotosPaths,
      safetyObservations: safetyObservations,
      encargadoCentro: encargadoCentro,
      correoEmpresaServicios: correoEmpresaServicios,
      profesional: nombreProfesional,
      tipoFaena: tipoActividad == 'INSPECCION_EMBARCACION'
          ? "INSPECCION DE EMBARCACION"
          : "INSPECCION DE BUCEO",
      supervisor: supervisorNombre,
      horaInicio: horaInicio ?? "--:--",
      horaTermino: horaTermino ?? "--:--",
      compresor1Matricula: compresor1Matricula,
      compresor1Vigencia: compresor1Vigencia,
      compresor1PH: compresor1PH,
      compresor1Buzos: compresor1Buzos,
      compresor2Matricula: compresor2Matricula,
      compresor2Vigencia: compresor2Vigencia,
      compresor2PH: compresor2PH,
      compresor2Buzos: compresor2Buzos,
      estadoGlobal: estadoGlobalFinal,
      esAprobado: aprobadoFinal,
      equipo: equipoDto,
      items: itemsProcesados,
      fotosGeneralesPaths: fotosGeneralesPaths,
      fotosExtraObservaciones: fotosExtraPaths,
      totalCumple: countC,
      totalNoCumple: countNC,
      totalNoAplica: countNA,
      totalIntolerables: countIntolerables,
      sumPesoCumple: sumPesoC,
      sumPesoNoCumple: sumPesoNC,
      observacionPrevencionista: observacionPrevencionista,
      verificacionesBuceo: verificacionesBuceo != null
          ? {
              'IV. Autorizacion de la Faena':
                  verificacionesBuceo.autorizacionAutoridadMaritima,
              'V. Induccion Centro de Cultivo':
                  verificacionesBuceo.induccionCentroCultivo,
              'VI. Permiso de Buceo (Centro Correcto)':
                  verificacionesBuceo.permisoBuceoCentroCorrecto,
              'VII. Plan de Contingencias':
                  verificacionesBuceo.planContingenciasCentroOk,
              'VIII. Examenes Ocupacionales Vigentes':
                  verificacionesBuceo.examenesOcupacionalesVigentes,
            }
          : {},
    );
  }

  String? _fmtDate(DateTime? dt) {
    if (dt == null) return null;
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
  }
}
