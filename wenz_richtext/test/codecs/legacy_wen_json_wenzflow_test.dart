// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

/// Verification that `LegacyWenJsonCodec` can ingest the JSON payloads
/// `wenzflow` actually persists.
///
/// wenzflow stores rich text content as a plain business JSON *array* produced
/// by `wenz_editor`'s `yDocToJson()` (see
/// `wenz_editor/lib/editor/crdt/doc_utils.dart`). Despite the "YDoc" name, it
/// is **not** Yjs' internal CRDT serialization — there are no `_mb`/`_al`
/// fields. It is a `[ {block}, {block}, ... ]` array whose schema closely
/// matches what `LegacyWenJsonCodec.decode` expects:
///
///   - top-level bare array
///   - per-block `type` dispatch (`title`/`text`/`quote`/`code`/`image`/
///     `table`/`line`)
///   - inline fragments under `children`, each carrying its own style flags
///   - ARGB-int `color`/`background` values
///   - list marker under `itemType` (`li`/`oli`/`check`)
///
/// This file is therefore a *compatibility report* as much as a test suite:
/// every test names a real wenzflow payload shape, and the inline comments flag
/// the known divergences an integration must be aware of.
void main() {
  const codec = LegacyWenJsonCodec();

  // ---------------------------------------------------------------------------
  // 1. Realistic mixed document (the headline case: can a wenzflow note round-
  //    trip through LegacyWenJsonCodec?)
  // ---------------------------------------------------------------------------

  test(
      'decodes a realistic wenzflow note with title, styled body, todo and quote',
      () {
    // Shape mirrors `yDocToJson()` output: bare top-level array, title block
    // carries level + children (styled inline fragments), plain paragraphs
    // carry `"level": 0`, todo items use `itemType: "check"`.
    final source = jsonEncode(<Object?>[
      <String, Object?>{
        'type': 'title',
        'level': 1,
        'children': <Object?>[
          <String, Object?>{'text': '温知工作流', 'bold': true},
          <String, Object?>{
            'text': '使用指南',
            'url': 'https://example.com/guide',
          },
        ],
      },
      <String, Object?>{
        'type': 'text',
        'level': 0,
        'text': '一段正文，无样式',
      },
      <String, Object?>{
        'type': 'text',
        'level': 0,
        'children': <Object?>[
          <String, Object?>{'text': '红色', 'color': 0xFFD81B60},
          <String, Object?>{'text': '高亮', 'background': 0xFFFFFF00},
        ],
      },
      <String, Object?>{
        'type': 'text',
        'level': 0,
        'itemType': 'check',
        'checked': true,
        'text': '已完成的待办',
      },
      <String, Object?>{
        'type': 'quote',
        'text': '引用块',
      },
    ]);

    final document = codec.decode(source);

    expect(document.blocks, hasLength(5));

    // [0] title -> heading level 1, inline run preserves bold + link.
    final heading = document.blocks[0];
    expect(heading.type, BlockType.heading);
    expect(heading.attributes.level, 1);
    expect(heading.plainText, '温知工作流使用指南');
    final headingRuns = (heading as TextBlockNode).content;
    expect(headingRuns, hasLength(2));
    expect(headingRuns[0], isA<TextRun>());
    expect((headingRuns[0] as TextRun).attributes.bold, isTrue);
    expect(
      (headingRuns[1] as TextRun).attributes.url,
      'https://example.com/guide',
    );
    // Children inherit the parent block's attributes — bold set on the block
    // level should flow into the link run that did not set its own bold.
    // (parent block here has no bold, so the link run stays non-bold.)
    expect((headingRuns[1] as TextRun).attributes.bold, isNull);

    // [1] plain paragraph carried `"level": 0`; level 0 is the wenz_editor
    // sentinel for "body text" and must NOT turn this into a heading.
    final body = document.blocks[1] as TextBlockNode;
    expect(body.type, BlockType.paragraph);
    expect(body.attributes.level, 0);
    expect(body.plainText, '一段正文，无样式');

    // [2] ARGB-int colors survive verbatim.
    final styled = document.blocks[2] as TextBlockNode;
    expect(
      (styled.content[0] as TextRun).attributes.color,
      0xFFD81B60,
    );
    expect(
      (styled.content[1] as TextRun).attributes.background,
      0xFFFFFF00,
    );

    // [3] todo item -> listItem block.
    final todo = document.blocks[3] as TextBlockNode;
    expect(todo.type, BlockType.listItem);
    expect(todo.attributes.checked, isTrue);
    // ⚠️ Known divergence: itemType is stored verbatim, not normalized.
    // wenzflow emits 'check'; the new model documents 'ordered'/'task'/null.
    // See the dedicated test below.
    expect(todo.attributes.listType, 'check');

    // [4] legacy `type: "quote"` decodes as an independent quote block.
    // ⚠️ Known divergence vs. the new-format decoder: see dedicated test.
    expect(document.blocks[4].type, BlockType.quote);
  });

  // ---------------------------------------------------------------------------
  // 2. Known divergence: itemType is NOT normalized to the new model's
  //    'ordered'/'task' vocabulary.
  // ---------------------------------------------------------------------------

  test(
      'KNOWN GAP: wenzflow list itemType values pass through un-normalized',
      () {
    // wenz_editor uses `li` (unordered), `oli` (ordered), `check` (todo).
    // BlockAttributes docs say listType should be 'ordered'/'task'/null, but
    // LegacyWenJsonCodec stores the legacy string verbatim
    // (legacy_wen_json_codec.dart line 179). Rendering / list commands that
    // compare against 'ordered'/'task' will need to tolerate these aliases.
    final source = jsonEncode(<Object?>[
      <String, Object?>{
        'type': 'text',
        'itemType': 'li',
        'text': 'unordered item',
      },
      <String, Object?>{
        'type': 'text',
        'itemType': 'oli',
        'text': 'ordered item',
      },
      <String, Object?>{
        'type': 'text',
        'itemType': 'check',
        'checked': false,
        'text': 'unchecked todo',
      },
    ]);

    final document = codec.decode(source);

    final unordered = document.blocks[0] as TextBlockNode;
    expect(unordered.type, BlockType.listItem);
    expect(unordered.attributes.listType, 'li'); // NOT normalized to null

    final ordered = document.blocks[1] as TextBlockNode;
    expect(ordered.type, BlockType.listItem);
    expect(ordered.attributes.listType, 'oli'); // NOT normalized to 'ordered'

    final todo = document.blocks[2] as TextBlockNode;
    expect(todo.attributes.listType, 'check'); // NOT normalized to 'task'
    expect(todo.attributes.checked, isFalse);
  });

  // ---------------------------------------------------------------------------
  // 3. Known divergence: legacy quote representation differs from new format.
  // ---------------------------------------------------------------------------

  test(
      'KNOWN GAP: legacy `type:"quote"` and new-format quote use incompatible '
      'representations',
      () {
    // LegacyWenJsonCodec maps `type:"quote"` to an independent
    // `BlockType.quote` block. But TextBlockNode.fromJson (the *new* format
    // path) normalizes quote away into `type: paragraph` + `attrs.quoted: true`
    // (block_node.dart lines 155-161). Two documents that look identical to a
    // user can therefore have different in-memory representations depending on
    // which codec produced them. Code that detects quotes MUST check both
    // `block.type == BlockType.quote` AND `block.attributes.isQuoted`.
    final legacySource = jsonEncode(<Object?>[
      <String, Object?>{'type': 'quote', 'text': 'legacy quote'},
    ]);

    final legacyDoc = codec.decode(legacySource);
    final legacyQuote = legacyDoc.blocks.single as TextBlockNode;
    expect(legacyQuote.type, BlockType.quote);
    // The legacy codec does NOT set attrs.quoted, so isQuoted is false even
    // though the block renders as a quote.
    expect(legacyQuote.attributes.quoted, isNull);
    expect(legacyQuote.attributes.isQuoted, isFalse);
    expect(legacyQuote.plainText, 'legacy quote');
  });

  // ---------------------------------------------------------------------------
  // 4. Known divergence: legacy codec never reads `quoted` attrs.
  // ---------------------------------------------------------------------------

  test('KNOWN GAP: `quoted:true` on a legacy block is ignored', () {
    // A forward-migrated document might attach `quoted: true` to a paragraph
    // in the new style. The legacy decoder only recognizes `type: "quote"` and
    // ignores the `quoted` attribute entirely, so such a block decodes as a
    // plain paragraph.
    final source = jsonEncode(<Object?>[
      <String, Object?>{
        'type': 'text',
        'quoted': true,
        'text': 'should-be-quote-but-is-not',
      },
    ]);

    final document = codec.decode(source);
    final block = document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.paragraph);
    expect(block.attributes.quoted, isNull);
  });

  // ---------------------------------------------------------------------------
  // 5. Code, image, divider, formula embed — the media/embed shapes wenzflow
  //    can produce.
  // ---------------------------------------------------------------------------

  test('decodes code, image, formula embed and divider blocks', () {
    // Image block uses `id` as assetId and `file` for the local/remote path;
    // both are exactly what wenzflow's WenzWebAssetsFileManager produces.
    // Inline formula embeds arrive as a child with `itemType: "formula"`.
    final source = jsonEncode(<Object?>[
      <String, Object?>{
        'type': 'code',
        'language': 'python',
        'code': "print('hello')",
      },
      <String, Object?>{
        'type': 'image',
        'id': 'asset-abc',
        'file': 'asset-abc',
        'width': 1920,
        'height': 1080,
        'showWidth': 480.0,
        'showHeight': 270.0,
      },
      <String, Object?>{
        'type': 'text',
        'children': <Object?>[
          <String, Object?>{'text': '面积 = '},
          <String, Object?>{'itemType': 'formula', 'text': r'\pi r^2'},
        ],
      },
      <String, Object?>{'type': 'line'},
    ]);

    final document = codec.decode(source);

    final code = document.blocks[0] as CodeBlockNode;
    expect(code.language, 'python');
    expect(code.code, "print('hello')");

    final image = document.blocks[1] as ImageBlockNode;
    expect(image.assetId, 'asset-abc');
    expect(image.file, 'asset-abc');
    expect(image.width, 1920);
    expect(image.height, 1080);
    expect(image.showWidth, 480);
    expect(image.showHeight, 270);

    final text = document.blocks[2] as TextBlockNode;
    expect(text.content.last, isA<InlineEmbed>());
    final formula = text.content.last as InlineEmbed;
    expect(formula.embedType, 'formula');
    expect(formula.data['text'], r'\pi r^2');

    expect(document.blocks[3], isA<DividerBlockNode>());
  });

  // ---------------------------------------------------------------------------
  // 6. Table — the most structurally divergent block between old and new.
  // ---------------------------------------------------------------------------

  test('decodes a wenzflow table with column alignments and mixed cells', () {
    // wenzflow persists tables as `rows: List<List<WenElement>>`, each cell
    // being a full block element (text/image/...). Cell-level alignment lives
    // directly on the cell element. LegacyWenJsonCodec maps this to TableModel
    // where each TableCellNode wraps the decoded block.
    final source = jsonEncode(<Object?>[
      <String, Object?>{
        'type': 'table',
        'level': 0,
        'alignments': <String, String>{'0': 'left', '1': 'center'},
        'rows': <List<Object?>>[
          <Object?>[
            <String, Object?>{
              'type': 'text',
              'level': 0,
              'children': <Object?>[
                <String, Object?>{'text': '名称', 'bold': true},
              ],
            },
            <String, Object?>{
              'type': 'text',
              'level': 0,
              'children': <Object?>[
                <String, Object?>{'text': '值'},
              ],
            },
          ],
          <Object?>[
            <String, Object?>{
              'type': 'text',
              'level': 0,
              'text': '图片',
            },
            <String, Object?>{
              'type': 'image',
              'id': 'img-1',
              'file': 'img-1',
              'width': 100,
              'height': 80,
              'alignment': 'center',
            },
          ],
        ],
      },
    ]);

    final document = codec.decode(source);
    final table = document.blocks.single as TableBlockNode;

    expect(table.table.rowCount, 2);
    expect(table.table.columnCount, 2);
    expect(table.table.columnAlignments[0], 'left');
    expect(table.table.columnAlignments[1], 'center');

    // Header cell with bold text.
    expect(table.table.cellAt(0, 0)?.plainText, '名称');
    final headerRun =
        (table.table.cellAt(0, 0)!.blocks.single as TextBlockNode)
            .content
            .first as TextRun;
    expect(headerRun.attributes.bold, isTrue);

    // Mixed cell: image carries a cell-level alignment that coexists with the
    // column alignment.
    final imageCell = table.table.cellAt(1, 1);
    expect(imageCell?.blocks.single, isA<ImageBlockNode>());
    expect(imageCell?.alignment, 'center');
    expect((imageCell!.blocks.single as ImageBlockNode).assetId, 'img-1');
  });

  // ---------------------------------------------------------------------------
  // 7. Robustness: shapes wenzflow may emit at the edges.
  // ---------------------------------------------------------------------------

  test('decodes an empty wenzflow note (`[]`)', () {
    // wenzflow's controller falls back to `"[]"` for empty content
    // (controller.dart line 187-189). Must decode cleanly to an empty doc.
    final document = codec.decode('[]');
    expect(document.blocks, isEmpty);
  });

  test('decodes a wrapped `{ "blocks": [...] }` envelope', () {
    // LegacyWenJsonCodec also accepts the envelope form even though wenzflow
    // persists the bare array. Verifies both roots are tolerated.
    final source = jsonEncode(<String, Object?>{
      'blocks': <Object?>[
        <String, Object?>{
          'type': 'text',
          'text': 'enveloped',
        },
      ],
    });

    final document = codec.decode(source);
    expect(document.plainText, 'enveloped');
  });

  test('unknown block type degrades to a paragraph', () {
    // Defensive: if a future wenzflow version emits an unrecognised `type`
    // (e.g. an experimental block), the decoder must not throw — it falls back
    // to a paragraph carrying whatever text it can find.
    final source = jsonEncode(<Object?>[
      <String, Object?>{
        'type': 'futureBlock',
        'text': 'graceful fallback',
      },
    ]);

    final document = codec.decode(source);
    expect(document.blocks.single.type, BlockType.paragraph);
    expect(document.plainText, 'graceful fallback');
  });

  test('garbage block entries are skipped, valid siblings survive', () {
    // A corrupted row in SQLite could yield a non-object entry in the array.
    // The decoder skips it rather than failing the whole document load —
    // critical for a notes app that cannot afford to lose an entire note over
    // one malformed block.
    final source = jsonEncode(<Object?>[
      <String, Object?>{'type': 'text', 'text': 'before'},
      'corrupted-string-entry',
      null,
      <String, Object?>{'type': 'text', 'text': 'after'},
    ]);

    final document = codec.decode(source);
    // Two of the four entries are non-objects and are skipped. Document-level
    // plainText joins blocks with newlines (see RichTextDocument.plainText).
    expect(document.blocks, hasLength(2));
    expect(document.plainText, 'before\nafter');
  });

  test('synthetic block ids are stable and indexed', () {
    // Legacy payloads carry no ids, so the codec synthesises `legacy-<index>`.
    // wenzflow-side code that needs to address migrated blocks (e.g. selection
    // restoration, autosave) must not assume uuids; it should treat these ids
    // as positional.
    final source = jsonEncode(<Object?>[
      <String, Object?>{'type': 'text', 'text': 'a'},
      <String, Object?>{'type': 'text', 'text': 'b'},
    ]);

    final document = codec.decode(source);
    expect(document.blocks[0].id, 'legacy-0');
    expect(document.blocks[1].id, 'legacy-1');
    // Table cells are addressed as `<blockId>-r<row>-c<col>`.
    final tableSource = jsonEncode(<Object?>[
      <String, Object?>{
        'type': 'table',
        'rows': <List<Object?>>[
          <Object?>[
            <String, Object?>{'type': 'text', 'text': 'c'},
          ],
        ],
      },
    ]);
    final tableDoc = codec.decode(tableSource);
    final cell = (tableDoc.blocks.single as TableBlockNode).table.cellAt(0, 0);
    expect(cell?.id, 'legacy-0-r0-c0');
  });

  // ---------------------------------------------------------------------------
  // 8. Error paths — must surface structured DocumentDecodeException so
  //    `tryLoadJson` in the controller never throws into the UI.
  // ---------------------------------------------------------------------------

  test('malformed JSON raises DocumentDecodeException', () {
    expect(
      () => codec.decode('{broken'),
      throwsA(
        predicate<DocumentDecodeException>(
          (e) => e.reason == 'Source is not valid JSON.',
        ),
      ),
    );
  });

  test('non-list / non-envelope root raises DocumentDecodeException', () {
    // A bare string or number at the top level is not a valid wenzflow note.
    expect(
      () => codec.decode('"just a string"'),
      throwsA(
        predicate<DocumentDecodeException>(
          (e) => e.reason == 'Legacy Wen JSON must be a block list.',
        ),
      ),
    );
  });
}
