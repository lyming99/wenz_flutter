import 'package:flutter/material.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

/// Example host wrapper around [WenzOutlineTree].
///
/// The workbench keeps the [WenzOutlineController] as the single source of
/// truth, so this panel only assembles the inputs the tree needs to render and
/// react:
/// * the live heading list comes from [WenzOutlineController.items];
/// * the active heading is derived from the caret's block index (the last
///   heading at or before the caret);
/// * taps are forwarded to [WenzOutlineController.select], which moves the
///   selection to the heading so a mounted editor scrolls it into view.
///
/// The workbench rebuilds this panel via `setState` whenever the editor or the
/// outline controller notifies, so the tree stays in sync with the document in
/// real time (new/edited/removed headings, fold toggles, caret moves).
class ExampleOutlinePanel extends StatelessWidget {
  const ExampleOutlinePanel({
    super.key,
    required this.outlineController,
    required this.selection,
    this.width = 260,
  });

  /// The outline controller the workbench assembled with the editor.
  final WenzOutlineController outlineController;

  /// The current editor selection, used to resolve the active heading. Passing
  /// it in (rather than reading the controller) keeps this widget pure and
  /// cheaply testable.
  final DocumentSelection? selection;

  /// Fixed panel width forwarded to [WenzOutlineTree.width].
  final double width;

  @override
  Widget build(BuildContext context) {
    return WenzOutlineTree(
      items: outlineController.items,
      activeBlockId: activeBlockId,
      width: width,
      onSelect: (item) => outlineController.select(item),
    );
  }

  /// Resolves the heading that covers the caret: the last heading whose block
  /// index is at or before the caret. Returns `null` when there is no selection
  /// or the caret sits above the first heading, leaving no row highlighted.
  String? get activeBlockId {
    final caretBlockIndex = selection?.extent.blockIndex;
    if (caretBlockIndex == null) {
      return null;
    }
    final items = outlineController.items;
    for (var i = items.length - 1; i >= 0; i--) {
      if (items[i].blockIndex <= caretBlockIndex) {
        return items[i].blockId;
      }
    }
    return null;
  }
}
