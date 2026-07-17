# 富文本编辑器进阶功能阶段性开发计划

## 当前进度（2026-06-24）

- 第一轮高优先级能力已完成并标记：`ADV-001`、`ADV-002`、`ADV-003`、`ADV-004`、`ADV-005`、`ADV-006`、`ADV-007`、`ADV-012`、`ADV-017`。
- 第二轮已完成并标记：`ADV-008`、`ADV-009`、`ADV-010`、`ADV-011`、`ADV-013`、`ADV-014`、`ADV-015`、`ADV-016`。
- 第三轮已完成并标记：`ADV-018`、`ADV-019`、`ADV-020`、`ADV-021`、`ADV-022`、`ADV-023`、`ADV-024`、`ADV-025`、`ADV-026`、`ADV-027`、`ADV-028`、`ADV-029`、`ADV-030`。
- 最近完成项：早期 P0 任务状态收敛。任务列表补齐 `ADV-003`、`ADV-004`、`ADV-005` 的 `[done]` 标记，并同步矩阵说明。
- 本轮推进项：`ADV-003`、`ADV-004`、`ADV-005` 完成状态收敛；本轮仅做文档一致性更新，不重做已完成实现。
- 当前验证：文档一致性检查已通过，确认 `ADV-001` 至 `ADV-030` 在任务列表、当前进度与矩阵中均有完成状态；本轮无代码变更，未运行 Flutter 测试。
- 下一步建议：全部 ADV 任务已完成并标记；后续优先进入发布前回归、示例体验复核或新增计划拆分。

## 目标

基于当前 `wenz_richtext` 已有的自研文档模型、命令体系、输入层、渲染层、序列化能力，逐步补齐进阶编辑器能力，让项目从“可用的富文本核心”推进到“可业务集成、可扩展、可发布”的编辑器组件。

核心原则：

- 先稳定单机编辑体验，再增强复杂内容块，再扩展导入导出与协作能力。
- 所有用户可见能力都要经过命令层，保证 undo/redo、schema normalize、序列化一致。
- 每个阶段都要有可演示 example、自动化测试、文档更新和明确验收标准。
- 协作能力先做数据结构和扩展接口，不在核心层绑定具体 CRDT 或服务端实现。

## 阶段总览

| 阶段 | 主题 | 建议周期 | 核心产出 |
| --- | --- | --- | --- |
| 阶段 0 | 能力盘点与技术设计 | 0.5-1 周 | 功能矩阵、schema 变更方案、测试矩阵 |
| 阶段 1 | 编辑效率增强 | 2-3 周 | Markdown 快捷输入、快捷键、粘贴清洗、查找替换 |
| 阶段 2 | 结构化内容增强 | 2-4 周 | Slash 菜单、列表增强、Callout、代码块、表格体验补强 |
| 阶段 3 | 媒体与嵌入内容 | 2-4 周 | 图片编辑、附件、链接预览、公式、mention、emoji |
| 阶段 4 | 文档级能力与导入导出 | 2-4 周 | 大纲目录、锚点、字数统计、版本快照、Markdown/HTML/PDF/DOCX 策略 |
| 阶段 5 | 评论、修订与协作预留 | 3-5 周 | 评论线程、批注锚点、修订标记、协作 adapter 接口 |
| 阶段 6 | 插件化、质量与发布 | 2-3 周 | 插件 API、可访问性、Golden/benchmark、发布文档 |

## 阶段 0：能力盘点与技术设计

目标：把现有能力、目标能力、数据结构影响和测试边界先对齐，避免后续功能各自生长。

阶段任务：

- 梳理当前已支持能力：
  - 文档模型：paragraph、heading、quote、list、code、table、media placeholder、callout 等。
  - 命令体系：文本、样式、块结构、表格、selection、history。
  - 编码能力：rich JSON、legacy JSON、plain text、Markdown、HTML。
  - 输入能力：IME、clipboard、keyboard shortcuts 的当前边界。
- 产出进阶功能矩阵：
  - `planned`：计划实现。
  - `supported`：已有实现。
  - `partial`：已有骨架但体验不足。
  - `deferred`：暂不进入近期版本。
- 为新增能力确认 schema 影响：
  - 新 block 类型是否需要新增模型。
  - 新 inline embed 是否可以复用 `InlineEmbed`。
  - 是否需要新增 document metadata。
  - 是否影响 JSON version migration。
