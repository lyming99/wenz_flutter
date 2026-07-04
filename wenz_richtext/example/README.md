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

- 文本块 / 代码块 / 表格 / 图片 / 视频 / 分割线渲染。
- 点击定位 caret、水平拖拽选择并高亮。
- 键盘：字符输入、Enter、Backspace/Delete、方向键、Shift+方向键扩选。
- Undo / Redo。
- 工具栏：加粗 / 斜体 / 清除样式、块类型切换（标题/段落/任务项）、插入代码块/表格/图片/视频。
- 右侧 Inspector：文档指标、当前 selection 的 blockIndex/path/offset、Debug overlay 开关。

## 媒体工具栏按钮

- 默认工具栏只负责展示图片/视频按钮并触发 `WenzDefaultDesktopToolbarActions` 回调；资源选择、上传、占位回退和业务元数据由宿主负责。
- 点击工具栏「插入图片」会由 example 打开系统文件选择器，支持 `jpg` / `jpeg` / `png` / `gif` / `webp` / `bmp`。
- 取消选择不会调用插入命令，不会修改文档，也不会产生新的撤销记录。
- 选择成功后，example 会把本地路径或 URI 写入 `ImageBlockNode.file`，并把文件名写入 `caption` / `altText`。
- Windows / IO 平台通过条件导入的本地图片 helper 预览 `file`；Web 或不支持的来源返回内置图片占位，不会让编辑器崩溃。
- 网络图片仍可由 `MediaResolver` 通过 `Image.network` 渲染；核心包不内置文件选择器或本地图片解码依赖。
- 点击工具栏「插入视频」会由 example 生成一个 `VideoBlockNode`，使用 `assets/videos/sample.mp4` 作为可播放来源，并写入标题、描述、封面和默认宽高比。
- 真实业务接入时，宿主可在同一个回调中先完成视频选择/上传，再把 `assetId`、`playbackUrl`、`coverUrl`、`uploadStatus` 等元数据传给控制器。

## 相关文档

- [优化阶段性计划](../docs/optimization_roadmap.md)
- [选区与位置模型](../docs/selection_model.md)
- [Web / Windows 运行说明](../docs/running_guide.md)
