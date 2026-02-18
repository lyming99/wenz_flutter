#include "include/wenz_draw/wenz_draw_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "wenz_draw_plugin.h"

void WenzDrawPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  wenz_draw::WenzDrawPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
