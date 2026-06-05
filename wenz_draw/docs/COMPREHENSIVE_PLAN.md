# wenz_draw 无限画布综合开发方案

> 基于 3 份独立方案的深度整合，结合项目现状（空目录骨架 + 已有设计文档）制定

---

## 一、方案定位与目标

**项目定位**：跨平台 Flutter 高性能无限画布绘图 SDK（Android / iOS / Windows / Web）

**核心目标**：
- 提供类 Excalidraw 风格的无限画布体验
- 支持无限平移/缩放、多元素绘制、图层管理、撤销重做
- 插件化工具系统，可扩展自定义绘制工具
- 保持最小依赖原则，核心基于 Flutter SDK 原生能力

**技术基线**：
- Flutter SDK >= 3.3.0 | Dart SDK ^3.8.0
- 渲染方案：CustomPainter + Canvas 2D（不依赖第三方画布库）
- 状态管理：ChangeNotifier（作为底层库保持最小依赖）

---

## 二、三方案对比与取舍

| 维度 | 方案1（架构型） | 方案2（Excalidraw型） | 方案3（工程型） | **综合方案取舍** |
|:---|:---|:---|:---|:---|
| 坐标系统 | 二层（Screen↔Canvas） | 三层（Screen↔Canvas↔World） | 二层（Screen↔World） | **采用三层坐标系**，概念更清晰 |
| 元素模型 | 不可变 + copyWith + 独立渲染器注册 | 简单抽象 + draw() 方法 | 抽象基类 + 含变换矩阵 | **不可变元素 + 独立渲染器注册**，扩展性最优 |
| 历史记录 | Command 模式（精细） | 快照模式（简单） | Command 模式（含批量命令） | **Command 模式 + BatchCommand**，兼顾精细和批量 |
| 工具系统 | 策略模式 + ToolResult sealed class | DrawTool 枚举 + 简单接口 | 策略模式 + PointerEvent 回调 | **策略模式 + sealed ToolResult + PointerEvent**，最灵活 |
| 图层系统 | LayerManager + zIndex | 无独立图层 | LayerManager + 离屏缓存 | **完整图层系统 + 离屏缓存** |
| 空间索引 | 未提及 | 可选（R-Tree） | 四叉树（推荐） | **四叉树**，动态元素场景表现好 |
| 手势系统 | 优先级分层 + 手势竞技场 | 状态机 + 模式矩阵 | 层次分发 + GestureResolver | **层次分发 + GestureResolver + 状态机** |
| 性能优化 | 7 项策略（视口裁剪、图层缓存等） | 7 项策略（含 LOD、空间索引） | 5 项策略（含帧率控制） | **全部采纳，按优先级分阶段实施** |
| 已有代码兼容 | 未考虑 | 未考虑 | 考虑了已有代码问题 | **修正已知 Bug，兼容已有接口** |

---

## 三、整体架构设计

### 3.1 分层架构

```
┌─────────────────────────────────────────────────────────┐
│                   Widget Layer (API)                     │
│    InfiniteCanvasWidget / InfiniteCanvasConfig           │
├─────────────────────────────────────────────────────────┤
│                 Controller Layer                         │
│  ┌────────────────────────────────────────────────────┐ │
│  │           InfiniteCanvasController                 │ │
│  │    (视图变换: pan/zoom/rotate + 坐标转换)          │ │
│  └──────────────────────┬─────────────────────────────┘ │
│                         │ 委托                           │
│  ┌──────────────────────▼─────────────────────────────┐ │
│  │             CanvasController                        │ │
│  │    (核心画布逻辑: 元素/图层/选择/历史/工具协调)     │ │
│  ├──────────┬──────────┬──────────┬───────────────────┤ │
│  │ Element  │  Layer   │ Selection│   History         │ │
│  │ Manager  │  Manager │  Manager │   Manager         │ │
│  └──────────┴──────────┴──────────┴───────────────────┘ │
├─────────────────────────────────────────────────────────┤
│                  Tool Layer                              │
│    ToolManager → CanvasTool (策略模式)                    │
│    PenTool / LineTool / RectTool / EllipseTool / ...    │
├─────────────────────────────────────────────────────────┤
│                Rendering Pipeline                        │
│  ┌──────────┬──────────┬──────────┬───────────────────┐ │
│  │ Spatial  │ Viewport │ Element  │  Background       │ │
│  │ Index    │ Culling  │ Renderer │  Painter          │ │
│  │ (QuadTree)│         │ Registry │  (Grid/Dots)      │ │
│  └──────────┴──────────┴──────────┴───────────────────┘ │
├─────────────────────────────────────────────────────────┤
│                 Gesture System                           │
│  ┌──────────┬──────────┬──────────┬───────────────────┐ │
│  │ Gesture  │ Pan/Zoom │ Tool     │  Keyboard         │ │
│  │ Resolver │ Handler  │ Dispatch │  Shortcuts        │ │
│  └──────────┴──────────┴──────────┴───────────────────┘ │
├─────────────────────────────────────────────────────────┤
│              Serialization Layer                         │
│    JsonSerializer / PngExporter / SvgExporter            │
└─────────────────────────────────────────────────────────┘
```

### 3.2 设计原则

