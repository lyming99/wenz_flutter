# wenz_richtext

`wenz_richtext` 是一个自研 Flutter 富文本编辑器 package，包含文档模型、命令体系、历史记录、输入桥、渲染组件、导入导出和扩展点。当前版本面向内部 alpha / 业务接入验证。

## 安装

Flutter SDK 需满足 `>=3.22.0`，Dart SDK 需满足 `>=3.3.4`。在本仓库或 monorepo 内部接入时使用 path dependency：

```yaml
dependencies:
  wenz_richtext:
    path: ../wenz_richtext
```

发布到包仓库后可切换为版本依赖，例如 `wenz_richtext: ^0.1.0`。

## 快速开始

```dart
import 'package:flutter/material.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final WenzRichTextController controller = WenzRichTextController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WenzRichTextEditor(
        controller: controller,
        autofocus: true,
      ),
    );
  }
}
```

## 常用能力

- **命令**：直接调用 `WenzRichTextController.insertText`、`setBlockType`、`insertTable`、`insertVideo` 等 typed helper；工具栏场景优先用 `ToolbarController` 派生 active / enabled 状态。
- **Block 行操作**：编辑模式下每个顶层 block 左侧有拖拽把手；点击/键盘 Enter/Space 打开复制、引用、复制副本、上移/下移、删除等菜单，拖过阈值后显示落点线并调整行位置，变更可撤销/重做；只读模式隐藏把手但保留文本选区。自定义 `BlockRendererRegistry` 仍由编辑器外层统一包裹行把手，业务 renderer 不需要额外处理排序 chrome。
- **序列化**：`controller.toJson()` 输出当前 canonical rich JSON；`controller.loadJson(source)` 读取 rich JSON；`controller.loadJson(source, legacy: true)` 读取旧 `wenz_editor` JSON。
- **Markdown / HTML**：通过 `controller.toMarkdown()`、`controller.loadMarkdown(source)` 和 `HtmlCodec` 覆盖常见 block / inline 互转；复杂媒体与业务 embed 按文档策略降级。
- **视频组件**：通过斜杠菜单 `video`/`视频`、`ToolbarController.insertVideo` 或 `WenzRichTextController.insertVideo` 写入 `VideoBlockNode`；默认只提供占位渲染，真实播放器由业务通过 `MediaResolver` 注入，核心包不依赖 `video_player`。
- **扩展**：通过 `BlockRendererRegistry`、`InlineEmbedRenderer`、`MediaResolver` 和 `WenzRichTextPlugin` 注入业务 block、inline embed、媒体渲染、slash item、toolbar item 与 paste transformer。
- **质量门禁**：Golden baseline 覆盖基础块、合并表格、selection / caret、高级块与 inline embed；benchmark 覆盖大文档、复杂表格、滚动 remount 与高级混合文档。

## 文档地图

- API 入口：`docs/api_reference.md`
- 架构概览：`docs/architecture.md`
- 迁移指南：`docs/migration_guide.md`
- 命令与 schema：`docs/schema_and_commands.md`
- 导入导出：`docs/import_export_strategy.md`
- 运行 example：`docs/running_guide.md`
- 发布检查：`docs/release_checklist.md`
- 选区与 block 拖拽：`docs/selection_engine.md`

## 回归验证

- Block 行操作改动优先运行：`flutter test test/core/block_structure_commands_test.dart --name MoveBlockCommand`、`flutter test test/widgets/wenz_rich_text_editor_test.dart --name "block drag handles"`、`flutter test test/widgets/editor_golden_test.dart --name "golden: block"`
- 更新视觉基线时使用：`flutter test test/widgets/editor_golden_test.dart --update-goldens --name "golden: block"`
- 发布或合并前再运行：`flutter analyze` 与 `flutter test`

## FAQ

- **是否依赖原生插件？** 不依赖。核心 package 是纯 Flutter / Dart；视频播放、下载、远端资源加载等由业务通过 resolver 或 adapter 注入。
- **是否兼容旧数据？** 支持。旧 `wenz_editor` JSON 可用 `legacy: true` 导入；rich JSON 使用 `DocumentMigrationRegistry` 管理 schema version。
- **PDF / DOCX 是否内建？** 当前只提供平台、依赖和 adapter 合约方案，核心库不引入 PDF、print、OOXML 依赖。
- **alpha 还有哪些边界？** 屏幕阅读器抽样手验、移动端 selection handles、部分三端 IME 手验仍按 `docs/release_checklist.md` 作为发布门禁。
