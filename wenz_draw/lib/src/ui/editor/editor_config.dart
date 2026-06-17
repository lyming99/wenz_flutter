import 'package:flutter/widgets.dart';

import '../../canvas/canvas_controller.dart';
import '../../infinite_canvas/infinite_canvas_controller.dart';

/// A toolbar action contributed by the host. Wired into the default editor
/// toolbar's trailing cluster when provided via [EditorConfig.toolbarActions].
class EditorToolbarAction {
  const EditorToolbarAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final void Function(CanvasController canvas, InfiniteCanvasController view)
      onPressed;
}

/// Host callbacks that create demo content. When a callback is null, the
/// corresponding toolbar/panel entry is hidden.
class EditorContentCallbacks {
  const EditorContentCallbacks({
    this.onAddStickyNote,
    this.onAddCounter,
    this.onAddMindmap,
    this.onInsertImage,
  });

  final VoidCallback? onAddStickyNote;
  final VoidCallback? onAddCounter;
  final VoidCallback? onAddMindmap;
  final VoidCallback? onInsertImage;
}

/// Configuration for [WenzDrawEditor]. Every option defaults to a value that
/// reproduces the bundled example editor, so a config-less editor is fully
/// functional.
class EditorConfig {
  const EditorConfig({
    this.showLeftPanel = true,
    this.showRightPanel = true,
    this.leftPanelWidth = 244,
    this.rightPanelWidth = 292,
    this.contentCallbacks = const EditorContentCallbacks(),
    this.toolbarActions = const [],
    this.leftPanelBuilder,
    this.rightPanelBuilder,
    this.toolbarBuilder,
  });

  final bool showLeftPanel;
  final bool showRightPanel;
  final double leftPanelWidth;
  final double rightPanelWidth;
  final EditorContentCallbacks contentCallbacks;
  final List<EditorToolbarAction> toolbarActions;

  final Widget Function(
    BuildContext context,
    CanvasController canvas,
    InfiniteCanvasController view,
  )? leftPanelBuilder;

  final Widget Function(
    BuildContext context,
    CanvasController canvas,
    InfiniteCanvasController view,
  )? rightPanelBuilder;

  final Widget Function(
    BuildContext context,
    CanvasController canvas,
    InfiniteCanvasController view,
  )? toolbarBuilder;
}
