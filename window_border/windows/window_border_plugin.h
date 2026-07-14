#ifndef FLUTTER_PLUGIN_WINDOW_BORDER_PLUGIN_H_
#define FLUTTER_PLUGIN_WINDOW_BORDER_PLUGIN_H_

// Windows headers must be included before Flutter's Windows headers.
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <cstdint>
#include <memory>
#include <optional>
#include <string>

namespace window_border {

class WindowBorderPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  // Kept public so the generated native test target can instantiate the class.
  WindowBorderPlugin();
  ~WindowBorderPlugin() override;

  WindowBorderPlugin(const WindowBorderPlugin&) = delete;
  WindowBorderPlugin& operator=(const WindowBorderPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  WindowBorderPlugin(flutter::PluginRegistrarWindows* registrar,
                     flutter::BinaryMessenger* messenger,
                     HWND flutter_view);

  std::optional<LRESULT> HandleWindowProc(HWND hwnd,
                                          UINT message,
                                          WPARAM wparam,
                                          LPARAM lparam);
  bool EnsureWindow(std::string* error);
  bool UpdateStyle(const flutter::EncodableMap& arguments,
                   std::string* error);
  bool SetBorderEnabled(bool enabled, std::string* error);
  void ApplyFramelessStyle();
  void RestoreWindowStyle();
  void ApplyWindowEffects();
  void RestoreWindowEffects();
  void LayoutFlutterView();
  void UpdateRoundedRegions(bool redraw = true);
  void PaintBorder(HDC device_context = nullptr);
  LRESULT HitTest(POINT screen_point) const;
  int ScaleLogicalPixels(double logical_pixels) const;
  int EffectiveCornerRadiusPixels() const;
  std::string CurrentState() const;
  void NotifyStateChanged();
  void RebuildBorderBrush();
  void RebuildBackgroundBrush();

  flutter::PluginRegistrarWindows* registrar_ = nullptr;
  int window_proc_delegate_id_ = -1;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  HWND flutter_view_ = nullptr;
  HWND window_ = nullptr;
  LONG_PTR original_style_ = 0;
  bool has_original_style_ = false;
  bool enabled_ = false;

  double border_width_ = 1.0;
  double corner_radius_ = 0.0;
  double resize_border_width_ = 8.0;
  bool resizable_ = true;
  bool shadow_enabled_ = true;
  bool native_corner_preference_supported_ = false;
  bool child_region_applied_ = false;
  bool fallback_window_region_applied_ = false;
  uint32_t border_color_;
  uint32_t background_color_;
  HBRUSH border_brush_ = nullptr;
  HBRUSH background_brush_ = nullptr;
  std::string last_state_;
};

}  // namespace window_border

#endif  // FLUTTER_PLUGIN_WINDOW_BORDER_PLUGIN_H_