- 定义测试矩阵：
  - core command tests。
  - controller integration tests。
  - widget tests。
  - golden tests。
  - example manual checklist。

验收标准：

- 有一份进阶功能矩阵文档。
- 每个后续阶段都有明确数据结构影响和测试入口。
- 不引入会破坏现有 JSON round-trip 的 schema 变更。

## 阶段 1：编辑效率增强

目标：补齐高频编辑体验，让编辑器在文本输入、快捷操作、粘贴和查找方面接近成熟编辑器。

阶段任务：

- Markdown 快捷输入：
  - `#`、`##`、`###` 转标题。
  - `-`、`*` 转无序列表。
  - `1.` 转有序列表。
  - `- [ ]` 转任务列表。
  - `>` 转引用块。
  - 输入三个反引号转代码块。
  - `---` 转分割线。
- 快捷键体系：
  - Ctrl/Cmd+B/I/U/S。
  - Ctrl/Cmd+K 设置链接。
  - Ctrl/Cmd+F 查找。
  - Ctrl/Cmd+H 替换。
  - Ctrl/Cmd+Shift+7/8 切换列表。
  - Tab/Shift+Tab 控制列表缩进和表格导航。
- 粘贴清洗：
  - 纯文本粘贴。
  - Markdown 粘贴。
  - HTML 粘贴。
  - 从 Word/网页粘贴时去除危险或无关样式。
  - 保留标题、列表、链接、代码、表格、图片占位。
- 查找与替换：
  - 当前命中、高亮所有命中。
  - 上一个/下一个。
  - 替换当前/全部替换。
  - 区分大小写和全词匹配预留。
- undo/redo 粒度优化：
  - 连续输入合并。
  - 连续删除合并。
  - 自动格式化与用户输入合并为合理历史步。

验收标准：

- Markdown 快捷输入触发后可以正常 undo 回原输入。
- 粘贴内容不会破坏文档 schema。
- 查找替换对跨 block 文档可用。
- 阶段能力覆盖 core、input、widget 测试。

## 阶段 2：结构化内容增强

目标：让编辑器具备更强的文档组织能力，支持常用块级结构和更高效的块插入体验。

阶段任务：

- Slash 菜单：
  - `/heading`、`/list`、`/todo`、`/quote`、`/code`、`/table`、`/image`。
  - 支持键盘上下选择、Enter 确认、Esc 取消。
  - 菜单项由 registry 提供，便于业务侧扩展。
- 列表增强：
  - 有序列表、无序列表、任务列表统一模型。
  - 多级缩进。
  - Enter 自动延续列表。
  - 空列表项 Enter 退出列表。
- 代码块增强：
  - 语言选择。
  - Tab 输入或缩进策略。
  - 复制代码。
  - 代码块内 selection 与普通文本 selection 一致。
- Callout / 提示块：
  - 类型：info、success、warning、danger。
  - 图标、标题、正文。
  - 支持切换类型。
- 表格体验补强：
  - 快速插入行列。
  - 表格浮动工具条。
  - 单元格背景色、对齐、表头。
  - 行列拖拽调整预留。
- 文档大纲基础：
  - 从 heading 自动生成 outline。
  - 点击 outline 跳转到 block。

验收标准：

- Slash 菜单可通过键盘完成主流程。
- 列表、代码块、Callout、表格命令全部进入 undo/redo。
- 新增 block 可以 JSON/Markdown/HTML round-trip 或有明确降级策略。

## 阶段 3：媒体与嵌入内容

目标：补齐图片、附件、链接、公式、mention 等内容型能力，让编辑器适合真实业务内容生产。

阶段任务：

- 图片能力：
  - 插入本地/远程图片。
  - 图片加载状态、失败状态。
  - 图片尺寸调整。
  - 图片说明文字 caption。
  - alt text。
  - 替换图片源。
- 文件附件：
  - 文件块模型。
  - 文件名、大小、类型、下载地址。
  - 上传状态和失败重试预留。
- 链接增强：
  - 链接编辑弹窗。
  - 自动识别 URL。
  - 链接预览卡片预留。
- Inline embed：
  - mention。
  - emoji。
  - formula。
  - inline image。
- Block embed：
  - video。
  - custom embed placeholder。
  - 业务侧 renderer 注入。
