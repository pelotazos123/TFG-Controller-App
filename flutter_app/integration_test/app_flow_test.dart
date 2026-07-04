import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_rccontroller_app/app.dart';
import 'package:flutter_rccontroller_app/transport/controller_protocol.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('startup, settings navigation, and movement matrix toggle', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.apps), findsWidgets);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    final hasSettingsTitle =
        find.text('Settings').evaluate().isNotEmpty ||
        find.text('Ajustes').evaluate().isNotEmpty;

    expect(hasSettingsTitle, isTrue);

    await tester.dragUntilVisible(
      find.byType(DropdownButton<ControllerMode>),
      find.byType(ListView),
      const Offset(0, -300),
    );

    await tester.tap(find.byType(DropdownButton<ControllerMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WiFi AP').last);
    await tester.pumpAndSettle();

    final hasIpField =
      find.text('ESP32 IP Address').evaluate().isNotEmpty ||
      find.text('Dirección IP del ESP32').evaluate().isNotEmpty;

    expect(hasIpField, isTrue);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.apps), findsWidgets);

    await tester.tap(find.byIcon(Icons.apps));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.apps_outlined), findsWidgets);

    await tester.tap(find.byIcon(Icons.apps_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.apps), findsWidgets);
  });

  testWidgets('theme dropdown in settings', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byType(DropdownButton<ThemeMode>),
      find.byType(ListView),
      const Offset(0, -300),
    );

    expect(find.byType(DropdownButton<ThemeMode>), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('language dropdown in settings', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(
      find.byType(DropdownButton<String>),
      findsWidgets,
      reason: 'Language dropdown should be present in settings',
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('landscape orientation lock and return to portrait', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.screen_rotation), findsOneWidget);
    expect(find.byIcon(Icons.screen_lock_rotation), findsNothing);

    await tester.tap(find.byIcon(Icons.screen_rotation));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.screen_lock_rotation), findsOneWidget);
    expect(find.byIcon(Icons.screen_rotation), findsNothing);

    await tester.tap(find.byIcon(Icons.screen_lock_rotation));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.screen_rotation), findsOneWidget);
    expect(find.byIcon(Icons.screen_lock_rotation), findsNothing);
  });
}