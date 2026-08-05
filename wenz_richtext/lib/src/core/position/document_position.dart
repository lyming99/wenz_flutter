/// Describes *what* a [DocumentPosition] points at inside a block.
///
/// There are four well-formed shapes, all constructed via the named
/// factories. The raw [segments] list is the canonical storage; the typed
/// accessors ([blockId], [isBlockText], ...) are convenience views over it.
///
/// Contract:
/// - [blockText] / [blockCode] identify inline content of a single
///   [TextBlockNode] / [CodeBlockNode].
/// - [blockObject] identifies an atomic block-level object, such as an image,
///   video, file attachment, or divider.
/// - [tableCellText] identifies a single cell's first text block. Full
///   cell editing (multi-block cells, range selection inside cells) is out
///   of scope until stage 4.
///
/// Ordering is defined by [PositionPath.compare], which compares *structurally*
/// (type rank, then numeric/string segments) rather than lexicographically —
/// so `row/10` sorts after `row/2`.
class PositionPath {
  const PositionPath(this.segments);

  final List<Object> segments;

  factory PositionPath.blockText(String blockId) {
    return PositionPath(<Object>['block', blockId, 'text']);
  }

  factory PositionPath.blockCode(String blockId) {
    return PositionPath(<Object>['block', blockId, 'code']);
  }

  factory PositionPath.blockObject(String blockId) {
    return PositionPath(<Object>['block', blockId, 'object']);
  }

  factory PositionPath.tableCellText(
    String tableBlockId,
    int rowIndex,
    int columnIndex,
  ) {
    return PositionPath(<Object>[
      'block',
      tableBlockId,
      'row',
      rowIndex,
      'cell',
      columnIndex,
    ]);
  }

  /// The owning block id. For [tableCellText] this is the *table* block id.
  String get blockId => segments[1] as String;

  bool get isBlockText => _kind == _PathKind.blockText;

  bool get isBlockCode => _kind == _PathKind.blockCode;

  bool get isBlockObject => _kind == _PathKind.blockObject;

  bool get isTableCellText => _kind == _PathKind.tableCellText;

  /// Row index when [isTableCellText], otherwise `null`.
  int? get tableRowIndex => isTableCellText ? segments[3] as int : null;

  /// Column index when [isTableCellText], otherwise `null`.
  int? get tableColumnIndex => isTableCellText ? segments[5] as int : null;

  _PathKind get _kind {
    if (segments.length == 3 && segments[2] == 'text') {
      return _PathKind.blockText;
    }
    if (segments.length == 3 && segments[2] == 'code') {
      return _PathKind.blockCode;
    }
    if (segments.length == 3 && segments[2] == 'object') {
      return _PathKind.blockObject;
    }
    if (segments.length == 6 && segments[2] == 'row' && segments[4] == 'cell') {
      return _PathKind.tableCellText;
    }
    return _PathKind.unknown;
  }

  /// Structural comparison: type rank first, then segments numerically when
  /// both are ints, otherwise as strings. Returns negative/zero/positive.
  int compare(PositionPath other) {
    final rank = _kind.rank.compareTo(other._kind.rank);
    if (rank != 0) {
      return rank;
    }
    final maxLen = segments.length < other.segments.length
        ? segments.length
        : other.segments.length;
    for (var i = 0; i < maxLen; i++) {
      final cmp = _compareSegment(segments[i], other.segments[i]);
      if (cmp != 0) {
        return cmp;
      }
    }
    return segments.length.compareTo(other.segments.length);
  }

  static int _compareSegment(Object a, Object b) {
    if (a is int && b is int) {
      return a.compareTo(b);
    }
    if (a is num && b is num) {
      return a.compareTo(b);
    }
    return a.toString().compareTo(b.toString());
  }

  @override
  String toString() => segments.join('/');

  @override
  bool operator ==(Object other) {
    return other is PositionPath && _listEquals(other.segments, segments);
  }

  @override
  int get hashCode => Object.hashAll(segments);
}

enum _PathKind { unknown, blockText, blockCode, blockObject, tableCellText }

extension on _PathKind {
  int get rank => switch (this) {
        _PathKind.blockText => 0,
        _PathKind.blockCode => 1,
        _PathKind.blockObject => 2,
        _PathKind.tableCellText => 3,
        _PathKind.unknown => 4,
      };
}

class DocumentPosition implements Comparable<DocumentPosition> {
  const DocumentPosition({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.offset,
  });

  /// Collapsed position at [offset] inside the inline text of a
  /// [TextBlockNode] with id [blockId].
  factory DocumentPosition.text({
    required String blockId,
    required int blockIndex,
    required int offset,
  }) {
    return DocumentPosition(
      blockId: blockId,
      blockIndex: blockIndex,
      path: PositionPath.blockText(blockId),
      offset: offset,
    );
  }

  /// Collapsed position at [offset] inside the code of a [CodeBlockNode].
  factory DocumentPosition.code({
    required String blockId,
    required int blockIndex,
    required int offset,
  }) {
    return DocumentPosition(
      blockId: blockId,
      blockIndex: blockIndex,
      path: PositionPath.blockCode(blockId),
      offset: offset,
    );
  }

  /// Collapsed position at [offset] inside the first text block of a
  /// table cell at ([tableRowIndex], [tableColumnIndex]).
  factory DocumentPosition.tableCell({
    required String tableBlockId,
    required int blockIndex,
    required int tableRowIndex,
    required int tableColumnIndex,
    required int offset,
  }) {
    return DocumentPosition(
      blockId: tableBlockId,
      blockIndex: blockIndex,
      path: PositionPath.tableCellText(
        tableBlockId,
        tableRowIndex,
        tableColumnIndex,
      ),
      offset: offset,
    );
  }

