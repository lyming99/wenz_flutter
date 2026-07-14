// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:window_border/window_border.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native window state is available', (WidgetTester tester) async {
    final WindowBorder plugin = WindowBorder.instance;
    await plugin.initialize(enabled: false);

    expect(await plugin.getState(), isNot(WindowState.unknown));
  });
}
