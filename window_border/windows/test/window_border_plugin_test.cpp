#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>

#include "window_border_plugin.h"

namespace window_border {

class WindowBorderPluginTestPeer {
 public:
  static void SetWindow(WindowBorderPlugin& plugin, HWND window) {
    plugin.window_ = window;
  }
  static bool AttachView(WindowBorderPlugin& plugin, HWND view) {
    plugin.flutter_view_ = view;
    plugin.enabled_ = true;
    return plugin.InstallFlutterViewSubclass();
  }
  static void DetachView(WindowBorderPlugin& plugin) {
    plugin.RemoveFlutterViewSubclass();
    plugin.enabled_ = false;
  }
  static void SetResizable(WindowBorderPlugin& plugin, bool value) {
    plugin.resizable_ = value;
  }
  static int Scale(const WindowBorderPlugin& plugin, double value) {
    return plugin.ScaleLogicalPixels(value);
  }
  static LRESULT HitTest(const WindowBorderPlugin& plugin, int x, int y) {
    POINT point{x, y};
    ClientToScreen(plugin.window_, &point);
    return plugin.HitTest(point);
  }
};

namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

TEST(WindowBorderPlugin, ResizeHitTargetIncludesExtraTwoLogicalPixels) {
  HWND window = CreateWindowEx(0, L"STATIC", L"resize test", WS_POPUP,
                               100, 100, 400, 300, nullptr, nullptr,
                               GetModuleHandle(nullptr), nullptr);
  ASSERT_NE(window, nullptr);
  {
    WindowBorderPlugin plugin;
    WindowBorderPluginTestPeer::SetWindow(plugin, window);
    const int width = WindowBorderPluginTestPeer::Scale(plugin, 10);
    const auto hit = [&](int x, int y) {
      return WindowBorderPluginTestPeer::HitTest(plugin, x, y);
    };
    EXPECT_EQ(hit(width - 1, 150), HTLEFT);
    EXPECT_EQ(hit(width, 150), HTCLIENT);
    EXPECT_EQ(hit(400 - width, 150), HTRIGHT);
    EXPECT_EQ(hit(399 - width, 150), HTCLIENT);
    EXPECT_EQ(hit(200, width - 1), HTTOP);
    EXPECT_EQ(hit(200, WindowBorderPluginTestPeer::Scale(plugin, 12) - 1), HTTOP);
    EXPECT_EQ(hit(200, WindowBorderPluginTestPeer::Scale(plugin, 12)), HTCLIENT);
    EXPECT_EQ(hit(WindowBorderPluginTestPeer::Scale(plugin, 16) - 1, 0), HTTOPLEFT);
    EXPECT_EQ(hit(WindowBorderPluginTestPeer::Scale(plugin, 16), 0), HTTOP);
    EXPECT_EQ(hit(200, 300 - width), HTBOTTOM);
    EXPECT_EQ(hit(200, 299 - width), HTCLIENT);
    EXPECT_EQ(hit(width - 1, width - 1), HTTOPLEFT);
    EXPECT_EQ(hit(400 - width, width - 1), HTTOPRIGHT);
    EXPECT_EQ(hit(width - 1, 300 - width), HTBOTTOMLEFT);
    EXPECT_EQ(hit(400 - width, 300 - width), HTBOTTOMRIGHT);
    WindowBorderPluginTestPeer::SetResizable(plugin, false);
    EXPECT_EQ(hit(0, 0), HTCLIENT);
    WindowBorderPluginTestPeer::SetResizable(plugin, true);
    MONITORINFO info{sizeof(MONITORINFO)};
    if (GetMonitorInfo(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST),
                       &info)) {
      SetWindowPos(window, nullptr, info.rcMonitor.left, info.rcMonitor.top,
                   info.rcMonitor.right - info.rcMonitor.left,
                   info.rcMonitor.bottom - info.rcMonitor.top,
                   SWP_NOZORDER | SWP_NOACTIVATE);
      EXPECT_EQ(hit(0, 0), HTCLIENT);
    } else {
      ADD_FAILURE() << "Cannot query test monitor";
    }
    WindowBorderPluginTestPeer::SetWindow(plugin, nullptr);
  }
  DestroyWindow(window);
}

