import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/features/formative_activities/data/repositories/local_formative_activity_repository.dart';
import 'package:jf_innova_app/features/formative_activities/domain/models/formative_activity.dart';
import 'package:jf_innova_app/features/formative_activities/services/formative_activity_pdf_service.dart';
import 'package:jf_innova_app/features/sync/services/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Database db;
  final remote = <String, Map<String, dynamic>>{};
  final uploadedPdfs = <List<int>>[];
  var nextNumber = 1;
  var failPdfUpload = false;
  final repository = LocalFormativeActivityRepository();

  FormativeActivity activity() => FormativeActivity(
    id: 'activity-test',
    usuarioId: 'user-test',
    empresaId: 'company-test',
    tipoActividad: 'CHARLA',
    fecha: DateTime(2026, 10, 17),
    horaInicio: '09:00',
    horaTermino: '09:16',
    asistentes: 4,
    relatorNombre: 'Relator de prueba',
  );

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('formative_sync_');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await DatabaseHelper.instance.database;
    await db.insert('empresas', {
      'id': 'company-test',
      'nombre': 'Empresa de prueba',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => directory.path,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : true,
        );

    await Supabase.initialize(
      url: 'https://formative-test.invalid',
      anonKey: 'test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        const headers = {'content-type': 'application/json'};
        if (path == '/rest/v1/actividades') {
          if (request.method == 'GET') {
            final id = request.url.queryParameters['id']?.substring(3);
            final row = remote[id];
            return http.Response(
              jsonEncode(row == null ? [] : [row]),
              200,
              headers: headers,
              request: request,
            );
          }
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload.containsKey('numero_informe'), isFalse);
          expect(payload.containsKey('numero_reporte'), isFalse);
          if (request.method == 'POST') {
            final row = Map<String, dynamic>.from(payload);
            if (row['estado_final'] == 'En Seguimiento') {
              row['numero_informe'] = nextNumber++;
            }
            remote[row['id'] as String] = row;
            return http.Response(
              jsonEncode(row),
              201,
              headers: headers,
              request: request,
            );
          }
          if (request.method == 'PATCH') {
            final id = request.url.queryParameters['id']!.substring(3);
            final row = remote[id]!;
            row.addAll(payload);
            if (row['estado_final'] == 'En Seguimiento' &&
                row['numero_informe'] == null) {
              row['numero_informe'] = nextNumber++;
            }
            return http.Response('', 204, request: request);
          }
        }
        if (path.startsWith('/storage/v1/object/reportes/')) {
          if (path.endsWith('.pdf')) {
            if (failPdfUpload) {
              return http.Response(
                jsonEncode({
                  'statusCode': '403',
                  'error': 'Forbidden',
                  'message': 'PDF upload rejected by test',
                }),
                403,
                headers: headers,
                request: request,
              );
            }
            final multipart = latin1.decode(request.bodyBytes);
            final start = multipart.indexOf('%PDF-');
            final end = multipart.lastIndexOf('\r\n--');
            expect(start, greaterThanOrEqualTo(0));
            expect(end, greaterThan(start));
            uploadedPdfs.add(request.bodyBytes.sublist(start, end));
          }
          return http.Response(
            jsonEncode({'Key': path.substring('/storage/v1/object/'.length)}),
            200,
            headers: headers,
            request: request,
          );
        }
        if (request.method == 'GET') {
          return http.Response('[]', 200, headers: headers, request: request);
        }
        if (path == '/rest/v1/actividad_formativa_registros') {
          return http.Response('', 201, request: request);
        }
        if (path == '/rest/v1/actividad_participantes' &&
            request.method == 'DELETE') {
          return http.Response('', 204, request: request);
        }
        throw StateError('Unexpected request: ${request.method} $path');
      }),
    );
  });

  setUp(() async {
    await db.delete('actividades_formativas_pendientes');
    await db.delete('actividades_pendientes');
    remote.clear();
    uploadedPdfs.clear();
    nextNumber = 1;
    failPdfUpload = false;
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'drafts consume no number; finalizing synchronizes 1 and its PDF',
    () async {
      await repository.save(activity(), finalized: false);
      await SyncService().sincronizarTodo();
      expect(
        (await repository.getById('activity-test'))!['numero_reporte'],
        isNull,
      );
      expect(nextNumber, 1);
      expect(uploadedPdfs, isEmpty);

      await repository.save(activity(), finalized: true);
      // Offline finalization stores no invented official number.
      expect(
        (await repository.getById('activity-test'))!['numero_reporte'],
        isNull,
      );
      expect(uploadedPdfs, isEmpty);
      await SyncService().sincronizarTodo();

      final row = (await repository.getById('activity-test'))!;
      expect(row['numero_reporte'], '1');
      expect(row['pdf_url'], endsWith('/activity-test/reporte_1.pdf'));
      expect(row['subido'], 1);
      expect(row['hh_sin_relator'], 2);
      expect(row['hh_con_relator'], 2.5);
      expect(uploadedPdfs, hasLength(1));
      expect(ascii.decode(uploadedPdfs.single.take(5).toList()), '%PDF-');
      expect(
        await File(row['pdf_path_local'] as String).readAsBytes(),
        uploadedPdfs.single,
      );
      await SyncService().sincronizarTodo();
      expect(nextNumber, 2);
      expect(uploadedPdfs, hasLength(1));
      expect(
        (await repository.getById('activity-test'))!['numero_reporte'],
        '1',
      );
    },
  );

  test(
    'generates the pending-number preview preserving both stored HH values',
    () async {
      await repository.save(activity(), finalized: false);
      final row = (await repository.getById('activity-test'))!;
      final bytes = await FormativeActivityPdfService().generate(
        data: row,
        signatureBytes: null,
      );
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(row['hh_sin_relator'], 2);
      expect(row['hh_con_relator'], 2.5);
      expect(row['duracion_real_minutos'], 16);
      expect(row['duracion_contabilizada_minutos'], 30);
    },
  );

  test(
    'a failed PDF upload retries without consuming another number',
    () async {
      await repository.save(activity(), finalized: true);
      failPdfUpload = true;
      await SyncService().sincronizarTodo();
      final pending = (await repository.getById('activity-test'))!;
      expect(pending['numero_reporte'], '1');
      expect(pending['pdf_url'], isNull);
      expect(pending['subido'], 0);
      expect(uploadedPdfs, isEmpty);

      failPdfUpload = false;
      await SyncService().sincronizarTodo();
      final synced = (await repository.getById('activity-test'))!;
      expect(synced['numero_reporte'], '1');
      expect(synced['pdf_url'], endsWith('/activity-test/reporte_1.pdf'));
      expect(synced['subido'], 1);
      expect(nextNumber, 2);
      expect(uploadedPdfs, hasLength(1));
    },
  );

  test(
    'does not upload an official PDF before its detail is synchronized',
    () async {
      await repository.save(activity(), finalized: true);
      await db.update('actividades_pendientes', {
        'numero_reporte': '1',
        'subido': 1,
      });
      await SyncService().sincronizarTodo();
      expect(uploadedPdfs, isEmpty);
      expect((await repository.getById('activity-test'))!['pdf_url'], isNull);
    },
  );
}
