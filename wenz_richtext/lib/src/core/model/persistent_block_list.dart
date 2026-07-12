import 'dart:collection';

import 'block_node.dart';

/// Immutable, structurally shared list used by live editor sessions.
///
/// Blocks are stored in a balanced tree of small leaves. A point replacement
/// copies one leaf and the O(log N) path to it, while iteration remains O(N).
/// Public document constructors still accept ordinary lists for compatibility;
/// [PersistentBlockList.from] is applied once at a session boundary.
class PersistentBlockList extends ListBase<BlockNode> {
  PersistentBlockList._(
    this._root, {
    WeakReference<PersistentBlockList>? parent,
    Set<int> changedIndexes = const <int>{},
    Set<int> schemaDirtyIndexes = const <int>{},
    Map<String, int>? indexesById,
  })  : _parent = parent,
        changedIndexes = Set<int>.unmodifiable(changedIndexes),
        _schemaDirtyIndexes = Set<int>.unmodifiable(schemaDirtyIndexes),
        _indexesById = indexesById ?? const <String, int>{};

  factory PersistentBlockList.from(Iterable<BlockNode> source) {
    if (source is PersistentBlockList) {
      return source.asCleanSnapshot();
    }
    final blocks = source.toList(growable: false);
    if (blocks.isEmpty) {
      return PersistentBlockList._(null, indexesById: const <String, int>{});
    }
    final leaves = <_BlockTree>[];
    for (var start = 0; start < blocks.length; start += _leafCapacity) {
      final end = (start + _leafCapacity).clamp(0, blocks.length).toInt();
      leaves.add(
        _BlockLeaf(List<BlockNode>.unmodifiable(blocks.sublist(start, end))),
      );
    }
    return PersistentBlockList._(
      _buildBalanced(leaves, 0, leaves.length),
      indexesById: Map<String, int>.unmodifiable(<String, int>{
        for (var index = 0; index < blocks.length; index++)
          blocks[index].id: index,
      }),
    );
  }

  static const int _leafCapacity = 64;

  final _BlockTree? _root;
  final WeakReference<PersistentBlockList>? _parent;

  /// Indexes replaced when this snapshot was created from its direct parent.
  final Set<int> changedIndexes;
  final Set<int> _schemaDirtyIndexes;
  final Map<String, int> _indexesById;

  int? indexOfBlockId(String blockId) => _indexesById[blockId];

  /// Point updates since the nearest schema-normalized snapshot.
  Set<int> get pendingNormalizationIndexes {
    final pending = <int>{};
    PersistentBlockList cursor = this;
    while (cursor._schemaDirtyIndexes.isNotEmpty) {
      pending.addAll(cursor._schemaDirtyIndexes);
      final parent = cursor._parent?.target;
      if (parent == null) {
        break;
      }
      cursor = parent;
    }
    return Set<int>.unmodifiable(pending);
  }

  @override
  int get length => _root?.size ?? 0;

  @override
  set length(int value) {
    throw UnsupportedError('PersistentBlockList is immutable.');
  }

