import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jf_innova_app/core/theme/app_theme.dart';
import 'package:jf_innova_app/shared/widgets/gradient_app_bar.dart';
import 'package:jf_innova_app/features/inspection/presentation/widgets/category_header.dart';

/// Smoke tests para los widgets visuales rediseñados.
///
/// Estos tests validan que los widgets puros (sin dependencias de
/// controllers/services) renderizan sin errores tras el rediseño visual y
/// preservan los contratos clave (texto en mayúsculas, foreground blanco,
/// gradiente, elementos accesibles para los test keys de integración).
void main() {
  group('GradientAppBar', () {
    testWidgets('renderiza title y actions sin errores', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: GradientAppBar(
              title: Text('Mi Título'),
              actions: [Icon(Icons.search)],
              centerTitle: true,
            ),
          ),
        ),
      );

      expect(find.text('Mi Título'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('preferredSize incluye altura del bottom widget', (
      tester,
    ) async {
      const bar = GradientAppBar(
        title: Text('x'),
        bottom: TabBar(
          tabs: [
            Tab(text: 'A'),
            Tab(text: 'B'),
          ],
        ),
      );
      // kToolbarHeight (56) + TabBar.preferredSize.height (~46)
      expect(bar.preferredSize.height, greaterThan(kToolbarHeight));
    });

    testWidgets('preferredSize sin bottom es kToolbarHeight', (tester) async {
      const bar = GradientAppBar(title: Text('x'));
      expect(bar.preferredSize.height, kToolbarHeight);
    });

    testWidgets('foreground es blanco', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(appBar: GradientAppBar(title: Text('Test'))),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.foregroundColor, Colors.white);
      expect(appBar.backgroundColor, Colors.transparent);
    });

    testWidgets('expone gradient en flexibleSpace', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(appBar: GradientAppBar(title: Text('Test'))),
        ),
      );

      // El flexibleSpace contiene un Container con BoxDecoration que tiene gradient
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      final grad = decoration.gradient as LinearGradient;
      expect(grad.colors, contains(AppTheme.primaryBlue));
    });
  });

  group('CategoryHeader', () {
    testWidgets('muestra el nombre en MAYÚSCULAS', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CategoryHeader(nombre: 'Equipos de Buceo')),
        ),
      );
      expect(find.text('EQUIPOS DE BUCEO'), findsOneWidget);
      expect(find.text('Equipos de Buceo'), findsNothing);
    });

    testWidgets('renderiza icono folder en cápsula', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CategoryHeader(nombre: 'X')),
        ),
      );
      expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);
    });

    testWidgets('aplica gradiente azul corporativo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CategoryHeader(nombre: 'X')),
        ),
      );
      final container = tester
          .widgetList<Container>(find.byType(Container))
          .first;
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      final grad = decoration.gradient as LinearGradient;
      expect(grad.colors.first, AppTheme.primaryBlue);
      expect(decoration.borderRadius, BorderRadius.circular(14));
    });

    testWidgets('texto largo no rompe layout (Expanded)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryHeader(
              nombre:
                  'Categoría con un nombre muy muy largo que podría provocar overflow horizontal',
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
