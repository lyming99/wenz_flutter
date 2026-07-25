#include "maximized_window_bounds.h"

#include <algorithm>
#include <cstdint>
#include <limits>

namespace window_border {
namespace {

std::int32_t ClampDimension(std::int64_t value) {
  return static_cast<std::int32_t>(
      std::clamp<std::int64_t>(value, 0,
                               std::numeric_limits<std::int32_t>::max()));
}

}  // namespace

MaximizedWindowBounds CalculateMaximizedWindowBounds(
    const PhysicalWindowRect& monitor,
    const PhysicalWindowRect& work_area) {
  if (monitor.right <= monitor.left || monitor.bottom <= monitor.top) {
    return MaximizedWindowBounds{0, 0, 0, 0, false};
  }

  const std::int32_t left =
      std::clamp(work_area.left, monitor.left, monitor.right);
  const std::int32_t top =
      std::clamp(work_area.top, monitor.top, monitor.bottom);
  const std::int32_t right =
      std::clamp(work_area.right, monitor.left, monitor.right);
  const std::int32_t bottom =
      std::clamp(work_area.bottom, monitor.top, monitor.bottom);
  if (right <= left || bottom <= top) {
    return MaximizedWindowBounds{0, 0, 0, 0, false};
  }

  return MaximizedWindowBounds{
      ClampDimension(static_cast<std::int64_t>(left) - monitor.left),
      ClampDimension(static_cast<std::int64_t>(top) - monitor.top),
      ClampDimension(static_cast<std::int64_t>(right) - left),
      ClampDimension(static_cast<std::int64_t>(bottom) - top),
      true,
  };
}

}  // namespace window_border
