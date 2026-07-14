## 0.0.1

* Adds native frameless-window setup for Windows, Linux, and macOS.
* Adds native border styling, moving, resizing, state, and system controls.
* Includes a custom-title-bar example.
* Prevents the Windows border brush from flashing over Flutter content while
  entering native move and resize loops.
* Prevents white flashes during live Windows resizing by synchronously laying
  out the Flutter child once and suppressing intermediate Win32 erases.
* Adds configurable rounded corners and compositor-backed external shadows.
* Uses a Chrome-style neutral dark border and a separate black native host
  background by default.
