#ifndef FLUTTER_PLUGIN_WENZ_DRAW_PLUGIN_H_
#define FLUTTER_PLUGIN_WENZ_DRAW_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace wenz_draw {

class WenzDrawPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  WenzDrawPlugin();

  virtual ~WenzDrawPlugin();

  // Disallow copy and assign.
  WenzDrawPlugin(const WenzDrawPlugin&) = delete;
  WenzDrawPlugin& operator=(const WenzDrawPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace wenz_draw

#endif  // FLUTTER_PLUGIN_WENZ_DRAW_PLUGIN_H_