  /// Position at [offset] on an atomic block-level object such as an image,
  /// video, file attachment, embed, or divider.
  factory DocumentPosition.object({
    required String blockId,
    required int blockIndex,
    int offset = 0,
  }) {
    return DocumentPosition(
      blockId: blockId,
      blockIndex: blockIndex,
      path: PositionPath.blockObject(blockId),
      offset: offset,
    );
  }

  final String blockId;
  final int blockIndex;
  final PositionPath path;
  final int offset;

  DocumentPosition copyWith({
    String? blockId,
    int? blockIndex,
    PositionPath? path,
    int? offset,
  }) {
    return DocumentPosition(
      blockId: blockId ?? this.blockId,
      blockIndex: blockIndex ?? this.blockIndex,
      path: path ?? this.path,
      offset: offset ?? this.offset,
    );
  }

  @override
  int compareTo(DocumentPosition other) {
    final blockCompare = blockIndex.compareTo(other.blockIndex);
    if (blockCompare != 0) {
      return blockCompare;
    }
    final pathCompare = path.compare(other.path);
    if (pathCompare != 0) {
      return pathCompare;
    }
    return offset.compareTo(other.offset);
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentPosition &&
        other.blockId == blockId &&
        other.blockIndex == blockIndex &&
        other.path == path &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(blockId, blockIndex, path, offset);
}

class DocumentSelection {
  const DocumentSelection({required this.base, required this.extent});

  final DocumentPosition base;
  final DocumentPosition extent;

  bool get isCollapsed => base.compareTo(extent) == 0;

  DocumentPosition get start => base.compareTo(extent) <= 0 ? base : extent;

  DocumentPosition get end => base.compareTo(extent) <= 0 ? extent : base;

  /// Returns the bounding-box rectangle of table cells spanned by this
  /// selection, or `null` if the selection is not entirely within a single
  /// table.
  ///
  /// The returned [TableCellRange] always satisfies
  /// `startRow <= endRow` and `startColumn <= endColumn`, regardless of the
  /// relative order of [base] and [extent]. The rectangle is computed purely
  /// from row/column indices; it does **not** account for merged/covered
  /// cells — a cell that is covered by a span may still fall inside the
  /// rectangle.
  TableCellRange? get tableCellRange {
    final baseRow = base.path.tableRowIndex;
    final baseColumn = base.path.tableColumnIndex;
    final extentRow = extent.path.tableRowIndex;
    final extentColumn = extent.path.tableColumnIndex;
    if (!base.path.isTableCellText ||
        !extent.path.isTableCellText ||
        base.blockId != extent.blockId ||
        base.blockIndex != extent.blockIndex ||
        baseRow == null ||
        baseColumn == null ||
        extentRow == null ||
        extentColumn == null) {
      return null;
    }
    return TableCellRange(
      tableBlockId: base.blockId,
      blockIndex: base.blockIndex,
      startRow: baseRow < extentRow ? baseRow : extentRow,
      endRow: baseRow > extentRow ? baseRow : extentRow,
      startColumn: baseColumn < extentColumn ? baseColumn : extentColumn,
      endColumn: baseColumn > extentColumn ? baseColumn : extentColumn,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentSelection &&
        other.base == base &&
        other.extent == extent;
  }

  @override
  int get hashCode => Object.hash(base, extent);
}

/// A rectangular region of table cells identified by row and column indices.
///
/// **Covered cell semantics**: This range is defined purely by row/column
/// index boundaries. It does not inspect the table's actual cell-spans or
/// merged-cell structure. Cells that are "covered" (hidden) by a spanning
/// cell may still satisfy [containsCell] if their indices fall within the
/// rectangle. Callers that need span-aware ranges should further filter
/// against the table's cell-span metadata.
///
/// **Invariants**: `startRow <= endRow` and `startColumn <= endColumn`.
/// All row/column indices must be non-negative.
class TableCellRange {
  const TableCellRange({
    required this.tableBlockId,
    required this.blockIndex,
    required this.startRow,
    required this.endRow,
    required this.startColumn,
    required this.endColumn,
  })  : assert(startRow <= endRow,
            'startRow ($startRow) must be <= endRow ($endRow)'),
        assert(startColumn <= endColumn,
            'startColumn ($startColumn) must be <= endColumn ($endColumn)'),
        assert(startRow >= 0, 'startRow must be non-negative, got $startRow'),
        assert(startColumn >= 0,
            'startColumn must be non-negative, got $startColumn');

  final String tableBlockId;
  final int blockIndex;
  final int startRow;
  final int endRow;
  final int startColumn;
  final int endColumn;

  bool get isSingleCell {
    return startRow == endRow && startColumn == endColumn;
  }

  bool containsCell(int row, int column) {
    return row >= startRow &&
        row <= endRow &&
        column >= startColumn &&
        column <= endColumn;
  }

  @override
  bool operator ==(Object other) {
    return other is TableCellRange &&
        other.tableBlockId == tableBlockId &&
        other.blockIndex == blockIndex &&
        other.startRow == startRow &&
        other.endRow == endRow &&
        other.startColumn == startColumn &&
        other.endColumn == endColumn;
  }

  @override
  int get hashCode => Object.hash(
        tableBlockId,
        blockIndex,
        startRow,
        endRow,
        startColumn,
        endColumn,
      );
}

bool _listEquals(List<Object> a, List<Object> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
