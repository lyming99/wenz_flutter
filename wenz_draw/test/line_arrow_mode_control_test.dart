import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';
import 'package:wenz_draw/wenz_draw_ui.dart';

void main() {
  testWidgets('line arrow control exposes all three modes', (tester) async {
    LineArrowMode? changedMode;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 292,
            child: LineArrowModeControl(
              value: LineArrowMode.none,
              onChanged: (mode) => changedMode = mode,
            ),
          ),
        ),
      ),
    );

    expect(find.text('无箭头'), findsOneWidget);
    expect(find.text('单向箭头'), findsOneWidget);
    expect(find.text('双向箭头'), findsOneWidget);

    await tester.tap(find.text('双向箭头'));
    expect(changedMode, LineArrowMode.both);
  });

  testWidgets('inspector updates a selected line to double arrows', (
    tester,
  ) async {
    final controller = CanvasController()
      ..addElement(
        const LineElement(id: 'line', start: Offset.zero, end: Offset(100, 0)),
        record: false,
      )
      ..setSelection({'line'});
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 292,
            height: 900,
            child: RightInspectorPanel(canvasController: controller),
          ),
        ),
      ),
    );

    expect(find.text('无箭头'), findsOneWidget);
    await tester.tap(find.text('双向箭头'));
    await tester.pump();

    expect(
      (controller.elementById('line') as LineElement).arrowStyle.mode,
      LineArrowMode.both,
    );
  });
}
