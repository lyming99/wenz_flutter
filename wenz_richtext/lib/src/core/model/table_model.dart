import 'block_node.dart';

class TableModel {
  const TableModel({
    this.rows = const <List<TableCellNode>>[],
    this.columnAlignments = const <int, String>{},
    this.columnWidths = const <int, double>{},
  });

  final List<List<TableCellNode>> rows;
  final Map<int, String> columnAlignments;
  final Map<int, double> columnWidths;

  int get rowCount => rows.length;

  int get columnCount {
    var result = 0;
    for (final row in rows) {
      if (row.length > result) {
        result = row.length;
      }
    }
    return result;
  }

  TableCellNode? cellAt(int row, int column) {
    if (row < 0 || row >= rows.length) {
      return null;
    }
    final cells = rows[row];
    if (column < 0 || column >= cells.length) {
      return null;
    }
    return cells[column];
  }

  String get plainText {
    return rows
        .map((row) => row.map((cell) => cell.plainText).join('\t'))
        .join('\n');
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'rows':
          rows.map((row) => row.map((cell) => cell.toJson()).toList()).toList(),
      if (columnAlignments.isNotEmpty)
        'columnAlignments': columnAlignments.map(
          (key, value) => MapEntry('$key', value),
        ),
      if (columnWidths.isNotEmpty)
        'columnWidths': columnWidths.map(
          (key, value) => MapEntry('$key', value),
        ),
    };
  }

  factory TableModel.fromJson(Map<String, Object?> json) {
    final rawRows = json['rows'];
    final rawAlignments = json['columnAlignments'];
    final rawWidths = json['columnWidths'];
    return TableModel(
      rows: rawRows is List
          ? rawRows
              .whereType<List>()
              .map(
                (row) => row
                    .whereType<Map>()
                    .map(
                      (cell) => TableCellNode.fromJson(
                        Map<String, Object?>.from(cell),
                      ),
                    )
                    .toList(),
              )
              .toList()
          : const <List<TableCellNode>>[],
      columnAlignments: rawAlignments is Map
          ? rawAlignments.map(
              (key, value) => MapEntry(int.parse('$key'), value as String),
            )
          : const <int, String>{},
      columnWidths: rawWidths is Map
          ? rawWidths.map(
              (key, value) => MapEntry(int.parse('$key'), _asDouble(value)),
            )
          : const <int, double>{},
    );
  }
}

class TableCellNode {
  const TableCellNode({
    required this.id,
    this.blocks = const <BlockNode>[],
    this.rowSpan = 1,
    this.columnSpan = 1,
    this.isHeader = false,
    this.backgroundColor,
    this.covered = false,
    this.alignment,
  });

  final String id;
  final List<BlockNode> blocks;
  final int rowSpan;
  final int columnSpan;
  final bool isHeader;
  final int? backgroundColor;
  final bool covered;
  // Cell-level text alignment ('left'/'center'/'right'/'justify'). When `null`
  // the cell inherits the column alignment (`TableModel.columnAlignments`).
  final String? alignment;

  String get plainText => blocks.map((block) => block.plainText).join('\n');

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'blocks': blocks.map((block) => block.toJson()).toList(),
      if (rowSpan != 1) 'rowSpan': rowSpan,
      if (columnSpan != 1) 'columnSpan': columnSpan,
      if (isHeader) 'isHeader': true,
      if (backgroundColor != null) 'backgroundColor': backgroundColor,
      if (covered) 'covered': true,
      if (alignment != null) 'alignment': alignment,
    };
  }

  factory TableCellNode.fromJson(Map<String, Object?> json) {
    final rawBlocks = json['blocks'];
    final rawAlignment = json['alignment'];
    return TableCellNode(
      id: json['id'] as String? ?? '',
      blocks: rawBlocks is List
          ? rawBlocks
              .whereType<Map>()
              .map(
                (block) => BlockNode.fromJson(Map<String, Object?>.from(block)),
              )
              .toList()
          : const <BlockNode>[],
      rowSpan: _asInt(json['rowSpan'], fallback: 1),
      columnSpan: _asInt(json['columnSpan'], fallback: 1),
      isHeader: json['isHeader'] as bool? ?? false,
      backgroundColor: _asNullableInt(json['backgroundColor']),
      covered: json['covered'] as bool? ?? false,
      alignment: rawAlignment is String && rawAlignment.isNotEmpty
          ? rawAlignment
          : null,
    );
  }
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return fallback;
}

int? _asNullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}
