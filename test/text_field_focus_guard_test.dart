import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/core/utils/focus_utils.dart';

Widget _app({required FocusNode focusNode}) {
  return MaterialApp(
    builder: (context, child) => TextFieldFocusGuard(child: child!),
    home: Scaffold(
      body: ListView(
        children: [
          TextField(key: const Key('campo'), focusNode: focusNode),
          const SizedBox(key: Key('vacio'), height: 300),
          const SizedBox(height: 2000),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets(
    'tocar fuera de la caja la suelta (también en Android)',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_app(focusNode: focus));

      await tester.tap(find.byKey(const Key('campo')));
      await tester.pump();
      expect(focus.hasFocus, isTrue);

      await tester.tap(find.byKey(const Key('vacio')), warnIfMissed: false);
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'desplazar desde la misma caja también la suelta',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_app(focusNode: focus));

      await tester.tap(find.byKey(const Key('campo')));
      await tester.pump();
      expect(focus.hasFocus, isTrue);

      // El arrastre empieza dentro de la caja: el toque afuera no aplica,
      // la suelta el aviso de inicio de scroll.
      await tester.drag(find.byKey(const Key('campo')), const Offset(0, -300));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'desplazar las opciones de un Autocomplete no lo cierra',
    (tester) async {
      final opciones = List.generate(30, (i) => 'Opcion $i');
      await tester.pumpWidget(
        MaterialApp(
          builder: (c, child) => TextFieldFocusGuard(child: child!),
          home: Scaffold(
            body: Autocomplete<String>(
              optionsBuilder: (v) => opciones.where((o) => o.contains(v.text)),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('Opcion 0'), findsOneWidget);

      await tester.drag(find.text('Opcion 1'), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(find.textContaining('Opcion '), findsWidgets);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'tocar una opción del Autocomplete la selecciona',
    (tester) async {
      final opciones = List.generate(30, (i) => 'Opcion $i');
      String? sel;
      await tester.pumpWidget(
        MaterialApp(
          builder: (c, child) => TextFieldFocusGuard(child: child!),
          home: Scaffold(
            body: Autocomplete<String>(
              optionsBuilder: (v) => opciones.where((o) => o.contains(v.text)),
              onSelected: (s) => sel = s,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Opcion 2'));
      await tester.pumpAndSettle();
      expect(sel, 'Opcion 2');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'el scroll interno de una caja de varias líneas no la suelta',
    (tester) async {
      final f = FocusNode();
      final c = TextEditingController(
        text: List.generate(40, (i) => 'linea $i').join('\n'),
      );
      addTearDown(f.dispose);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (ctx, child) => TextFieldFocusGuard(child: child!),
          home: Scaffold(
            body: ListView(
              children: [
                TextField(
                  key: const Key('m'),
                  focusNode: f,
                  controller: c,
                  maxLines: 4,
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('m')));
      await tester.pump();
      await tester.drag(find.byKey(const Key('m')), const Offset(0, -40));
      await tester.pump();
      expect(f.hasFocus, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'tocar otra caja pasa el foco sin cerrar el teclado',
    (tester) async {
      final a = FocusNode();
      final b = FocusNode();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (ctx, child) => TextFieldFocusGuard(child: child!),
          home: Scaffold(
            body: Column(
              children: [
                TextField(key: const Key('a'), focusNode: a),
                TextField(key: const Key('b'), focusNode: b),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('a')));
      await tester.pump();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('b'))),
      );
      await tester.pump();
      expect(a.hasFocus, isTrue);
      await gesture.up();
      await tester.pump();
      expect(b.hasFocus, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'tocar dentro de la caja no la suelta',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_app(focusNode: focus));

      await tester.tap(find.byKey(const Key('campo')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('campo')));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
    },
    variant: TargetPlatformVariant.mobile(),
  );
}
