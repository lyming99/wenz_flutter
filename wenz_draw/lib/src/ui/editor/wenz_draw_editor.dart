import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

import '../panels/left_shape_panel.dart';
import '../panels/right_inspector_panel.dart';
import '../theme/editor_theme.dart';
import '../toolbar/toolbar.dart';
import 'canvas_stage.dart';
import 'editor_config.dart';

/// A ready-to-use infinite-canvas editor: toolbar on top, shape palette on the
/// left, the canvas in the middle, and an inspector on the right.
///
/// This is the fastest integration path. Hosts that need a bespoke layout can
/// instead compose the individual pieces ([Toolbar], [LeftShapePanel],
/// [CanvasStage], [RightInspectorPanel]) directly.
///
/// ```dart
/// WenzDrawEditor(
///   canvasController: myCanvas,
///   viewController: myView,
///   config: EditorConfig(
///     contentCallbacks: EditorContentCallbacks(
///       onAddMindmap: _addMindmap,
///     ),
///   ),
/// )
/// ```
class WenzDrawEditor extends StatelessWidget {
  const WenzDrawEditor({
    super.key,
    required this.canvasController,
    required this.viewController,
    this.config = const EditorConfig(),
    this.theme = const EditorTheme(),
  });

  final CanvasController canvasController;
  final InfiniteCanvasController viewController;
  final EditorConfig config;
  final EditorTheme theme;

  @override
  Widget build(BuildContext context) {
    return EditorThemeScope(
      theme: theme,
      child: ColoredBox(
        color: theme.appBackground,
        child: _EditorBody(
          editor: this,
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final builder = config.toolbarBuilder;
    if (builder != null) {
      return builder(context, canvasController, viewController);
    }
    return Toolbar(
      canvasController: canvasController,
      viewController: viewController,
      onAddStickyNote: config.contentCallbacks.onAddStickyNote ?? () {},
      onAddCounter: config.contentCallbacks.onAddCounter ?? () {},
      onAddMindmap: config.contentCallbacks.onAddMindmap ?? () {},
      onInsertImage: config.contentCallbacks.onInsertImage ?? () {},
      documentStore: config.contentCallbacks.documentStore,
      onExportPng: config.contentCallbacks.onExportPng,
      metadata: config.contentCallbacks.metadata,
      actions: config.toolbarActions,
    );
  }

  Widget _buildLeftPanelContent(BuildContext context) {
    final builder = config.leftPanelBuilder;
    if (builder != null) {
      return builder(context, canvasController, viewController);
    }
    return LeftShapePanel(
      canvasController: canvasController,
      onAddStickyNote: config.contentCallbacks.onAddStickyNote ?? () {},
    );
  }

  Widget _buildRightPanelContent(BuildContext context) {
    final builder = config.rightPanelBuilder;
    if (builder != null) {
      return builder(context, canvasController, viewController);
    }
    return RightInspectorPanel(canvasController: canvasController);
  }

  Widget _buildCanvas(BuildContext context) {
    return CanvasStage(
      canvasController: canvasController,
      viewController: viewController,
      canvasConfig: config.canvasConfig,
    );
  }
}

/// Stateful body that owns the live widths of the left/right panels so the user
/// can drag the dividers to resize them. Widths are seeded from
/// [EditorConfig.leftPanelWidth] / [EditorConfig.rightPanelWidth] and clamped to
/// a sensible range.
class _EditorBody extends StatefulWidget {
  const _EditorBody({required this.editor});

  final WenzDrawEditor editor;

  @override
  State<_EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends State<_EditorBody> {
  late double _leftWidth;
  late double _rightWidth;

  static const double _minPanelWidth = 180;
  static const double _maxPanelWidth = 520;
  static const double _dividerHitWidth = 8;

  @override
  void initState() {
    super.initState();
    _leftWidth = widget.editor.config.leftPanelWidth;
    _rightWidth = widget.editor.config.rightPanelWidth;
  }

  @override
  void didUpdateWidget(covariant _EditorBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the host changed the configured widths, follow.
    if (oldWidget.editor.config.leftPanelWidth !=
        widget.editor.config.leftPanelWidth) {
      _leftWidth = widget.editor.config.leftPanelWidth;
    }
    if (oldWidget.editor.config.rightPanelWidth !=
        widget.editor.config.rightPanelWidth) {
      _rightWidth = widget.editor.config.rightPanelWidth;
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    return Column(
      children: [
        editor._buildToolbar(context),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (editor.config.showLeftPanel) ...[
                SizedBox(
                  width: _leftWidth,
                  child: editor._buildLeftPanelContent(context),
                ),
                _buildDivider(isLeft: true),
              ],
              Expanded(child: editor._buildCanvas(context)),
              if (editor.config.showRightPanel) ...[
                _buildDivider(isLeft: false),
                SizedBox(
                  width: _rightWidth,
                  child: editor._buildRightPanelContent(context),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider({required bool isLeft}) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          setState(() {
            if (isLeft) {
              _leftWidth = (_leftWidth + details.delta.dx)
                  .clamp(_minPanelWidth, _maxPanelWidth);
            } else {
              _rightWidth = (_rightWidth - details.delta.dx)
                  .clamp(_minPanelWidth, _maxPanelWidth);
            }
          });
        },
        child: Container(
          width: _dividerHitWidth,
          // No visible border — the divider is invisible, keeping the layout
          // clean. The 8px hit area + resize cursor make it discoverable.
          color: Colors.transparent,
        ),
      ),
    );
  }
}
