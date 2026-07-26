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
namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

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