- 媒体 resolver/uploader 接口：
  - resolve media metadata。
  - upload progress callback。
  - error presentation。

验收标准：

- 媒体块不阻塞普通文本编辑。
- 媒体失败时 editor 不崩溃。
- 图片、附件、embed 可以通过 JSON 保存和恢复。
- 业务侧可以通过 renderer/resolver 替换默认展示。

## 阶段 4：文档级能力与导入导出

目标：把编辑器从“内容输入控件”推进到“文档编辑工具”，支持文档级信息、统计、导航、快照和更完整的转换能力。

阶段任务：

- 文档导航：
  - 大纲目录。
  - block anchor。
  - 书签。
  - 跳转到指定 block。
- 文档统计：
  - `[done] ADV-018` 字数统计。
  - `[done] ADV-018` 字符数统计。
  - `[done] ADV-018` 段落数、标题数、图片数。
  - `[done] ADV-018` 阅读时间估算。
- 自动保存与草稿恢复：
  - `[done] ADV-019` controller 层暴露 dirty state。
  - `[done] ADV-019` onChanged 防抖建议。
  - `[done] ADV-019` 保存成功后标记 clean。
  - `[done] ADV-019` 外部持久化 adapter 示例。
- 版本快照：
  - `[done] ADV-020` 文档快照模型。
  - `[done] ADV-020` 快照元信息：id、时间、作者、说明。
  - `[done] ADV-020` 快照恢复。
  - `[done] ADV-020` 快照 diff 预留。
- 导入导出：
  - Markdown import/export 完善。
  - HTML import/export 完善。
  - `[done] ADV-022` PDF export 方案设计。
  - `[done] ADV-022` DOCX import/export 方案设计。
  - `[done] ADV-022` 图片和附件资源导出策略。

验收标准：

- 大纲与统计能跟随文档变化更新。
- 自动保存示例不会造成频繁阻塞。
- 版本快照能序列化元信息并恢复文档，diff base 预留不写入正文 schema。
- Markdown/HTML 覆盖主流 block 与 inline 样式。
- PDF/DOCX 有明确平台能力、依赖和降级边界。

## 阶段 5：评论、修订与协作预留

目标：先建立评论、批注、修订这些协作前置数据结构，再提供可插拔的协作 adapter，不把具体实时协作方案写死在核心层。

阶段任务：

- 评论与批注：
  - comment anchor inline 标记。
  - 评论线程模型。
  - 评论状态：open、resolved。
  - 评论侧栏。
  - 点击评论定位到 selection。
- 修订模式：
  - insert/delete/format change 标记。
  - 接受/拒绝修订。
  - 修订作者、时间。
  - 普通模式与修订模式切换。
- 协作预留：
  - operation/change event adapter。
  - remote cursor 数据结构。
  - remote selection 渲染接口。
  - 权限态：read、comment、edit。
  - 冲突处理策略文档。
- 不进入近期核心的内容：
  - 默认内置服务端。
  - 默认绑定 Yjs/CRDT。
  - 默认多人房间管理。

验收标准：

- 评论和修订信息可以随文档 JSON 保存恢复。
- 评论定位与 selection 语义一致。
- 协作 adapter 接口不影响单机编辑性能。
- 权限态可以禁用对应命令。

## 阶段 6：插件化、质量与发布

目标：把前面新增能力收敛成稳定 API、测试矩阵和发布文档，支撑业务方长期接入。

阶段任务：

- 插件系统：
  - command plugin。
  - block renderer plugin。
  - inline embed renderer plugin。
  - slash menu item plugin。
  - toolbar item plugin。
  - paste transformer plugin。
- API 稳定：
  - 标记 stable、stabilising、experimental。
  - 梳理 breaking change。
  - 完善 migration guide。
- 可访问性：
  - 语义节点。
  - 键盘可达。
  - 屏幕阅读器标签。
  - 高对比度主题预留。
- 测试：
  - core command 全量测试。
  - input/IME 回归测试。
  - widget interaction 测试。
  - golden tests。
  - benchmark。
  - example integration tests。
- 发布准备：
  - README 快速开始。
  - API reference。
  - cookbook。
  - changelog。
  - 0.2.0-alpha 或 0.3.0-alpha 发布检查。

验收标准：

