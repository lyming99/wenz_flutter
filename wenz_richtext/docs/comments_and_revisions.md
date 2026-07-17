# 评论与修订能力说明

更新时间：2026-06-24

## 当前状态

- `[done] ADV-023` 已提供评论线程模型、rich JSON 持久化和基础侧栏 UI。
- `[done] ADV-024` 已提供修订模式基础模型、同块文本修订命令、接受/拒绝命令和 controller 修订模式入口。
- 核心层不绑定实时协作服务、CRDT 或多人房间；后续由协作 adapter 承接。

## 评论模型

- `CommentAnchor` 保存 `blockId`、`blockIndex`、`PositionPath`、`startOffset`、`endOffset`，并通过 `selection` 映射回 `DocumentSelection`。
- `CommentEntry` 保存单条评论的 `id`、作者、正文、创建时间和可选更新时间。
- `CommentThread` 保存线程 `id`、anchor、messages、`open` / `resolved` 状态、创建/更新时间和可选 resolved 时间。
- `RichTextDocument.comments` 是可选顶层字段；旧文档缺省为空列表。
- `TextAttributes.commentIds` 是 inline anchor 标记，用于把文本 run 与线程 id 关联。

## 修订模型

- `RevisionRange` 保存 `blockId`、`blockIndex`、`PositionPath`、`startOffset`、`endOffset`，并可映射回 `DocumentSelection`。
- `RevisionChange` 保存修订 `id`、`insert/delete/format` 类型、`pending/accepted/rejected` 状态、作者、创建时间、接受/拒绝时间和可选格式前后属性。
- `RichTextDocument.revisions` 是可选顶层字段；旧文档缺省为空列表。
- `TextAttributes.revisionIds` 是 inline 修订标记，用于把文本 run 与 pending 修订关联。
- `InsertRevisionTextCommand`、`MarkDeletionRevisionCommand`、`MarkFormatRevisionCommand` 写入修订标记；`AcceptRevisionCommand` / `RejectRevisionCommand` 负责清理标记并应用或撤销同块文本修订。
- `WenzRichTextController.setRevisionMode` 是运行时开关；开启后 `insertText`、`deleteSelection`、`deleteBackward`、`deleteForward`、`formatText` 会优先走修订命令。

## UI 边界

- `WenzCommentSidebar` 渲染线程列表、open/resolved 状态和消息摘要。
- 点击线程或定位按钮会回调 `onRevealAnchor(thread, selection)`；业务侧可调用 `WenzRichTextController.setSelection(selection)` 完成跳转。
- resolve/reopen 按钮只发出回调，线程更新和文档替换由业务侧或未来 comment command 完成。
- inline 高亮、hover popover、评论输入 composer、修订侧栏和修订可视化渲染暂未内置。

## Codec 边界

- Rich JSON 保存并恢复 `comments` 与 inline `commentIds`。
- Rich JSON 保存并恢复 `revisions` 与 inline `revisionIds`。
- Markdown、HTML、plain text 仅保留正文内容，不导出评论线程或修订元数据。
- 评论与修订均为 additive optional schema，无需当前 migration bump；旧文档缺省为空列表。

## 验收入口

- `test/core/comment_model_test.dart` 覆盖 anchor selection 语义、inline `commentIds`、rich JSON round-trip 和 open/resolved helper。
- `test/core/revision_model_test.dart` 覆盖 revision selection 语义、inline `revisionIds`、rich JSON round-trip、插入/删除/格式修订命令、接受/拒绝和 controller 修订模式。
- `test/widgets/comment_sidebar_test.dart` 覆盖侧栏展示、点击定位回调、resolve/reopen 回调。
