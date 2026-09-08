#include "window_border_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <windowsx.h>

#include <VersionHelpers.h>
#include <dwmapi.h>
#include <commctrl.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <memory>
#include <optional>
#include <sstream>
#include <string>
#include <variant>

#include "dwm_border_color.h"
#include "flutter_view_layout.h"
#include "maximized_window_bounds.h"

namespace window_border {
namespace {

constexpr UINT kLayoutFlutterViewMessage = WM_APP + 0x04B0;
constexpr double kResizeHitTestExtraLogicalPixels = 2.0;

bool IsFullscreenWindow(HWND window) {
  RECT bounds{};
  MONITORINFO monitor_info{sizeof(MONITORINFO)};
  if (!GetWindowRect(window, &bounds) ||
      !GetMonitorInfo(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST),
                      &monitor_info)) {
    return false;
  }
  return EqualRect(&bounds, &monitor_info.rcMonitor) != FALSE;
}

// The default window chrome is owned by the native implementation. Dart can
// optionally override these values, but it does not draw either surface.
constexpr uint32_t kChromeDarkBorderColor = 0xFF3C4043;
constexpr uint32_t kNativeBlackBackgroundColor = 0xFF000000;

HRGN CreateRegionForRect(const RECT& rect, LONG radius) {
  if (rect.right <= rect.left || rect.bottom <= rect.top) {
    return CreateRectRgn(0, 0, 0, 0);
  }
  const LONG maximum_radius =
      std::min(rect.right - rect.left, rect.bottom - rect.top) / 2;
  const LONG clamped_radius =
      std::max<LONG>(0, std::min(radius, maximum_radius));
  if (clamped_radius == 0) {
    return CreateRectRgn(rect.left, rect.top, rect.right, rect.bottom);
  }
  return CreateRoundRectRgn(rect.left, rect.top, rect.right + 1,
                            rect.bottom + 1, clamped_radius * 2,
                            clamped_radius * 2);
}

void AssignWindowRegion(HWND window, HRGN region, BOOL redraw) {
  if (SetWindowRgn(window, region, redraw) == 0 && region != nullptr) {
    DeleteObject(region);
  }
}

const flutter::EncodableValue* FindValue(
    const flutter::EncodableMap& arguments,
    const std::string& key) {
  const auto iterator = arguments.find(flutter::EncodableValue(key));
  return iterator == arguments.end() ? nullptr : &iterator->second;
}

std::optional<double> AsDouble(const flutter::EncodableValue* value) {
  if (value == nullptr) {
    return std::nullopt;
  }
  if (const auto* number = std::get_if<double>(value)) {
    return *number;
  }
  if (const auto* number = std::get_if<int32_t>(value)) {
    return static_cast<double>(*number);
  }
  if (const auto* number = std::get_if<int64_t>(value)) {
    return static_cast<double>(*number);
  }
  return std::nullopt;
}

std::optional<int64_t> AsInteger(const flutter::EncodableValue* value) {
  if (value == nullptr) {
    return std::nullopt;
  }
  if (const auto* number = std::get_if<int32_t>(value)) {
    return static_cast<int64_t>(*number);
  }
  if (const auto* number = std::get_if<int64_t>(value)) {
    return *number;
  }
  return std::nullopt;
}

std::optional<bool> AsBool(const flutter::EncodableValue* value) {
  if (value == nullptr) {
    return std::nullopt;
  }
  if (const auto* boolean = std::get_if<bool>(value)) {
    return *boolean;
  }
  return std::nullopt;
}

std::optional<LRESULT> ResizeHitTestFromName(const std::string& edge) {
  if (edge == "left") {
    return HTLEFT;
  }
  if (edge == "top") {
    return HTTOP;
  }
  if (edge == "right") {
    return HTRIGHT;
  }
  if (edge == "bottom") {
    return HTBOTTOM;
  }
  if (edge == "topLeft") {
    return HTTOPLEFT;
  }
  if (edge == "topRight") {
    return HTTOPRIGHT;
  }
  if (edge == "bottomLeft") {
    return HTBOTTOMLEFT;
  }
  if (edge == "bottomRight") {
    return HTBOTTOMRIGHT;
  }
  return std::nullopt;
}

}  // namespace

// static
void WindowBorderPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  HWND flutter_view = nullptr;
  if (registrar->GetView() != nullptr) {
    flutter_view = registrar->GetView()->GetNativeWindow();
  }

  auto plugin = std::unique_ptr<WindowBorderPlugin>(new WindowBorderPlugin(
      registrar, registrar->messenger(), flutter_view));
  WindowBorderPlugin* plugin_pointer = plugin.get();

  plugin->channel_->SetMethodCallHandler(
      [plugin_pointer](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  plugin->window_proc_delegate_id_ =
      registrar->RegisterTopLevelWindowProcDelegate(
          [plugin_pointer](HWND hwnd, UINT message, WPARAM wparam,
                           LPARAM lparam) {
            return plugin_pointer->HandleWindowProc(hwnd, message, wparam,
                                                    lparam);
          });

  registrar->AddPlugin(std::move(plugin));
}

WindowBorderPlugin::WindowBorderPlugin()
    : border_color_(kChromeDarkBorderColor),
      background_color_(kNativeBlackBackgroundColor) {
  RebuildBorderBrush();
  RebuildBackgroundBrush();
}

WindowBorderPlugin::WindowBorderPlugin(
    flutter::PluginRegistrarWindows* registrar,
    flutter::BinaryMessenger* messenger,
    HWND flutter_view)
    : registrar_(registrar),
      flutter_view_(flutter_view),
      border_color_(kChromeDarkBorderColor),
      background_color_(kNativeBlackBackgroundColor) {
  channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "window_border",
          &flutter::StandardMethodCodec::GetInstance());
  RebuildBorderBrush();
  RebuildBackgroundBrush();
}

