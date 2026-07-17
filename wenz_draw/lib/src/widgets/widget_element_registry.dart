import 'widget_element_builder.dart';

class WidgetElementRegistry {
  WidgetElementRegistry._();

  static final Map<String, WidgetElementBuilder> _builders = {};

  static void register(String widgetType, WidgetElementBuilder builder) {
    _builders[widgetType] = builder;
  }

  static WidgetElementBuilder? getBuilder(String widgetType) {
    return _builders[widgetType];
  }

  static bool hasBuilder(String widgetType) {
    return _builders.containsKey(widgetType);
  }

  static void unregister(String widgetType) {
    _builders.remove(widgetType);
  }

  static Iterable<String> get registeredTypes => _builders.keys;

  static void clear() {
    _builders.clear();
  }
}
