import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/src/core/position/document_position.dart';

void main() {
  group('PositionPath factories', () {
    test('blockText exposes typed accessors', () {
      final path = PositionPath.blockText('b1');
      expect(path.blockId, 'b1');
      expect(path.isBlockText, isTrue);
      expect(path.isBlockCode, isFalse);
      expect(path.isTableCellText, isFalse);
      expect(path.tableRowIndex, isNull);
      expect(path.tableColumnIndex, isNull);
    });

    test('blockCode exposes typed accessors', () {
      final path = PositionPath.blockCode('b1');
      expect(path.blockId, 'b1');
      expect(path.isBlockCode, isTrue);
      expect(path.isBlockText, isFalse);
      expect(path.isBlockObject, isFalse);
      expect(path.isTableCellText, isFalse);
    });

    test('blockObject exposes typed accessors', () {
      final path = PositionPath.blockObject('image1');
      expect(path.blockId, 'image1');
      expect(path.isBlockObject, isTrue);
      expect(path.isBlockText, isFalse);
      expect(path.isBlockCode, isFalse);
      expect(path.isTableCellText, isFalse);
      expect(path.tableRowIndex, isNull);
      expect(path.tableColumnIndex, isNull);
    });

    test('tableCellText exposes row and column indices', () {
      final path = PositionPath.tableCellText('table', 2, 3);
      expect(path.blockId, 'table');
      expect(path.isTableCellText, isTrue);
      expect(path.tableRowIndex, 2);
      expect(path.tableColumnIndex, 3);
      expect(path.isBlockText, isFalse);
      expect(path.isBlockObject, isFalse);
    });
  });

  group('PositionPath structural comparison', () {
    test('orders path kinds by rank', () {
      const text = PositionPath(['block', 'b', 'text']);
      const code = PositionPath(['block', 'b', 'code']);
      const object = PositionPath(['block', 'b', 'object']);
      const cell = PositionPath([
        'block',
        'b',
        'row',
        0,
        'cell',
        0,
      ]);
      expect(text.compare(code), lessThan(0));
      expect(code.compare(object), lessThan(0));
      expect(object.compare(cell), lessThan(0));
      expect(text.compare(cell), lessThan(0));
    });

    test('orders table cells by numeric row and column, not lexicographically',
        () {
      // Regression: lexicographic string compare would order row/10 before
      // row/2 because '1' < '2'. Numeric compare must keep 2 < 10.
      final row2 = PositionPath.tableCellText('t', 2, 0);
      final row10 = PositionPath.tableCellText('t', 10, 0);
      expect(row2.compare(row10), lessThan(0));
      expect(row10.compare(row2), greaterThan(0));

      final col2 = PositionPath.tableCellText('t', 0, 2);
      final col10 = PositionPath.tableCellText('t', 0, 10);
      expect(col2.compare(col10), lessThan(0));
    });

    test('blockId string segment still compares when ids differ', () {
      final a = PositionPath.blockText('a');
      final b = PositionPath.blockText('b');
      expect(a.compare(b), lessThan(0));
    });

    test('compare is consistent with equality', () {
      final a = PositionPath.tableCellText('t', 1, 2);
      final b = PositionPath.tableCellText('t', 1, 2);
      expect(a.compare(b), 0);
      expect(a == b, isTrue);
    });
  });

  group('DocumentPosition convenience factories', () {
    test('text factory builds blockText path', () {
      final pos = DocumentPosition.text(
        blockId: 'b1',
        blockIndex: 0,
        offset: 3,
      );
      expect(pos.path.isBlockText, isTrue);
      expect(pos.blockId, 'b1');
      expect(pos.offset, 3);
    });

    test('code factory builds blockCode path', () {
      final pos = DocumentPosition.code(
        blockId: 'c1',
        blockIndex: 1,
        offset: 0,
      );
      expect(pos.path.isBlockCode, isTrue);
    });

    test('tableCell factory builds tableCellText path', () {
      final pos = DocumentPosition.tableCell(
        tableBlockId: 't1',
        blockIndex: 2,
        tableRowIndex: 1,
        tableColumnIndex: 4,
        offset: 5,
      );
      expect(pos.path.isTableCellText, isTrue);
      expect(pos.path.tableRowIndex, 1);
      expect(pos.path.tableColumnIndex, 4);
      expect(pos.offset, 5);
    });
  });

  group('DocumentPosition.compareTo', () {
    test('orders by block index first', () {
      final a = DocumentPosition.text(blockId: 'a', blockIndex: 0, offset: 0);
      final b = DocumentPosition.text(blockId: 'b', blockIndex: 1, offset: 0);
      expect(a.compareTo(b), lessThan(0));
    });

    test('falls back to path comparison then offset', () {
      final low = DocumentPosition.text(blockId: 'b', blockIndex: 0, offset: 5);
      final high =
          DocumentPosition.text(blockId: 'b', blockIndex: 0, offset: 9);
      expect(low.compareTo(high), lessThan(0));
    });

    test('sorts table cell positions numerically across double digits', () {
      final pos2 = DocumentPosition.tableCell(
        tableBlockId: 't',
        blockIndex: 0,
        tableRowIndex: 2,
        tableColumnIndex: 0,
        offset: 0,
      );
      final pos10 = DocumentPosition.tableCell(
        tableBlockId: 't',
        blockIndex: 0,
        tableRowIndex: 10,
        tableColumnIndex: 0,
        offset: 0,
      );
      final positions = <DocumentPosition>[pos10, pos2]..sort();
      expect(positions, <DocumentPosition>[pos2, pos10]);
    });
  });

  group('DocumentSelection.tableCellRange', () {
    test('normalizes table cell endpoints', () {
      final selection = DocumentSelection(
        base: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 2,
          tableColumnIndex: 3,
          offset: 1,
        ),
        extent: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 1,
          offset: 4,
        ),
      );

      final range = selection.tableCellRange;
      expect(range, isNotNull);
      expect(range!.tableBlockId, 'table1');
      expect(range.startRow, 0);
      expect(range.endRow, 2);
      expect(range.startColumn, 1);
      expect(range.endColumn, 3);
      expect(range.containsCell(1, 2), isTrue);
      expect(range.containsCell(1, 0), isFalse);
      expect(range.isSingleCell, isFalse);
    });

    test('returns null for non-table or different table selections', () {
      final textSelection = DocumentSelection(
        base: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 0),
        extent: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 1),
      );
      expect(textSelection.tableCellRange, isNull);

      final crossTable = DocumentSelection(
        base: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 0,
        ),
        extent: DocumentPosition.tableCell(
          tableBlockId: 'table2',
          blockIndex: 1,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 0,
        ),
      );
      expect(crossTable.tableCellRange, isNull);
    });
  });
}
