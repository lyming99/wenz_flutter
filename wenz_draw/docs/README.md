# Wenz Draw - Flutter 绘图白板组件

一个功能强大的 Flutter 绘图画布组件插件，支持多种绘图工具和交互功能。

## 功能特性

### 核心绘图功能
- **自由绘制** - 支持画笔自由绘制
- **形状绘制** - 支持直线、矩形、圆形等基础形状
- **文本标注** - 支持在画布上添加文字标注
- **橡皮擦** - 支持擦除功能

### 样式定制
- **画笔颜色** - 支持自定义画笔颜色
- **画笔粗细** - 支持调节画笔/橡皮擦粗细
- **填充模式** - 支持形状填充与描边切换

### 画布操作
- **撤销/重做** - 支持操作历史记录
- **清空画布** - 一键清空所有内容
- **导出图片** - 支持将画布导出为图片

### 手势交互
- **平移** - 支持画布拖拽移动
- **缩放** - 支持画布缩放
- **双指手势** - 支持多点触控操作

## 项目结构

```
wenz_draw/
├── lib/
│   └── wenz_draw.dart          # 插件主入口
├── platforms/
│   ├── android/                # Android 平台实现
│   ├── ios/                    # iOS 平台实现
│   ├── web/                    # Web 平台实现
│   └── windows/                # Windows 平台实现
├── example/                     # 示例应用
├── docs/                        # 文档目录
│   └── README.md               # 项目说明文档
└── pubspec.yaml                # 依赖配置
```

## 使用方式

### 基本用法

```dart
import 'package:wenz_draw/wenz_draw.dart';

// 创建画布组件
WenzDrawCanvas(
  onDrawingChanged: (drawing) {
    // 处理绘图变化
  },
)
```

### 高级配置

```dart
WenzDrawCanvas(
  // 画笔配置
  brushColor: Colors.black,
  brushSize: 5.0,

  // 画布配置
  backgroundColor: Colors.white,
  canvasSize: Size(800, 600),

  // 功能配置
  enableUndo: true,
  enableRedo: true,
  enableZoom: true,
  enablePan: true,

  // 回调
  onDrawingChanged: (drawing) {},
  onCanvasCleared: () {},
)
```

## 开发计划

### Phase 1 - 基础功能
- [x] 创建 Flutter 插件工程
- [ ] 实现 Dart 层画布组件
- [ ] 实现基础绘制功能（自由绘制）
- [ ] 实现画笔颜色和粗细设置

### Phase 2 - 形状和工具
- [ ] 实现形状绘制（直线、矩形、圆形）
- [ ] 实现橡皮擦功能
- [ ] 实现文本标注

### Phase 3 - 高级功能
- [ ] 实现撤销/重做
- [ ] 实现画布缩放和平移
- [ ] 实现图片导出

### Phase 4 - 平台实现
- [ ] Android 平台实现
- [ ] iOS 平台实现
- [ ] Web 平台实现
- [ ] Windows 平台实现

## 技术栈

- **Flutter** - 跨平台 UI 框架
- **CustomPainter** - Flutter 自定义绘制
- **GestureDetector** - 手势识别

## 依赖项

```yaml
dependencies:
  flutter:
    sdk: flutter
```

## 运行示例

```bash
cd wenz_draw/example
flutter run
```

## License

MIT License
