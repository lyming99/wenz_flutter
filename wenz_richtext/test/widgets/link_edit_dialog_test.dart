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
}
