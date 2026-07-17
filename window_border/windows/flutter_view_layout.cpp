#include "flutter_view_layout.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>

namespace window_border {
namespace {

constexpr uint32_t kDefaultDpi = 96;

int ScaleBorderWidth(double border_width, uint32_t dpi) {
  if (!std::isfinite(border_width) || border_width <= 0.0) {
    return 0;
  }
  const long double scaled =
      static_cast<long double>(border_width) *
      static_cast<long double>(dpi == 0 ? kDefaultDpi : dpi) / kDefaultDpi;
  if (scaled >= std::numeric_limits<int>::max()) {
    return std::numeric_limits<int>::max();
  }
  return static_cast<int>(std::round(scaled));
}

int ContentDimension(int client_dimension, int inset) {
  const int64_t dimension = std::max(0, client_dimension);
  const int64_t content = dimension - static_cast<int64_t>(inset) * 2;
  return static_cast<int>(std::max<int64_t>(0, content));
}

}  // namespace

FlutterViewLayout CalculateFlutterViewLayout(int client_width,
                                             int client_height,
                                             double border_width, uint32_t dpi,
                                             bool border_enabled,
                                             bool maximized) {
  const int inset =
      border_enabled && !maximized ? ScaleBorderWidth(border_width, dpi) : 0;
  return FlutterViewLayout{inset, inset, ContentDimension(client_width, inset),
                           ContentDimension(client_height, inset)};
}

}  // namespace window_border
