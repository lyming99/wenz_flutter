import 'package:flutter/widgets.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

/// Test-only affordance that exposes the workbench's [WenzRichTextController]
/// through the widget tree so integration tests can assert on document model
/// state (plain text, selection, undo stack) in addition to rendered UI.
///
/// This is a grey-box hook: production code wraps the editor in a
/// [WenzEditorTestHost] with zero behavioural impact (it is a passthrough
/// [InheritedWidget]); only tests call [WenzEditorTestHost.of].
class WenzEditorTestHost extends InheritedWidget {
  const WenzEditorTestHost({
    super.key,
    required this.controller,
    required super.child,
  });

  /// The controller owned by the surrounding workbench.
  final WenzRichTextController controller;

  /// Resolves the controller from the widget tree. Returns `null` when no
  /// [WenzEditorTestHost] is present (production-only builds).
  static WenzRichTextController? of(BuildContext context) {
    final host = context
        .dependOnInheritedWidgetOfExactType<WenzEditorTestHost>();
    return host?.controller;
  }

  @override
  bool updateShouldNotify(WenzEditorTestHost oldWidget) =>
      !identical(controller, oldWidget.controller);
}