- `flutter analyze` 通过。
- `flutter test` 通过。
- example Web/Windows 主流程可演示。
- docs 覆盖安装、初始化、命令、序列化、扩展、常见问题。

## 任务列表

| ID | 阶段 | 优先级 | 任务 | 主要落点 |
| --- | --- | --- | --- | --- |
| [done] ADV-001 | 阶段 0 | P0 | 建立进阶功能矩阵 | `docs/advanced_feature_matrix.md` |
| [done] ADV-002 | 阶段 0 | P0 | 评估 schema 与 JSON migration 影响 | `docs/schema_migration_impact.md`、`lib/src/core/schema/`、`lib/src/codecs/` |
| [done] ADV-003 | 阶段 1 | P0 | Markdown 快捷输入引擎 | `lib/src/input/`、`lib/src/core/commands/` |
| [done] ADV-004 | 阶段 1 | P0 | 快捷键集中管理 | `lib/src/input/`、`lib/src/widgets/` |
| [done] ADV-005 | 阶段 1 | P0 | 粘贴清洗 pipeline | `lib/src/input/clipboard_service.dart` |
| [done] ADV-006 | 阶段 1 | P1 | 查找替换 controller 与 UI | `lib/src/controller/find_replace_controller.dart`、`lib/src/widgets/find_replace_panel.dart` |
| [done] ADV-007 | 阶段 2 | P0 | Slash 菜单基础框架 | `lib/src/controller/slash_menu_controller.dart`、`lib/src/widgets/slash_menu_overlay.dart` |
| [done] ADV-008 | 阶段 2 | P0 | 列表模型与命令增强 | `lib/src/core/model/`、`lib/src/core/commands/` |
| [done] ADV-009 | 阶段 2 | P1 | 代码块语言与工具条 | `lib/src/core/model/`、`lib/src/widgets/` |
| [done] ADV-010 | 阶段 2 | P1 | Callout 类型增强 | `lib/src/core/model/`、`lib/src/core/commands/`、`lib/src/widgets/`、`lib/src/codecs/` |
| [done] ADV-011 | 阶段 2 | P1 | 表格浮动工具与行列体验 | `lib/src/core/commands/`、`lib/src/widgets/` |
| [done] ADV-012 | 阶段 3 | P0 | 图片尺寸、caption、alt text | `lib/src/core/model/`、`lib/src/core/commands/`、`lib/src/widgets/`、`lib/src/codecs/` |
| [done] ADV-013 | 阶段 3 | P1 | 文件附件块 | `lib/src/core/model/`、`lib/src/core/commands/`、`lib/src/controller/`、`lib/src/widgets/`、`lib/src/codecs/` |
| [done] ADV-014 | 阶段 3 | P1 | 链接编辑与自动识别 URL | `lib/src/core/commands/`、`lib/src/widgets/` |
| [done] ADV-015 | 阶段 3 | P1 | mention、emoji、formula inline embed | `lib/src/core/model/`、`lib/src/widgets/` |
| [done] ADV-016 | 阶段 3 | P2 | Block embed 与业务 renderer 注入 | `lib/src/core/model/block_node.dart`、`lib/src/widgets/block_renderer_registry.dart`、`lib/src/widgets/wenz_rich_text_editor.dart`、`lib/src/codecs/`、`example/lib/` |
| [done] ADV-017 | 阶段 4 | P0 | 大纲目录与 block anchor | `lib/src/controller/`、`lib/src/widgets/` |
| [done] ADV-018 | 阶段 4 | P1 | 文档统计 | `lib/src/controller/` |
| [done] ADV-019 | 阶段 4 | P1 | 自动保存状态与示例 | `lib/src/controller/`、`example/lib/` |
| [done] ADV-020 | 阶段 4 | P2 | 版本快照模型 | `lib/src/core/model/`、`lib/src/codecs/` |
| [done] ADV-021 | 阶段 4 | P1 | Markdown/HTML import/export 完善 | `lib/src/codecs/`、`example/lib/` |
| [done] ADV-022 | 阶段 4 | P2 | PDF/DOCX 方案设计 | `docs/`、`lib/src/exporters/` |
| [done] ADV-023 | 阶段 5 | P1 | 评论线程模型与 UI | `lib/src/core/model/`、`lib/src/widgets/` |
| [done] ADV-024 | 阶段 5 | P2 | 修订模式模型与命令 | `lib/src/core/model/`、`lib/src/core/commands/` |
| [done] ADV-025 | 阶段 5 | P2 | 协作 adapter 接口 | `lib/src/collaboration/` |
| [done] ADV-026 | 阶段 5 | P2 | 权限态与命令禁用 | `lib/src/controller/`、`lib/src/core/commands/` |
| [done] ADV-027 | 阶段 6 | P0 | 插件 API 收敛 | `lib/src/plugins/editor_plugin.dart`、`lib/src/core/commands/`、`lib/src/widgets/` |
| [done] ADV-028 | 阶段 6 | P0 | Golden 与 benchmark 补齐 | `test/widgets/`、`test/benchmarks/` |
| [done] ADV-029 | 阶段 6 | P1 | 可访问性增强 | `lib/src/widgets/` |
| [done] ADV-030 | 阶段 6 | P0 | 发布文档与 migration guide | `docs/`、`README.md` |

