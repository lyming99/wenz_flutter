import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw_example/main.dart';

void main() {
  testWidgets('renders the example canvas app', (tester) async {
    await tester.pumpWidget(const WenzDrawExampleApp());

    expect(find.text('100%'), findsOneWidget);
  });
}
