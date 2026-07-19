import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_ui/tab/reorderable_tab_controller.dart';
import 'package:wenz_ui/tab/reorderable_tab_model.dart';
import 'package:wenz_ui/tab/reorderable_tab_view.dart';

void main() {
  testWidgets('keeps the fourth tab active when the window is resized',
      (tester) async {
    final fixture = ReorderableTabControllerFixture();
    addTearDown(fixture.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.binding.setSurfaceSize(const Size(800, 600));
    await tester.pumpWidget(fixture.buildApp());
    await tester.pumpAndSettle();

    fixture.controller.setSelectTab('tab-4');
    await tester.pumpAndSettle();
    _expectFourthTabIsActive(tester, fixture);

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpAndSettle();
    _expectFourthTabIsActive(tester, fixture);

    await tester.binding.setSurfaceSize(const Size(640, 480));
    await tester.pumpAndSettle();
    _expectFourthTabIsActive(tester, fixture);
  });
}

void _expectFourthTabIsActive(
  WidgetTester tester,
  ReorderableTabControllerFixture fixture,
) {
  expect(fixture.controller.selectedItem, same(fixture.items[3]));
  expect(fixture.controller.selectedIndex, 3);
  expect(fixture.controller.pageController.page, closeTo(3, 0.001));
  expect(find.text('Content 4').hitTestable(), findsOneWidget);
  expect(fixture.tabChanges, [3]);
  expect(fixture.tabChanges, isNot(contains(0)));
}

class ReorderableTabControllerFixture {
  ReorderableTabControllerFixture()
      : items = List.generate(
          4,
          (index) => TabItem<void>(
            id: 'tab-${index + 1}',
            title: 'Tab ${index + 1}',
            builder: (_, __) => Center(child: Text('Content ${index + 1}')),
          ),
        ) {
    controller = ReorderableTabController(
      items: items,
      onTabChanged: tabChanges.add,
    );
  }

  final List<TabItem<void>> items;
  final List<int> tabChanges = [];
  late final ReorderableTabController controller;

  Widget buildApp() {
    return MaterialApp(
      home: Scaffold(
        body: ReorderableTabView(controller: controller),
      ),
    );
  }

  void dispose() {
    controller.pageController.dispose();
    controller.scrollController.dispose();
    controller.focusScopeNode.dispose();
    controller.dispose();
  }
}
