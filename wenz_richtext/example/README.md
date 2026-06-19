# wenz_richtext example

自研富文本编辑器 `wenz_richtext` 的演示工程，支持 Web 和 Windows 桌面运行。

## 运行

前置：Flutter SDK `>=3.22.0`。

```bash
cd example
flutter pub get

# Windows 桌面
flutter run -d windows

# Web (Chrome)
flutter run -d chrome
```

详细的平台运行说明、已验证交互清单与已知差异见 [`../docs/running_guide.md`](../docs/running_guide.md)。

## 功能概览

- 文本块 / 代码块 / 表格 / 图片 / 视频占位 / 分割线渲染。
- 点击定位 caret、水平拖拽选择并高亮。
- 键盘：字符输入、Enter、Backspace/Delete、方向键、Shift+方向键扩选。
- Undo / Redo。
- 工具栏：加粗 / 斜体 / 清除样式、块类型切换（标题/段落/任务项）、插入代码块/表格/图片。
- 右侧 Inspector：文档指标、当前 selection 的 blockIndex/path/offset、Debug overlay 开关。

## 相关文档

- [优化阶段性计划](../docs/optimization_roadmap.md)
- [选区与位置模型](../docs/selection_model.md)
- [Web / Windows 运行说明](../docs/running_guide.md)
