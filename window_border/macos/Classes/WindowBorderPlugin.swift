import Cocoa
import FlutterMacOS

public class WindowBorderPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel
  private weak var flutterView: NSView?

  private var enabled = false
  private var borderWidth: CGFloat = 1
  private var borderColor: UInt32 = 0xFF3C4043
  private var backgroundColor: UInt32 = 0xFF000000
  private var cornerRadius: CGFloat = 0
  private var shadowEnabled = true
  private var resizeBorderWidth: CGFloat = 8
  private var resizable = true

  private var originalStyleMask: NSWindow.StyleMask?
  private var originalTitleVisibility: NSWindow.TitleVisibility = .visible
  private var originalTitlebarAppearsTransparent = false
  private var originalMovableByBackground = false
  private var originalButtonVisibility: [NSWindow.ButtonType: Bool] = [:]
  private var originalWantsLayer = false
  private var originalLayerBorderWidth: CGFloat = 0
  private var originalLayerBorderColor: CGColor?
  private var originalLayerBackgroundColor: CGColor?
  private var originalLayerCornerRadius: CGFloat = 0
  private var originalLayerMasksToBounds = false
  private var originalWindowHasShadow = true
  private var originalWindowBackgroundColor: NSColor?
  private var notificationTokens: [NSObjectProtocol] = []
  private var lastState = ""

  private var window: NSWindow? {
    flutterView?.window ?? NSApp.mainWindow
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "window_border",
      binaryMessenger: registrar.messenger)
    let instance = WindowBorderPlugin(channel: channel, view: registrar.view)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  init(channel: FlutterMethodChannel, view: NSView?) {
    self.channel = channel
    self.flutterView = view
    super.init()
  }

  deinit {
    setEnabled(false)
    removeWindowObservers()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case "initialize":
      guard let arguments = call.arguments as? [String: Any] else {
        result(invalidArguments("initialize expects a style map."))
        return
      }
      if let error = updateStyle(arguments) {
        result(error)
        return
      }
      let shouldEnable = arguments["enabled"] as? Bool ?? true
      if shouldEnable && arguments["enabled"] != nil &&
          !(arguments["enabled"] is Bool) {
        result(invalidArguments("enabled must be a boolean."))
        return
      }
      guard window != nil else {
        result(windowUnavailable())
        return
      }
      setEnabled(shouldEnable)
      notifyState()
      result(nil)
    case "setEnabled":
      guard let value = call.arguments as? Bool else {
        result(invalidArguments("setEnabled expects a boolean."))
        return
      }
      guard window != nil else {
        result(windowUnavailable())
        return
      }
      setEnabled(value)
      result(nil)
    case "setStyle":
      guard let arguments = call.arguments as? [String: Any] else {
        result(invalidArguments("setStyle expects a style map."))
        return
      }
      if let error = updateStyle(arguments) {
        result(error)
      } else {
        result(nil)
      }
    case "startDragging":
      guard let window = window else {
        result(windowUnavailable())
        return
      }
      if let event = NSApp.currentEvent {
        window.performDrag(with: event)
      }
      result(nil)
    case "startResizing":
      let validEdges: Set<String> = [
        "left", "top", "right", "bottom", "topLeft", "topRight",
        "bottomLeft", "bottomRight",
      ]
      guard let edge = call.arguments as? String, validEdges.contains(edge) else {
        result(invalidArguments("Unknown resize edge."))
        return
      }
      // NSWindow keeps native edge resizing while .resizable is present.
      result(nil)
    case "minimize":
      guard let window = window else {
        result(windowUnavailable())
        return
      }
      window.miniaturize(nil)
      result(nil)
    case "maximize":
      guard let window = window else {
        result(windowUnavailable())
        return
      }
      if !window.isZoomed { window.performZoom(nil) }
      result(nil)
    case "restore":
      guard let window = window else {
        result(windowUnavailable())
        return
      }
      if window.isMiniaturized { window.deminiaturize(nil) }
      if window.isZoomed { window.performZoom(nil) }
      result(nil)
    case "toggleMaximize":
      guard let window = window else {
        result(windowUnavailable())
        return
      }
      window.performZoom(nil)
      result(nil)
    case "close":
      guard let window = window else {
        result(windowUnavailable())
        return
      }
      result(nil)
      window.performClose(nil)
    case "isMaximized":
      guard let window = window else {
        result(windowUnavailable())
        return
      }
      result(window.isZoomed)
    case "getState":
      guard let window = window else {
        result(windowUnavailable())
        return
      }
      result(currentState(window))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func updateStyle(_ arguments: [String: Any]) -> FlutterError? {
    if let value = arguments["borderWidth"] {
      guard let number = value as? NSNumber,
            number.doubleValue.isFinite,
            number.doubleValue >= 0 else {
        return invalidArguments(
          "borderWidth must be a finite non-negative number.")
      }
      borderWidth = CGFloat(number.doubleValue)
    }
    if let value = arguments["resizeBorderWidth"] {
      guard let number = value as? NSNumber,
            number.doubleValue.isFinite,
            number.doubleValue >= 0 else {
        return invalidArguments(
          "resizeBorderWidth must be a finite non-negative number.")
      }
      resizeBorderWidth = CGFloat(number.doubleValue)
    }
    if let value = arguments["cornerRadius"] {
      guard let number = value as? NSNumber,
            number.doubleValue.isFinite,
            number.doubleValue >= 0 else {
        return invalidArguments(
          "cornerRadius must be a finite non-negative number.")
      }
      cornerRadius = CGFloat(number.doubleValue)
    }
    if let value = arguments["borderColor"] {
      guard let number = value as? NSNumber,
            number.int64Value >= 0,
            number.uint64Value <= UInt64(UInt32.max) else {
        return invalidArguments("borderColor must be a 32-bit ARGB integer.")
      }
      borderColor = number.uint32Value
    }
    if let value = arguments["backgroundColor"] {
      guard let number = value as? NSNumber,
            number.int64Value >= 0,
            number.uint64Value <= UInt64(UInt32.max) else {
        return invalidArguments("backgroundColor must be a 32-bit ARGB integer.")
      }
      backgroundColor = number.uint32Value
    }
    if let value = arguments["resizable"] {
      guard let boolValue = value as? Bool else {
        return invalidArguments("resizable must be a boolean.")
      }
      resizable = boolValue
    }
    if let value = arguments["shadowEnabled"] {
      guard let boolValue = value as? Bool else {
        return invalidArguments("shadowEnabled must be a boolean.")
      }
      shadowEnabled = boolValue
    }
    if enabled {
      applyFramelessStyle()
      applyBorderLayer()
    }
    return nil
  }

  private func setEnabled(_ value: Bool) {
    guard value != enabled, let window = window else { return }
    if value {
      originalStyleMask = window.styleMask
      originalTitleVisibility = window.titleVisibility
      originalTitlebarAppearsTransparent = window.titlebarAppearsTransparent
      originalMovableByBackground = window.isMovableByWindowBackground
      originalWindowHasShadow = window.hasShadow
      originalWindowBackgroundColor = window.backgroundColor
      originalButtonVisibility.removeAll()
      for type in buttonTypes {
        if let button = window.standardWindowButton(type) {
          originalButtonVisibility[type] = button.isHidden
        }
      }
      if let contentView = window.contentView {
        originalWantsLayer = contentView.wantsLayer
        originalLayerBorderWidth = contentView.layer?.borderWidth ?? 0
        originalLayerBorderColor = contentView.layer?.borderColor
        originalLayerBackgroundColor = contentView.layer?.backgroundColor
        originalLayerCornerRadius = contentView.layer?.cornerRadius ?? 0
        originalLayerMasksToBounds = contentView.layer?.masksToBounds ?? false
      }
      enabled = true
      applyFramelessStyle()
      applyBorderLayer()
      installWindowObservers(window)
    } else {
      enabled = false
      removeWindowObservers()
      if let styleMask = originalStyleMask {
        window.styleMask = styleMask
      }
      window.titleVisibility = originalTitleVisibility
      window.titlebarAppearsTransparent = originalTitlebarAppearsTransparent
      window.isMovableByWindowBackground = originalMovableByBackground
      window.hasShadow = originalWindowHasShadow
      if let color = originalWindowBackgroundColor {
        window.backgroundColor = color
      }
      for (type, wasHidden) in originalButtonVisibility {
        window.standardWindowButton(type)?.isHidden = wasHidden
      }
      if let contentView = window.contentView {
        contentView.layer?.borderWidth = originalLayerBorderWidth
        contentView.layer?.borderColor = originalLayerBorderColor
        contentView.layer?.backgroundColor = originalLayerBackgroundColor
        contentView.layer?.cornerRadius = originalLayerCornerRadius
        contentView.layer?.masksToBounds = originalLayerMasksToBounds
        contentView.wantsLayer = originalWantsLayer
      }
      originalStyleMask = nil
      originalWindowBackgroundColor = nil
      originalButtonVisibility.removeAll()
    }
  }

  private func applyFramelessStyle() {
    guard let window = window else { return }
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.styleMask.insert(.fullSizeContentView)
    if resizable {
      window.styleMask.insert(.resizable)
    } else {
      window.styleMask.remove(.resizable)
    }
    window.isMovableByWindowBackground = false
    window.hasShadow = shadowEnabled
    window.backgroundColor = nsColor(fromARGB: backgroundColor)
    for type in buttonTypes {
      window.standardWindowButton(type)?.isHidden = true
    }
  }

  private func applyBorderLayer() {
    guard let contentView = window?.contentView else { return }
    contentView.wantsLayer = true
    contentView.layer?.borderWidth = borderWidth
    contentView.layer?.borderColor = nsColor(fromARGB: borderColor).cgColor
    contentView.layer?.backgroundColor = nsColor(fromARGB: backgroundColor).cgColor
    contentView.layer?.cornerRadius = cornerRadius
    contentView.layer?.masksToBounds = cornerRadius > 0
  }

  private func nsColor(fromARGB color: UInt32) -> NSColor {
    let alpha = CGFloat((color >> 24) & 0xFF) / 255
    let red = CGFloat((color >> 16) & 0xFF) / 255
    let green = CGFloat((color >> 8) & 0xFF) / 255
    let blue = CGFloat(color & 0xFF) / 255
    return NSColor(
      calibratedRed: red, green: green, blue: blue, alpha: alpha)
  }

  private func installWindowObservers(_ window: NSWindow) {
    removeWindowObservers()
    let names: [Notification.Name] = [
      NSWindow.didMiniaturizeNotification,
      NSWindow.didDeminiaturizeNotification,
      NSWindow.didEnterFullScreenNotification,
      NSWindow.didExitFullScreenNotification,
      NSWindow.didResizeNotification,
    ]
    notificationTokens = names.map { name in
      NotificationCenter.default.addObserver(
        forName: name, object: window, queue: .main) { [weak self] _ in
          self?.notifyState()
        }
    }
  }

  private func removeWindowObservers() {
    for token in notificationTokens {
      NotificationCenter.default.removeObserver(token)
    }
    notificationTokens.removeAll()
  }

  private func notifyState() {
    guard let window = window else { return }
    let state = currentState(window)
    guard state != lastState else { return }
    lastState = state
    channel.invokeMethod("windowStateChanged", arguments: state)
  }

  private func currentState(_ window: NSWindow) -> String {
    if window.isMiniaturized { return "minimized" }
    if window.styleMask.contains(.fullScreen) { return "fullscreen" }
    if window.isZoomed { return "maximized" }
    return "normal"
  }

  private var buttonTypes: [NSWindow.ButtonType] {
    [.closeButton, .miniaturizeButton, .zoomButton]
  }

  private func invalidArguments(_ message: String) -> FlutterError {
    FlutterError(code: "invalid_arguments", message: message, details: nil)
  }

  private func windowUnavailable() -> FlutterError {
    FlutterError(
      code: "window_unavailable",
      message: "The Flutter view is not attached to a native window yet.",
      details: nil)
  }
}
