// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

/// Performance benchmarks for the editor's rendering layer.
///
/// These run as normal `flutter test` cases but their purpose is to *measure*
/// frame build/layout/paint cost, not to assert correctness. Each case:
///   1. mounts the editor in a fixed 800×600 viewport,
///   2. warms up with a couple of frames,
///   3. times a fixed number of frames and prints the average per-frame µs.
///
/// The numbers depend on the host machine, so each case also enforces a *loose*
/// upper bound (well above what a healthy run produces) — enough to catch a
/// severe regression (e.g. virtualisation accidentally disabled) without
/// flaking on slower CI boxes. Compare before/after on the same machine for
/// real signal.
///
/// Run manually:
/// ```
/// flutter test test/benchmarks/editor_benchmarks.dart
/// ```
///
/// Roadmap scenarios (see docs/optimization_roadmap.md stage 5):
/// - 1k blocks (large document).
/// - 10k inline runs (a single block with many text runs).
/// - a large table (50×20 cells).

const Size _benchViewport = Size(800, 600);

/// Average per-frame time (µs) across [frames] pumps, after a warm-up. Also
/// returns the worst single-frame time for tail-latency reporting.
Future<({double avgUs, double maxUs})> _timeFrames(
  WidgetTester tester, {
  required int frames,
}) async {
  // Warm up so the first build / layout / paint is not counted.
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final stopwatch = Stopwatch()..start();
  var maxMicros = 0;
  for (var i = 0; i < frames; i++) {
    final frame = Stopwatch()..start();
    await tester.pump(const Duration(milliseconds: 16));
    frame.stop();
    if (frame.elapsedMicroseconds > maxMicros) {
      maxMicros = frame.elapsedMicroseconds;
    }
  }
  stopwatch.stop();
  return (
    avgUs: stopwatch.elapsedMicroseconds / frames,
    maxUs: maxMicros.toDouble(),
  );
}

void _report(String label, ({double avgUs, double maxUs}) r) {
  print('  $label: avg ${r.avgUs.toStringAsFixed(0)}µs/frame, '
      'max ${r.maxUs.toStringAsFixed(0)}µs/frame');
}
Widget _harness(WenzRichTextController controller) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox.fromSize(
        size: _benchViewport,
        child: WenzRichTextEditor(controller: controller, enableIme: false),
      ),
    ),
  );
}

RichTextDocument _largeBlockDocument({int count = 1000}) {
  return RichTextDocument(
    blocks: <BlockNode>[
      for (var i = 0; i < count; i++)
        TextBlockNode(
          id: 'p$i',
          type: BlockType.paragraph,
          content: <InlineNode>[
            TextRun(text: 'Paragraph $i — the quick brown fox jumps over.'),
          ],
        ),
    ],
  );
}

/// A single paragraph containing [runCount] text runs, each one character with
/// alternating bold, to stress the inline-span construction + layout.
RichTextDocument _inlineRunDocument(int runCount) {
  final runs = <InlineNode>[];
  for (var i = 0; i < runCount; i++) {
    runs.add(TextRun(text: 'a', attributes: TextAttributes(bold: i.isEven)));
  }
  return RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(id: 'heavy', type: BlockType.paragraph, content: runs),
    ],
  );
}

RichTextDocument _largeTableDocument({int rows = 50, int columns = 20}) {
  final tableRows = <List<TableCellNode>>[
    for (var r = 0; r < rows; r++)
      <TableCellNode>[
        for (var c = 0; c < columns; c++)
          TableCellNode(
            id: 'cell-$r-$c',
            blocks: <BlockNode>[
              TextBlockNode(
                id: 'cell-$r-$c-p',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: '$r,$c')],
              ),
            ],
            isHeader: r == 0,
          ),
      ],
  ];
  return RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(id: 'bigtable', table: TableModel(rows: tableRows)),
    ],
  );
}

void main() {
  testWidgets('benchmark: 1k blocks initial mount + idle frames', (tester) async {
    tester.view.physicalSize = _benchViewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller =
        WenzRichTextController(document: _largeBlockDocument(count: 1000));
    await tester.pumpWidget(_harness(controller));

    final r = await _timeFrames(tester, frames: 20);
    _report('1k blocks', r);
    // Loose guard: a healthy virtualised mount stays well under this even on
    // slow machines. ~50ms/frame would indicate virtualisation regressed.
    expect(r.avgUs, lessThan(50000), reason: '1k-block frame budget blew out');
  });

  testWidgets('benchmark: 1k blocks caret-driven editing tick', (tester) async {
    tester.view.physicalSize = _benchViewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = WenzRichTextController(
      document: _largeBlockDocument(count: 1000),
      selection: _textPosition('p0', 0, 0),
    );
    await tester.pumpWidget(_harness(controller));
    await tester.pump();

    // Prime an editing tick (incremental rebuild path).
    controller.insertText('x');
    await tester.pump();
    final r = await _timeFrames(tester, frames: 20);
    _report('1k blocks editing', r);
    expect(r.avgUs, lessThan(50000), reason: 'editing frame budget blew out');
  });

  testWidgets('benchmark: 10k inline runs single-block mount', (tester) async {
    tester.view.physicalSize = _benchViewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller =
        WenzRichTextController(document: _inlineRunDocument(10000));
    await tester.pumpWidget(_harness(controller));

    final r = await _timeFrames(tester, frames: 20);
    _report('10k inline runs', r);
    // 10k runs is a heavy single block; allow a generous budget.
    expect(r.avgUs, lessThan(120000), reason: '10k-run frame budget blew out');
  });

  testWidgets('benchmark: large table (50x20) mount', (tester) async {
    tester.view.physicalSize = _benchViewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller =
        WenzRichTextController(document: _largeTableDocument(rows: 50, columns: 20));
    await tester.pumpWidget(_harness(controller));

    final r = await _timeFrames(tester, frames: 20);
    _report('50x20 table', r);
    expect(r.avgUs, lessThan(120000), reason: 'large-table frame budget blew out');
  });

  testWidgets('benchmark: 1k blocks scroll (remount cost)', (tester) async {
    // Scrolling mounts/unmounts blocks continuously. With the shared
    // TextPainter cache, re-entering a previously-viewed block should reuse its
    // laid-out painter. This case exercises the remount path.
    tester.view.physicalSize = _benchViewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller =
        WenzRichTextController(document: _largeBlockDocument(count: 1000));
    await tester.pumpWidget(_harness(controller));
    // Scroll down then back up so blocks remount, then time steady scrolling.
    await tester.drag(find.byType(WenzRichTextEditor), const Offset(0, -4000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(WenzRichTextEditor), const Offset(0, 4000));
    await tester.pumpAndSettle();

    // Now time frames while scrolling (each pump advances ~16ms of scroll).
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      await tester.drag(
        find.byType(WenzRichTextEditor),
        const Offset(0, -120),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    stopwatch.stop();
    final avgUs = stopwatch.elapsedMicroseconds / 20;
    print('  1k blocks scroll (remount): avg ${avgUs.toStringAsFixed(0)}µs/frame');
    expect(avgUs, lessThan(80000), reason: 'scroll/remount budget blew out');
  });
}

DocumentSelection _textPosition(String blockId, int blockIndex, int offset) {
  final position = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockText(blockId),
    offset: offset,
  );
  return DocumentSelection(base: position, extent: position);
}
