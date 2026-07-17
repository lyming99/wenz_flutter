#include <gtest/gtest.h>

#include "flutter_view_layout.h"

namespace window_border {
namespace test {
namespace {

void ExpectLayout(const FlutterViewLayout& layout, int x, int y, int width,
                  int height) {
  EXPECT_EQ(layout.x, x);
  EXPECT_EQ(layout.y, y);
  EXPECT_EQ(layout.width, width);
  EXPECT_EQ(layout.height, height);
}

TEST(FlutterViewLayoutTest, InsetsNormalWindowForConfiguredBorderWidths) {
  struct TestCase {
    double border_width;
    int expected_inset;
  };
  constexpr TestCase test_cases[] = {
      {0.0, 0},
      {1.0, 1},
      {2.0, 2},
      {7.5, 8},
  };

  for (const auto& test_case : test_cases) {
    SCOPED_TRACE(test_case.border_width);
    const FlutterViewLayout layout = CalculateFlutterViewLayout(
        1280, 720, test_case.border_width, 96, true, false);
    ExpectLayout(layout, test_case.expected_inset, test_case.expected_inset,
                 1280 - test_case.expected_inset * 2,
                 720 - test_case.expected_inset * 2);
  }
}

TEST(FlutterViewLayoutTest, ScalesNormalWindowBorderForDpi) {
  struct TestCase {
    uint32_t dpi;
    int expected_inset;
  };
  constexpr TestCase test_cases[] = {
      {96, 2},
      {120, 3},
      {144, 3},
      {192, 4},
  };

  for (const auto& test_case : test_cases) {
    SCOPED_TRACE(test_case.dpi);
    const FlutterViewLayout layout = CalculateFlutterViewLayout(
        1000, 700, 2.0, test_case.dpi, true, false);
    ExpectLayout(layout, test_case.expected_inset, test_case.expected_inset,
                 1000 - test_case.expected_inset * 2,
                 700 - test_case.expected_inset * 2);
  }
}

TEST(FlutterViewLayoutTest, MaximizedWindowAlwaysFillsClientArea) {
  struct TestCase {
    int client_width;
    int client_height;
    double border_width;
    uint32_t dpi;
  };
  constexpr TestCase test_cases[] = {
      {1920, 1080, 2.0, 96},
      {2560, 1440, 12.0, 144},
      {3840, 2160, 100.0, 192},
      {1, 1, 8.0, 120},
  };

  for (const auto& test_case : test_cases) {
    SCOPED_TRACE(test_case.dpi);
    const FlutterViewLayout layout = CalculateFlutterViewLayout(
        test_case.client_width, test_case.client_height,
        test_case.border_width, test_case.dpi, true, true);
    ExpectLayout(layout, 0, 0, test_case.client_width,
                 test_case.client_height);
  }
}

TEST(FlutterViewLayoutTest, RestoreReappliesScaledBorderInset) {
  const FlutterViewLayout maximized =
      CalculateFlutterViewLayout(1600, 900, 4.0, 144, true, true);
  ExpectLayout(maximized, 0, 0, 1600, 900);

  const FlutterViewLayout restored =
      CalculateFlutterViewLayout(1200, 800, 4.0, 144, true, false);
  ExpectLayout(restored, 6, 6, 1188, 788);
}

TEST(FlutterViewLayoutTest, DisabledBorderDoesNotInsetNormalWindow) {
  const FlutterViewLayout layout =
      CalculateFlutterViewLayout(800, 600, 10.0, 192, false, false);
  ExpectLayout(layout, 0, 0, 800, 600);
}

TEST(FlutterViewLayoutTest, TinyClientAreaNeverProducesNegativeDimensions) {
  const FlutterViewLayout tiny =
      CalculateFlutterViewLayout(3, 1, 8.0, 192, true, false);
  ExpectLayout(tiny, 16, 16, 0, 0);

  const FlutterViewLayout empty =
      CalculateFlutterViewLayout(-10, -20, 2.0, 96, true, false);
  ExpectLayout(empty, 2, 2, 0, 0);
}

}  // namespace
}  // namespace test
}  // namespace window_border