## 建议文件结构列表

当前已有结构可以继续沿用，新增能力优先放在对应层级内，不建议把编辑逻辑塞进 widget。

```text
lib/
  wenz_richtext.dart
  src/
    core/
      model/
        block_node.dart
        inline_node.dart
        attributes.dart
        rich_text_document.dart
        table_model.dart
        document_metadata.dart          # planned: 版本、权限等元信息；文档统计已由 controller 派生
        comment_model.dart              # done: 评论线程与批注锚点
        revision_model.dart             # planned: 修订标记
      position/
        document_position.dart
      schema/
        document_schema.dart
      commands/
        editor_command.dart
        command_executor.dart
        command_registry.dart
        text_commands.dart
        inline_commands.dart
        block_commands.dart
        block_structure_commands.dart
        table_commands.dart
        selection_commands.dart
        markdown_shortcut_commands.dart # planned: 快捷输入触发后的命令封装
        comment_commands.dart           # planned
        revision_commands.dart          # planned
    controller/
      wenz_rich_text_controller.dart
      toolbar_controller.dart
      slash_menu_controller.dart        # done
      find_replace_controller.dart      # done
      outline_controller.dart           # done
      document_stats_controller.dart    # done
      autosave_controller.dart          # done
    input/
      editor_text_input_client.dart
      clipboard_service.dart
      composition_state.dart
      shortcut_manager.dart             # done
      markdown_shortcut_engine.dart     # planned
      paste_pipeline.dart               # not needed; pipeline lives in ClipboardService
      html_paste_sanitizer.dart         # planned
    plugins/
      editor_plugin.dart                # done: ADV-027 unified plugin API
    widgets/
      wenz_rich_text_editor.dart
      selection_gesture_overlay.dart
      block_renderer_registry.dart
      inline_embed_renderer.dart
      media_resolver.dart
      shared_text_layout_cache.dart
      block_geometry_registry.dart
      find_replace_panel.dart           # done
      comment_sidebar.dart              # done
      toolbar/
        editor_toolbar.dart             # planned/example 可先放 example
        table_toolbar.dart              # planned
        media_toolbar.dart              # planned
      overlays/
        slash_menu_overlay.dart         # done
        link_editor_overlay.dart        # planned
        find_replace_panel.dart         # not needed; implemented as reusable widgets/find_replace_panel.dart
        comment_popover.dart            # planned: inline popover / composer
      media/
        image_block_view.dart           # not needed; default image renderer wraps media with _ImageBlockContent
        file_block_view.dart            # planned
        embed_block_view.dart           # planned
    rendering/
      text_layout_service.dart
    codecs/
      rich_text_json_codec.dart
      legacy_wen_json_codec.dart
      plain_text_codec.dart
      markdown_codec.dart
      html_codec.dart
      document_migration.dart
      document_errors.dart
      docx_codec.dart                   # planned/optional
      pdf_exporter.dart                 # planned/optional
    collaboration/
      collaboration_adapter.dart        # done: adapter + remote selection model
      remote_cursor.dart                # not needed yet; remote selection lives in collaboration_adapter.dart
      permission_policy.dart            # not needed; permission lives in controller + core command API
    history/
      history_manager.dart
```

测试结构建议：

