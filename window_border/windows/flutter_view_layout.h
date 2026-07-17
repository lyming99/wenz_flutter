#ifndef FLUTTER_PLUGIN_FLUTTER_VIEW_LAYOUT_H_
#define FLUTTER_PLUGIN_FLUTTER_VIEW_LAYOUT_H_

#include <cstdint>

namespace window_border {

struct FlutterViewLayout {
  int x;
  int y;
  int width;
  int height;
};

// Calculates the Flutter child window bounds within the host client area.
// The configured border occupies space only while the custom border is
// enabled and the host is not maximized.
FlutterViewLayout CalculateFlutterViewLayout(int client_width,
                                             int client_height,
                                             double border_width, uint32_t dpi,
                                             bool border_enabled,
                                             bool maximized);

}  // namespace window_border

#endif  // FLUTTER_PLUGIN_FLUTTER_VIEW_LAYOUT_H_