bool WindowBorderPlugin::InstallFlutterViewSubclass() {
  if (flutter_view_ == nullptr || flutter_view_ == window_) {
    return true;
  }
  return SetWindowSubclass(flutter_view_, FlutterViewSubclassProc,
                           reinterpret_cast<UINT_PTR>(this),
                           reinterpret_cast<DWORD_PTR>(this)) != FALSE;
}

void WindowBorderPlugin::RemoveFlutterViewSubclass() {
  if (flutter_view_ != nullptr && IsWindow(flutter_view_)) {
    RemoveWindowSubclass(flutter_view_, FlutterViewSubclassProc,
                         reinterpret_cast<UINT_PTR>(this));
  }
}

LRESULT CALLBACK WindowBorderPlugin::FlutterViewSubclassProc(
    HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam,
    UINT_PTR subclass_id, DWORD_PTR reference_data) {
  auto* plugin = reinterpret_cast<WindowBorderPlugin*>(reference_data);
  if (message == WM_NCDESTROY) {
    RemoveWindowSubclass(hwnd, FlutterViewSubclassProc, subclass_id);
    plugin->flutter_view_ = nullptr;
  } else if (plugin->enabled_) {
    if (message == WM_NCHITTEST || message == WM_NCLBUTTONDOWN) {
      const POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      const LRESULT hit = plugin->HitTest(point);
      if (hit != HTCLIENT) {
        if (message == WM_NCHITTEST) {
          return hit;
        }
        // The child owns the hit, but only the top-level HWND must enter
        // Windows' native sizing loop. Do not rely on HTTRANSPARENT routing.
        ReleaseCapture();
        PostMessage(plugin->window_, WM_NCLBUTTONDOWN,
                    static_cast<WPARAM>(hit), lparam);
        return 0;
      }
    } else if (message == WM_SETCURSOR) {
      POINT point{};
      if (GetCursorPos(&point)) {
        LPCWSTR cursor = nullptr;
        switch (plugin->HitTest(point)) {
          case HTTOP:
          case HTBOTTOM: cursor = IDC_SIZENS; break;
          case HTLEFT:
          case HTRIGHT: cursor = IDC_SIZEWE; break;
          case HTTOPLEFT:
          case HTBOTTOMRIGHT: cursor = IDC_SIZENWSE; break;
          case HTTOPRIGHT:
          case HTBOTTOMLEFT: cursor = IDC_SIZENESW; break;
        }
        if (cursor != nullptr) {
          SetCursor(LoadCursor(nullptr, cursor));
          return TRUE;
        }
      }
    }
  }
  return DefSubclassProc(hwnd, message, wparam, lparam);
}

WindowBorderPlugin::~WindowBorderPlugin() {
  RemoveFlutterViewSubclass();
  if (enabled_) {
    std::string ignored_error;
    SetBorderEnabled(false, &ignored_error);
  }
  if (registrar_ != nullptr && window_proc_delegate_id_ >= 0) {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_delegate_id_);
  }
  if (border_brush_ != nullptr) {
    DeleteObject(border_brush_);
    border_brush_ = nullptr;
  }
  if (background_brush_ != nullptr) {
    DeleteObject(background_brush_);
    background_brush_ = nullptr;
  }
}

void WindowBorderPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "getPlatformVersion") {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
    return;
  }

  std::string error;
  if (method == "initialize") {
    const auto* arguments = method_call.arguments() == nullptr
                                ? nullptr
                                : std::get_if<flutter::EncodableMap>(
                                      method_call.arguments());
    if (arguments == nullptr) {
      result->Error("invalid_arguments", "initialize expects a style map.");
      return;
    }
    if (!UpdateStyle(*arguments, &error)) {
      result->Error("invalid_arguments", error);
      return;
    }
    const bool should_enable =
        AsBool(FindValue(*arguments, "enabled")).value_or(true);
    if (!EnsureWindow(&error)) {
      result->Error("window_unavailable", error);
      return;
    }
    if (!SetBorderEnabled(should_enable, &error)) {
      result->Error("window_unavailable", error);
      return;
    }
    NotifyStateChanged();
    result->Success();
    return;
  }

  if (method == "setEnabled") {
    const auto enabled = AsBool(method_call.arguments());
    if (!enabled.has_value()) {
      result->Error("invalid_arguments", "setEnabled expects a boolean.");
      return;
    }
    if (!SetBorderEnabled(*enabled, &error)) {
      result->Error("window_unavailable", error);
      return;
    }
    result->Success();
    return;
  }

  if (method == "setStyle") {
    const auto* arguments = method_call.arguments() == nullptr
                                ? nullptr
                                : std::get_if<flutter::EncodableMap>(
                                      method_call.arguments());
    if (arguments == nullptr) {
      result->Error("invalid_arguments", "setStyle expects a style map.");
      return;
    }

    const double previous_border_width = border_width_;
    const double previous_corner_radius = corner_radius_;
    const bool previous_resizable = resizable_;
    const bool previous_shadow_enabled = shadow_enabled_;
    const uint32_t previous_border_color = border_color_;
    const uint32_t previous_background_color = background_color_;
    if (!UpdateStyle(*arguments, &error)) {
      result->Error("invalid_arguments",
                    error.empty() ? "setStyle expects a style map." : error);
      return;
    }

    const bool frame_layout_changed =
        border_width_ != previous_border_width ||
        resizable_ != previous_resizable;
    const bool window_effects_changed =
        corner_radius_ != previous_corner_radius ||
        shadow_enabled_ != previous_shadow_enabled;
    const bool painted_style_changed =
        frame_layout_changed || window_effects_changed ||
        border_color_ != previous_border_color ||
        background_color_ != previous_background_color;
    if (enabled_ && frame_layout_changed) {
      ApplyFramelessStyle();
      LayoutFlutterView();
    } else if (enabled_ && window_effects_changed) {
      ApplyWindowEffects();
    }
    if (enabled_ && border_color_ != previous_border_color) {
      SetDwmBorderColor(window_, border_color_);
    }
    if (enabled_ && painted_style_changed && window_ != nullptr &&
        IsWindow(window_)) {
      RedrawWindow(window_, nullptr, nullptr,
                   RDW_INVALIDATE | RDW_NOERASE | RDW_NOCHILDREN);
    }
    result->Success();
    return;
  }

  if (!EnsureWindow(&error)) {
    result->Error("window_unavailable", error);
    return;
  }

  if (method == "startDragging") {
    POINT point{};
    GetCursorPos(&point);
    ReleaseCapture();
    PostMessage(window_, WM_NCLBUTTONDOWN, HTCAPTION,
                MAKELPARAM(point.x, point.y));
    result->Success();
  } else if (method == "startResizing") {
    const auto* edge = method_call.arguments() == nullptr
                           ? nullptr
                           : std::get_if<std::string>(method_call.arguments());
    const auto hit_test =
        edge == nullptr ? std::nullopt : ResizeHitTestFromName(*edge);
    if (!hit_test.has_value()) {
      result->Error("invalid_arguments", "Unknown resize edge.");
      return;
    }
    if (!resizable_ || IsZoomed(window_)) {
      result->Success();
      return;
    }
    POINT point{};
    GetCursorPos(&point);
    ReleaseCapture();
    PostMessage(window_, WM_NCLBUTTONDOWN, *hit_test,
                MAKELPARAM(point.x, point.y));
    result->Success();
  } else if (method == "minimize") {
    ShowWindow(window_, SW_MINIMIZE);
    result->Success();
  } else if (method == "maximize") {
    ShowWindowWithSynchronizedLayout(SW_MAXIMIZE);
    result->Success();
  } else if (method == "restore") {
    ShowWindowWithSynchronizedLayout(SW_RESTORE);
    result->Success();
  } else if (method == "toggleMaximize") {
    ShowWindowWithSynchronizedLayout(IsZoomed(window_) ? SW_RESTORE
                                                       : SW_MAXIMIZE);
    result->Success();
  } else if (method == "close") {
    PostMessage(window_, WM_CLOSE, 0, 0);
    result->Success();
  } else if (method == "isMaximized") {
    result->Success(flutter::EncodableValue(IsZoomed(window_) != FALSE));
  } else if (method == "getState") {
    result->Success(flutter::EncodableValue(CurrentState()));
  } else {
    result->NotImplemented();
  }
}

