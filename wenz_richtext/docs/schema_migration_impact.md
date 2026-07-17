# Schema impact and JSON migration plan

本文档对应 `ADV-002`，用于在继续开发进阶功能前固定 schema 决策边界：哪些能力复用现有模型，哪些能力需要新增 JSON 字段，以及新增字段时必须补哪些 migration、codec 和测试入口。

## Current baseline

- **Canonical rich JSON**：顶层对象包含 `version` 与 `blocks`；`RichTextJsonCodec.encode` 写出当前模型，`RichTextJsonCodec.decode` 可通过可选 `DocumentMigrationRegistry` 在模型反序列化前迁移旧版本。
- **Current migration target**：`DocumentMigrationRegistry.currentVersion` 默认为 `2`；已提供 `V1ToV2DocumentMigration`，负责补齐缺失 block `id` 并规范化旧 `listType`。
- **Normalizer boundary**：`DocumentSchema.normalize` 是命令执行和 controller 加载后的修复边界，负责空文档兜底、文本块 attrs 规范化、表格空 cell 兜底、缩进约束，以及 `BlockEmbedNode.embedType/fallbackText` 规范化。
- **Codec boundary**：Markdown/HTML/PlainText codec 只映射已有模型字段；无法稳定 round-trip 的内容必须明确降级，而不是引入 codec 专用 schema。

## Schema bump rules

| 变更类型 | 是否 bump JSON version | 必做事项 |
| --- | --- | --- |
| 新增可选字段且旧 JSON 可按默认值安全读取 | 通常不 bump | `fromJson` 默认值、`toJson` 省略空值、schema normalize 保持幂等、codec 降级策略。 |
| 字段重命名、删除、语义改变或默认值改变 | 必须 bump | 新增 `DocumentMigration`、注册链路示例、旧 JSON fixture、迁移单测。 |
| 新增 core block type | 通常 bump | `BlockType`/`BlockNode.fromJson`/renderer/command/codec 策略、未知或旧数据降级说明。 |
| 新增 inline embed 约定 | 不一定 bump | 优先复用 `InlineEmbed.embedType + data`；只有改变既有 embed 语义才 bump。 |
| 新增 document metadata | 通常 bump 或外部化 | 明确 metadata 是否随正文保存；外部状态不写入 rich JSON。 |
| 仅新增 controller、toolbar、resolver、adapter、plugin runtime 状态 | 不 bump | 状态由业务层或 controller 派生，不进入 document JSON。 |

## Feature impact matrix