```text
test/
  core/
    comment_model_test.dart             # done
    markdown_shortcut_commands_test.dart
    comment_commands_test.dart
    revision_commands_test.dart
    document_stats_test.dart
  input/
    shortcut_manager_test.dart          # done
    markdown_shortcut_engine_test.dart
    paste_pipeline_test.dart            # covered by clipboard_service_test.dart
    html_paste_sanitizer_test.dart
  controller/
    slash_menu_controller_test.dart     # done
    find_replace_controller_test.dart   # done
    outline_controller_test.dart
    autosave_controller_test.dart       # done
  collaboration/
    collaboration_adapter_test.dart     # done
  plugins/
    editor_plugin_test.dart             # done
  widgets/
    slash_menu_overlay_test.dart        # done
    find_replace_panel_test.dart        # done
    comment_sidebar_test.dart           # done
    media_block_view_test.dart
    comment_popover_test.dart
    editor_advanced_golden_test.dart
  codecs/
    markdown_advanced_codec_test.dart
    html_advanced_codec_test.dart
    docx_codec_test.dart
    pdf_exporter_test.dart
  benchmarks/
    editor_advanced_benchmarks.dart
```

文档结构建议：

```text
docs/
  advanced_feature_development_plan.md  # 本文档
  advanced_feature_matrix.md            # done
  markdown_shortcuts.md                 # planned
  slash_menu.md                         # planned
  media_and_embeds.md                   # planned
  comments_and_revisions.md             # done for comments; revisions planned
  import_export_strategy.md             # done
  plugin_api.md                         # planned
  release_checklist.md                  # planned
```

example 结构建议：

```text
example/
  lib/
    main.dart
    test_host.dart
    demos/
      markdown_shortcuts_demo.dart      # planned
      slash_menu_demo.dart              # planned
      media_demo.dart                   # planned
      comments_demo.dart                # planned
      import_export_demo.dart           # done in main.dart Inspector
```

## 推荐近期排期

第一轮优先做 P0/P1 且不重依赖外部服务的能力：

1. `[done] ADV-001` 进阶功能矩阵。
2. `[done] ADV-002` schema 与 JSON migration 影响评估。
3. `[done] ADV-003` Markdown 快捷输入。
4. `[done] ADV-004` 快捷键集中管理。
5. `[done] ADV-005` 粘贴清洗 pipeline。
6. `[done] ADV-006` 查找替换。
7. `[done] ADV-007` Slash 菜单基础框架。
8. `[done] ADV-012` 图片 caption/alt/尺寸。
9. `[done] ADV-017` 大纲目录。

第二轮再推进结构化内容和媒体：

1. `[done] ADV-008` 列表模型与命令增强。
2. `[done] ADV-009` 代码块语言与工具条。
3. `[done] ADV-010` Callout 类型增强。
4. `[done] ADV-011` 表格浮动工具。
5. `[done] ADV-013` 文件附件块。
6. `[done] ADV-014` 链接编辑与自动识别 URL。
7. `[done] ADV-015` mention、emoji、formula。

第三轮推进文档级能力、协作预留和发布：

1. `[done] ADV-018` 文档统计。
2. `[done] ADV-019` 自动保存状态与示例。
3. `[done] ADV-021` Markdown/HTML import/export 完善。
4. `[done] ADV-022` PDF/DOCX 方案设计。
5. `[done] ADV-023` 评论线程。
6. `[done] ADV-025` 协作 adapter。
7. `[done] ADV-027` 插件 API 收敛。
8. `[done] ADV-028` Golden 与 benchmark 补齐。
9. `[done] ADV-030` 发布文档。

## 风险与控制

- Markdown 快捷输入和自动格式化必须可撤销，否则会破坏用户信任。
- 粘贴清洗不能直接信任 HTML，需要白名单解析和 schema normalize 双重保护。
- Slash 菜单不应直接修改文档，应转成命令执行。
- 媒体上传不应绑定到核心包，核心只保留 resolver/uploader 接口。
- 评论、修订、协作会影响 selection 与 JSON schema，需要先做模型设计再做 UI。
- PDF/DOCX 能力可能引入较重依赖，建议先写方案和 adapter，不急于进入核心依赖。

## 阶段完成定义

每个阶段完成时必须满足：

- 有可运行 example 或 demo。
- 有核心单元测试。
- 有 widget 测试或 golden 测试覆盖用户可见交互。
- 文档已更新。
- `flutter analyze` 通过。
- `flutter test` 通过。
- 新增 JSON 字段有 migration 或兼容策略。


