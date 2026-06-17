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
        child: Column(
          children: [
            _buildToolbar(context),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (config.showLeftPanel) _buildLeftPanel(context),
                  Expanded(child: _buildCanvas(context)),
                  if (config.showRightPanel) _buildRightPanel(context),
                ],
              ),
            ),
          ],
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
    );
  }

  Widget _buildLeftPanel(BuildContext context) {
    final builder = config.leftPanelBuilder;
    if (builder != null) {
      return SizedBox(
        width: config.leftPanelWidth,
        child: builder(context, canvasController, viewController),
      );
    }
    return SizedBox(
      width: config.leftPanelWidth,
      child: LeftShapePanel(
        canvasController: canvasController,
        onAddStickyNote: config.contentCallbacks.onAddStickyNote ?? () {},
      ),
    );
  }

  Widget _buildRightPanel(BuildContext context) {
    final builder = config.rightPanelBuilder;
    if (builder != null) {
      return SizedBox(
        width: config.rightPanelWidth,
        child: builder(context, canvasController, viewController),
      );
    }
    return SizedBox(
      width: config.rightPanelWidth,
      child: RightInspectorPanel(canvasController: canvasController),
    );
  }

  Widget _buildCanvas(BuildContext context) {
    return CanvasStage(
      canvasController: canvasController,
      viewController: viewController,
    );
  }
}
