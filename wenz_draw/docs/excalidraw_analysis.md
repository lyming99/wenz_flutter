# Excalidraw 技术分析与 Flutter 迁移可行性报告

> 项目源码: https://github.com/excalidraw/excalidraw
> 官网: https://excalidraw.com
> 分析日期: 2026-01-30

---

## 1. 项目概述

Excalidraw 是一个开源的虚拟手绘风格白板工具，支持实时协作和端到端加密。该项目使用 TypeScript + React 构建，核心功能通过 npm 包 `@excalidraw/excalidraw` 提供。

### 1.1 核心特性

- 无限画布白板
- 手绘风格渲染
- 深色模式支持
- 图片支持和形状库
- 导出 PNG/SVG/剪贴板
- 开放格式 (.excalidraw JSON)
- 撤销/重做
- 缩放和平移支持
- 实时协作 (excalidraw.com)
- 端到端加密
- PWA 支持

---

## 2. 关键技术栈

### 2.1 核心框架

| 技术 | 版本 | 用途 |
|------|------|------|
| TypeScript | 5.9.3 | 类型安全开发 |
| React | ^17-19 | UI 框架 |
| ReactDOM | ^17-19 | DOM 渲染 |

### 2.2 核心依赖库

```json
{
  "@excalidraw/common": "0.18.0",      // 公共类型和工具
  "@excalidraw/element": "0.18.0",     // 元素数据结构
  "@excalidraw/math": "0.18.0",        // 数学计算工具
  "@excalidraw/laser-pointer": "1.3.1", // 激光指针效果
  "roughjs": "4.6.4",                  // 手绘风格渲染 ⭐
  "perfect-freehand": "1.2.0",         // 自由绘制平滑处理 ⭐
  "jotai": "2.11.0",                   // 状态管理
  "@radix-ui/react-popover": "1.1.6",  // UI 组件
  "@radix-ui/react-tabs": "1.1.3",     // 标签页组件
  "nanoid": "3.3.3",                   // ID 生成
  "pako": "2.0.3",                     // 压缩/解压
  "points-on-curve": "1.0.1",          // 曲线点计算
  "fractional-indexing": "3.2.0"       // 分数索引 (协作排序)
}
```

---

## 3. 项目架构

### 3.1 Monorepo 结构

```
excalidraw/
├── packages/
│   ├── excalidraw/          # 主 npm 包
│   ├── excalidraw-common/   # 公共类型和工具
│   ├── excalidraw-element/  # 元素数据结构
│   ├── excalidraw-math/     # 数学计算
│   └── excalidraw-laser-pointer/ # 激光指针
├── packages-excalidraw-libraries/  # 可选库集成
└── website/                 # excalidraw.com 站点
```

### 3.2 核心模块导出

```typescript
// packages/excalidraw/package.json exports
{
  "./common/*":   // 公共工具导出
  "./element/*":  // 元素类型导出
  "./math/*":     // 数学工具导出
  "./utils/*":    // 工具函数导出
  "./index.css":  // 样式文件
  ".":            // 主入口
}
```

### 3.3 渲染架构

```
┌─────────────────────────────────────────────┐
│              React Component Layer          │
├─────────────────────────────────────────────┤
│            State Management (Jotai)         │
├─────────────────────────────────────────────┤
│              Canvas Rendering               │
├──────────────┬──────────────┬───────────────┤
│  Rough.js    │ Perfect      │  Custom       │
│  (几何形状)  │ Freehand     │  Renderer     │
│              │ (自由绘制)   │               │
└──────────────┴──────────────┴───────────────┘
```

---

## 4. 核心技术实现

### 4.1 手绘风格渲染 - Rough.js

**作用**: 将规则几何图形渲染成手绘风格

```javascript
// Rough.js 工作原理
import rc from 'roughjs';

const canvas = document.getElementById('canvas');
const ctx = canvas.getContext('2d');
const rc_canvas = rc.canvas(canvas);

// 绘制手绘风格矩形
rc_canvas.rectangle(10, 10, 200, 100, {
  stroke: '#000',
  roughness: 1,      // 粗糙度
  bowing: 1          // 弯曲度
});
```

**核心算法**:
1. 在规则路径上添加随机偏移
2. 多次绘制同一线条产生"重复描边"效果
3. SVG 路径计算后缓存，避免重复计算

