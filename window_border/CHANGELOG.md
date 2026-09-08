## 0.0.1

* Uses explicit native resize hits, cursors, and forwarding from the Flutter
  child to the top-level Windows sizing loop instead of HTTRANSPARENT.
  Adds a minimum 12dp top target and Chromium-style 16dp corner zones.

* Fixes resize hit testing over the Windows Flutter child view so the expanded
  top edge and corner targets reach the native host instead of Flutter content.
  The child subclass is removed when disabled or destroyed.

* Expands Windows edge and corner resize hit targets by 2 logical pixels,
  scaled with window DPI, without changing visible borders or content layout.
  Maximized, fullscreen, and non-resizable windows do not expose resize targets.

* Adds native frameless-window setup for Windows, Linux, and macOS.
* Fixes the Windows Flutter view geometry during maximize, restore, and DPI
  changes. A maximized view now fills the client area without reserving native
  border or rounded-corner space, while restoring reapplies the configured
  border inset.
* Extends the Windows example integration test to verify native state events
  and stable Flutter view sizes across maximize and restore transitions.
* Adds native border styling, moving, resizing, state, and system controls.
* Includes a custom-title-bar example.
* Prevents the Windows border brush from flashing over Flutter content while
  entering native move and resize loops.
* Prevents white flashes during live Windows resizing by synchronously laying
  out the Flutter child once and suppressing intermediate Win32 erases.
* Adds configurable rounded corners and compositor-backed external shadows.
* Uses a Chrome-style neutral dark border and a separate black native host
  background by default.
* Supports deriving a contrasting native border from a Flutter `themeColor`,
  with explicit `borderColor` overrides taking precedence.
* Synchronizes runtime border color changes with the Windows 11 DWM frame
  instead of updating only the hidden GDI backing pixels.
