#include "dwm_border_color.h"

#include <gtest/gtest.h>
#include <windows.h>

namespace window_border {
namespace test {

TEST(DwmBorderColorTest, ConvertsArgbToWindowsColorRef) {
  EXPECT_EQ(ColorRefFromArgb(0xFF112233), RGB(0x11, 0x22, 0x33));
  EXPECT_EQ(ColorRefFromArgb(0x003C4043), RGB(0x3C, 0x40, 0x43));
}

TEST(DwmBorderColorTest, SetsAndRestoresSupportedDwmBorderColor) {
  HWND window = CreateWindowExW(0, L"STATIC", L"window_border_test",
                                WS_OVERLAPPED, 0, 0, 100, 100, nullptr, nullptr,
                                GetModuleHandle(nullptr), nullptr);
  ASSERT_NE(window, nullptr);

  const HRESULT set_result = SetDwmBorderColor(window, 0xFF112233);
  if (FAILED(set_result)) {
    DestroyWindow(window);
    GTEST_SKIP() << "DWMWA_BORDER_COLOR is unavailable on this Windows host.";
  }

  EXPECT_TRUE(SUCCEEDED(ResetDwmBorderColor(window)));

  DestroyWindow(window);
}

}  // namespace test
}  // namespace window_border