### 4.2 自由绘制平滑 - Perfect Freehand

**作用**: 处理手绘笔触，生成平滑曲线

```javascript
import { getStroke } from 'perfect-freehand';

// 输入原始点列
const points = [[0, 0], [10, 5], [20, 8], ...];

// 生成平滑笔触路径
const stroke = getStroke(points, {
  size: 16,
  thinning: 0.5,
  smoothing: 0.5,
  streamline: 0.5
});
```

### 4.3 状态管理 - Jotai

```typescript
// Excalidraw 使用 Jotai 进行原子化状态管理
import { atom, useAtom } from 'jotai';

// 元素状态
const elementsAtom = atom<ExcalidrawElement[]>([]);

// 应用状态
const appStateAtom = atom<AppState>({
  zoom: { value: 1 },
  scrollX: 0,
  scrollY: 0,
  // ...
});
```

### 4.4 画布架构

```
┌──────────────────────────────────────┐
│         Infinite Canvas               │
│  ┌────────────────────────────────┐  │
│  │   Virtual Viewport (Zoom)      │  │
│  │  ┌──────────────────────────┐  │  │
│  │  │   Visible Area            │  │  │
│  │  │   (Rendered Elements)     │  │  │
│  │  └──────────────────────────┘  │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

---

## 5. Flutter 迁移可行性分析

### 5.1 技术对比

| 功能 | Excalidraw (Web) | Flutter | 可行性 |
|------|------------------|---------|--------|
| Canvas 渲染 | HTML5 Canvas | CustomPainter | ✅ 可行 |
| 手绘风格 | Rough.js | rough_flutter | ✅ 有对应库 |
| 自由绘制 | Perfect Freehand | 需要实现 | ⚠️ 需移植 |
| 状态管理 | Jotai | Provider/Riverpod | ✅ 可行 |
| 无限画布 | 自研 | InteractiveViewer | ✅ 原生支持 |
| 手势处理 | Web Events | GestureDetector | ✅ 更优 |
| 协作同步 | WebSocket | WebSocket/dio | ✅ 可行 |

### 5.2 现有 Flutter 生态

#### rough_flutter
```yaml
dependencies:
  rough_flutter: ^0.1.1
```

- Rough.js 的 Dart 移植版本
- 支持基本手绘风格图形
- **限制**: 功能不如原版完整

#### canvas_kit
```yaml
dependencies:
  canvas_kit: ^latest
```

- 提供无限画布支持
- 内置缩放和平移
- **限制**: 需要配合其他库使用

#### flutter_drawing_board
```yaml
dependencies:
  flutter_drawing_board: ^latest
```

- 完整的绘图板实现
- 支持多种绘图工具
- **限制**: 缺少手绘风格

### 5.3 迁移挑战

#### 1. Perfect Freehand 等效库 ⭐ **核心难点**

Perfect Freehand 是 Excalidraw 自由绘制的核心，Flutter 生态**没有直接等效库**。

**解决方案**:
- 方案 A: 将 Perfect Freehand 移植到 Dart (推荐)
- 方案 B: 使用 FFI 调用 JS 版本
- 方案 C: 使用 Flutter CustomPainter 手动实现

#### 2. Rough.js 功能完整性

`rough_flutter` 功能较原版有所阉割:
- 缺少部分高级选项
- 渲染效果可能有差异

**解决方案**:
- Fork `rough_flutter` 补全功能
- 或直接使用 `roughjs` 通过 JS 互操作

#### 3. 协作同步

Excalidraw 的实时协作依赖:
- CRDT (Conflict-free Replicated Data Types)
- WebSocket 实时通信
- 分数索引排序

**解决方案**:
- 使用 `fractional_indexing` Dart 移植版
- WebSocket 连接使用 `web_socket_channel`
- CRDT 可用 `dart-crdt` 包

### 5.4 推荐迁移架构

```dart
// Flutter 架构设计
┌─────────────────────────────────────────────┐
│            Flutter Widget Layer             │
│         (InheritedWidget/Provider)          │
├─────────────────────────────────────────────┤
│              Canvas Layer                   │
│         (CustomPainter + Canvas)            │
├──────────────┬──────────────┬───────────────┤
│ rough_flutter│ Custom       │  Stroke       │
│ (几何形状)   │ Freehand     │  Renderer     │
│              │ Implementation│              │
└──────────────┴──────────────┴───────────────┘
```

---

## 6. 迁移实施建议

### 6.1 分阶段实施

#### Phase 1: 基础画布 (2-3 周)
- [ ] 设置 CustomPainter 基础架构
- [ ] 实现 InteractiveViewer 缩放平移
- [ ] 基本手势处理 (拖拽、缩放)

#### Phase 2: 手绘风格 (3-4 周)
- [ ] 集成 rough_flutter
- [ ] 实现矩形、圆形、线条等基础图形
- [ ] 测试渲染效果

#### Phase 3: 自由绘制 (4-6 周) ⭐
- [ ] 移植 Perfect Freehand 算法
- [ ] 实现平滑曲线渲染
- [ ] 笔触优化

#### Phase 4: 编辑功能 (3-4 周)
- [ ] 选择、移动、缩放元素
- [ ] 撤销/重做栈
- [ ] 导出功能

#### Phase 5: 协作功能 (4-6 周)
- [ ] WebSocket 通信
- [ ] CRDT 数据同步
- [ ] 多人光标显示

### 6.2 关键代码示例

```dart
// CustomPainter 基础实现
class ExcalidrawPainter extends CustomPainter {
  final List<Element> elements;

