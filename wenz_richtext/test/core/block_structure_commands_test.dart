import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  group('IndentCommand', () {
    test('increases indent on text blocks in the selection', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              attributes: BlockAttributes(anchor: 'intro'),
              content: <InlineNode>[TextRun(text: 'a')],
            ),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'b')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const IndentCommand(1));

      final block = session.document.blocks[0] as TextBlockNode;
      expect(block.attributes.indent, 1);
      expect(block.attributes.anchor, 'intro');
      // block 2 untouched (not in the collapsed selection); normaliser clamps
      // a null indent to 0.
      expect(
        (session.document.blocks[1] as TextBlockNode).attributes.indent,
        0,
      );
    });

    test('clamps at zero when outdenting an unindented block', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const IndentCommand(-1));

      expect(
        (session.document.blocks.single as TextBlockNode).attributes.indent,
        0,
      );
    });
  });

  group('ToggleTodoCommand', () {
    test('converts a paragraph to an unchecked task item', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'todo')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const ToggleTodoCommand());

      final block = session.document.blocks.single as TextBlockNode;
      expect(block.type, BlockType.listItem);
      expect(block.attributes.listType, 'task');
      expect(block.attributes.checked, isFalse);
    });

    test('toggles checked state on an existing task item', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 't1',
              type: BlockType.listItem,
              attributes: BlockAttributes(listType: 'task', checked: false),
              content: <InlineNode>[TextRun(text: 'todo')],
            ),
          ],
        ),
        selection: collapsedTextSelection('t1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const ToggleTodoCommand());

      expect(
        (session.document.blocks.single as TextBlockNode).attributes.checked,
        isTrue,
      );
    });
  });

  group('MoveBlockCommand', () {
    test('moves a block to the requested final index and records history', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'one')],
            ),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'two')],
            ),
            TextBlockNode(
              id: 'p3',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'three')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      final change = executor.execute(
        const MoveBlockCommand(fromIndex: 0, toIndex: 2),
      );

      expect(change.description, 'moveBlock');
      expect(session.document.blocks.map((block) => block.id), [
        'p2',
        'p3',
        'p1',
      ]);
      expect(session.selection, collapsedTextSelection('p1', 2, 3));
      expect(session.canUndo, isTrue);

      expect(session.undo(), isTrue);
      expect(session.document.blocks.map((block) => block.id), [
        'p1',
        'p2',
        'p3',
      ]);
      expect(session.selection, collapsedTextSelection('p1', 0, 0));

      expect(session.redo(), isTrue);
      expect(session.document.blocks.map((block) => block.id), [
        'p2',
        'p3',
        'p1',
      ]);
      expect(session.selection, collapsedTextSelection('p1', 2, 3));
    });

    test('preserves object metadata and retargets comments and revisions', () {
      final createdAt = DateTime.utc(2026, 6, 25);
      final session = DocumentSession(
        document: RichTextDocument(
          version: 7,
          blocks: const <BlockNode>[
            FileBlockNode(
              id: 'f1',
              assetId: 'asset-1',
              name: 'doc.pdf',
              size: 2048,
              mimeType: 'application/pdf',
              downloadUrl: 'https://cdn.example.com/doc.pdf',
              uploadStatus: FileUploadStatus.failed,
              uploadError: 'network timeout',
            ),
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'after')],
            ),
          ],
          comments: <CommentThread>[
            CommentThread(
              id: 'comment-1',
              anchor: CommentAnchor(
                blockId: 'f1',
                blockIndex: 0,
                path: PositionPath.blockObject('f1'),
                startOffset: 0,
                endOffset: 1,
              ),
              messages: <CommentEntry>[
                CommentEntry(
                  id: 'message-1',
                  authorName: 'A',
                  text: 'check file',
                  createdAt: createdAt,
                ),
              ],
              createdAt: createdAt,
            ),
          ],
          revisions: <RevisionChange>[
            RevisionChange(
              id: 'rev-1',
              type: RevisionChangeType.insert,
              range: RevisionRange(
                blockId: 'f1',
                blockIndex: 0,
                path: PositionPath.blockObject('f1'),
                startOffset: 0,
                endOffset: 1,
              ),
              createdAt: createdAt,
              metadata: <String, Object?>{'source': 'test'},
            ),
          ],
        ),
      );
      final executor = CommandExecutor(session);

      executor.execute(const MoveBlockCommand(fromIndex: 0, toIndex: 1));

      expect(session.document.version, 7);
      expect(session.document.blocks.map((block) => block.id), ['p1', 'f1']);
      final file = session.document.blocks[1] as FileBlockNode;
      expect(file.assetId, 'asset-1');
      expect(file.name, 'doc.pdf');
      expect(file.size, 2048);
      expect(file.mimeType, 'application/pdf');
      expect(file.effectiveDownloadUrl, 'https://cdn.example.com/doc.pdf');
      expect(file.uploadStatus, FileUploadStatus.failed);
      expect(file.uploadError, 'network timeout');
      expect(session.document.comments.single.anchor.blockIndex, 1);
      expect(session.document.revisions.single.range.blockIndex, 1);
      expect(session.document.revisions.single.metadata, {'source': 'test'});
      expect(
          session.selection,
          DocumentSelection(
            base: DocumentPosition.object(blockId: 'f1', blockIndex: 1),
            extent: DocumentPosition.object(blockId: 'f1', blockIndex: 1)
                .copyWith(offset: 1),
          ));
    });

    test('moves heterogeneous top-level blocks and selects moved table cell',
        () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'heading',
              type: BlockType.heading,
              attributes: BlockAttributes(level: 2),
              content: <InlineNode>[TextRun(text: 'Heading')],
            ),
            TextBlockNode(
              id: 'todo',
              type: BlockType.listItem,
              attributes: BlockAttributes(listType: 'task', checked: true),
              content: <InlineNode>[TextRun(text: 'Todo')],
            ),
            TextBlockNode(
              id: 'quote',
              type: BlockType.quote,
              content: <InlineNode>[TextRun(text: 'Quote')],
            ),
            CalloutBlockNode(
              id: 'callout',
              variant: CalloutBlockNode.warningVariant,
              title: 'Watch',
              icon: '!',
              content: <InlineNode>[TextRun(text: 'Risk')],
            ),
            TableBlockNode(
              id: 'table',
              table: TableModel(
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'cell-a',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'cell-a-p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Cell A')],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            FileBlockNode(id: 'file', assetId: 'asset', name: 'brief.pdf'),
          ],
        ),
      );
      final executor = CommandExecutor(session);

      final change = executor.execute(
        const MoveBlockCommand(fromIndex: 4, toIndex: 1),
      );

      expect(change.description, 'moveBlock');
      expect(session.document.blocks.map((block) => block.id), [
        'heading',
        'table',
        'todo',
        'quote',
        'callout',
        'file',
      ]);
      final todo = session.document.blocks[2] as TextBlockNode;
      expect(todo.attributes.checked, isTrue);
      final callout = session.document.blocks[4] as CalloutBlockNode;
      expect(callout.variant, CalloutBlockNode.warningVariant);
      expect(callout.title, 'Watch');
      expect((callout.content.single as TextRun).text, 'Risk');
      final table = session.document.blocks[1] as TableBlockNode;
      expect(table.table.rows.single.single.blocks.single.id, 'cell-a-p');

      final tablePosition = DocumentPosition.tableCell(
        tableBlockId: 'table',
        blockIndex: 1,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 0,
      );
      expect(
        session.selection,
        DocumentSelection(base: tablePosition, extent: tablePosition),
      );
      expect(session.canUndo, isTrue);
    });

    test('does not record history for out-of-range or same-index moves', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(id: 'p1', type: BlockType.paragraph),
            TextBlockNode(id: 'p2', type: BlockType.paragraph),
          ],
        ),
      );
      final executor = CommandExecutor(session);

      final sameIndex = executor.execute(
        const MoveBlockCommand(fromIndex: 1, toIndex: 1),
      );
      final outOfRange = executor.execute(
        const MoveBlockCommand(fromIndex: 0, toIndex: 2),
      );

      expect(sameIndex.isNoop, isTrue);
      expect(outOfRange.isNoop, isTrue);
      expect(session.document.blocks.map((block) => block.id), ['p1', 'p2']);
      expect(session.canUndo, isFalse);
    });
  });

  group('SetCodeLanguageCommand', () {
    test('updates the language of the code block at the caret', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            CodeBlockNode(id: 'c1', code: 'print(1)', language: 'text'),
          ],
        ),
        selection: collapsedCodeSelection('c1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const SetCodeLanguageCommand('python'));

      expect(
        (session.document.blocks.single as CodeBlockNode).language,
        'python',
      );
    });

    test('records language changes in history', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            CodeBlockNode(id: 'c1', code: 'print(1)', language: 'text'),
          ],
        ),
        selection: collapsedCodeSelection('c1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const SetCodeLanguageCommand('python'));

      expect(session.canUndo, isTrue);
      expect(session.undo(), isTrue);
      expect(
          (session.document.blocks.single as CodeBlockNode).language, 'text');
    });

    test('no-op on a non-code block', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'hi')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const SetCodeLanguageCommand('python'));

      expect(session.document.blocks.single, isA<TextBlockNode>());
    });
  });

  group('IndentCodeBlockCommand', () {
    test('indents the current code line and moves the caret', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[CodeBlockNode(id: 'c1', code: 'aa\nbb')],
        ),
        selection: collapsedCodeSelection('c1', 0, 4),
      );
      final executor = CommandExecutor(session);

      executor.execute(const IndentCodeBlockCommand());

      expect(
          (session.document.blocks.single as CodeBlockNode).code, 'aa\n  bb');
      expect(session.selection?.extent.offset, 6);
      expect(session.canUndo, isTrue);
    });

    test('outdents selected code lines', () {
      final start = DocumentPosition.code(
        blockId: 'c1',
        blockIndex: 0,
        offset: 0,
      );
      final end = DocumentPosition.code(
        blockId: 'c1',
        blockIndex: 0,
        offset: 9,
      );
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[CodeBlockNode(id: 'c1', code: '  aa\n  bb\ncc')],
        ),
        selection: DocumentSelection(base: start, extent: end),
      );
      final executor = CommandExecutor(session);

      executor.execute(const IndentCodeBlockCommand(outdent: true));

      expect(
          (session.document.blocks.single as CodeBlockNode).code, 'aa\nbb\ncc');
      expect(session.selection?.base.offset, 0);
      expect(session.selection?.extent.offset, 5);
    });

    test('no-op outside code blocks', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'hi')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 1),
      );
      final executor = CommandExecutor(session);

      executor.execute(const IndentCodeBlockCommand());

      expect((session.document.blocks.single as TextBlockNode).plainText, 'hi');
      expect(session.canUndo, isFalse);
    });
  });

  group('ToggleQuoteCommand', () {
    test('paragraph becomes quote and back', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'q')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const ToggleQuoteCommand());
      expect(
        (session.document.blocks.single as TextBlockNode).type,
        BlockType.quote,
      );

      executor.execute(const ToggleQuoteCommand());
      expect(
        (session.document.blocks.single as TextBlockNode).type,
        BlockType.paragraph,
      );
    });
  });

  group('CalloutBlockNode / FileBlockNode', () {
    test('callout round-trips through JSON', () {
      const block = CalloutBlockNode(
        id: 'co1',
        variant: 'warning',
        title: 'Heads up',
        icon: '🚨',
        content: <InlineNode>[TextRun(text: 'hey')],
      );
      final decoded = BlockNode.fromJson(
        Map<String, Object?>.from(block.toJson()),
      );
      expect(decoded, isA<CalloutBlockNode>());
      final callout = decoded as CalloutBlockNode;
      expect(callout.variant, 'warning');
      expect(callout.title, 'Heads up');
      expect(callout.icon, '🚨');
      expect(callout.plainText, 'Heads up\nhey');
    });

    test('updates callout variant title and icon through command', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            CalloutBlockNode(
              id: 'co1',
              variant: 'info',
              title: 'Before',
              icon: 'ℹ️',
              content: <InlineNode>[TextRun(text: 'body')],
            ),
          ],
        ),
        selection: collapsedTextSelection('co1', 0, 0),
      );
      final executor = CommandExecutor(session);

      final change = executor.execute(
        const UpdateCalloutBlockCommand(
          variant: 'danger',
          title: ' Stop ',
          icon: ' 🔥 ',
        ),
      );

      expect(change.description, 'updateCalloutBlock');
      var callout = session.document.blocks.single as CalloutBlockNode;
      expect(callout.variant, 'danger');
      expect(callout.title, 'Stop');
      expect(callout.icon, '🔥');
      expect(callout.effectiveTitle, 'Stop');
      expect(callout.effectiveIcon, '🔥');
      expect(session.canUndo, isTrue);

      expect(session.undo(), isTrue);
      callout = session.document.blocks.single as CalloutBlockNode;
      expect(callout.variant, 'info');
      expect(callout.title, 'Before');
      expect(callout.icon, 'ℹ️');

      expect(session.redo(), isTrue);
      callout = session.document.blocks.single as CalloutBlockNode;
      expect(callout.variant, 'danger');
      expect(callout.title, 'Stop');
      expect(callout.icon, '🔥');
    });

    test('returns no-op for non-callout metadata target', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'text')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      final change = executor.execute(
        const UpdateCalloutBlockCommand(title: 'ignored'),
      );

      expect(change.isNoop, isTrue);
      expect(session.canUndo, isFalse);
    });

    test('file block round-trips through JSON', () {
      const block = FileBlockNode(
        id: 'f1',
        assetId: 'a1',
        name: 'doc.pdf',
        size: 1024,
        mimeType: 'application/pdf',
        downloadUrl: 'https://cdn.example.com/doc.pdf',
        uploadStatus: FileUploadStatus.failed,
        uploadError: 'network timeout',
      );
      final decoded = BlockNode.fromJson(
        Map<String, Object?>.from(block.toJson()),
      );
      expect(decoded, isA<FileBlockNode>());
      final file = decoded as FileBlockNode;
      expect(file.name, 'doc.pdf');
      expect(file.size, 1024);
      expect(file.mimeType, 'application/pdf');
      expect(file.effectiveDownloadUrl, 'https://cdn.example.com/doc.pdf');
      expect(file.uploadStatus, FileUploadStatus.failed);
      expect(file.uploadError, 'network timeout');
    });
  });
}
