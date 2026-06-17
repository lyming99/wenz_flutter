import 'package:flutter/widgets.dart';

import '../canvas/canvas_controller.dart';
import '../elements/canvas_element.dart';

/// Builds an inspector section for the currently-selected element.
///
/// The right-hand inspector panel walks every registered builder and asks each
/// whether it wants to contribute a section for [element] (via [matches]), then
/// embeds the returned [Widget] as a panel section. This lets optional modules
/// (e.g. the mind map module) surface their own inspector controls without the
/// editor shell having to import them, keeping the dependency direction
/// one-way: modules depend on the shell, never the reverse.
///
/// Register a builder once at app startup via [InspectorSectionRegistry.register].
abstract class InspectorSectionBuilder {
  /// Whether this builder has anything to show for [element].
  ///
  /// Called on every selection change; keep it cheap. Inspectors receive the
  /// controller so they can read sibling elements (e.g. a mind map tree) if
  /// needed.
  bool matches(CanvasController controller, CanvasElement? element);

  /// The section widget to embed. Only called when [matches] returned true.
  /// Returning null is treated the same as [matches] being false.
  Widget? build(
    BuildContext context,
    CanvasController controller,
    CanvasElement element,
  );
}

/// Holds the active [InspectorSectionBuilder]s, consulted by the default
/// inspector panel. Modules register their builders here; the editor shell
/// remains unaware of concrete modules.
class InspectorSectionRegistry {
  InspectorSectionRegistry._();

  static final List<InspectorSectionBuilder> _builders = [];

  /// Registers [builder]. Idempotent if the same instance is added twice.
  static void register(InspectorSectionBuilder builder) {
    if (!_builders.contains(builder)) {
      _builders.add(builder);
    }
  }

  /// Removes [builder].
  static void unregister(InspectorSectionBuilder builder) {
    _builders.remove(builder);
  }

  /// All registered builders, in registration order.
  static List<InspectorSectionBuilder> get builders =>
      List.unmodifiable(_builders);

  /// Removes every builder. Mainly for tests.
  static void clear() {
    _builders.clear();
  }
}