| 原则 | 说明 |
|:---|:---|
| **不可变数据** | 所有元素（CanvasElement）为不可变对象，通过 copyWith 修改 |
| **单一数据源** | CanvasState 作为唯一状态源，通过 Controller 驱动变更 |
| **单向数据流** | 手势 → Controller → State → Render，禁止反向依赖 |
| **策略模式工具** | Tool 采用策略模式，可扩展自定义绘制工具 |
| **命令模式历史** | 所有修改操作封装为 Command，支持精确撤销/重做 |
| **增量渲染** | 仅重绘视口内可见元素（视口裁剪 + 四叉树空间索引） |
| **最小依赖** | 核心功能基于 Flutter SDK，仅 uuid 作为必要外部依赖 |

---

## 四、坐标系统

### 4.1 三层坐标系

```
屏幕坐标 (Screen)  ← 手势输入、UI 叠加层
    │
    │  screenPoint = worldPoint * scale + offset
    │  worldPoint  = (screenPoint - offset) / scale
    ▼
世界坐标 (World)   ← 元素存储、数据序列化、命中测试
    │
    │  (元素局部变换矩阵)
    ▼
局部坐标 (Local)   ← 元素内部绘制（旋转/缩放后的坐标系）
```

### 4.2 CanvasTransform

```dart
/// 不可变的 2D 仿射变换（平移 + 缩放）
class CanvasTransform {
  final double scale;     // 缩放比例，默认 1.0，范围 0.1 ~ 10.0
  final Offset offset;    // 画布原点在屏幕上的位置

  const CanvasTransform({this.scale = 1.0, this.offset = Offset.zero});
  static const identity = CanvasTransform();

  // 坐标转换
  Offset screenToWorld(Offset screenPoint) =>
    (screenPoint - offset) / scale;
  Offset worldToScreen(Offset worldPoint) =>
    worldPoint * scale + offset;

  // 视口在世界坐标系中的矩形
  Rect visibleWorldRect(Size viewportSize) => Rect.fromLTWH(
    -offset.dx / scale,
    -offset.dy / scale,
    viewportSize.width / scale,
    viewportSize.height / scale,
  );

  // 变换操作（返回新实例）
  CanvasTransform pan(Offset delta) => copyWith(offset: offset + delta);
  CanvasTransform zoomTo(double newScale, Offset focalPoint);
  CanvasTransform reset() => const CanvasTransform();

  Matrix4 toMatrix4() => Matrix4.identity()
    ..translate(offset.dx, offset.dy)
    ..scale(scale);
}
```

### 4.3 以焦点为中心的缩放算法

```dart
CanvasTransform zoomTo(double newScale, Offset focalPoint) {
  newScale = newScale.clamp(0.1, 10.0);
  // 缩放前焦点对应的世界坐标
  final worldPoint = screenToWorld(focalPoint);
  // 缩放后保持该世界坐标点仍在屏幕同一位置
  final newOffset = Offset(
    focalPoint.dx - worldPoint.dx * newScale,
    focalPoint.dy - worldPoint.dy * newScale,
  );
  return CanvasTransform(scale: newScale, offset: newOffset);
}
```

---

## 五、核心模块详细设计

### 5.1 元素系统 (elements/)

#### 5.1.1 元素基类（不可变）

```dart
/// 画布元素基类 — 不可变对象
abstract class CanvasElement {
  String get id;                    // UUID
  String get type;                  // 元素类型标识
  String get layerId;               // 所属图层 ID
  Rect get bounds;                  // 世界坐标系下的包围盒
  bool get visible;                 // 可见性
  double get opacity;               // 透明度 0.0~1.0
  int get zIndex;                   // 层级排序

  /// 命中测试（世界坐标）
  bool hitTest(Offset worldPoint, {double tolerance = 5.0});

  /// 序列化
  Map<String, dynamic> toJson();

  /// 创建副本
  CanvasElement copyWith({...});

  /// 变换（返回新实例）
  CanvasElement translate(Offset delta);
  CanvasElement scaleElement(double factor, {Offset? pivot});
}
```

#### 5.1.2 内置元素类型

| 类型 | 类名 | 核心属性 |
|:---|:---|:---|
| 自由路径 | PathElement | List\<PathPoint\> points, PaintStyle style |
| 直线 | LineElement | Offset start, end, PaintStyle style |
| 矩形 | RectElement | Rect rect, double borderRadius, PaintStyle stroke, PaintStyle? fill |
| 椭圆 | EllipseElement | Rect rect, PaintStyle stroke, PaintStyle? fill |
| 箭头 | ArrowElement | Offset start, end, ArrowHeadStyle headStyle, PaintStyle style |
| 文本 | TextElement | Offset position, String text, TextStyle style |
| 图片 | ImageElement | Rect rect, ImageProvider image, BoxFit fit |

#### 5.1.3 PathPoint（支持压感）

```dart
class PathPoint {
  final Offset position;      // 世界坐标
  final double pressure;      // 压感 0.0~1.0
  final double timestamp;     // 时间戳（毫秒）

  const PathPoint({
    required this.position,
    this.pressure = 0.5,
    this.timestamp = 0,
  });
}
```

#### 5.1.4 元素渲染器注册