std::optional<LRESULT> WindowBorderPlugin::HandleWindowProc(
    HWND hwnd,
    UINT message,
    WPARAM wparam,
    LPARAM lparam) {
  if (window_ == nullptr) {
    window_ = hwnd;
  }
  if (!enabled_ || hwnd != window_) {
    return std::nullopt;
  }

  switch (message) {
    case WM_NCCALCSIZE:
      // Make the full top-level window client area available to the native
      // border host and remove the system caption/frame.
      return 0;
    case WM_NCPAINT:
      return 0;
    case WM_NCACTIVATE:
      return TRUE;
    case WM_NCHITTEST: {
      POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      return HitTest(point);
    }
    case WM_GETMINMAXINFO: {
      auto* min_max_info = reinterpret_cast<MINMAXINFO*>(lparam);
      const HMONITOR monitor =
          MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      MONITORINFO monitor_info{sizeof(MONITORINFO)};
      if (GetMonitorInfo(monitor, &monitor_info)) {
        const MaximizedWindowBounds bounds = CalculateMaximizedWindowBounds(
            PhysicalWindowRect{monitor_info.rcMonitor.left,
                               monitor_info.rcMonitor.top,
                               monitor_info.rcMonitor.right,
                               monitor_info.rcMonitor.bottom},
            PhysicalWindowRect{monitor_info.rcWork.left,
                               monitor_info.rcWork.top,
                               monitor_info.rcWork.right,
                               monitor_info.rcWork.bottom});
        if (bounds.valid) {
          min_max_info->ptMaxPosition.x = bounds.x;
          min_max_info->ptMaxPosition.y = bounds.y;
          min_max_info->ptMaxSize.x = bounds.width;
          min_max_info->ptMaxSize.y = bounds.height;
        }
      }
      return 0;
    }
    case WM_ERASEBKGND:
      PaintBorder(reinterpret_cast<HDC>(wparam));
      return 1;
    case WM_PAINT: {
      PAINTSTRUCT paint{};
      HDC device_context = BeginPaint(hwnd, &paint);
      PaintBorder(device_context);
      EndPaint(hwnd, &paint);
      return 0;
    }
    case WM_SIZE:
      // Consume WM_SIZE so the stock Runner cannot first stretch the Flutter
      // child to the full client area. Resizing it once, synchronously, avoids
      // two consecutive Flutter surface recreations for every drag step.
      LayoutFlutterView();
      PaintBorder();
      RedrawWindow(hwnd, nullptr, nullptr,
                   RDW_INVALIDATE | RDW_NOERASE | RDW_NOCHILDREN);
      NotifyStateChanged();
      return 0;
    case WM_DPICHANGED:
    case WM_DISPLAYCHANGE:
      // The Runner applies the suggested DPI bounds after plugin delegates
      // return. Defer one coalesced pass so the final client rect and DPI are
      // used; WM_SIZE may already have synchronized the child by then.
      ScheduleFlutterViewLayout();
      return std::nullopt;
    case WM_SETTINGCHANGE:
      // Taskbar relocation and auto-hide changes publish a new rcWork without
      // necessarily changing the display mode.
      if (wparam == SPI_SETWORKAREA || IsZoomed(hwnd)) {
        ScheduleFlutterViewLayout();
      }
      return std::nullopt;
    case WM_WINDOWPOSCHANGED:
      // A maximized window can be moved to another monitor through shell
      // shortcuts. Re-read that monitor after DefWindowProc settles the move.
      if (IsZoomed(hwnd)) {
        ScheduleFlutterViewLayout();
      }
      return std::nullopt;
    case WM_DWMCOMPOSITIONCHANGED:
      ApplyWindowEffects();
      ScheduleFlutterViewLayout();
      return std::nullopt;
    case WM_DWMNCRENDERINGCHANGED:
    case WM_DWMWINDOWMAXIMIZEDCHANGE:
      // DWM can publish these after the window state and client bounds have
      // changed. Share the coalesced follow-up used by DPI/display changes so
      // the Flutter HWND observes the settled geometry exactly once.
      ScheduleFlutterViewLayout();
      return std::nullopt;
    case kLayoutFlutterViewMessage:
      SynchronizeMaximizedWindowBounds();
      LayoutFlutterView();
      InvalidateRect(hwnd, nullptr, FALSE);
      layout_message_pending_ = false;
      return 0;
    case WM_NCDESTROY:
      window_ = nullptr;
      enabled_ = false;
      has_original_style_ = false;
      layout_message_pending_ = false;
      return std::nullopt;
    default:
      return std::nullopt;
  }
}

bool WindowBorderPlugin::EnsureWindow(std::string* error) {
  if (window_ != nullptr && IsWindow(window_)) {
    return true;
  }
  if (flutter_view_ == nullptr || !IsWindow(flutter_view_)) {
    *error = "Flutter did not provide a native view for this engine.";
    return false;
  }

  HWND root = GetAncestor(flutter_view_, GA_ROOT);
  if (root == nullptr || root == flutter_view_) {
    const HWND parent = GetParent(flutter_view_);
    root = parent == nullptr ? nullptr : GetAncestor(parent, GA_ROOT);
  }
  if (root == nullptr || root == flutter_view_) {
    *error = "The Flutter view is not attached to a top-level window yet.";
    return false;
  }
  window_ = root;
  return true;
}

bool WindowBorderPlugin::UpdateStyle(
    const flutter::EncodableMap& arguments,
    std::string* error) {
  if (const auto* value = FindValue(arguments, "borderWidth")) {
    const auto width = AsDouble(value);
    if (!width.has_value() || !std::isfinite(*width) || *width < 0.0) {
      *error = "borderWidth must be a finite non-negative number.";
      return false;
    }
    border_width_ = *width;
  }

  if (const auto* value = FindValue(arguments, "resizeBorderWidth")) {
    const auto width = AsDouble(value);
    if (!width.has_value() || !std::isfinite(*width) || *width < 0.0) {
      *error = "resizeBorderWidth must be a finite non-negative number.";
      return false;
    }
    resize_border_width_ = *width;
  }

  if (const auto* value = FindValue(arguments, "cornerRadius")) {
    const auto radius = AsDouble(value);
    if (!radius.has_value() || !std::isfinite(*radius) || *radius < 0.0) {
      *error = "cornerRadius must be a finite non-negative number.";
      return false;
    }
    corner_radius_ = *radius;
  }

  if (const auto* value = FindValue(arguments, "borderColor")) {
    const auto color = AsInteger(value);
    if (!color.has_value() || *color < 0 ||
        *color > static_cast<int64_t>(std::numeric_limits<uint32_t>::max())) {
      *error = "borderColor must be a 32-bit ARGB integer.";
      return false;
    }
    const auto next_color = static_cast<uint32_t>(*color);
    if (next_color != border_color_) {
      border_color_ = next_color;
      RebuildBorderBrush();
    }
  }

  if (const auto* value = FindValue(arguments, "backgroundColor")) {
    const auto color = AsInteger(value);
    if (!color.has_value() || *color < 0 ||
        *color > static_cast<int64_t>(std::numeric_limits<uint32_t>::max())) {
      *error = "backgroundColor must be a 32-bit ARGB integer.";
      return false;
    }
    const auto next_color = static_cast<uint32_t>(*color);
    if (next_color != background_color_) {
      background_color_ = next_color;
      RebuildBackgroundBrush();
    }
  }

  if (const auto* value = FindValue(arguments, "resizable")) {
    const auto resizable = AsBool(value);
    if (!resizable.has_value()) {
      *error = "resizable must be a boolean.";
      return false;
    }
    resizable_ = *resizable;
  }

  if (const auto* value = FindValue(arguments, "shadowEnabled")) {
    const auto shadow_enabled = AsBool(value);
    if (!shadow_enabled.has_value()) {
      *error = "shadowEnabled must be a boolean.";
      return false;
    }
    shadow_enabled_ = *shadow_enabled;
  }
  return true;
}

