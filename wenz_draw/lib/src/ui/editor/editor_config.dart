import 'package:flutter/widgets.dart';

import '../../canvas/canvas_controller.dart';
import '../../infinite_canvas/infinite_canvas_config.dart';
import '../../infinite_canvas/infinite_canvas_controller.dart';
import '../../serialization/canvas_document.dart';
import '../../serialization/document_store.dart';

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
    this.documentStore,
    this.onExportPng,
    this.metadata,
  });

  final VoidCallback? onAddStickyNote;
  final VoidCallback? onAddCounter;
  final VoidCallback? onAddMindmap;
  final VoidCallback? onInsertImage;

  /// Optional persistence backend. When set, the editor's 文件菜单 wires
  /// 保存/加载 to [DocumentStore.save] / [DocumentStore.load], giving a full
  /// save → close → reopen round-trip without host code. When null, those menu
  /// entries fall back to in-memory snapshots / JSON dialogs.
  final DocumentStore? documentStore;

  /// Optional override for PNG export. Receives the controllers so the host can
  /// render via its own pipeline (e.g. with a custom background). When null the
  /// editor uses the bundled [PngExporter].
  final Future<void> Function(
    BuildContext context,
    CanvasController canvas,
    InfiniteCanvasController view,
  )? onExportPng;

  /// Document metadata to embed on save (title, app id, …). Optional.
  final DocumentMetadata? metadata;
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
    this.canvasConfig,
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

  /// Optional override for the canvas's gesture/grid configuration. When null,
  /// [CanvasStage] uses its built-in default (line grid, all gestures enabled).
  /// Pass an [InfiniteCanvasConfig] to tune pinch/wheel/keyboard/double-tap/fling
  /// behavior or grid styling.
  final InfiniteCanvasConfig? canvasConfig;

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