```dart
/// 每种元素类型对应一个渲染器（分离绘制逻辑与数据模型）
abstract class ElementRenderer<T extends CanvasElement> {
  void render(Canvas canvas, T element);
  bool hitTest(T element, Offset worldPoint, double tolerance);
}

class ElementRendererRegistry {
  static final _renderers = <String, ElementRenderer>{};

  static void register<T extends CanvasElement>(
    String type, ElementRenderer<T> renderer
  );
  static ElementRenderer? getRenderer(String type);
}
```

### 5.2 工具系统 (tools/)

#### 5.2.1 工具接口（策略模式）

```dart
/// 绘制工具抽象
abstract class CanvasTool {
  String get id;
  String get name;
  IconData get icon;

  /// 工具激活/停用
  void onActivate(CanvasController controller) {}
  void onDeactivate(CanvasController controller) {}

  /// 处理指针事件
  ToolResult handleEvent(CanvasEvent event, CanvasController controller);

  /// 绘制实时预览（拖拽中的临时形状）
  void paintPreview(Canvas canvas, Size size, CanvasTransform transform) {}
}

/// 工具处理结果（sealed class）
sealed class ToolResult {
  const ToolResult();
}
class ToolResultNone extends ToolResult {}          // 无操作
class ToolResultElement extends ToolResult {         // 产生新元素
  final CanvasElement element;
}
class ToolResultPreview extends ToolResult {         // 实时预览
  final CanvasElement preview;
}
class ToolResultConsumed extends ToolResult {}       // 事件已消费
class ToolResultSelect extends ToolResult {          // 选择操作
  final Set<String> selectedIds;
}
```

#### 5.2.2 画布事件

```dart
sealed class CanvasEvent {
  final Offset screenPoint;
  final Offset worldPoint;
  final CanvasTransform transform;
  final int pointerCount;          // 当前指针数量
}

class CanvasPointerDownEvent extends CanvasEvent { ... }
class CanvasPointerMoveEvent extends CanvasEvent { ... }
class CanvasPointerUpEvent extends CanvasEvent { ... }
class CanvasDoubleTapEvent extends CanvasEvent { ... }
class CanvasLongPressEvent extends CanvasEvent { ... }
class CanvasScrollEvent extends CanvasEvent {
  final Offset scrollDelta;        // 滚轮偏移
}
class CanvasKeyEvent extends CanvasEvent {
  final LogicalKeyboardKey key;
  final bool isKeyDown;
}
```

#### 5.2.3 内置工具

| 工具 | 类名 | 说明 |
|:---|:---|:---|
| 选择 | SelectTool | 点选/框选/移动/缩放元素 |
| 画笔 | PenTool | 自由绘制路径（支持压感） |
| 直线 | LineTool | 拖拽绘制直线 |
| 矩形 | RectTool | 拖拽绘制矩形 |
| 椭圆 | EllipseTool | 拖拽绘制椭圆 |
| 箭头 | ArrowTool | 拖拽绘制箭头 |
| 文本 | TextTool | 点击输入文本 |
| 橡皮擦 | EraserTool | 擦除经过的元素 |
| 荧光笔 | HighlighterTool | 半透明宽笔触 |
| 平移 | PanTool | 专用平移模式 |

#### 5.2.4 ToolManager

```dart
class ToolManager extends ChangeNotifier {
  final Map<String, CanvasTool> _tools = {};
  CanvasTool? _activeTool;
  BrushSettings _brushSettings = const BrushSettings();

  void registerTool(CanvasTool tool);
  void setActiveTool(String toolId);
  CanvasTool? get activeTool;
  List<CanvasTool> get tools;

  /// 将事件分发到当前活跃工具
  ToolResult dispatch(CanvasEvent event, CanvasController controller);

  BrushSettings get brushSettings;
  void updateBrushSettings(BrushSettings settings);
}
```

### 5.3 历史记录系统 (history/)

#### 5.3.1 Command 模式

```dart
/// 可撤销的操作命令
abstract class CanvasCommand {
  void execute(CanvasState state);
  void undo(CanvasState state);
  String get description;    // 操作描述（用于 UI 显示）
}

// 具体命令
class AddElementCommand extends CanvasCommand { ... }
class RemoveElementCommand extends CanvasCommand { ... }
class MoveElementCommand extends CanvasCommand { ... }
class TransformElementCommand extends CanvasCommand { ... }
class StyleChangeCommand extends CanvasCommand { ... }
class ReorderLayerCommand extends CanvasCommand { ... }
class BatchCommand extends CanvasCommand {       // 批量操作（框选删除等）
  final List<CanvasCommand> commands;
}
```

#### 5.3.2 HistoryManager

```dart
class HistoryManager {
  final List<CanvasCommand> _undoStack = [];
  final List<CanvasCommand> _redoStack = [];
  final int maxHistory = 100;

  void execute(CanvasCommand command, CanvasState state);
  void undo(CanvasState state);
  void redo(CanvasState state);
  bool get canUndo;
  bool get canRedo;
  void clear();
}
```

### 5.4 图层系统 (layers/)

