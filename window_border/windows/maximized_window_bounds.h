#ifndef FLUTTER_PLUGIN_MAXIMIZED_WINDOW_BOUNDS_H_
#define FLUTTER_PLUGIN_MAXIMIZED_WINDOW_BOUNDS_H_

#include <cstdint>

namespace window_border {

/// A rectangle in the physical virtual-screen coordinate space.
struct PhysicalWindowRect {
  std::int32_t left;
  std::int32_t top;
  std::int32_t right;
  std::int32_t bottom;
};

/// Bounds supplied to `WM_GETMINMAXINFO` for a maximized frameless window.
struct MaximizedWindowBounds {
  std::int32_t x;
  std::int32_t y;
  std::int32_t width;
  std::int32_t height;
  bool valid;
};

/// Calculates maximized bounds from a monitor rectangle and its work area.
///
/// Both inputs are already physical pixels when the host process is
/// per-monitor-DPI aware, so this function deliberately performs no DPI
/// scaling. The work area is clipped to the monitor as a defensive guard
/// against stale shell geometry.
MaximizedWindowBounds CalculateMaximizedWindowBounds(
    const PhysicalWindowRect& monitor,
    const PhysicalWindowRect& work_area);

}  // namespace window_border

#endif  // FLUTTER_PLUGIN_MAXIMIZED_WINDOW_BOUNDS_H_
