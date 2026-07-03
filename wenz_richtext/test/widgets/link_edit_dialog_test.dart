import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  testWidgets('link edit dialog applies trimmed URL', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showWenzLinkEditDialog(context: context);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' https://wenz.dev ');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(result, 'https://wenz.dev');
  });

  testWidgets('link edit dialog uses dark theme surface and outline',
      (tester) async {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: WenzLinkEditDialog(
            initialUrl: 'https://wenz.dev',
            canRemove: true,
          ),
        ),
      ),
    );

    final colorScheme = theme.colorScheme;
    final dialog = tester.widget<AlertDialog>(
      find.byKey(const ValueKey<String>('wenz-link-edit-dialog')),
    );
    expect(dialog.backgroundColor, colorScheme.surfaceContainerLow);
    expect(dialog.elevation, 3);
    expect(dialog.shadowColor, colorScheme.shadow.withAlpha(30));
    expect(dialog.surfaceTintColor, Colors.transparent);
    final shape = dialog.shape as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(10));
    expect(shape.side.color, colorScheme.outlineVariant.withAlpha(96));

    final textField = tester.widget<TextField>(find.byType(TextField));
    final decoration = textField.decoration!;
    final enabledBorder = decoration.enabledBorder! as OutlineInputBorder;
    expect(enabledBorder.borderSide.color,
        colorScheme.outlineVariant.withAlpha(96));

    final removeButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Remove'),
    );
    expect(
      removeButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      colorScheme.error,
    );
  });
}