```dart
class CanvasLayer {
  final String id;
  final String name;
  final bool isVisible;
  final bool isLocked;
  final double opacity;       // 0.0 ~ 1.0
  final BlendMode blendMode;
  final List<String> elementIds;   // 该图层包含的元素 ID

  CanvasLayer copyWith({...});

  // 离屏缓存（性能优化用）
  ui.Image? _cachedImage;
  bool _isDirty = true;
  void markDirty() { _isDirty = true; }
}

class LayerManager extends ChangeNotifier {
  final List<CanvasLayer> _layers = [];
  String? _activeLayerId;

  void addLayer({String? name});
  void removeLayer(String id);
  void setActiveLayer(String id);
  void toggleVisibility(String id);
  void toggleLock(String id);
  void setOpacity(String id, double opacity);
  void reorder(int oldIndex, int newIndex);
  void mergeDown(String id);

  List<CanvasLayer> get layers;
  CanvasLayer? get activeLayer;
  List<CanvasLayer> get visibleLayers;
}
```

### 5.5 选择系统 (selection/)

```dart
class SelectionManager extends ChangeNotifier {
  final Set<String> _selectedIds = {};

  void select(String id, {bool addToSelection = false});
  void selectInRect(Rect worldRect, List<CanvasElement> elements);
  void selectAll(List<CanvasElement> elements);
  void deselectAll();
  void removeFromSelection(String id);

  Set<String> get selectedIds;
  bool isSelected(String id);
  List<CanvasElement> getSelectedElements(List<CanvasElement> all);
}
```

### 5.6 CanvasController（核心画布控制器）

```dart
class CanvasController extends ChangeNotifier {
  final ElementManager _elementManager;
  final LayerManager _layerManager;
  final SelectionManager _selectionManager;
  final HistoryManager _historyManager;
  final ToolManager _toolManager;

  // 元素 CRUD
  void addElement(CanvasElement element);
  void removeElement(String id);
  void updateElement(String id, CanvasElement element);
  List<CanvasElement> get elements;

  // 选择
  void select(String? id, {bool addToSelection = false});
  void selectInRect(Rect worldRect);
  void deselectAll();
  List<CanvasElement> get selectedElements;

  // 撤销/重做
  void undo();
  void redo();
  bool get canUndo;
  bool get canRedo;

  // 工具
  void setTool(String toolId);
  CanvasTool? get currentTool;

  // 序列化
  Map<String, dynamic> toJson();
  void fromJson(Map<String, dynamic> json);
}
```

### 5.7 InfiniteCanvasController（视图变换控制器）

```dart
class InfiniteCanvasController extends ChangeNotifier {
  final CanvasController canvasController;

  // 视图变换状态
  CanvasTransform _transform = CanvasTransform.identity;
  Size? _viewportSize;    // 由 Widget 层注入

  // 缩放限制
  static const minScale = 0.1;
  static const maxScale = 10.0;

  // 变换操作
  void pan(Offset delta);
  void zoomTo(double newScale, {Offset? focalPoint});
  void zoomIn();
  void zoomOut();
  void resetView();
  void zoomToFit(Rect contentBounds);

  // 坐标转换
  Offset screenToWorld(Offset screenPoint);
  Offset worldToScreen(Offset worldPoint);
  Rect get visibleWorldRect;

  // 惯性滚动
  void startFling(Offset velocity);
  void cancelFling();
}
```

---

## 六、手势系统

### 6.1 手势层次分发

```
Level 0: 系统手势（返回等）— Flutter 自动处理
Level 1: 画布级手势（始终优先响应）
  ├── 双指缩放/平移 (ScaleGestureRecognizer)
  ├── Ctrl + 鼠标滚轮缩放
  └── 空格 + 拖拽 → 临时平移
Level 2: 工具级手势
  └── 当前活跃工具的指针事件
Level 3: 回退
  └── 单指拖拽（无工具消费时）→ 画布平移
```

### 6.2 GestureResolver

```dart
class GestureResolver {
  bool _isSpacePressed = false;
  Set<int> _activePointers = {};

  GestureType resolve(PointerEvent event) {
    // 滚轮 → 缩放
    if (event is PointerScrollEvent) return GestureType.wheelZoom;
    // 双指 → 缩放+平移
    if (_activePointers.length >= 2) return GestureType.pinchZoomPan;
    // 空格+拖拽 → 临时平移
    if (_isSpacePressed) return GestureType.temporaryPan;
    // 交给当前工具
    return GestureType.tool;
  }
}

enum GestureType {
  wheelZoom,
  pinchZoomPan,
  temporaryPan,
  tool,
}
```

### 6.3 手势状态机

```
                 ┌──────────┐
    ┌───────────►│   IDLE   │◄────────────┐
    │            └────┬─────┘             │
    │                 │                   │
    │    ┌────────────┼────────────┐      │
    │    │            │            │      │
    │ 1 finger    2 fingers   longPress  │
    │ (tool)      (canvas)     (context) │
    │    │            │            │      │
    │    ▼            ▼            ▼      │
    │ ┌───────┐  ┌────────┐  ┌───────┐   │
    │ │TOOLING│  │ZOOMING/│  │CONTEXT│   │
    │ │       │  │PANNING │  │       │   │
    │ └───┬───┘  └───┬────┘  └───┬───┘   │
    │     │          │           │       │
    └─────┴──────────┴───────────┘───────┘
          手势结束 / 手指抬起
```

---

## 七、渲染管线

### 7.1 分层渲染（从底到顶）

