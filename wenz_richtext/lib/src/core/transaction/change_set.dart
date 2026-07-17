import 'dart:convert';

import '../model/block_node.dart';
import '../model/persistent_block_list.dart';
import '../model/rich_text_document.dart';
import '../position/document_position.dart';

class ChangeSet {
  ChangeSet({
    required this.before,
    required this.after,
    this.selectionBefore,
    this.selectionAfter,
    this.description = '',
    this.metadata,
    DocumentChangeSummary? changeSummary,
  }) : changeSummary = changeSummary ??
            DocumentChangeSummary.compatibilityFallback(before, after);

  final RichTextDocument before;
  final RichTextDocument after;
  final DocumentSelection? selectionBefore;
  final DocumentSelection? selectionAfter;
  final String description;

  /// Optional command metadata for observers such as command pipeline hooks.
  final Map<String, Object?>? metadata;

  /// Structured information about the committed document mutation.
  ///
  /// The command executor always provides this explicitly, keeping JSON
  /// serialisation out of the input hot path. The constructor retains a
  /// compatibility fallback for middleware or external code that manually
  /// creates a [ChangeSet] without a summary.
  final DocumentChangeSummary changeSummary;

  bool get isNoop => !changeSummary.documentChanged;

  Set<String> get changedBlockIds => changeSummary.changedBlockIds;

  Set<String> get removedBlockIds => changeSummary.removedBlockIds;

  bool get structureChanged => changeSummary.structureChanged;
}

class DocumentChangeSummary {
  const DocumentChangeSummary({
    required this.documentChanged,
    this.changedBlockIds = const <String>{},
    this.removedBlockIds = const <String>{},
    this.structureChanged = false,
    this.metadataChanged = false,
    this.changedStartIndex,
    this.changedEndIndexExclusive,
    this.estimatedChangedBytes = 0,
  });

  static const DocumentChangeSummary none = DocumentChangeSummary(
    documentChanged: false,
  );

  factory DocumentChangeSummary.between(
    RichTextDocument before,
    RichTextDocument after, {
    required bool documentChanged,
  }) {
    if (!documentChanged) {
      return none;
    }

    final beforeBlocks = before.blocks;
    final afterBlocks = after.blocks;
    final metadataChanged = before.version != after.version ||
        !identical(before.comments, after.comments) ||
        !identical(before.revisions, after.revisions);

    if (afterBlocks is PersistentBlockList &&
        beforeBlocks.length == afterBlocks.length) {
      final delta = afterBlocks.deltaSince(beforeBlocks);
      if (delta != null) {
        final indexes = delta.changedIndexes.toList()..sort();
        var sameStructure = true;
        for (final index in indexes) {
          if (index < 0 ||
              index >= afterBlocks.length ||
              beforeBlocks[index].id != afterBlocks[index].id) {
            sameStructure = false;
            break;
          }
        }
        if (sameStructure) {
          final changed = <String>{};
          int? changedStart;
          int? changedEnd;
          var estimatedChangedBytes = metadataChanged ? 128 : 0;
          for (final index in indexes) {
            if (!_sameBlockValue(beforeBlocks[index], afterBlocks[index])) {
              changed.add(afterBlocks[index].id);
              estimatedChangedBytes +=
                  _estimateBlockBytes(beforeBlocks[index]) +
                      _estimateBlockBytes(afterBlocks[index]);
              changedStart ??= index;
              changedEnd = index + 1;
            }
          }
          final effectiveDocumentChanged =
              changed.isNotEmpty || metadataChanged;
          if (!effectiveDocumentChanged) {
            return none;
          }
          return DocumentChangeSummary(
            documentChanged: true,
            changedBlockIds: Set<String>.unmodifiable(changed),
            metadataChanged: metadataChanged,
            changedStartIndex: changedStart,
            changedEndIndexExclusive: changedEnd,
            estimatedChangedBytes: estimatedChangedBytes,
          );
        }
      }
    }

    final changed = <String>{};
    final removed = <String>{};
    var structureChanged = beforeBlocks.length != afterBlocks.length;
    int? changedStart;
    int? changedEnd;
    var estimatedChangedBytes = metadataChanged ? 128 : 0;

    if (!structureChanged) {
      for (var index = 0; index < beforeBlocks.length; index++) {
        if (beforeBlocks[index].id != afterBlocks[index].id) {
          structureChanged = true;
          break;
        }
      }
    }

    if (!structureChanged) {
      for (var index = 0; index < beforeBlocks.length; index++) {
        if (!_sameBlockValue(beforeBlocks[index], afterBlocks[index])) {
          changed.add(afterBlocks[index].id);
          estimatedChangedBytes += _estimateBlockBytes(beforeBlocks[index]) +
              _estimateBlockBytes(afterBlocks[index]);
          changedStart ??= index;
          changedEnd = index + 1;
        }
      }
    } else {
      // A structural edit shifts indexes, but it must not mark every shifted
      // block dirty. Match nodes by id and identity so an insertion at the
      // beginning reports only the inserted/replaced node as content-dirty.
      final beforeById = <String, BlockNode>{
        for (final block in beforeBlocks) block.id: block,
      };
      final afterIds = <String>{};
      for (var index = 0; index < afterBlocks.length; index++) {
        final block = afterBlocks[index];
        afterIds.add(block.id);
        final previous = beforeById[block.id];
        if (previous == null || !_sameBlockValue(previous, block)) {
          changed.add(block.id);
          estimatedChangedBytes +=
              (previous == null ? 0 : _estimateBlockBytes(previous)) +
                  _estimateBlockBytes(block);
          changedStart = changedStart == null || index < changedStart
              ? index
              : changedStart;
          changedEnd = changedEnd == null || index + 1 > changedEnd
              ? index + 1
              : changedEnd;
        }
      }
      for (final block in beforeBlocks) {
        if (!afterIds.contains(block.id)) {
          removed.add(block.id);
          estimatedChangedBytes += _estimateBlockBytes(block);
        }
      }

      var prefix = 0;
      final sharedLength = beforeBlocks.length < afterBlocks.length
          ? beforeBlocks.length
          : afterBlocks.length;
      while (prefix < sharedLength &&
          beforeBlocks[prefix].id == afterBlocks[prefix].id) {
        prefix++;
      }
      var suffix = 0;
      while (suffix < sharedLength - prefix &&
          beforeBlocks[beforeBlocks.length - suffix - 1].id ==
              afterBlocks[afterBlocks.length - suffix - 1].id) {
        suffix++;
      }
      changedStart = prefix;
      final beforeEnd = beforeBlocks.length - suffix;
      final afterEnd = afterBlocks.length - suffix;
      changedEnd = beforeEnd > afterEnd ? beforeEnd : afterEnd;
    }

    final effectiveDocumentChanged = structureChanged ||
        changed.isNotEmpty ||
        removed.isNotEmpty ||
        metadataChanged;
    if (!effectiveDocumentChanged) {
      return none;
    }
    if (structureChanged) {
      // Structural commands rebuild the persistent list spine. Account for
      // those retained references in addition to changed block payloads.
      estimatedChangedBytes += (beforeBlocks.length + afterBlocks.length) * 8;
    }

    return DocumentChangeSummary(
      documentChanged: effectiveDocumentChanged,
      changedBlockIds: Set<String>.unmodifiable(changed),
      removedBlockIds: Set<String>.unmodifiable(removed),
      structureChanged: structureChanged,
      metadataChanged: metadataChanged,
      changedStartIndex: changedStart,
      changedEndIndexExclusive: changedEnd,
      estimatedChangedBytes: estimatedChangedBytes,
    );
  }

