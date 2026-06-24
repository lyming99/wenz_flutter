# 手动验收清单（Win / Web / Android）

> 配套 `docs/acceptance_report.md` Part 4 第 5 条：手验项三端各勾一遍。
> 自动化测试覆盖不到的"手感/视觉/平台差异"在这里逐项确认。

## 约定

- 三端各跑一次 `example/`（Windows 桌面 / Chrome / Android 设备或模拟器）。
- 通过 `[x]`，未通过 `[ ]` 并在「备注」写复现路径。
- 每个任务 ID 对应验收报告 Part 2 的同 ID 任务。

---

## ADV-016 · Block embed 与业务 renderer 注入

操作：运行 `example/`，确认初始文档里的 CRM card block；点击工具栏 `Insert CRM embed`；导出 HTML/Markdown，重新加载 HTML demo 或通过业务入口调用 `loadHtml`。

| 端 | CRM card 初始可见 | 插入按钮可新增 | HTML round-trip 保留卡片 | Markdown 可读降级 | 备注 |
|----|------------------|----------------|--------------------------|-------------------|------|
| Windows | [ ] | [ ] | [ ] | [ ] | |
| Web (Chrome) | [ ] | [ ] | [ ] | [ ] | |
| Android | [ ] | [ ] | [ ] | [ ] | |

预期：
- CRM card 使用业务 renderer 展示 title、owner、stage，而不是默认占位。
- 新增 block 可被选中，debug overlay 打开时仍有对象块几何信息。
- rich JSON/HTML 保留 `embedType/data/fallbackText`；Markdown/plain text 输出可读 fallback。
- 业务 renderer 注入不影响普通段落输入、undo/redo 和滚动。

---

## ADV-018 · 文档统计侧栏

操作：运行 `example/`，查看右侧 Document 区域；输入英文、中文、emoji/mention/formula，并撤销一次。

| 端 | 字数实时更新 | 字符数实时更新 | 阅读时间更新 | undo 后恢复 | 备注 |
|----|-------------|---------------|--------------|-------------|------|
| Windows | [ ] | [ ] | [ ] | [ ] | |
| Web (Chrome) | [ ] | [ ] | [ ] | [ ] | |
| Android | [ ] | [ ] | [ ] | [ ] | |

预期：
- Document 区域显示 Blocks、Paragraphs、Headings、Images、Words、Characters、Text chars、Read time。
- 输入或撤销后统计跟随文档变化，单纯移动光标不改变统计。
- formula / mention / emoji 使用可读文本降级参与统计，不写入额外 schema 字段。

---

## ADV-019 · 自动保存状态与草稿示例

操作：运行 `example/`，查看右侧 Autosave 区域；输入文本、等待防抖保存、点击 Save now，并模拟撤销回 clean 内容。

| 端 | dirty 状态变化 | scheduled/saving/clean 可见 | Save now 可触发 | 草稿字节数更新 | 备注 |
|----|----------------|-----------------------------|-----------------|----------------|------|
| Windows | [ ] | [ ] | [ ] | [ ] | |
| Web (Chrome) | [ ] | [ ] | [ ] | [ ] | |
| Android | [ ] | [ ] | [ ] | [ ] | |

预期：
- 输入后 Autosave 显示 dirty/scheduled，等待约 1 秒后进入 saving/clean。
- 单纯移动光标不改变 revision 或 dirty state。
- Save now 通过外部草稿 adapter 保存当前 rich JSON，失败时应保留 dirty/error 供业务重试。
- 自动保存状态不写入文档 JSON schema，草稿恢复仍通过 `loadJson` / `tryLoadJson`。

---

## ADV-023 · 评论线程侧栏

操作：在宿主页面嵌入 `WenzCommentSidebar`，传入含 open/resolved 的 `CommentThread` 列表；点击线程卡片和定位按钮，把回调 selection 交给 `WenzRichTextController.setSelection`。

| 端 | open/resolved 可见 | 点击线程回调 selection | resolve/reopen 回调触发 | rich JSON 恢复评论 | 备注 |
|----|--------------------|------------------------|--------------------------|--------------------|------|
| Windows | [ ] | [ ] | [ ] | [ ] | |
| Web (Chrome) | [ ] | [ ] | [ ] | [ ] | |
| Android | [ ] | [ ] | [ ] | [ ] | |