```
Layer 1: BackgroundLayer  → 背景色 + 无限网格/点阵
Layer 2: ElementLayer     → 已确认的绘图元素（视锥剔除 + 四叉树查询）
Layer 3: PreviewLayer     → 正在绘制的预览元素
Layer 4: SelectionLayer   → 选中框 + 变换控制手柄
Layer 5: OverlayLayer     → 小地图、缩放指示器等 UI 叠加（不参与变换）
```

### 7.2 核心 Paint 方法

```dart
@override
void paint(Canvas canvas, Size size) {
  // 1. 清背景
  canvas.drawColor(backgroundColor, BlendMode.srcOver);

  // 2. 绘制网格（使用世界坐标计算可见网格）
  _drawGrid(canvas, size);

  // 3. 应用视图变换
  canvas.save();
  canvas.translate(transform.offset.dx, transform.offset.dy);
  canvas.scale(transform.scale);

  // 4. 遍历可见图层
  for (final layer in visibleLayers) {
    if (!layer.isVisible) continue;

    // 4a. 图层缓存检查
    if (!layer._isDirty && layer._cachedImage != null) {
      canvas.drawImage(layer._cachedImage!, Offset.zero, Paint());
      continue;
    }

    // 4b. 视锥剔除 + 四叉树查询
    final visibleRect = transform.visibleWorldRect(size);
    final visibleElements = spatialIndex.query(visibleRect);

    // 4c. 按 zIndex 排序渲染
    for (final element in visibleElements.sorted((a,b) => a.zIndex - b.zIndex)) {
      final renderer = ElementRendererRegistry.getRenderer(element.type);
      renderer?.render(canvas, element);
    }
  }

  // 5. 绘制工具预览
  currentTool?.paintPreview(canvas, size, transform);

  // 6. 绘制选中装饰
  _drawSelectionDecorations(canvas);

  canvas.restore();

  // 7. UI 叠加层（不参与变换）
  _drawOverlayIndicators(canvas, size);
}
```

### 7.3 自适应网格

```dart
double _getGridSize(double scale) {
  const base = 50.0;
  if (scale < 0.25) return base * 8;
  if (scale < 0.5)  return base * 4;
  if (scale < 1.0)  return base * 2;
  if (scale < 2.0)  return base;
  if (scale < 4.0)  return base / 2;
  return base / 4;
}
```

---

## 八、性能优化策略

| 策略 | 说明 | 优先级 | 对应阶段 |
|:---|:---|:---|:---|
| **视口裁剪** | 只绘制 visibleWorldRect 内的元素 | 🔴 必须 | Phase 1 |
| **脏标记重绘** | shouldRepaint 仅在状态变化时返回 true | 🔴 必须 | Phase 1 |
| **四叉树空间索引** | 元素 >200 时引入，加速视锥查询 O(log n) | 🔴 必须 | Phase 4 |
| **图层离屏缓存** | 不可变图层用 PictureRecorder 缓存为 Picture | 🟡 推荐 | Phase 3 |
| **路径简化** | RDP 算法实时简化，1000 点 → 100-200 点 | 🟡 推荐 | Phase 2 |
| **指针事件节流** | 高速绘制时 throttle 到 16ms | 🟡 推荐 | Phase 4 |
| **LOD 分级** | 极小缩放时简化渲染（色块替代细节） | 🟢 可选 | Phase 5 |
| **延迟提交** | 拖拽中只更新 previewElement，松手后提交 | 🔴 必须 | Phase 2 |
| **异步图片解码** | instantiateImageCodec 不阻塞主线程 | 🟢 可选 | Phase 5 |
| **分帧渲染** | 大量元素分批绘制避免掉帧 | 🟢 可选 | Phase 5 |

---

## 九、序列化与持久化

### 9.1 JSON 数据格式

```json
{
  "version": "1.0",
  "canvas": {
    "backgroundColor": "#FFFFFF",
    "transform": { "scale": 1.0, "offset": { "dx": 0, "dy": 0 } }
  },
  "layers": [
    {
      "id": "layer_1",
      "name": "图层 1",
      "visible": true,
      "locked": false,
      "opacity": 1.0,
      "elements": [
        {
          "id": "elem_1",
          "type": "path",
          "points": [{"x":100,"y":200,"pressure":0.5}],
          "style": {"color":"#000000","strokeWidth":2.0}
        }
      ]
    }
  ]
}
```

### 9.2 导出能力

| 格式 | 说明 | 阶段 |
|:---|:---|:---|
| JSON | 画布数据序列化/反序列化 | Phase 5 |
| PNG | 导出为图片 | Phase 6 |
| SVG | 导出为矢量图 | Phase 6 |

---

## 十、文件目录结构

