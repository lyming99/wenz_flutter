import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  testWidgets('sidebar reveals anchor selection when tapping a thread',
      (tester) async {
    final thread = _thread();
    CommentThread? selectedThread;
    DocumentSelection? revealedSelection;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzCommentSidebar(
            threads: <CommentThread>[thread],
            onSelectThread: (thread) => selectedThread = thread,
            onRevealAnchor: (thread, selection) => revealedSelection = selection,
          ),
        ),
      ),
    );

    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Please clarify this sentence.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('wenz-comment-thread-t1')));
    await tester.pump();

    expect(selectedThread, thread);
    expect(revealedSelection, thread.anchor.selection);
  });

  testWidgets('sidebar exposes resolve and reopen actions', (tester) async {
    final openThread = _thread();
    final resolvedThread = _thread(
      id: 't2',
      status: CommentThreadStatus.resolved,
      resolvedAt: DateTime.utc(2026, 1, 2, 10),
    );
    CommentThread? resolved;
    CommentThread? reopened;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzCommentSidebar(
            threads: <CommentThread>[openThread, resolvedThread],
            activeThreadId: 't2',
            onResolveThread: (thread) => resolved = thread,
            onReopenThread: (thread) => reopened = thread,
          ),
        ),
      ),
    );

    expect(find.text('1 open / 2 total'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('wenz-comment-resolve-t1')));
    await tester.tap(find.byKey(const ValueKey<String>('wenz-comment-reopen-t2')));

    expect(resolved, openThread);
    expect(reopened, resolvedThread);
  });

  testWidgets('sidebar uses dark theme surfaces and status colors',
      (tester) async {
    final openThread = _thread();
    final resolvedThread = _thread(
      id: 't2',
      status: CommentThreadStatus.resolved,
      resolvedAt: DateTime.utc(2026, 1, 2, 10),
    );
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: WenzCommentSidebar(
            threads: <CommentThread>[openThread, resolvedThread],
            activeThreadId: 't1',
          ),
        ),
      ),
    );

    final colorScheme = theme.colorScheme;
    final sidebar = tester.widget<Material>(
      find.byKey(const ValueKey<String>('wenz-comment-sidebar-surface')),
    );
    expect(sidebar.color, colorScheme.surface);
    expect(sidebar.surfaceTintColor, Colors.transparent);

    final activeCard = tester.widget<Card>(
      find.byKey(const ValueKey<String>('wenz-comment-thread-t1')),
    );
    expect(activeCard.color, colorScheme.primaryContainer.withAlpha(72));
    final activeShape = activeCard.shape as RoundedRectangleBorder;
    expect(activeShape.side.color, colorScheme.primary);

    final inactiveCard = tester.widget<Card>(
      find.byKey(const ValueKey<String>('wenz-comment-thread-t2')),
    );
    expect(inactiveCard.color, colorScheme.surfaceContainerLow);

    final openChip = tester.widget<Chip>(
      find.widgetWithText(Chip, 'Open'),
    );
    expect(openChip.backgroundColor, colorScheme.primaryContainer);
    expect(openChip.labelStyle?.color, colorScheme.onPrimaryContainer);

    final resolvedChip = tester.widget<Chip>(
      find.widgetWithText(Chip, 'Resolved'),
    );
    expect(resolvedChip.backgroundColor, colorScheme.secondaryContainer);
    expect(resolvedChip.labelStyle?.color, colorScheme.onSecondaryContainer);
  });
}

CommentThread _thread({
  String id = 't1',
  CommentThreadStatus status = CommentThreadStatus.open,
  DateTime? resolvedAt,
}) {
  return CommentThread(
    id: id,
    anchor: CommentAnchor(
      blockId: 'p1',
      blockIndex: 0,
      path: PositionPath.blockText('p1'),
      startOffset: 0,
      endOffset: 5,
    ),
    messages: <CommentEntry>[
      CommentEntry(
        id: 'm1',
        authorName: 'Alice',
        text: 'Please clarify this sentence.',
        createdAt: DateTime.utc(2026, 1, 2, 8, 30),
      ),
    ],
    createdAt: DateTime.utc(2026, 1, 2, 8, 30),
    status: status,
    resolvedAt: resolvedAt,
  );
}
