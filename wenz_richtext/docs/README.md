# wenz_richtext docs

本目录用于承载从 `wenz_editor` 重构到 `wenz_richtext` 的设计与实施文档。业务接入方先看根 [README 接口文档](../README.md#接口文档) 完成首轮 API 选型；本目录继续维护详细契约、架构设计和专题说明。

- [README 接口文档（首要 API 入口）](../README.md#接口文档)
- [标准对外接口详细契约](./integration_guide.md)
- [完整 API 参考](./api_reference.md)
- [架构总览](./architecture.md)
- [消费者接入 / 迁移指南](./migration_guide.md)
- [命令与 Schema 体系](./schema_and_commands.md)
- [导入导出策略](./import_export_strategy.md)
- [输入系统与 Slash 菜单](./input_system.md)
- [选区与位置模型](./selection_model.md)
- [选区引擎](./selection_engine.md)
- [渲染架构](./rendering.md)
- [Web / Windows 运行说明](./running_guide.md)
- [发布检查清单](./release_checklist.md)
- [Schema 影响与 JSON migration 方案](./schema_migration_impact.md)
- [项目验收、Roadmap 与完善计划](./project_acceptance_roadmap_plan.md)
- [重构总体方案](./refactor_plan.md)
- [优化阶段性计划](./optimization_roadmap.md)

## 工具栏与业务集成 API

工具栏状态（active 样式 / 当前块类型 / 命令 enable 状态）通过 `ToolbarController`
派生自 `WenzRichTextController`：

```dart
final controller = WenzRichTextController(document: doc);
final toolbar = ToolbarController(controller);

// 监听 toolbar 状态变化（内部监听 host 的 ChangeNotifier）
toolbar.addListener(() {
  // 读 toolbar.bold / toolbar.isHeading(1) / toolbar.canSetLink …
});

// 命令执行入口（转发到 host 的 typed 命令方法）
toolbar.toggleBold();          // ToggleMarkCommand(TextMark.bold)
toolbar.setLink('https://…');  // SetLinkCommand
toolbar.setHeading(2);         // SetBlockTypeCommand(type: heading, level: 2)
```

`ToolbarState` 是不可变快照（实现了 `==` / `hashCode`），可作为 widget 的 value
直接比对，避免每次 host 通知都重建。enable 状态严格镜像各命令 execute 开头的
noop 判定，UI 不会出现"按钮可点但点了没反应"。详见 `lib/src/controller/toolbar_controller.dart`
和 `example/lib/main.dart` 的 `_Toolbar`。