```
lib/
├── wenz_draw.dart                              # 库入口，导出公共 API
├── wenz_draw_method_channel.dart               # 已有 - 平台通道
├── wenz_draw_platform_interface.dart           # 已有 - 平台接口
├── wenz_draw_web.dart                          # 已有 - Web 平台
├── src/
│   ├── infinite_canvas/
│   │   ├── infinite_canvas_widget.dart         # InfiniteCanvasWidget (StatefulWidget)
│   │   ├── infinite_canvas_controller.dart     # 视图变换控制器
│   │   ├── infinite_canvas_config.dart         # 配置项（网格类型、背景色等）
│   │   ├── infinite_canvas_painter.dart        # CustomPainter 主渲染器
│   │   ├── canvas_transform.dart               # 不可变变换数据结构
│   │   ├── canvas_event.dart                   # 事件定义 (sealed class)
│   │   └── minimap_widget.dart                 # 小地图 Widget
│   │
│   ├── canvas/
│   │   ├── canvas_controller.dart              # 核心画布控制器
│   │   ├── canvas_state.dart                   # 画布全局状态（不可变）
│   │   ├── element_manager.dart                # 元素 CRUD 管理
│   │   ├── selection_manager.dart              # 选择管理器
│   │   ├── paint_style.dart                    # 画笔样式模型
│   │   └── spatial_index.dart                  # 四叉树空间索引
│   │
│   ├── elements/
│   │   ├── canvas_element.dart                 # 元素抽象基类
│   │   ├── path_element.dart                   # 自由路径
│   │   ├── line_element.dart                   # 直线
│   │   ├── rect_element.dart                   # 矩形
│   │   ├── ellipse_element.dart                # 椭圆
│   │   ├── arrow_element.dart                  # 箭头
│   │   ├── text_element.dart                   # 文本
│   │   ├── image_element.dart                  # 图片
│   │   ├── element_renderer.dart               # 渲染器接口
│   │   └── element_registry.dart               # 渲染器注册中心
│   │
│   ├── tools/
│   │   ├── canvas_tool.dart                    # 工具接口 & ToolResult
│   │   ├── tool_manager.dart                   # 工具管理器
│   │   ├── brush_settings.dart                 # 画笔配置
│   │   ├── select_tool.dart                    # 选择工具
│   │   ├── pen_tool.dart                       # 画笔工具
│   │   ├── highlighter_tool.dart               # 荧光笔工具
│   │   ├── line_tool.dart                      # 直线工具
│   │   ├── rect_tool.dart                      # 矩形工具
│   │   ├── ellipse_tool.dart                   # 椭圆工具
│   │   ├── arrow_tool.dart                     # 箭头工具
│   │   ├── text_tool.dart                      # 文本工具
│   │   ├── eraser_tool.dart                    # 橡皮擦
│   │   └── pan_tool.dart                       # 平移工具
│   │
│   ├── history/
│   │   ├── canvas_command.dart                 # 命令接口
│   │   ├── history_manager.dart                # 历史管理器
│   │   └── commands/
│   │       ├── add_element_command.dart
│   │       ├── remove_element_command.dart
│   │       ├── move_element_command.dart
│   │       ├── transform_command.dart
│   │       ├── style_change_command.dart
│   │       └── batch_command.dart
│   │
│   ├── layers/
│   │   ├── canvas_layer.dart                   # 图层模型
│   │   └── layer_manager.dart                  # 图层管理器
│   │
│   ├── rendering/
│   │   ├── grid_renderer.dart                  # 网格渲染（自适应密度）
│   │   ├── selection_renderer.dart             # 选中框 + 控制手柄
│   │   └── viewport_culling.dart               # 视锥剔除
│   │
│   ├── gestures/
│   │   ├── gesture_resolver.dart               # 手势冲突解决
│   │   ├── canvas_gesture_handler.dart         # 统一手势处理
│   │   └── inertia_scroll.dart                 # 惯性滚动
│   │
│   ├── serialization/
│   │   ├── canvas_serializer.dart              # JSON 序列化/反序列化
│   │   └── exporters/
│   │       ├── png_exporter.dart               # PNG 导出
│   │       └── svg_exporter.dart               # SVG 导出
│   │
│   └── utils/
│       ├── path_simplifier.dart                # RDP 路径简化算法
│       ├── quad_tree.dart                      # 四叉树数据结构
│       ├── math_utils.dart                     # 数学工具函数
│       └── uuid_generator.dart                 # UUID 生成
│
example/
├── lib/
│   └── main.dart                               # 示例 App
```

---

## 十一、公共 API 设计

```dart
// lib/wenz_draw.dart
library wenz_draw;

// === 核心 Widget ===
export 'src/infinite_canvas/infinite_canvas_widget.dart';
export 'src/infinite_canvas/infinite_canvas_config.dart';

// === 控制器 ===
export 'src/infinite_canvas/infinite_canvas_controller.dart';
export 'src/canvas/canvas_controller.dart';

// === 变换 ===
export 'src/infinite_canvas/canvas_transform.dart';

// === 元素 ===
export 'src/elements/canvas_element.dart';
export 'src/elements/path_element.dart';
export 'src/elements/line_element.dart';
export 'src/elements/rect_element.dart';
export 'src/elements/ellipse_element.dart';
export 'src/elements/arrow_element.dart';
export 'src/elements/text_element.dart';
export 'src/elements/image_element.dart';

// === 工具 ===
export 'src/tools/canvas_tool.dart';
export 'src/tools/tool_manager.dart';
export 'src/tools/brush_settings.dart';
export 'src/tools/select_tool.dart';
export 'src/tools/pen_tool.dart';
export 'src/tools/line_tool.dart';
export 'src/tools/rect_tool.dart';
export 'src/tools/ellipse_tool.dart';
export 'src/tools/arrow_tool.dart';
export 'src/tools/text_tool.dart';
export 'src/tools/eraser_tool.dart';

// === 图层 ===
export 'src/layers/canvas_layer.dart';
export 'src/layers/layer_manager.dart';

// === 历史 ===
export 'src/history/canvas_command.dart';
export 'src/history/history_manager.dart';

// === 样式 ===
export 'src/canvas/paint_style.dart';

// === 事件 ===
export 'src/infinite_canvas/canvas_event.dart';
```

