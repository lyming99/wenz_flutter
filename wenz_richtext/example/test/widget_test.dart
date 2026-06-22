import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext_example/main.dart';

void main() {
  testWidgets('renders editor workbench', (tester) async {
    // The workbench's toolbar spans many actions and wraps onto extra rows on
    // narrow surfaces; give it enough height so the layout doesn't overflow.
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const WenzRichTextExampleApp());

    expect(find.text('Wenz RichText'), findsOneWidget);
    expect(find.text('Document'), findsOneWidget);
    expect(find.byIcon(Icons.format_bold), findsOneWidget);
    expect(find.byIcon(Icons.table_chart), findsOneWidget);
  });
}
