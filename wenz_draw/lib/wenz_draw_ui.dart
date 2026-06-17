/// Optional editor UI shell for the wenz_draw infinite canvas SDK.
///
/// Import this barrel to embed the bundled editor ([WenzDrawEditor]) or to use
/// its building blocks (toolbar, panels, color picker, canvas stage). Hosts
/// that only need the headless kernel import [wenz_draw] instead.
///
/// ```dart
/// import 'package:wenz_draw/wenz_draw.dart';
/// import 'package:wenz_draw/wenz_draw_ui.dart';
///
/// WenzDrawEditor(
///   canvasController: controller,
///   viewController: view,
/// );
/// ```
library wenz_draw_ui;

// Theme
export 'src/ui/theme/editor_theme.dart';
export 'src/ui/theme/ui_colors.dart';

// Editor shell
export 'src/ui/editor/canvas_stage.dart';
export 'src/ui/editor/editor_actions.dart';
export 'src/ui/editor/editor_config.dart';
export 'src/ui/editor/wenz_draw_editor.dart';

// Toolbar
export 'src/ui/toolbar/line_tool_icon.dart';
export 'src/ui/toolbar/tool_button.dart';
export 'src/ui/toolbar/toolbar.dart';
export 'src/ui/toolbar/toolbar_divider.dart';

// Panels
export 'src/ui/panels/inspector_fields.dart';
export 'src/ui/panels/inspector_utils.dart';
export 'src/ui/panels/layer_row.dart';
export 'src/ui/panels/left_shape_panel.dart';
export 'src/ui/panels/panel_section.dart';
export 'src/ui/panels/right_inspector_panel.dart';
export 'src/ui/panels/shape_palette_data.dart';
export 'src/ui/panels/shape_palette_group.dart';

// Widgets (color picker, search, shape tiles, floating pill, ...)
export 'src/ui/widgets/color_picker_dialog.dart';
export 'src/ui/widgets/color_picker_painters.dart';
export 'src/ui/widgets/floating_pill.dart';
export 'src/ui/widgets/rgb_spectrum_picker.dart';
export 'src/ui/widgets/search_box.dart';
export 'src/ui/widgets/shape_preview_icon.dart';
export 'src/ui/widgets/shape_tile.dart';
export 'src/ui/widgets/spectrum_icon.dart';