  factory DocumentChangeSummary.compatibilityFallback(
    RichTextDocument before,
    RichTextDocument after,
  ) {
    final documentChanged =
        jsonEncode(before.toJson()) != jsonEncode(after.toJson());
    return DocumentChangeSummary.between(
      before,
      after,
      documentChanged: documentChanged,
    );
  }

  factory DocumentChangeSummary.merge(
    DocumentChangeSummary first,
    DocumentChangeSummary second,
  ) {
    if (!first.documentChanged) {
      return second;
    }
    if (!second.documentChanged) {
      return first;
    }
    final starts = <int>[
      if (first.changedStartIndex != null) first.changedStartIndex!,
      if (second.changedStartIndex != null) second.changedStartIndex!,
    ];
    final ends = <int>[
      if (first.changedEndIndexExclusive != null)
        first.changedEndIndexExclusive!,
      if (second.changedEndIndexExclusive != null)
        second.changedEndIndexExclusive!,
    ];
    starts.sort();
    ends.sort();
    return DocumentChangeSummary(
      documentChanged: true,
      changedBlockIds: Set<String>.unmodifiable(
        <String>{...first.changedBlockIds, ...second.changedBlockIds},
      ),
      removedBlockIds: Set<String>.unmodifiable(
        <String>{...first.removedBlockIds, ...second.removedBlockIds},
      ),
      structureChanged: first.structureChanged || second.structureChanged,
      metadataChanged: first.metadataChanged || second.metadataChanged,
      changedStartIndex: starts.isEmpty ? null : starts.first,
      changedEndIndexExclusive: ends.isEmpty ? null : ends.last,
      estimatedChangedBytes:
          first.estimatedChangedBytes + second.estimatedChangedBytes,
    );
  }

  final bool documentChanged;
  final Set<String> changedBlockIds;
  final Set<String> removedBlockIds;
  final bool structureChanged;
  final bool metadataChanged;
  final int? changedStartIndex;
  final int? changedEndIndexExclusive;
  final int estimatedChangedBytes;
}

bool _sameBlockValue(BlockNode first, BlockNode second) {
  if (identical(first, second)) {
    return true;
  }
  return jsonEncode(first.toJson()) == jsonEncode(second.toJson());
}

int _estimateBlockBytes(BlockNode block) {
  return 128 + block.plainText.length * 2;
}