bool WindowBorderPlugin::SetBorderEnabled(bool enabled, std::string* error) {
  if (enabled) {
    if (!EnsureWindow(error)) {
      return false;
    }
    if (!InstallFlutterViewSubclass()) {
      *error = "Unable to install Flutter view resize hit testing.";
      return false;
    }
  } else {
    RemoveFlutterViewSubclass();
  }
  if (enabled == enabled_) {
    if (enabled) {
      if (!EnsureWindow(error)) {
        return false;
      }
      ApplyFramelessStyle();
      LayoutFlutterView();
    }
    return true;
  }

  if (enabled) {
    if (!EnsureWindow(error)) {
      return false;
    }
    original_style_ = GetWindowLongPtr(window_, GWL_STYLE);
    has_original_style_ = true;
    enabled_ = true;
    ApplyFramelessStyle();
    LayoutFlutterView();
    InvalidateRect(window_, nullptr, FALSE);
  } else {
    enabled_ = false;
    layout_message_pending_ = false;
    RestoreWindowEffects();
    RestoreWindowStyle();
    LayoutFlutterView();
    if (window_ != nullptr && IsWindow(window_)) {
      InvalidateRect(window_, nullptr, FALSE);
    }
  }
  return true;
}

void WindowBorderPlugin::ApplyFramelessStyle() {
  if (window_ == nullptr || !IsWindow(window_) || !has_original_style_) {
    return;
  }
  LONG_PTR style = original_style_ & ~static_cast<LONG_PTR>(WS_CAPTION);
  // Prevent parent erase/paint operations from touching the Flutter child
  // surface. Without this, the border brush can briefly replace a frame while
  // Windows enters its native move/resize loop.
  style |= WS_CLIPCHILDREN;
  if (resizable_) {
    style |= WS_THICKFRAME;
  } else {
    style &= ~static_cast<LONG_PTR>(WS_THICKFRAME);
  }
  SetWindowLongPtr(window_, GWL_STYLE, style);
  SetWindowPos(window_, nullptr, 0, 0, 0, 0,
               SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                   SWP_NOACTIVATE);
  ApplyWindowEffects();
}

void WindowBorderPlugin::RestoreWindowStyle() {
  if (window_ == nullptr || !IsWindow(window_) || !has_original_style_) {
    has_original_style_ = false;
    return;
  }
  SetWindowLongPtr(window_, GWL_STYLE, original_style_);
  SetWindowPos(window_, nullptr, 0, 0, 0, 0,
               SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                   SWP_NOACTIVATE);
  has_original_style_ = false;
}

void WindowBorderPlugin::ApplyWindowEffects() {
  if (!enabled_ || window_ == nullptr || !IsWindow(window_)) {
    return;
  }

  const bool maximized = IsZoomed(window_) != FALSE;
  DWM_WINDOW_CORNER_PREFERENCE corner_preference = DWMWCP_DONOTROUND;
  if (corner_radius_ > 0.0 && !maximized) {
    corner_preference =
        corner_radius_ <= 8.0 ? DWMWCP_ROUNDSMALL : DWMWCP_ROUND;
  }
  const HRESULT corner_result = DwmSetWindowAttribute(
      window_, DWMWA_WINDOW_CORNER_PREFERENCE, &corner_preference,
      sizeof(corner_preference));
  native_corner_preference_supported_ =
      shadow_enabled_ && SUCCEEDED(corner_result);

  const DWMNCRENDERINGPOLICY rendering_policy =
      shadow_enabled_ ? DWMNCRP_ENABLED : DWMNCRP_DISABLED;
  DwmSetWindowAttribute(window_, DWMWA_NCRENDERING_POLICY,
                        &rendering_policy, sizeof(rendering_policy));
  SetDwmBorderColor(window_, border_color_);
  const MARGINS shadow_margins = enabled_ && shadow_enabled_ && !maximized
                                     ? MARGINS{1, 1, 1, 1}
                                     : MARGINS{0, 0, 0, 0};
  DwmExtendFrameIntoClientArea(window_, &shadow_margins);
  UpdateRoundedRegions();
}

