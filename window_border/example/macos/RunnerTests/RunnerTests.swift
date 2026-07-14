import XCTest

@testable import window_border

class RunnerTests: XCTestCase {
  func testPluginClassIsAvailable() {
    XCTAssertNotNil(WindowBorderPlugin.self)
  }
}
