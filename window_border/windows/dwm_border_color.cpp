#include "dwm_border_color.h"

#include <dwmapi.h>

namespace window_border {
namespace {

// DWMWA_BORDER_COLOR is available at runtime starting with Windows 11 build
// 22000. Keep the numeric value here so the plug-in can still compile with an
// older Windows SDK; older systems simply reject the attribute.
constexpr auto kDwmBorderColorAttribute = static_cast<DWMWINDOWATTRIBUTE>(34);
constexpr COLORREF kDwmDefaultColor = 0xFFFFFFFF;

}  // namespace

COLORREF ColorRefFromArgb(uint32_t color) {
  const BYTE red = static_cast<BYTE>((color >> 16) & 0xFF);
  const BYTE green = static_cast<BYTE>((color >> 8) & 0xFF);
  const BYTE blue = static_cast<BYTE>(color & 0xFF);
  return RGB(red, green, blue);
}

HRESULT SetDwmBorderColor(HWND window, uint32_t color) {
  const COLORREF color_ref = ColorRefFromArgb(color);
  // Windows 11 composites its own visible frame border over the client area.
  // Updating the GDI brush alone changes the backing DC but leaves that DWM
  // layer in its previous color until the compositor attribute is updated.
  return DwmSetWindowAttribute(window, kDwmBorderColorAttribute, &color_ref,
                               sizeof(color_ref));
}

HRESULT ResetDwmBorderColor(HWND window) {
  return DwmSetWindowAttribute(window, kDwmBorderColorAttribute,
                               &kDwmDefaultColor, sizeof(kDwmDefaultColor));
}

}  // namespace window_border