void WindowBorderPlugin::RestoreWindowEffects() {
  if (child_region_applied_ && flutter_view_ != nullptr &&
      IsWindow(flutter_view_)) {
    AssignWindowRegion(flutter_view_, nullptr, TRUE);
  }
  child_region_applied_ = false;
  if (window_ == nullptr || !IsWindow(window_)) {
    native_corner_preference_supported_ = false;
    fallback_window_region_applied_ = false;
    return;
  }
  if (fallback_window_region_applied_) {
    AssignWindowRegion(window_, nullptr, TRUE);
  }
  fallback_window_region_applied_ = false;

  const DWM_WINDOW_CORNER_PREFERENCE corner_preference = DWMWCP_DEFAULT;
  DwmSetWindowAttribute(window_, DWMWA_WINDOW_CORNER_PREFERENCE,
                        &corner_preference, sizeof(corner_preference));
  const DWMNCRENDERINGPOLICY rendering_policy = DWMNCRP_USEWINDOWSTYLE;
  DwmSetWindowAttribute(window_, DWMWA_NCRENDERING_POLICY,
                        &rendering_policy, sizeof(rendering_policy));
  ResetDwmBorderColor(window_);
  const MARGINS margins{0, 0, 0, 0};
  DwmExtendFrameIntoClientArea(window_, &margins);
  native_corner_preference_supported_ = false;
}

void WindowBorderPlugin::LayoutFlutterView() {
  if (window_ == nullptr || flutter_view_ == nullptr ||
      !IsWindow(window_) || !IsWindow(flutter_view_)) {
    return;
  }
  RECT client{};
  GetClientRect(window_, &client);
  UINT dpi = GetDpiForWindow(window_);
  if (dpi == 0) {
    dpi = 96;
  }
  const FlutterViewLayout layout = CalculateFlutterViewLayout(
      static_cast<int>(client.right - client.left),
      static_cast<int>(client.bottom - client.top), border_width_, dpi,
      enabled_, IsZoomed(window_) != FALSE);

  RECT flutter_rect{};
  GetWindowRect(flutter_view_, &flutter_rect);
  POINT flutter_points[2]{{flutter_rect.left, flutter_rect.top},
                          {flutter_rect.right, flutter_rect.bottom}};
  MapWindowPoints(HWND_DESKTOP, window_, flutter_points, 2);
  const bool geometry_changed =
      flutter_points[0].x != layout.x || flutter_points[0].y != layout.y ||
      flutter_points[1].x - flutter_points[0].x != layout.width ||
      flutter_points[1].y - flutter_points[0].y != layout.height;
  if (geometry_changed) {
    // Flutter synchronizes its render surface from the child HWND's WM_SIZE.
    // Resize only once, but allow the Flutter HWND to repaint the newly exposed
    // edge pixels. SWP_NOREDRAW leaves those pixels at the swapchain's default
    // clear color until a later frame, which appears as a white strip.
    SetWindowPos(flutter_view_, nullptr, layout.x, layout.y, layout.width,
                 layout.height, SWP_NOACTIVATE | SWP_NOZORDER);
  }
  UpdateRoundedRegions(false);
}

void WindowBorderPlugin::ScheduleFlutterViewLayout() {
  if (layout_message_pending_ || window_ == nullptr || !IsWindow(window_)) {
    return;
  }
  if (PostMessage(window_, kLayoutFlutterViewMessage, 0, 0)) {
    layout_message_pending_ = true;
  }
}

void WindowBorderPlugin::SynchronizeMaximizedWindowBounds() {
  if (window_ == nullptr || !IsWindow(window_) ||
      IsZoomed(window_) == FALSE) {
    return;
  }

  const HMONITOR monitor =
      MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info{sizeof(MONITORINFO)};
  if (monitor == nullptr || !GetMonitorInfo(monitor, &monitor_info)) {
    return;
  }

  const MaximizedWindowBounds bounds = CalculateMaximizedWindowBounds(
      PhysicalWindowRect{monitor_info.rcMonitor.left, monitor_info.rcMonitor.top,
                         monitor_info.rcMonitor.right,
                         monitor_info.rcMonitor.bottom},
      PhysicalWindowRect{monitor_info.rcWork.left, monitor_info.rcWork.top,
                         monitor_info.rcWork.right,
                         monitor_info.rcWork.bottom});
  if (!bounds.valid) {
    return;
  }

  const int left = monitor_info.rcMonitor.left + bounds.x;
  const int top = monitor_info.rcMonitor.top + bounds.y;
  RECT current{};
  if (GetWindowRect(window_, &current) &&
      current.left == left && current.top == top &&
      current.right - current.left == bounds.width &&
      current.bottom - current.top == bounds.height) {
    return;
  }

  SetWindowPos(window_, nullptr, left, top, bounds.width, bounds.height,
               SWP_NOACTIVATE | SWP_NOZORDER);
}

void WindowBorderPlugin::ShowWindowWithSynchronizedLayout(int command) {
  if (window_ == nullptr || !IsWindow(window_)) {
    return;
  }
  ShowWindow(window_, command);
  // ShowWindow normally sends WM_SIZE synchronously. Run a final pass after
  // the state transition as well so the child geometry never depends on that
  // implementation detail. LayoutFlutterView avoids a second SetWindowPos
  // when WM_SIZE already applied the same bounds.
  LayoutFlutterView();
}