  @override
  BlockNode operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    return _blockAt(_root!, index);
  }

  @override
  void operator []=(int index, BlockNode value) {
    throw UnsupportedError('PersistentBlockList is immutable.');
  }

  @override
  Iterator<BlockNode> get iterator => _iterateTree(_root).iterator;

  @override
  List<BlockNode> toList({bool growable = true}) {
    return List<BlockNode>.of(this, growable: growable);
  }

  PersistentBlockList replaceAt(int index, BlockNode block) {
    RangeError.checkValidIndex(index, this, 'index', length);
    if (identical(this[index], block)) {
      return this;
    }
    final previous = this[index];
    var indexesById = _indexesById;
    if (previous.id != block.id) {
      final nextIndexes = Map<String, int>.of(_indexesById)
        ..remove(previous.id)
        ..[block.id] = index;
      indexesById = Map<String, int>.unmodifiable(nextIndexes);
    }
    return PersistentBlockList._(
      _replaceAt(_root!, index, block),
      parent: WeakReference<PersistentBlockList>(this),
      changedIndexes: <int>{index},
      schemaDirtyIndexes: <int>{index},
      indexesById: indexesById,
    );
  }

  PersistentBlockList replaceMany(Map<int, BlockNode> replacements) {
    if (replacements.isEmpty) {
      return this;
    }
    var root = _root!;
    final changed = <int>{};
    var indexesById = _indexesById;
    Map<String, int>? mutableIndexes;
    final indexes = replacements.keys.toList()..sort();
    for (final index in indexes) {
      RangeError.checkValidIndex(index, this, 'index', length);
      final block = replacements[index]!;
      if (identical(this[index], block)) {
        continue;
      }
      root = _replaceAt(root, index, block);
      changed.add(index);
      final previous = this[index];
      if (previous.id != block.id) {
        mutableIndexes ??= Map<String, int>.of(indexesById);
        mutableIndexes
          ..remove(previous.id)
          ..[block.id] = index;
      }
    }
    if (changed.isEmpty) {
      return this;
    }
    return PersistentBlockList._(
      root,
      parent: WeakReference<PersistentBlockList>(this),
      changedIndexes: changed,
      schemaDirtyIndexes: changed,
      indexesById: mutableIndexes == null
          ? indexesById
          : Map<String, int>.unmodifiable(mutableIndexes),
    );
  }

  /// Returns point changes between [ancestor] and this list when both belong
  /// to the same structural-sharing chain. A null result asks callers to use
  /// their general structural diff path.
  PersistentBlockDelta? deltaSince(List<BlockNode> ancestor) {
    if (identical(this, ancestor)) {
      return const PersistentBlockDelta(changedIndexes: <int>{});
    }
    final changed = <int>{};
    PersistentBlockList cursor = this;
    while (true) {
      changed.addAll(cursor.changedIndexes);
      final parent = cursor._parent?.target;
      if (parent == null) {
        return null;
      }
      if (identical(parent, ancestor)) {
        return PersistentBlockDelta(
          changedIndexes: Set<int>.unmodifiable(changed),
        );
      }
      cursor = parent;
    }
  }

  PersistentBlockList asCleanSnapshot() {
    if (_parent == null && changedIndexes.isEmpty) {
      return this;
    }
    return PersistentBlockList._(_root, indexesById: _indexesById);
  }

  /// Clears the schema-dirty marker while retaining ancestry for the
  /// ChangeSet delta computed immediately after command execution.
  PersistentBlockList markNormalized() {
    if (_schemaDirtyIndexes.isEmpty) {
      return this;
    }
    final changed = <int>{};
    PersistentBlockList cursor = this;
    PersistentBlockList? normalizedParent;
    while (cursor._schemaDirtyIndexes.isNotEmpty) {
      changed.addAll(cursor.changedIndexes);
      final parent = cursor._parent?.target;
      if (parent == null) {
        break;
      }
      cursor = parent;
      if (cursor._schemaDirtyIndexes.isEmpty) {
        normalizedParent = cursor;
        break;
      }
    }
    return PersistentBlockList._(
      _root,
      parent: normalizedParent == null
          ? null
          : WeakReference<PersistentBlockList>(normalizedParent),
      changedIndexes: changed,
      indexesById: _indexesById,
    );
  }
}

class PersistentBlockDelta {
  const PersistentBlockDelta({required this.changedIndexes});

  final Set<int> changedIndexes;
}

sealed class _BlockTree {
  const _BlockTree(this.size);

  final int size;
}

class _BlockLeaf extends _BlockTree {
  _BlockLeaf(this.blocks) : super(blocks.length);

  final List<BlockNode> blocks;
}

class _BlockBranch extends _BlockTree {
  _BlockBranch(this.left, this.right) : super(left.size + right.size);

  final _BlockTree left;
  final _BlockTree right;
}

_BlockTree _buildBalanced(List<_BlockTree> nodes, int start, int end) {
  final count = end - start;
  if (count == 1) {
    return nodes[start];
  }
  final middle = start + count ~/ 2;
  return _BlockBranch(
    _buildBalanced(nodes, start, middle),
    _buildBalanced(nodes, middle, end),
  );
}

BlockNode _blockAt(_BlockTree node, int index) {
  if (node is _BlockLeaf) {
    return node.blocks[index];
  }
  final branch = node as _BlockBranch;
  if (index < branch.left.size) {
    return _blockAt(branch.left, index);
  }
  return _blockAt(branch.right, index - branch.left.size);
}

_BlockTree _replaceAt(_BlockTree node, int index, BlockNode block) {
  if (node is _BlockLeaf) {
    final next = node.blocks.toList(growable: false);
    next[index] = block;
    return _BlockLeaf(List<BlockNode>.unmodifiable(next));
  }
  final branch = node as _BlockBranch;
  if (index < branch.left.size) {
    return _BlockBranch(
      _replaceAt(branch.left, index, block),
      branch.right,
    );
  }
  return _BlockBranch(
    branch.left,
    _replaceAt(branch.right, index - branch.left.size, block),
  );
}

Iterable<BlockNode> _iterateTree(_BlockTree? root) sync* {
  if (root == null) {
    return;
  }
  final stack = <_BlockTree>[root];
  while (stack.isNotEmpty) {
    final node = stack.removeLast();
    if (node is _BlockLeaf) {
      yield* node.blocks;
    } else {
      final branch = node as _BlockBranch;
      stack
        ..add(branch.right)
        ..add(branch.left);
    }
  }
}
