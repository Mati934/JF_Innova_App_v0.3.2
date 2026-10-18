import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/core/database/database_helper.dart';
import 'package:jf_innova_app/core/services/user_session.dart';
import 'package:jf_innova_app/features/formative_activities/data/repositories/local_formative_activity_repository.dart';
import 'package:jf_innova_app/features/formative_activities/domain/models/formative_activity.dart';
import 'package:jf_innova_app/features/formative_activities/presentation/screens/formative_activity_form_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory databaseDirectory;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseDirectory = await Directory.systemTemp.createTemp(
      'formative_form_',
    );
    await databaseFactory.setDatabasesPath(databaseDirectory.path);
    final db = await DatabaseHelper.instance.database;
    await db.insert('empresas', {
      'id': 'company',
      'nombre': 'Empresa de prueba',
    });
    await db.insert('usuarios', {
      'id': 'user',
      'nombre_completo': 'Relator de prueba',
      'empresa_id': 'company',
    });
    await db.insert('areas', {'id': 'area', 'nombre': 'Area de prueba'});
    await db.insert('empresa_areas', {
      'empresa_id': 'company',
      'area_id': 'area',
    });
    await db.insert('centros', {
      'id': 'center',
      'nombre': 'Centro de prueba',
      'area_id': 'area',
    });
    await UserSession().loadFromSQLite('user');
    await LocalFormativeActivityRepository().save(
      FormativeActivity(
        id: '747659dd-test',
        usuarioId: 'user',
        empresaId: 'company',
        tipoActividad: 'CHARLA',
        fecha: DateTime(2026, 10, 17),
        horaInicio: '09:00',
        horaTermino: '09:16',
        asistentes: 4,
        relatorNombre: 'Relator de prueba',
      ),
      finalized: false,
    );
  });

  tearDownAll(() async {
    UserSession().clear();
    await (await DatabaseHelper.instance.database).close();
    await databaseDirectory.delete(recursive: true);
  });

  testWidgets('keeps context fields and shows only HH including the relator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FormativeActivityFormScreen(activityId: '747659dd-test'),
        ),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (find.byType(Form).evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });

    expect(find.text('Empresa de prueba'), findsOneWidget);
    expect(find.text('Área'), findsOneWidget);
    expect(find.text('Centro'), findsOneWidget);
    expect(find.text('Contexto'), findsNothing);
    expect(find.byIcon(Icons.help_outline), findsNothing);

    final scrollable = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Total HH'),
      250,
      scrollable: scrollable,
    );
    expect(find.text('Total HH'), findsOneWidget);
    expect(find.text('2.50'), findsOneWidget);
    expect(find.text('Duración real'), findsOneWidget);
    expect(find.text('16 min'), findsOneWidget);
    expect(find.text('Duración contabilizada'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Duración real')).dy,
      tester.getTopLeft(find.text('Duración contabilizada')).dy,
    );
    expect(find.text('Incluye al relator.'), findsOneWidget);
    expect(find.textContaining('HH sin relator'), findsNothing);
    expect(find.textContaining('confirmar cuál regla'), findsNothing);

    final attendees = find.widgetWithText(
      TextFormField,
      'Cantidad de asistentes',
    );
    expect(find.text('No incluyas al relator.'), findsOneWidget);
    expect(tester.widget<TextFormField>(attendees).controller!.text, '4');
    await tester.enterText(attendees, '8');
    await tester.pump();
    expect(find.text('4.50'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Finalizar registro'),
      250,
      scrollable: scrollable,
    );
    expect(find.text('Borrador 747659dd'), findsNothing);
    await tester.tap(find.text('Previsualizar PDF'));
    await tester.pump();
    expect(
      tester
          .widget<ButtonStyleButton>(
            find.ancestor(
              of: find.text('Finalizar registro'),
              matching: find.byWidgetPredicate(
                (widget) => widget is ButtonStyleButton,
              ),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