---

## 十二、使用示例

```dart
// 基础用法
final canvasController = CanvasController();
final viewController = InfiniteCanvasController(
  canvasController: canvasController,
);

Scaffold(
  body: InfiniteCanvasWidget(
    controller: viewController,
    config: const InfiniteCanvasConfig(
      showGrid: true,
      gridType: GridType.dots,
      backgroundColor: Colors.white,
    ),
  ),
);

// 注册工具
canvasController.setTool(PenTool.id);
canvasController.updateBrushSettings(
  const BrushSettings(color: Colors.black, width: 2.0),
);

// 编程式操作
canvasController.addElement(PathElement(...));
canvasController.undo();
viewController.zoomIn();
viewController.resetView();
canvasController.select('element-id');
```

---

## 十三、分阶段开发计划

### Phase 1：核心骨架 — 可无限平移缩放的空白画布（1~2 周）

**目标**：跑通端到端流程，无限画布可用

| 编号 | 任务 | 依赖 |
|:---|:---|:---|
| P1-1 | CanvasTransform 不可变数据结构 + 坐标转换 | 无 |
| P1-2 | CanvasState 不可变状态模型 | P1-1 |
| P1-3 | InfiniteCanvasController（视图变换 + 坐标转换） | P1-1 |
| P1-4 | InfiniteCanvasPainter（CustomPainter 基础渲染） | P1-3 |
| P1-5 | 自适应网格背景渲染（GridRenderer） | P1-4 |
| P1-6 | InfiniteCanvasWidget（StatefulWidget + 手势处理） | P1-4 |
| P1-7 | GestureResolver + 基础手势（双指缩放/平移/滚轮缩放） | P1-6 |
| P1-8 | 更新 wenz_draw.dart 公共导出 | P1-6 |
| P1-9 | 添加 uuid 依赖到 pubspec.yaml | 无 |

**验收标准**：可在无限画布上自由平移和缩放，网格背景自适应密度，惯性滚动流畅

### Phase 2：绘图能力 — 可绘制基础图形（1.5~2 周）

| 编号 | 任务 | 依赖 |
|:---|:---|:---|
| P2-1 | CanvasElement 抽象基类 + copyWith | Phase 1 |
| P2-2 | ElementRenderer 接口 + ElementRendererRegistry | P2-1 |
| P2-3 | PathElement + PathElementRenderer | P2-2 |
| P2-4 | LineElement + LineElementRenderer | P2-2 |
| P2-5 | RectElement + RectElementRenderer | P2-2 |
| P2-6 | EllipseElement + EllipseElementRenderer | P2-2 |
| P2-7 | CanvasTool 接口 + ToolResult sealed class | P2-1 |
| P2-8 | ToolManager 工具管理器 | P2-7 |
| P2-9 | PenTool 画笔工具（含路径简化） | P2-3, P2-8 |
| P2-10 | LineTool / RectTool / EllipseTool | P2-4~6, P2-8 |
| P2-11 | CanvasController 核心控制器（元素 CRUD + 工具协调） | P2-8 |
| P2-12 | 绘制预览（拖拽中实时显示） | P2-9~10 |
| P2-13 | 视口裁剪（ViewportCulling） | P2-3~6 |

**验收标准**：可在画布上绘制自由路径、直线、矩形、椭圆，拖拽时有实时预览

### Phase 3：交互增强 — 完整的元素选择和编辑能力（1.5~2 周）

| 编号 | 任务 | 依赖 |
|:---|:---|:---|
| P3-1 | SelectionManager 选择管理器 | Phase 2 |
| P3-2 | SelectTool（点选 + 框选 + 移动） | P3-1 |
| P3-3 | 选中元素边框 + 变换控制手柄（缩放/旋转） | P3-2 |
| P3-4 | ArrowElement + ArrowTool | Phase 2 |
| P3-5 | TextElement + TextTool | Phase 2 |
| P3-6 | EraserTool 橡皮擦 | P3-1 |
| P3-7 | HighlighterTool 荧光笔 | Phase 2 |
| P3-8 | 键盘快捷键（空格平移、Ctrl+Z/Y、Delete） | P3-2 |

**验收标准**：可选择/移动/缩放/删除元素，支持箭头、文本、橡皮擦

### Phase 4：图层 & 历史 & 性能（1.5~2 周）

| 编号 | 任务 | 依赖 |
|:---|:---|:---|
| P4-1 | HistoryManager + CanvasCommand 接口 | Phase 2 |
| P4-2 | 具体命令（Add/Remove/Move/Transform/Batch） | P4-1 |
| P4-3 | 集成到 CanvasController（undo/redo） | P4-2 |
| P4-4 | CanvasLayer + LayerManager | Phase 2 |
| P4-5 | 图层离屏缓存（PictureRecorder） | P4-4 |
| P4-6 | 集成图层到渲染管线 | P4-5 |
| P4-7 | 四叉树空间索引（QuadTree） | Phase 2 |
| P4-8 | 集成四叉树到视口裁剪 | P4-7 |
| P4-9 | 指针事件节流优化 | Phase 2 |

