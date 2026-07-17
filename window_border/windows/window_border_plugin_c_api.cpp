#include "include/window_border/window_border_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "window_border_plugin.h"

void WindowBorderPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  window_border::WindowBorderPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