| 功能/任务 | 当前 schema 影响 | Migration 决策 | Codec/降级策略 |
| --- | --- | --- | --- |
| Markdown 快捷输入、快捷键、粘贴、查找替换、Slash 菜单 | 无新增字段 | 不 bump；全部落到既有命令和 schema normalize | 粘贴输入通过 Markdown/HTML codec 后仍进入现有模型。 |
| 列表增强 | 复用 `BlockAttributes.listType/checked/indent` | 已由 v1→v2 处理旧 `unordered`/`li`；后续编号样式才评估 bump | Markdown/HTML 列表映射现有 attrs。 |
| 代码块语言、Callout 类型、图片 caption/alt/尺寸、文件附件 | 已有可选字段或已完成兼容字段 | 当前不新增 bump；继续通过默认值读取旧 JSON | Markdown/HTML 能 round-trip 的字段保留，不能表达的字段可读降级。 |
| 链接编辑、自动 URL、mention/formula/emoji | 链接复用 `TextAttributes.url`；内联对象复用 `InlineEmbed` | 不 bump；仅约定 `embedType` 与 `data` key | Markdown/HTML 对 embed 以可读文本或图片降级，不承诺还原 embed。 |
| 大纲、文档统计、自动保存 dirty state、权限态 | 从文档派生或外部 controller 状态 | 不 bump；不写入 rich JSON | 无 codec 字段。 |
| 版本快照 | 外部存储快照元信息 | 核心不 bump；只保存 rich JSON 快照 | 由业务 adapter 持久化。 |
| Block embed 与业务 renderer | `[done] ADV-016` 新增通用 `BlockType.embed` / `BlockEmbedNode(embedType,data,fallbackText)`，业务 renderer 注册不写入 schema | 当前作为 additive pre-1.0 模型扩展不 bump；旧版本无法识别时会按旧 `BlockType.parse` 降级为 paragraph，正式稳定版前如再新增 core block type 需重新评估 bump | rich JSON 与 HTML round-trip；Markdown/plain text 可读降级；业务 renderer 通过 `BlockRendererRegistry.registerEmbed` 注入。 |
| 链接预览卡片 | 可作为外部 custom block/embed；若内建则新增 block | 内建时需要 v3 migration 方案 | Markdown/HTML 至少降级为普通链接。 |
| Bookmark/document metadata | 可选核心 metadata | 若写入顶层 metadata，需要 v3 或明确可选兼容策略 | Markdown/HTML 通常不 round-trip metadata。 |
| 评论线程 | `[done] ADV-023` 使用可选顶层 `comments` 保存 `CommentThread`，inline run 通过 `TextAttributes.commentIds` 标记 anchor | additive optional 字段，不 bump；旧文档缺省空评论，新字段由 rich JSON round-trip 保留 | Markdown/HTML/plain text 仍只保留正文，评论元数据不跨格式导出。 |
| 修订模式 | `[done] ADV-024` 使用可选顶层 `revisions` 保存 `RevisionChange`，inline run 通过 `TextAttributes.revisionIds` 标记 pending 修订 | additive optional 字段，不 bump；旧文档缺省空修订，新字段由 rich JSON round-trip 保留 | Markdown/HTML/plain text 仍只保留正文，修订元数据不跨格式导出。 |
| 协作 adapter、remote cursor/selection | `[done] ADV-025` 不写入正文 schema；`WenzRemoteSelectionUpdate` 仅用于 adapter transport / renderer runtime | 不 bump；协作状态外部化 | 不进入 codecs；远端 presence/session 状态由业务 adapter 持久化或丢弃。 |
| 插件 API | `[done] ADV-027` 新增 `WenzRichTextPlugin`、runtime registry、toolbar descriptor、paste transformer | 不 bump；插件安装只修改运行时 registry，文档变更仍必须通过既有命令和模型 | 不进入 codecs；插件若定义新的 block/embed 持久语义，需按对应 block/embed 规则单独评估。 |
| PDF/DOCX import/export | adapter 能力 | 不因 adapter 本身 bump | 只映射现有模型；超出模型的布局信息降级。 |

## Required checklist for future schema changes

1. 更新模型：新增字段必须有默认值、`copy/copyWith`、`toJson/fromJson` 和 normalize 规则。
2. 更新 migration：若 bump version，新增一跳 `DocumentMigration`，并确保 registry 从旧版本可连续迁到当前版本。
3. 更新 codecs：rich JSON 必须 round-trip；Markdown/HTML/PlainText 要么 round-trip，要么写明可读降级。
4. 更新命令：用户可见变更必须通过命令层进入文档，保证 undo/redo 和 schema normalize 一致。
5. 更新测试：至少覆盖 model JSON、migration fixture、schema normalize、相关 command/controller，以及必要的 codec 降级。
6. 更新文档：同步 `advanced_feature_matrix.md`、`migration_guide.md`、`schema_and_commands.md`、API/architecture 文档和验收记录。

## ADV-002 decision

本轮评估结论：当前进阶任务中，已完成的高频编辑、列表、媒体、链接、inline/block embed、统计、自动保存、评论线程、修订基础模型和协作 adapter 能力不需要新的 schema bump；现有 rich JSON migration 框架可以覆盖未来破坏性变更。下一次最可能触发 version bump 的方向是内建链接预览卡片、顶层 document metadata 或跨块/表格级修订语义；这些任务进入编码前必须先提交独立 v3 schema 方案与 migration fixture。
