import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:window_border/window_border.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Flutter view follows maximize and restore transitions', (
    WidgetTester tester,
  ) async {
    final WindowBorder plugin = WindowBorder.instance;
    final states = <WindowState>[];
    final subscription = plugin.stateChanges.listen(states.add);
    addTearDown(() async {
      await plugin.restore();
      await subscription.cancel();
    });

    await plugin.initialize(
      style: const WindowBorderStyle(
        borderWidth: 12,
        themeColor: Color(0xFF101010),
        cornerRadius: 14,
        resizeBorderWidth: 12,
      ),
    );

    await plugin.restore();
    await _waitForState(tester, plugin, WindowState.normal);
    final restoredSize = await _waitForStablePhysicalSize(tester);

    await plugin.setStyle(
      const WindowBorderStyle(
        borderWidth: 12,
        themeColor: Color(0xFFF7F7F8),
        cornerRadius: 14,
        resizeBorderWidth: 12,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.view.physicalSize, restoredSize);

    await plugin.maximize();
    await _waitForState(tester, plugin, WindowState.maximized);
    final maximizedSize = await _waitForStablePhysicalSize(
      tester,
      differentFrom: restoredSize,
    );

    expect(await plugin.isMaximized(), isTrue);
    expect(maximizedSize.width, greaterThanOrEqualTo(restoredSize.width));
    expect(maximizedSize.height, greaterThanOrEqualTo(restoredSize.height));

    await plugin.restore();
    await _waitForState(tester, plugin, WindowState.normal);
    final finalSize = await _waitForStablePhysicalSize(
      tester,
      differentFrom: maximizedSize,
    );

    expect(await plugin.isMaximized(), isFalse);
    expect(finalSize, restoredSize);
    expect(
      states,
      containsAllInOrder(<WindowState>[
        WindowState.maximized,
        WindowState.normal,
      ]),
    );
  });
}

Future<void> _waitForState(
  WidgetTester tester,
  WindowBorder plugin,
  WindowState expected,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (await plugin.getState() == expected) return;
  }
  fail('Window did not reach ${expected.name} within 10 seconds.');
}

Future<Size> _waitForStablePhysicalSize(
  WidgetTester tester, {
  Size? differentFrom,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  Size? previous;
  var stableSamples = 0;

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 50));
    final current = tester.view.physicalSize;
    final isUsable = current.width > 0 && current.height > 0;
    final hasUpdated = differentFrom == null || current != differentFrom;

    if (isUsable && hasUpdated && current == previous) {
      stableSamples += 1;
      if (stableSamples >= 3) return current;
    } else {
      stableSamples = 0;
    }
    previous = current;
  }

  fail(
    'Flutter view did not reach a stable, updated physical size within '
    '10 seconds (last size: $previous).',
  );
}
