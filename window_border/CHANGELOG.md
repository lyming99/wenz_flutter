## 0.0.1

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
