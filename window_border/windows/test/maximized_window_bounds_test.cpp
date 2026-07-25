#include <gtest/gtest.h>

#include "maximized_window_bounds.h"

namespace window_border {
namespace test {
namespace {

void ExpectBounds(const MaximizedWindowBounds& bounds, std::int32_t x,
                  std::int32_t y, std::int32_t width, std::int32_t height) {
  EXPECT_TRUE(bounds.valid);
  EXPECT_EQ(bounds.x, x);
  EXPECT_EQ(bounds.y, y);
  EXPECT_EQ(bounds.width, width);
  EXPECT_EQ(bounds.height, height);
}

TEST(MaximizedWindowBoundsTest, UsesPrimaryMonitorWorkArea) {
  ExpectBounds(
      CalculateMaximizedWindowBounds(
          PhysicalWindowRect{0, 0, 1920, 1080},
          PhysicalWindowRect{0, 0, 1920, 1040}),
      0, 0, 1920, 1040);
}

TEST(MaximizedWindowBoundsTest, PreservesPhysicalPixelsAtMixedDpi) {
  // GetMonitorInfo returns physical pixels for a PerMonitorV2 process. A
  // 2560x1440 monitor at 150% must therefore remain 2560x1400 here rather than
  // being divided by the logical scale.
  ExpectBounds(
      CalculateMaximizedWindowBounds(
          PhysicalWindowRect{1920, 0, 4480, 1440},
          PhysicalWindowRect{1920, 0, 4480, 1400}),
      0, 0, 2560, 1400);
}

TEST(MaximizedWindowBoundsTest, HandlesNegativeVirtualScreenCoordinates) {
  ExpectBounds(
      CalculateMaximizedWindowBounds(
          PhysicalWindowRect{-2560, -200, 0, 1240},
          PhysicalWindowRect{-2560, -160, 0, 1240}),
      0, 40, 2560, 1400);
}

TEST(MaximizedWindowBoundsTest, HandlesTaskbarsOnEveryEdge) {
  const PhysicalWindowRect monitor{100, 200, 2020, 1280};
  struct TestCase {
    PhysicalWindowRect work;
    std::int32_t x;
    std::int32_t y;
    std::int32_t width;
    std::int32_t height;
  };
  constexpr TestCase test_cases[] = {
      {{100, 240, 2020, 1280}, 0, 40, 1920, 1040},
      {{100, 200, 2020, 1240}, 0, 0, 1920, 1040},
      {{148, 200, 2020, 1280}, 48, 0, 1872, 1080},
      {{100, 200, 1972, 1280}, 0, 0, 1872, 1080},
  };

  for (const auto& test_case : test_cases) {
    const MaximizedWindowBounds bounds =
        CalculateMaximizedWindowBounds(monitor, test_case.work);
    ExpectBounds(bounds, test_case.x, test_case.y, test_case.width,
                 test_case.height);
  }
}

TEST(MaximizedWindowBoundsTest, ClipsStaleWorkAreaToMonitor) {
  ExpectBounds(
      CalculateMaximizedWindowBounds(
          PhysicalWindowRect{0, 0, 1920, 1080},
          PhysicalWindowRect{-20, -10, 1940, 1090}),
      0, 0, 1920, 1080);
}

TEST(MaximizedWindowBoundsTest, RejectsInvalidRectangles) {
  EXPECT_FALSE(
      CalculateMaximizedWindowBounds(PhysicalWindowRect{0, 0, 0, 1080},
                                     PhysicalWindowRect{0, 0, 0, 1040})
          .valid);
  EXPECT_FALSE(
      CalculateMaximizedWindowBounds(PhysicalWindowRect{0, 0, 1920, 1080},
                                     PhysicalWindowRect{100, 100, 100, 200})
          .valid);
}

}  // namespace
}  // namespace test
}  // namespace window_border