  ExcalidrawPainter(this.elements);

  @override
  void paint(Canvas canvas, Size size) {
    for (var element in elements) {
      switch (element.type) {
        case ElementType.rectangle:
          _drawRectangle(canvas, element);
          break;
        case ElementType.line:
          _drawLine(canvas, element);
          break;
        case ElementType.freehand:
          _drawFreehand(canvas, element);
          break;
      }
    }
  }

  void _drawRectangle(Canvas canvas, Element element) {
    // 使用 rough_flutter 渲染手绘风格矩形
    final rc = RoughCanvas();
    rc.rectangle(canvas, element.x, element.y, element.width, element.height,
      RoughOptions(roughness: element.roughness));
  }

  @override
  bool shouldRepaint(ExcalidrawPainter oldDelegate) {
    return elements != oldDelegate.elements;
  }
}
```

### 6.3 依赖建议

```yaml
dependencies:
  # 状态管理
  flutter_riverpod: ^2.4.0

  # 手绘风格
  rough_flutter: ^0.1.1

  # ID 生成
  uuid: ^4.0.0

  # 数学计算
  vector_math: ^2.1.4

  # WebSocket
  web_socket_channel: ^2.4.0

  # 压缩
  archive: ^3.4.0
```

---

## 7. 结论

### 7.1 可行性评估

| 方面 | 评分 | 说明 |
|------|------|------|
| 整体可行性 | 8/10 | 技术栈对 Flutter 友好 |
| 开发难度 | 中等 | 主要挑战在于 Perfect Freehand 移植 |
| 性能预期 | 良好 | Flutter Canvas 性能优于 Web |
| 维护成本 | 中等 | 需要维护移植的算法库 |

### 7.2 最终建议

**可以迁移到 Flutter**，建议采用以下策略:

1. **分阶段实施**: 先实现基础功能，再添加协作
2. **重点投入**: Perfect Freehand 的 Dart 移植是关键
3. **参考现有**: 基于 `rough_flutter` 和 `canvas_kit` 构建
4. **社区贡献**: 移植后的算法库可开源贡献给社区

### 7.3 风险提示

- Perfect Freehand 算法较复杂，移植需要深入理解其实现
- 协作功能的 CRDT 需要仔细设计
- 与原版 Excalidraw 的文件格式兼容性需要保证

---

## 8. 参考资源

### 8.1 官方资源
- Excalidraw GitHub: https://github.com/excalidraw/excalidraw
- Excalidraw 官网: https://excalidraw.com
- Excalidraw Libraries: https://libraries.excalidraw.com/

### 8.2 核心库文档
- Rough.js: https://roughjs.com/
- Rough.js 算法解析: https://shihn.ca/posts/2020/roughjs-algorithms/
- Perfect Freehand: https://github.com/statelyai/perfect-freehand

### 8.3 Flutter 相关
- rough_flutter: https://pub.dev/packages/rough_flutter
- canvas_kit: https://pub.dev/packages/canvas_kit
- flutter_drawing_board: https://pub.dev/packages/flutter_drawing_board

---

**文档版本**: 1.0
**最后更新**: 2026-01-30
**作者**: AI 技术分析
