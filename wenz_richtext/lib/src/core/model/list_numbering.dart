import 'block_node.dart';

/// Computes ordered-list markers in one forward pass.
///
/// Deeper nested items do not interrupt a shallower sequence, while a block at
/// the same or lower indentation closes the affected sequence exactly like the
/// editor's historical backward scan.
List<int?> orderedListNumbersFor(List<BlockNode> blocks) {
  final result = List<int?>.filled(blocks.length, null, growable: false);
  final counters = <int, int>{};
  final active = <int, bool>{};

  for (var index = 0; index < blocks.length; index++) {
    final block = blocks[index];
    final indent = block.attributes.indent ?? 0;
    final deeperLevels = active.keys.where((level) => level > indent).toList();
    for (final level in deeperLevels) {
      active.remove(level);
      counters.remove(level);
    }

    final isOrdered = block is TextBlockNode &&
        block.type == BlockType.listItem &&
        block.attributes.listType == 'ordered';
    if (!isOrdered) {
      active[indent] = false;
      counters.remove(indent);
      continue;
    }

    final next = active[indent] == true ? (counters[indent] ?? 0) + 1 : 1;
    counters[indent] = next;
    active[indent] = true;
    result[index] = next;
  }

  return result;
}
