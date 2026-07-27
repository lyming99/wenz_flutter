#ifndef FLUTTER_PLUGIN_WINDOW_BORDER_DWM_BORDER_COLOR_H_
#define FLUTTER_PLUGIN_WINDOW_BORDER_DWM_BORDER_COLOR_H_

// Windows headers must be included before Flutter's Windows headers.
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

#include <cstdint>

namespace window_border {

COLORREF ColorRefFromArgb(uint32_t color);
HRESULT SetDwmBorderColor(HWND window, uint32_t color);
HRESULT ResetDwmBorderColor(HWND window);

}  // namespace window_border

#endif  // FLUTTER_PLUGIN_WINDOW_BORDER_DWM_BORDER_COLOR_H_
