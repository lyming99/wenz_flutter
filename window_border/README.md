# window_border

一个不需要修改 Flutter Runner 的桌面端原生无边框窗口插件。插件负责隐藏系统标题栏、用原生层绘制内容外框，并提供拖动、缩放、最小化、最大化、还原和关闭能力。

## 平台实现

| 平台 | 原生实现 | 当前能力 |
| --- | --- | --- |
| Windows | C++ / Win32 | 自定义非客户区、圆角 GDI 边框、DWM 外部阴影、DPI 缩放、八方向缩放命中测试、窗口状态事件 |
| Linux | C++ / GTK3 | 移除窗口装饰、GTK 圆角/阴影样式、拖动及显式缩放、系统窗口控制 |
| macOS | Swift / AppKit | 全尺寸内容视图、CALayer 圆角边框、AppKit 窗口阴影、原生拖动与系统窗口控制 |

Windows 是当前的主实现和验证平台。Linux 的窗口行为可能受 Wayland/X11 及窗口管理器影响；macOS 的边缘缩放由 `NSWindow` 自身处理。

## 使用

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:window_border/window_border.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    unawaited(WindowBorder.instance.initialize(
      style: const WindowBorderStyle(
        borderWidth: 2,
        cornerRadius: 14,
        shadowEnabled: true,
        resizeBorderWidth: 8,
        resizable: true,
      ),
    ));
  }

  // ...
}
```

在自定义标题栏中放置可拖动区域：

```dart
Row(
  children: [
    const Expanded(
      child: WindowDragArea(
        child: SizedBox(height: 44, child: Text('My application')),
      ),
    ),
    IconButton(
      onPressed: WindowBorder.instance.minimize,
      icon: const Icon(Icons.remove),
    ),
    IconButton(
      onPressed: WindowBorder.instance.toggleMaximize,
      icon: const Icon(Icons.crop_square),
    ),
    IconButton(
      onPressed: WindowBorder.instance.close,
      icon: const Icon(Icons.close),
    ),
  ],
)
```

`WindowDragArea` 支持拖动和双击最大化。交互按钮应放在它的外部。窗口状态可通过 `stateChanges` 监听，也可使用 `getState()` 主动读取。

`cornerRadius` 在 Windows 11 上会映射到 DWM 的“小圆角/标准圆角”偏好，系统不提供任意半径；Windows 10 使用窗口区域模拟指定半径。`shadowEnabled` 使用系统合成器绘制窗口外部阴影，Windows 10、Wayland/X11 上的最终效果可能受桌面合成器影响。最大化时圆角会自动取消。

Windows 默认边框色 `#3C4043` 和原生宿主底色 `#000000` 定义在 `windows/window_border_plugin.cpp`，并由 C++/GDI 绘制。`borderColor` 与 `backgroundColor` 仅作为可选的原生颜色覆盖；省略时不会从 Dart 发送颜色。Flutter 页面是独立渲染表面，其内容背景仍应在 `Scaffold` 或根 Widget 中设置；示例已使用纯黑背景。

完整示例见 [`example/lib/main.dart`](example/lib/main.dart)。

## Windows 原理

插件通过 `PluginRegistrarWindows` 注册顶层窗口消息委托，在启用时移除 `WS_CAPTION`，接管 `WM_NCCALCSIZE`、`WM_NCHITTEST` 与 `WM_SIZE`。Flutter 子窗口会按配置的边框宽度同步向内布局，每次尺寸变化只调整一次渲染表面，并禁止 Win32 在新 Flutter 帧提交前擦除子窗口背景。外层 HWND 使用 GDI 填充边框及原生宿主背景，因此边框并不是 Flutter Widget。禁用插件时会恢复原始窗口样式和内容布局。