预期：
- 侧栏展示 Comments 标题、open/total 计数、消息作者和摘要。
- 点击线程或定位按钮后，宿主能用返回的 `DocumentSelection` 定位到评论范围。
- resolve/reopen 不直接改文档，由宿主或后续 comment command 负责替换 `RichTextDocument.comments`。
- rich JSON round-trip 后 `comments` 与 inline `commentIds` 保持一致。

---

## ADV-024 · 修订模式模型与命令

操作：开启 `WenzRichTextController.setRevisionMode(true, authorId: ..., authorName: ...)`，在同一段文本内执行插入、选择删除、选择格式化，然后分别调用 `acceptRevision` / `rejectRevision`。

| 端 | 插入生成 revision | 删除标记可接受/拒绝 | 格式修订可拒绝还原 | rich JSON 恢复修订 | 备注 |
|----|-------------------|----------------------|--------------------|--------------------|------|
| Windows | [ ] | [ ] | [ ] | [ ] | |
| Web (Chrome) | [ ] | [ ] | [ ] | [ ] | |
| Android | [ ] | [ ] | [ ] | [ ] | |

预期：
- rich JSON round-trip 后 `revisions` 与 inline `revisionIds` 保持一致。
- 接受插入保留正文并清除 inline 修订标记；拒绝插入移除插入正文。
- 接受删除移除被标记文本；拒绝删除保留文本并清除 inline 修订标记。
- 跨块、表格、修订侧栏和可视化渲染暂不作为本轮手验范围。

---

## ADV-025 · 协作 adapter 接口

操作：在宿主示例或业务 demo 中接入一个内存/测试 `WenzCollaborationAdapter`，实例化 `WenzCollaborationController` 并连接同一个 `WenzRichTextController`。

| 端 | 本地变更发布 | 远端快照应用不回声 | remote selection 可渲染 | 不写入 rich JSON | 备注 |
|----|--------------|--------------------|-------------------------|----------------|------|
| Windows | [ ] | [ ] | [ ] | [ ] | |
| Web (Chrome) | [ ] | [ ] | [ ] | [ ] | |
| Android | [ ] | [ ] | [ ] | [ ] | |

预期：
- 输入正文后 adapter 收到 `WenzLocalDocumentChange`，包含 rich JSON、local revision、selection 和 `changedBlockIds`。
- 远端 `WenzRemoteDocumentUpdate` 通过 controller 应用到文档，但不会再次发布为本地变更。
- 远端 `WenzRemoteSelectionUpdate` 出现在 `remoteSelections`，clear 事件会移除对应 client。
- remote cursor、presence、房间和后端 revision 不进入 `RichTextDocument.toJson()`。

---

## B1 · 双击选词 / 三击选段

操作：在段落文本上双击（选词）、三击（选整段）、双击后拖拽（按词扩选）。

| 端 | 双击选词 | 三击选段 | 双击+拖拽按词扩选 | 备注 |
|----|---------|---------|------------------|------|
| Windows | [ ] | [ ] | [ ] | |
| Web (Chrome) | [ ] | [ ] | [ ] | |
| Android | [ ] | [ ] | [ ] | |

预期：
- 双击在英文单词上选中整个词（如 `hello world` 双击 `hello` 选中 0..5）。
- 双击在中文上选中一个字或一个词段（依平台 locale 分词，单测已验证不串到相邻词）。
- 三击选中整段（block 全文，含多行）。
- 自动化：`block_geometry_registry_test.dart` word/paragraph boundary 9 例 + widget 双击/三击 2 例。

---

## B2 · 拖拽自动滚动

操作：鼠标按住拖到视口顶部/底部边缘附近（48px 带）并停留。

| 端 | 鼠标拖底边停留→持续下滚 | 鼠标拖顶边停留→持续上滚 | 松开→停止 | 备注 |
|----|------------------------|------------------------|----------|------|
| Windows | [ ] | [ ] | [ ] | |
| Web (Chrome) | [ ] | [ ] | [ ] | |
| Android（触控笔/鼠标） | [ ] | [ ] | [ ] | 触屏手指拖走 selection handles（C9）路径 |