void WindowBorderPlugin::UpdateRoundedRegions(bool redraw) {
  if (window_ == nullptr || flutter_view_ == nullptr ||
      !IsWindow(window_) || !IsWindow(flutter_view_)) {
    return;
  }

  const bool maximized = IsZoomed(window_) != FALSE;
  const bool should_round = enabled_ && corner_radius_ > 0.0 && !maximized;
  if (native_corner_preference_supported_) {
    DWM_WINDOW_CORNER_PREFERENCE corner_preference = DWMWCP_DONOTROUND;
    if (should_round) {
      corner_preference =
          corner_radius_ <= 8.0 ? DWMWCP_ROUNDSMALL : DWMWCP_ROUND;
    }
    DwmSetWindowAttribute(window_, DWMWA_WINDOW_CORNER_PREFERENCE,
                          &corner_preference, sizeof(corner_preference));
  }
  // Extending the DWM frame by one pixel gives restored frameless windows a
  // compositor shadow. A maximized Flutter view owns every client pixel, so
  // remove that extension until the window is restored.
  const MARGINS shadow_margins = enabled_ && shadow_enabled_ && !maximized
                                     ? MARGINS{1, 1, 1, 1}
                                     : MARGINS{0, 0, 0, 0};
  DwmExtendFrameIntoClientArea(window_, &shadow_margins);
  if (!should_round) {
    if (child_region_applied_) {
      AssignWindowRegion(flutter_view_, nullptr, redraw ? TRUE : FALSE);
      child_region_applied_ = false;
    }
    if (fallback_window_region_applied_) {
      AssignWindowRegion(window_, nullptr, redraw ? TRUE : FALSE);
      fallback_window_region_applied_ = false;
    }
    return;
  }

  const int border = ScaleLogicalPixels(border_width_);
  const int outer_radius = EffectiveCornerRadiusPixels();
  const int inner_radius = std::max(0, outer_radius - border);
  RECT flutter_client{};
  GetClientRect(flutter_view_, &flutter_client);
  AssignWindowRegion(flutter_view_,
                     CreateRegionForRect(flutter_client, inner_radius),
                     redraw ? TRUE : FALSE);
  child_region_applied_ = true;

  if (native_corner_preference_supported_) {
    // Windows 11 clips the top-level surface and its compositor shadow.
    if (fallback_window_region_applied_) {
      AssignWindowRegion(window_, nullptr, redraw ? TRUE : FALSE);
      fallback_window_region_applied_ = false;
    }
    return;
  }

  // Windows 10 fallback: shape the top-level HWND itself. DWM composition
  // normally keeps the external shadow; behavior can vary by compositor.
  RECT window_rect{};
  GetWindowRect(window_, &window_rect);
  const RECT local_window_rect{0, 0, window_rect.right - window_rect.left,
                               window_rect.bottom - window_rect.top};
  AssignWindowRegion(window_,
                     CreateRegionForRect(local_window_rect, outer_radius),
                     redraw ? TRUE : FALSE);
  fallback_window_region_applied_ = true;
}

void WindowBorderPlugin::PaintBorder(HDC device_context) {
  if (!enabled_ || window_ == nullptr ||
      (border_brush_ == nullptr && background_brush_ == nullptr)) {
    return;
  }
  // The maximized Flutter view occupies the entire client area. Painting the
  // host in that state would cover pixels owned by Flutter, so leave both the
  // background and border entirely to the child surface.
  if (IsZoomed(window_)) {
    return;
  }
  const bool owns_context = device_context == nullptr;
  if (owns_context) {
    device_context = GetDC(window_);
  }
  if (device_context == nullptr) {
    return;
  }
  RECT client{};
  GetClientRect(window_, &client);
  UINT dpi = GetDpiForWindow(window_);
  if (dpi == 0) {
    dpi = 96;
  }
  const FlutterViewLayout layout = CalculateFlutterViewLayout(
      static_cast<int>(client.right - client.left),
      static_cast<int>(client.bottom - client.top), border_width_, dpi,
      enabled_, false);

  // Explicitly subtract the Flutter HWND's visible region before filling the
  // native host. WS_CLIPCHILDREN normally does the same work, while this extra
  // clip keeps GetDC/WM_ERASEBKGND paths safe during native move and resize.
  if (background_brush_ != nullptr) {
    const int saved_context = SaveDC(device_context);
    if (saved_context != 0) {
      if (flutter_view_ != nullptr && IsWindow(flutter_view_)) {
        RECT flutter_window{};
        GetWindowRect(flutter_view_, &flutter_window);
        POINT flutter_origin{flutter_window.left, flutter_window.top};
        ScreenToClient(window_, &flutter_origin);
        const int flutter_width = flutter_window.right - flutter_window.left;
        const int flutter_height = flutter_window.bottom - flutter_window.top;
        HRGN flutter_region =
            CreateRectRgn(0, 0, flutter_width, flutter_height);
        if (flutter_region != nullptr) {
          if (GetWindowRgn(flutter_view_, flutter_region) == ERROR) {
            SetRectRgn(flutter_region, 0, 0, flutter_width, flutter_height);
          }
          OffsetRgn(flutter_region, flutter_origin.x, flutter_origin.y);
          ExtSelectClipRgn(device_context, flutter_region, RGN_DIFF);
          DeleteObject(flutter_region);
        }
      }
      FillRect(device_context, &client, background_brush_);
      RestoreDC(device_context, saved_context);
    }
  }

  const LONG border = layout.x;

  if (border > 0 && border_brush_ != nullptr) {
    const int corner_radius =
        corner_radius_ > 0.0 ? EffectiveCornerRadiusPixels() : 0;
    const int outer_radius =
        native_corner_preference_supported_ ? 0 : corner_radius;
    const RECT inner{client.left + layout.x, client.top + layout.y,
                     client.left + layout.x + layout.width,
                     client.top + layout.y + layout.height};
    HRGN outer_region = CreateRegionForRect(client, outer_radius);
    HRGN inner_region = CreateRegionForRect(
        inner,
        std::max<LONG>(0, static_cast<LONG>(corner_radius) - border));
    HRGN border_region = CreateRectRgn(0, 0, 0, 0);
    CombineRgn(border_region, outer_region, inner_region, RGN_DIFF);
    FillRgn(device_context, border_region, border_brush_);
    DeleteObject(border_region);
    DeleteObject(inner_region);
    DeleteObject(outer_region);
  }
  if (owns_context) {
    ReleaseDC(window_, device_context);
  }
}

