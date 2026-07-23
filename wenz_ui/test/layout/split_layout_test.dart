import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_ui/index.dart';

void main() {
  testWidgets('dragging to the far edge keeps both panes visible',
      (tester) async {
    final controller = SplitLayoutController()..position = 320;
    await tester.pumpWidget(
      _splitHarness(
        controller: controller,
        key: const ValueKey('split'),
      ),
    );
    await tester.pump();

    final split = find.byKey(const ValueKey('split'));
    final origin = tester.getTopLeft(split);
    final gesture = await tester.startGesture(
      origin + controller.splitRect.center,
    );
    await gesture.moveBy(const Offset(1000, 0));
    await tester.pump();

    expect(controller.position, 400);
    expect(controller.isPrimaryHide, isFalse);
    expect(controller.isSecondaryHide, isFalse);
    expect(controller.primaryRect.width, 400);
    expect(controller.secondaryRect.width, 400);
    expect(
      tester
          .widgetList<AnimatedPositioned>(
            find.descendant(
              of: split,
              matching: find.byType(AnimatedPositioned),
            ),
          )
          .every((positioned) => positioned.duration == Duration.zero),
      isTrue,
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.position, 400);
    expect(find.byKey(const ValueKey('primary-pane')), findsOneWidget);
    expect(find.byKey(const ValueKey('secondary-pane')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an explicitly preserved position survives a remount',
      (tester) async {
    final controller = SplitLayoutController()..position = 320;
    await tester.pumpWidget(
      _splitHarness(
        controller: controller,
        key: const ValueKey('first-split'),
      ),
    );
    await tester.pump();

    controller.updatePosition(360);
    await tester.pump();
    expect(controller.position, 360);

    await tester.pumpWidget(
      _splitHarness(
        controller: controller,
        key: const ValueKey('second-split'),
      ),
    );
    await tester.pump();

    expect(controller.position, 360);
    expect(tester.takeException(), isNull);
  });
}

Widget _splitHarness({
  required SplitLayoutController controller,
  required Key key,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 800,
          height: 420,
          child: Builder(
            builder: (context) {
              appColor.build(context);
              return SplitLayout(
                key: key,
                controller: controller,
                initPrimaryPosition: false,
                primarySize: 320,
                primaryMinSize: 240,
                secondaryMinSize: 400,
                keepPrimary: true,
                primary: const ColoredBox(
                  key: ValueKey('primary-pane'),
                  color: Colors.blue,
                ),
                secondary: const ColoredBox(
                  key: ValueKey('secondary-pane'),
                  color: Colors.white,
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