TEST(WindowBorderPlugin, FlutterChildPassesTopResizeZoneToHost) {
  HWND host = CreateWindowEx(0, L"STATIC", L"host", WS_POPUP,
      100, 100, 400, 300, nullptr, nullptr, GetModuleHandle(nullptr), nullptr);
  ASSERT_NE(host, nullptr);
  HWND child = CreateWindowEx(0, L"STATIC", L"view", WS_CHILD | SS_NOTIFY,
      1, 1, 398, 298, host, nullptr, GetModuleHandle(nullptr), nullptr);
  ASSERT_NE(child, nullptr);
  {
    WindowBorderPlugin plugin;
    WindowBorderPluginTestPeer::SetWindow(plugin, host);
    EXPECT_TRUE(WindowBorderPluginTestPeer::AttachView(plugin, child));
    const auto hit = [&](int x, int y) {
      POINT point{x, y};
      ClientToScreen(host, &point);
      return SendMessage(child, WM_NCHITTEST, 0,
                         MAKELPARAM(point.x, point.y));
    };
    const int width = WindowBorderPluginTestPeer::Scale(plugin, 10);
    EXPECT_EQ(hit(200, width - 1), HTTOP);
    EXPECT_EQ(hit(width - 1, width - 1), HTTOPLEFT);
    EXPECT_EQ(hit(400 - width, width - 1), HTTOPRIGHT);
    EXPECT_EQ(hit(200, WindowBorderPluginTestPeer::Scale(plugin, 12) - 1), HTTOP);
    EXPECT_NE(hit(200, WindowBorderPluginTestPeer::Scale(plugin, 12)), HTTOP);
    POINT click{200, width - 1};
    ClientToScreen(host, &click);
    SendMessage(child, WM_NCLBUTTONDOWN, HTTOP, MAKELPARAM(click.x, click.y));
    MSG forwarded{};
    EXPECT_TRUE(PeekMessage(&forwarded, host, WM_NCLBUTTONDOWN,
                            WM_NCLBUTTONDOWN, PM_REMOVE));
    EXPECT_EQ(forwarded.wParam, static_cast<WPARAM>(HTTOP));
    EXPECT_EQ(forwarded.lParam, MAKELPARAM(click.x, click.y));
    WindowBorderPluginTestPeer::SetResizable(plugin, false);
    EXPECT_NE(hit(200, width - 1), HTTOP);
    WindowBorderPluginTestPeer::SetResizable(plugin, true);
    WindowBorderPluginTestPeer::DetachView(plugin);
    EXPECT_NE(hit(200, width - 1), HTTOP);
    EXPECT_TRUE(WindowBorderPluginTestPeer::AttachView(plugin, child));
    DestroyWindow(child);  // WM_NCDESTROY must detach without a stale callback.
    WindowBorderPluginTestPeer::DetachView(plugin);
    WindowBorderPluginTestPeer::SetWindow(plugin, nullptr);
  }
  DestroyWindow(host);
}

TEST(WindowBorderPlugin, GetPlatformVersion) {
  WindowBorderPlugin plugin;
  // Save the reply value from the success callback.
  std::string result_string;
  plugin.HandleMethodCall(
      MethodCall("getPlatformVersion", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [&result_string](const EncodableValue* result) {
            result_string = std::get<std::string>(*result);
          },
          nullptr, nullptr));

  // Since the exact string varies by host, just ensure that it's a string
  // with the expected format.
  EXPECT_TRUE(result_string.rfind("Windows ", 0) == 0);
}

TEST(WindowBorderPlugin, SetStyleAcceptsColorOnlyUpdatesWithoutAWindow) {
  WindowBorderPlugin plugin;
  EncodableMap arguments{
      {EncodableValue("borderColor"),
       EncodableValue(static_cast<int64_t>(0xFF112233))},
      {EncodableValue("backgroundColor"),
       EncodableValue(static_cast<int64_t>(0xFF010203))},
  };
  bool succeeded = false;
  plugin.HandleMethodCall(
      MethodCall("setStyle",
                 std::make_unique<EncodableValue>(std::move(arguments))),
      std::make_unique<MethodResultFunctions<>>(
          [&succeeded](const EncodableValue*) { succeeded = true; }, nullptr,
          nullptr));

  EXPECT_TRUE(succeeded);
}

}  // namespace test
}  // namespace window_border
