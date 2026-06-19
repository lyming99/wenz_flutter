import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext_example/main.dart';

void main() {
  testWidgets('renders editor workbench', (tester) async {
    await tester.pumpWidget(const WenzRichTextExampleApp());

    expect(find.text('Wenz RichText'), findsOneWidget);
    expect(find.text('Document'), findsOneWidget);
    expect(find.byIcon(Icons.format_bold), findsOneWidget);
    expect(find.byIcon(Icons.table_chart), findsOneWidget);
  });
}