**验收标准**：支持多图层管理、撤销重做、1000+ 元素保持 60fps

### Phase 5：高级功能（1~2 周）

| 编号 | 任务 | 依赖 |
|:---|:---|:---|
| P5-1 | ImageElement（异步图片解码） | Phase 2 |
| P5-2 | JSON 序列化/反序列化 | Phase 4 |
| P5-3 | CanvasDocument 文档模型 | P5-2 |
| P5-4 | 小地图（Minimap Widget） | Phase 4 |
| P5-5 | 缩放控制面板（ZoomControls） | Phase 1 |
| P5-6 | "适应屏幕" zoomToFit | P5-5 |
| P5-7 | LOD 分级渲染 | P4-8 |

**验收标准**：功能完整，支持数据持久化和图片元素

### Phase 6：扩展能力 & 发布（1~2 周）

| 编号 | 任务 | 依赖 |
|:---|:---|:---|
| P6-1 | 自定义工具扩展 API 文档 | Phase 4 |
| P6-2 | 自定义元素类型注册 | Phase 4 |
| P6-3 | PNG 导出 | P5-2 |
| P6-4 | SVG 导出 | P5-2 |
| P6-5 | Web 平台适配验证 | Phase 5 |
| P6-6 | Windows 平台适配验证 | Phase 5 |
| P6-7 | 编写 Example App | Phase 5 |
| P6-8 | 编写 API 文档 + README | Phase 5 |
| P6-9 | 单元测试 + Widget 测试 | Phase 5 |

**验收标准**：可作为独立 SDK 发布，支持自定义扩展

---

## 十四、技术依赖

| 依赖 | 用途 | 说明 |
|:---|:---|:---|
| flutter | SDK | 核心框架 |
| uuid ^4.0.0 | ID 生成 | 元素/图层唯一标识（**唯一外部依赖**） |
| collection ^1.18.0 | 集合工具 | Flutter SDK 内含 |

保持最小依赖原则。后续可选：
- rough_flutter — 手绘风格渲染（Phase 6+ 可选）
- perfect_freehand — 自由绘制平滑（需移植，Phase 6+ 可选）

---

## 十五、已知问题修正清单

> 来自方案3对已有代码的分析

| 问题 | 位置 | 修正方案 |
|:---|:---|:---|
| TickerProvider 问题 | InertiaScrollController | 改为 Widget 层通过 SingleTickerProviderStateMixin 提供 |
| canvasCenter 硬编码 | _getCanvasCenter() 返回 Offset(400,300) | 改为从 Widget 层注入 viewportSize 动态计算 |
| ScaleUpdateDetails.scale 语义错误 | handleScaleUpdate | scale 是累计值非增量值，需修正缩放逻辑 |
| Size.toOffset() 不存在 | getVisibleArea() | 改为 Offset(screenSize.width, screenSize.height) |
| 线程安全 | 绘制操作 | 大量元素时考虑 Isolate 做序列化 |
| Web 平台 dart:ui.Image | 离屏缓存 | 需提前验证 Web 上的缓存方案 |

---

## 十六、测试策略

| 测试类型 | 覆盖范围 | 框架 |
|:---|:---|:---|
| 单元测试 | CanvasTransform 坐标转换、HistoryManager 撤销重做、LayerManager 图层操作、QuadTree 空间索引、PathSimplifier | flutter_test |
| Widget 测试 | InfiniteCanvasWidget 渲染、手势交互、工具切换 | flutter_test |
| 集成测试 | 端到端绘制流程、性能基准 | integration_test |
| 黄金测试 | 各元素渲染截图对比 | flutter_test (matchesGoldenFile) |

---

## 十七、技术决策记录

| 决策 | 选项 | 选择 | 理由 |
|:---|:---|:---|:---|
| 渲染方案 | CustomPainter / RenderObject / CanvasKit | CustomPainter | 简单直观，与 Widget 树集成好 |
| 坐标系统 | 二层 / 三层 | 三层 | 概念更清晰，便于元素局部变换 |
| 元素模型 | 可变 / 不可变 | 不可变 + copyWith | 状态管理安全，便于 undo/redo |
| 渲染器分离 | 元素自绘 / 独立渲染器 | 独立渲染器注册 | 扩展性最优，支持自定义元素 |
| 历史模式 | 快照 / Command | Command | 内存效率高，支持增量操作 |
| 空间索引 | 四叉树 / R-Tree / 网格 | 四叉树 | 动态元素表现好，复杂度适中 |
| 状态管理 | ChangeNotifier / Riverpod / Bloc | ChangeNotifier | 底层库最小依赖，上层可封装 |
| 路径简化 | RDP / Visvalingam / 不简化 | RDP | 经典算法，实时性好 |
| 序列化格式 | JSON / Protobuf / 自定义二进制 | JSON | 调试方便，跨平台兼容 |
| 手势方案 | GestureDetector / RawGestureDetector | RawGestureDetector | 精确控制手势竞技场 |
