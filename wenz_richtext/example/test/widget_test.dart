import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';
import 'package:wenz_richtext_example/main.dart';

void main() {
  testWidgets('renders editor workbench', (tester) async {
    await _pumpWorkbench(tester);

    expect(find.text('Wenz RichText'), findsOneWidget);
    expect(find.text('Document'), findsOneWidget);
    expect(find.byIcon(Icons.format_bold), findsOneWidget);
    expect(find.byIcon(Icons.table_chart), findsOneWidget);
  });

  testWidgets('image toolbar picker inserts the selected local image',
      (tester) async {
    final fakeSelector = _FakeFileSelectorPlatform(
      XFile(
        r'C:\tmp\selected.png',
        name: 'selected.png',
        mimeType: 'image/png',
      ),
    );
    _installFakeFileSelector(fakeSelector);
    await _pumpWorkbench(tester);

    await tester.tap(find.byTooltip('插入图片'));
    await tester.pump();
    await tester.pump();

    expect(fakeSelector.openFileCallCount, 1);
    expect(
      fakeSelector.acceptedExtensions,
      containsAll(<String>['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']),
    );
    final images = _editorController(tester)
        .document
        .blocks
        .whereType<ImageBlockNode>()
        .toList();
    expect(images, hasLength(2));
    expect(images.last.file, r'C:\tmp\selected.png');
    expect(images.last.caption, 'selected.png');
    expect(images.last.altText, 'selected.png');
    expect(find.text('selected.png'), findsWidgets);
  });

  testWidgets('image toolbar picker cancellation leaves the document unchanged',
      (tester) async {
    final fakeSelector = _FakeFileSelectorPlatform(null);
    _installFakeFileSelector(fakeSelector);
    await _pumpWorkbench(tester);
    final controller = _editorController(tester);
    final imageCountBefore =
        controller.document.blocks.whereType<ImageBlockNode>().length;

    await tester.tap(find.byTooltip('插入图片'));
    await tester.pump();
    await tester.pump();

    expect(fakeSelector.openFileCallCount, 1);
    expect(controller.document.blocks.whereType<ImageBlockNode>(),
        hasLength(imageCountBefore));
    expect(controller.canUndo, isFalse);
    expect(find.text('cancelled.png'), findsNothing);
  });
}

Future<void> _pumpWorkbench(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const WenzRichTextExampleApp());
}

WenzRichTextController _editorController(WidgetTester tester) {
  return tester.widget<WenzRichTextEditor>(find.byType(WenzRichTextEditor))
      .controller;
}

void _installFakeFileSelector(_FakeFileSelectorPlatform fakeSelector) {
  final previousPlatform = FileSelectorPlatform.instance;
  FileSelectorPlatform.instance = fakeSelector;
  addTearDown(() => FileSelectorPlatform.instance = previousPlatform);
}

class _FakeFileSelectorPlatform extends FileSelectorPlatform {
  _FakeFileSelectorPlatform(this.nextFile);

  final XFile? nextFile;
  int openFileCallCount = 0;
  List<XTypeGroup>? acceptedTypeGroups;

  List<String> get acceptedExtensions {
    return acceptedTypeGroups
            ?.expand((group) => group.extensions ?? const <String>[])
            .toList() ??
        const <String>[];
  }

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    openFileCallCount += 1;
    this.acceptedTypeGroups = acceptedTypeGroups;
    return nextFile;
  }
}