预期：
- 鼠标拖到底部边缘停留：列表持续向下滚动，指针不动也滚。
- 鼠标拖到顶部边缘停留：列表持续向上滚动。
- 松开鼠标：滚动立即停止。
- 触屏手指拖拽：每次拖动同步推进列表（同步边缘滚动），但不触发持续 ticker（触屏选区跨视口由 C9 handles 处理）。
- 自动化：`wenz_rich_text_editor_test.dart` `auto-scroll on drag` group 3 例（底边/顶边/释放停止）。

---

## A1 · IME 三端手验

操作：在普通段落和表格 cell 内分别输入中文拼音、五笔、日文；测试组合区、候选提交、退格、选区替换。

| 端 | 中文拼音 | 五笔 | 日文 | 表格 cell 输入 | 备注 |
|----|----------|------|------|---------------|------|
| Windows 微软输入法 | [ ] | [ ] | [ ] | [ ] | |
| Windows 第三方输入法 | [ ] | [ ] | [ ] | [ ] | 候选框位置问题需与 Flutter `TextField` 对照 |
| Web (Chrome) | [ ] | [ ] | [ ] | [ ] | |
| Android | [ ] | [ ] | [ ] | [ ] | |

预期：
- composing region 只给正在组合的文本加下划线。
- 候选提交后 composition 清空，undo 粒度合理。
- stale offset / 非 delta fallback 不造成重复字或错位删除。
- 第三方 IME 若 Flutter `TextField` 同样复现候选框偏移，记录为 Flutter Windows engine 兼容限制。

---

## B3 · 合并单元格视觉横跨

操作：插入表格，分别测试横向合并、纵向合并、2×2 合并、拆分恢复、合并后点击与选区高亮。

| 端 | 横向合并占满 | 纵向合并占满 | 2×2 合并占满 | covered cell 不渲染 | 拆分恢复 | 备注 |
|----|-------------|-------------|--------------|---------------------|----------|------|
| Windows | [ ] | [ ] | [ ] | [ ] | [ ] | |
| Web (Chrome) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| Android | [ ] | [ ] | [ ] | [ ] | [ ] | |

预期：
- origin cell 根据 `rowSpan` / `columnSpan` 真正跨行跨列占满。
- covered cell 不参与绘制和点击命中。
- 合并/拆分后 JSON round-trip、undo/redo 不丢结构。

---

## ADV-029 · 可访问性屏幕阅读器与高对比

操作：开启平台屏幕阅读器或浏览器辅助功能，聚焦编辑器、移动到段落/图片/表格 cell，并在高对比模式下用键盘聚焦编辑器。

| 端 | 编辑器 label/hint | readOnly 文案 | block/table 语义 | 高对比焦点框 | 备注 |
|----|-------------------|---------------|------------------|--------------|------|
| Windows Narrator | [ ] | [ ] | [ ] | [ ] | |
| Web (Chrome) | [ ] | [ ] | [ ] | [ ] | |
| Android TalkBack | [ ] | [ ] | [ ] | [ ] | |

预期：
- 编辑器整体被读作可聚焦、多行 text field，并读出业务配置的 label/hint。
- read-only 模式读出只读文档语义，不提示可编辑。
- 段落、标题、图片、代码块、表格和合并 cell 能读出类型/行列/span/选中态。
- `MediaQuery.highContrast` 开启且编辑器聚焦时出现高对比边框，失焦后消失。

---

## C9 · 移动端 selection handles

操作：在 Android/iOS 触屏上长按或拖拽手柄修改选区，覆盖普通段落、跨块和表格 cell。

| 端 | 普通文本手柄 | 跨块拖拽 | 表格 cell | 边缘滚动 | 备注 |
|----|-------------|----------|-----------|----------|------|
| Android | [ ] | [ ] | [ ] | [ ] | |
| iOS | [ ] | [ ] | [ ] | [ ] | |

预期：
- 手柄拖拽只修改 selection，不意外输入或破坏 composition。
- 跨块与表格 cell 仍使用统一 `DocumentSelection` / `PositionPath` 语义。
- 拖到视口边缘时能继续扩展选区或明确记录限制。