LRESULT WindowBorderPlugin::HitTest(POINT screen_point) const {
  if (!resizable_ || IsZoomed(window_) || IsFullscreenWindow(window_)) {
    return HTCLIENT;
  }

  POINT point = screen_point;
  ScreenToClient(window_, &point);
  RECT client{};
  GetClientRect(window_, &client);
  // Expand only the invisible hit target, not the painted border or content
  // inset. Scale the additional 2dp with the current window DPI as well.
  const int resize_width = ScaleLogicalPixels(
      std::max(resize_border_width_, border_width_) +
      kResizeHitTestExtraLogicalPixels);

  if (!PtInRect(&client, point)) {
    return HTCLIENT;
  }
  // Like Chromium, distinguish edge thickness from the wider corner zones.
  // A slightly deeper top band keeps the handle reachable above Flutter tabs.
  const int top_width = std::max(resize_width, ScaleLogicalPixels(12.0));
  const int corner_width = std::max(resize_width, ScaleLogicalPixels(16.0));
  const bool corner_left = point.x < client.left + corner_width;
  const bool corner_right = point.x >= client.right - corner_width;

  const bool left = point.x >= client.left &&
                    point.x < client.left + resize_width;
  const bool right = point.x < client.right &&
                     point.x >= client.right - resize_width;
  const bool top = point.y >= client.top &&
                   point.y < client.top + top_width;
  const bool bottom = point.y < client.bottom &&
                      point.y >= client.bottom - resize_width;

  if (top && corner_left) {
    return HTTOPLEFT;
  }
  if (top && corner_right) {
    return HTTOPRIGHT;
  }
  if (bottom && corner_left) {
    return HTBOTTOMLEFT;
  }
  if (bottom && corner_right) {
    return HTBOTTOMRIGHT;
  }
  if (left) {
    return HTLEFT;
  }
  if (right) {
    return HTRIGHT;
  }
  if (top) {
    return HTTOP;
  }
  if (bottom) {
    return HTBOTTOM;
  }
  return HTCLIENT;
}

int WindowBorderPlugin::ScaleLogicalPixels(double logical_pixels) const {
  UINT dpi = 96;
  if (window_ != nullptr && IsWindow(window_)) {
    const UINT window_dpi = GetDpiForWindow(window_);
    if (window_dpi != 0) {
      dpi = window_dpi;
    }
  }
  return std::max(
      0, static_cast<int>(std::lround(logical_pixels * dpi / 96.0)));
}

int WindowBorderPlugin::EffectiveCornerRadiusPixels() const {
  if (corner_radius_ <= 0.0) {
    return 0;
  }
  if (native_corner_preference_supported_) {
    // DWM exposes small/regular preferences rather than an exact radius.
    return ScaleLogicalPixels(corner_radius_ <= 8.0 ? 4.0 : 8.0);
  }
  return ScaleLogicalPixels(corner_radius_);
}

std::string WindowBorderPlugin::CurrentState() const {
  if (window_ == nullptr || !IsWindow(window_)) {
    return "unknown";
  }
  if (IsIconic(window_)) {
    return "minimized";
  }
  if (IsZoomed(window_)) {
    return "maximized";
  }
  return "normal";
}

void WindowBorderPlugin::NotifyStateChanged() {
  const std::string state = CurrentState();
  if (state == last_state_) {
    return;
  }
  last_state_ = state;
  if (channel_ != nullptr) {
    channel_->InvokeMethod(
        "windowStateChanged",
        std::make_unique<flutter::EncodableValue>(state));
  }
}

void WindowBorderPlugin::RebuildBorderBrush() {
  if (border_brush_ != nullptr) {
    DeleteObject(border_brush_);
  }
  const BYTE red = static_cast<BYTE>((border_color_ >> 16) & 0xFF);
  const BYTE green = static_cast<BYTE>((border_color_ >> 8) & 0xFF);
  const BYTE blue = static_cast<BYTE>(border_color_ & 0xFF);
  border_brush_ = CreateSolidBrush(RGB(red, green, blue));
}

void WindowBorderPlugin::RebuildBackgroundBrush() {
  if (background_brush_ != nullptr) {
    DeleteObject(background_brush_);
  }
  const BYTE red = static_cast<BYTE>((background_color_ >> 16) & 0xFF);
  const BYTE green = static_cast<BYTE>((background_color_ >> 8) & 0xFF);
  const BYTE blue = static_cast<BYTE>(background_color_ & 0xFF);
  background_brush_ = CreateSolidBrush(RGB(red, green, blue));
}

}  // namespace window_border
