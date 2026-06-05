# wenz_draw

跨平台 Flutter 高性能无限画布绘图 SDK。

## 功能特性

- 🎨 **无限画布** — 无限平移/缩放，自适应网格背景
- ✏️ **多元素绘制** — 路径、直线、矩形、椭圆、箭头、文本
- 🖌️ **9 种内置工具** — 画笔、荧光笔、直线、箭头、矩形、椭圆、文本、橡皮擦、选择
- 📋 **图层管理** — 多图层、可见性、锁定、排序
- ↩️ **撤销/重做** — Command 模式，支持批量操作
- 🗺️ **小地图** — 全局缩略图 + 视口导航
- 💾 **序列化** — JSON 导入/导出
- 📤 **导出** — PNG、SVG 格式导出
- ⚡ **高性能** — 四叉树空间索引、视口裁剪、路径简化
- 🎯 **选择编辑** — 点选、框选、移动、删除
- ⌨️ **快捷键** — Ctrl+Z/Y、Delete、Ctrl+A、Escape

## 快速开始

### 1. 安装

```yaml
dependencies:
  wenz_draw:
    path: ../wenz_draw  # 或发布到 pub.dev
```

### 2. 基本使用

```dart
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  // 注册内置元素渲染器（只需调用一次）
  WenzDraw.registerBuiltinRenderers();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final _controller = InfiniteCanvasController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: InfiniteCanvasWidget(
        controller: _controller,
        config: const InfiniteCanvasConfig(
          showGrid: true,
          gridType: GridType.dots,
          backgroundColor: Color(0xFFFFFFFF),
        ),
      ),
    );
  }
}
```

### 3. 注册工具

```dart
final canvasCtrl = _controller.canvasController;

// 注册内置工具
canvasCtrl.toolManager.registerTool(
  PenTool(getBrushSettings: () => canvasCtrl.brushSettings),
);
canvasCtrl.toolManager.registerTool(
  RectTool(getBrushSettings: () => canvasCtrl.brushSettings),
);
// ... 其他工具

canvasCtrl.setTool('pen');
```

### 4. 编程式操作

```dart
// 添加元素
canvasCtrl.addElement(PathElement.create(
  points: [PathPoint(position: Offset(0, 0)), PathPoint(position: Offset(100, 100))],
  style: const PaintStyle(),
));

// 视图控制
_controller.zoomIn();
_controller.resetView();
_controller.pan(Offset(50, 0));

// 撤销/重做
canvasCtrl.undo();
canvasCtrl.redo();

// 导出
final json = canvasCtrl.toJson();
final svg = SvgExporter.exportToSvg(elements: canvasCtrl.elements, contentBounds: bounds);
```

## 架构

```
┌─────────────────────────────────────┐
│         Widget Layer (API)          │
│  InfiniteCanvasWidget / Config      │
├─────────────────────────────────────┤
│        Controller Layer             │
│  InfiniteCanvasController (视图)    │
│  CanvasController (核心)            │
│  ├─ ElementManager                  │
│  ├─ SelectionManager                │
│  ├─ HistoryManager                  │
│  ├─ ToolManager                     │
│  └─ LayerManager                    │
├─────────────────────────────────────┤
│          Tool Layer                 │
│  PenTool / LineTool / RectTool ...  │
├─────────────────────────────────────┤
│      Rendering Pipeline             │
│  GridRenderer + ElementRenderers    │
│  SelectionRenderer + ViewportCull   │
├─────────────────────────────────────┤
│        Gesture System               │
│  GestureResolver + CanvasGesture    │
├─────────────────────────────────────┤
│       Serialization Layer           │
│  JsonSerializer / PngExporter / SVG │
└─────────────────────────────────────┘
```

## 内置元素

| 类型 | 类名 | 说明 |
|:---|:---|:---|
| 路径 | `PathElement` | 自由绘制，支持压感 |
| 直线 | `LineElement` | 两点连线 |
| 矩形 | `RectElement` | 支持圆角、填充 |
| 椭圆 | `EllipseElement` | 支持填充 |
| 箭头 | `ArrowElement` | 带箭头头部 |
| 文本 | `TextElement` | 可配置字号、颜色、加粗 |

## 内置工具

| 工具 | 类名 | ID |
|:---|:---|:---|
| 选择 | `SelectTool` | `select` |
| 画笔 | `PenTool` | `pen` |
| 荧光笔 | `HighlighterTool` | `highlighter` |
| 直线 | `LineTool` | `line` |
| 箭头 | `ArrowTool` | `arrow` |
| 矩形 | `RectTool` | `rect` |
| 椭圆 | `EllipseTool` | `ellipse` |
| 文本 | `TextTool` | `text` |
| 橡皮擦 | `EraserTool` | `eraser` |

## 快捷键

| 快捷键 | 功能 |
|:---|:---|
| `Ctrl+Z` | 撤销 |
| `Ctrl+Y` | 重做 |
| `Delete` | 删除选中 |
| `Ctrl+A` | 全选 |
| `Escape` | 取消选择 |
| `空格+拖拽` | 临时平移 |
| `滚轮` | 缩放 |
| `双指` | 缩放+平移 |

## 自定义扩展

### 自定义元素

```dart
class MyElement extends CanvasElement {
  // 实现抽象方法: id, type, bounds, hitTest, toJson, copyWith, translate, scaleElement
}

class MyElementRenderer extends ElementRenderer<MyElement> {
  @override
  void render(Canvas canvas, MyElement element) { /* ... */ }

  @override
  bool hitTest(MyElement element, Offset worldPoint, double tolerance) { /* ... */ }
}

// 注册
ElementRendererRegistry.register<MyElement>('my_element', MyElementRenderer());
```

### 自定义工具

```dart
class MyTool extends CanvasTool {
  @override
  String get id => 'my_tool';

  @override
  ToolResult handleEvent(CanvasEvent event) {
    // 处理事件，返回 ToolResult
  }
}

// 注册
canvasCtrl.toolManager.registerTool(MyTool());
canvasCtrl.setTool('my_tool');
```

## 技术依赖

| 依赖 | 用途 |
|:---|:---|
| `flutter` | 核心框架 |
| `uuid ^4.0.0` | 元素/图层唯一标识 |

## License

MIT
