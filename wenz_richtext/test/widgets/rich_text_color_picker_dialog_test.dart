import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

const _hexInputKey = ValueKey<String>('wenz-color-hex-input');
const _spectrumKey = ValueKey<String>('wenz-color-sv-spectrum');
const _hueKey = ValueKey<String>('wenz-color-hue-spectrum');

void main() {
  group('WenzRichTextColorPickerDialog', () {
    testWidgets('shows initial color and synchronizes palette and HEX changes',
        (
      tester,
    ) async {
      await _pumpDialog(
        tester,
        initialColor: const Color(0xFF336699),
      );

      expect(_hexText(tester), '336699');
      _expectSelectedColor(tester, const Color(0xFF336699));

      await tester.tap(find.byKey(const ValueKey<int>(0xFFD32F2F)));
      await tester.pump();
      expect(_hexText(tester), 'D32F2F');
      _expectSelectedColor(tester, const Color(0xFFD32F2F));

      await tester.enterText(find.byKey(_hexInputKey), '#8044AA66');
      await tester.pump();
      expect(_hexText(tester), '8044AA66');
      _expectSelectedColor(tester, const Color(0x8044AA66));
    });

    testWidgets('spectrum and hue gestures keep the HEX value synchronized', (
      tester,
    ) async {
      await _pumpDialog(
        tester,
        initialColor: const Color(0xFFFF0000),
      );

      final hueRect = tester.getRect(find.byKey(_hueKey));
      await tester.tapAt(Offset(hueRect.center.dx, hueRect.center.dy));
      await tester.pump();
      expect(_hexText(tester), '00FFFF');

      final spectrumRect = tester.getRect(find.byKey(_spectrumKey));
      await tester.tapAt(spectrumRect.topLeft + const Offset(120, 75));
      await tester.pump();
      expect(_hexText(tester), '408080');
      _expectSelectedColor(tester, const Color(0xFF408080));
    });

    testWidgets('cancel returns null and apply returns the selected ARGB color',
        (
      tester,
    ) async {
      Color? result;
      var resultReported = false;
      await _pumpDialog(
        tester,
        initialColor: const Color(0xFF111827),
        onResult: (value) {
          result = value;
          resultReported = true;
        },
      );

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(resultReported, isTrue);
      expect(result, isNull);
      expect(find.byType(WenzRichTextColorPickerDialog), findsNothing);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      resultReported = false;
      await tester.enterText(find.byKey(_hexInputKey), '7F336699');
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();

      expect(resultReported, isTrue);
      expect(result?.toARGB32(), 0x7F336699);
      expect(find.byType(WenzRichTextColorPickerDialog), findsNothing);
    });
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required Color initialColor,
  ValueChanged<Color?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showDialog<Color>(
                  context: context,
                  builder: (_) => WenzRichTextColorPickerDialog(
                    initialColor: initialColor,
                    swatches: const <Color>[
                      Color(0xFF111827),
                      Color(0xFFD32F2F),
                      Color(0xFF1976D2),
                    ],
                  ),
                );
                onResult?.call(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

String _hexText(WidgetTester tester) {
  return tester.widget<TextField>(find.byKey(_hexInputKey)).controller!.text;
}

void _expectSelectedColor(WidgetTester tester, Color color) {
  final selectedDots = tester
      .widgetList<WenzRichTextColorDot>(find.byType(WenzRichTextColorDot))
      .where((dot) => dot.selected)
      .toList();
  expect(selectedDots, isNotEmpty);
  expect(
    selectedDots.every((dot) => dot.color.toARGB32() == color.toARGB32()),
    isTrue,
  );
}
