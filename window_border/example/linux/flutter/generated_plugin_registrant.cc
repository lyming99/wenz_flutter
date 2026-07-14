//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <window_border/window_border_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) window_border_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "WindowBorderPlugin");
  window_border_plugin_register_with_registrar(window_border_registrar);
}
