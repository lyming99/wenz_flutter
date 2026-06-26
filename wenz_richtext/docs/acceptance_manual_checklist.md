# 手动验收清单（Win / Web / Android）

> 配套 `docs/acceptance_report.md` Part 4 第 5 条：手验项三端各勾一遍。
> 自动化测试覆盖不到的"手感/视觉/平台差异"在这里逐项确认。

## 约定

- 三端各跑一次 `example/`（Windows 桌面 / Chrome / Android 设备或模拟器）。
- 通过 `[x]`，未通过 `[ ]` 并在「备注」写复现路径。
- 每个任务 ID 对应验收报告 Part 2 的同 ID 任务。

---

## FB-006-P006 · 表格悬浮工具栏 Overlay 验收记录

来源：反馈 6 / P006。`docs/plan/plan_feedback_6_20260625-035040.md` 是 AutoPlan 只读上下文，本节仅记录本任务补充的自动化覆盖、手工验收入口与当前遗留风险。

| 覆盖项 | 自动化记录 | 结论 |
|--------|------------|------|
| Overlay 承载与取消选区清理 | `table floating toolbar renders in overlay and clears selection` 断言工具栏位于 `Overlay` / `OverlayPortal` 链路中，且不挂在表格 cell 节点内；`controller.setSelection(null)` 后 overlay 移除 | 通过 |
| 按钮点击不穿透 | `table floating toolbar pointer does not penetrate selection layer` 覆盖按钮命中链路包含 toolbar blocker，且不进入编辑器级 selection listener；按钮点击只插入一行 | 通过 |
| 工具栏外仍可编辑 | `table floating toolbar leaves outside text editing available` 覆盖表格工具栏显示时点击后续段落并输入文本，外部编辑不被 overlay 阻塞 | 通过 |
| 滚动后跟随选区 | `table floating toolbar follows the selected cell while scrolling` 覆盖 scroll position 更新后工具栏与选中 cell 同步上移并维持约 `4px` 间距 | 通过 |
| 生命周期与表格命令回归 | 复用 `table floating toolbar edits rows columns and cells`、`table floating toolbar follows active table lifecycle` 覆盖表格命令、活动表格切换、跨表格选区隐藏和表格删除清理 | 通过 |

验证命令：
- `flutter test test/widgets/wenz_rich_text_editor_test.dart --name "^table floating toolbar (edits rows columns and cells|follows active table lifecycle|renders in overlay and clears selection|follows the selected cell while scrolling|leaves outside text editing available|pointer does not penetrate selection layer)$" --reporter expanded`：通过，`+6`。
- `flutter analyze`：通过，`No issues found!`。
- 全量测试：未运行；本任务只要求表格 toolbar overlay 的最小相关 widget 回归与 analyze。

手工验收：运行 `example/`，插入或选中表格 cell，覆盖普通视口、靠近视口顶部、滚动中和取消选区场景。

| 端 | Overlay 显示 | 按钮不穿透 | 工具栏外可编辑 | 滚动跟随 | 取消选区消失 | 备注 |
|----|--------------|------------|----------------|----------|----------------|------|
| Windows | [ ] | [ ] | [ ] | [ ] | [ ] | |
| Web (Chrome) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| Android | [ ] | [ ] | [ ] | [ ] | [ ] | |

预期：
- 工具栏显示在系统 overlay 中，靠近视口顶部时保持可见，不被表格父级裁剪。
- 点击工具栏按钮、背景、分隔线和空白区域不触发表格 cell 聚焦、文本选区或底层拖拽。
- 点击工具栏外的段落或表格 cell 仍可移动光标、输入文本和滚动编辑器。
- 滚动编辑器后工具栏跟随当前选中表格；取消表格选区、切换到非表格 block 或删除表格后 overlay 消失。

遗留风险与后续建议：
- 本轮补充了 overlay 承载、事件隔离、外部编辑、滚动跟随与生命周期自动化；真实三端仍需确认高 DPI、浏览器缩放、触屏滚动和平台手势差异。
- 扩展抽查包含既有几何用例 `table floating toolbar sits above the table cells`、`table floating toolbar keeps compact theme close to cells`、`table floating toolbar clamps to viewport top when close` 时仍失败；失败集中在旧断言要求 toolbar 始终位于 cell 上方且固定 `4px` 间距，而当前 overlay 顶部 clamp 场景会把 toolbar 保持在可见区域内。该风险未在 P006 中修改实现，建议后续结合 P003/P004 的定位策略决定修正实现还是更新旧几何期望。

---

## FB-004-P005 · 公式 / todo / 表格视觉回归记录

来源：反馈 4 / P005。`docs/plan/plan_feedback_4_20260625-024854.md` 由 AutoPlan 统一回写，本节仅记录本任务的验证范围、命令结果和未覆盖风险。

| 覆盖项 | 自动化记录 | 结论 |
|--------|------------|------|
| 公式同行居中 | `feedback #4 visual regressions keep formula todo and toolbar metrics` 覆盖中文、英文、emoji 同行普通公式中心偏移 | 通过，中心偏移阈值 `±0.75px` |
| 高公式行高兜底 | 同一用例覆盖高公式高度、公式所在行实际渲染高度与中心对齐 | 通过，高公式不裁剪且高度小于 `48px` |
| todo checkbox 首行对齐 | 同一用例覆盖单行 / 多行 todo checkbox 与首行中心偏移 | 通过，中心偏移阈值 `±0.75px` |
| 多行 todo 缩进 | 同一用例覆盖 wrapped todo 多行 `LineMetrics.left` 一致，且文本起点不压住 checkbox | 通过，续行缩进保持一致 |
| 表格工具栏贴近顶部 | 同一用例与既有 toolbar 用例覆盖选中表格 cell 后工具栏间距 | 通过，toolbar 与 cell 顶部间距约 `4px` |

验证命令：
- `flutter analyze`：通过，`No issues found!`。
- `flutter test test/widgets/wenz_rich_text_editor_test.dart --plain-name "feedback #4 visual regressions keep formula todo and toolbar metrics"`：通过，`+1`。
- `flutter test test/widgets/wenz_rich_text_editor_test.dart --name "(table floating toolbar (sits above|keeps compact|clamps)|keeps inline formulas centered|aligns todo checkbox|feedback #4 visual regressions)"`：通过，`+6`。
- 全量测试：未运行；本任务只要求当前反馈视觉回归的最小相关验证，未发现需要扩大到全量套件的失败信号。

未覆盖风险与后续建议：
- 真实 Windows / Web / Android 的字体栅格化、设备像素比和平台 checkbox 原生绘制差异仍需按本清单手验抽样确认。
- 本次未更新 golden 图片；视觉回归以 widget 几何断言锁定关键偏移，后续如推进综合 golden，可将该组合场景纳入 `test/widgets/goldens/`。

---

## REQ-010-P001 · 标题折叠交互规则

来源：需求 10 / P001。实现侧规则记录在 `WenzOutlineController` 与 `WenzRichTextEditor` 注释中；本条只确认交互契约，不要求提前完成折叠状态模型或可见 block 投影视图。

| 验收项 | 结论 | 备注 |
|--------|------|------|
| 只有顶层 `heading` block 展示折叠入口 | [ ] | 段落、引用、列表、代码、表格、媒体和对象块不展示入口 |
| 折叠范围按标题 level 截止 | [ ] | `H2` 到下一个 `H1/H2` 前；`H3` 到下一个 `H1/H2/H3` 前 |
| 空标题或无子内容标题不可折叠 | [ ] | 可不展示入口或展示禁用态，但不得隐藏内容 |
| 只读模式可切换折叠视图 | [ ] | 切换只影响视图，不修改文档 JSON / HTML / Markdown |
| 编辑模式折叠状态不进 undo/redo | [ ] | 撤销/重做只回滚文档编辑，不回滚折叠展开状态 |

预期：
- 折叠是编辑器视图状态，不删除、不移动、不改写任何 block。
- 被折叠内容的隐藏、命中测试、滚动定位和嵌套折叠优先级由后续 P002-P004 落地，本条只固定规则边界。

---

## REQ-013-P001 · 大纲折叠范围与交互规则

来源：需求 13 / P001。`docs/plan/plan_requirement_13_20260626-024112.md` 是 AutoPlan 只读上下文，本节仅明确范围与交互验收口径，不勾选 plan checkbox，不提前覆盖 P002-P007 的状态模型、可见投影、视觉回归或导入导出任务。

| 验收项 | 结论 | 备注 |
|--------|------|------|
| 只有顶层 `BlockType.heading` 行显示左侧折叠入口 | [ ] | 普通段落、列表、引用、代码块、表格、图片、视频、文件、分割线等非标题行不显示入口 |
| 折叠范围按 H1-H6 标题层级计算 | [ ] | `H1` 覆盖到下一个 `H1` 前；`H2` 覆盖到下一个 `H1/H2` 前；以此类推到 `H6` |
| 低级标题和普通内容纳入父标题范围 | [ ] | 父标题范围内的低级标题、文本块、对象块和媒体块都属于被覆盖内容 |
| 无子内容标题为空范围 no-op | [ ] | 标题后紧跟同级/更高级标题，或标题位于文档末尾时，按钮禁用或点击不隐藏任何 block |
| 空文档与空标题安全处理 | [ ] | 空文档不显示入口；空标题不作为有效大纲折叠目标，避免生成可隐藏范围 |
| 连续标题与嵌套标题边界清晰 | [ ] | 连续同级标题互不覆盖；嵌套低级标题归属最近的高一级范围，并按自身层级计算子范围 |

交互边界：
- 折叠按钮是标题行左侧行级入口，切换仅改变编辑器视图状态，不删除、不移动、不改写任何 document block。
- 非标题行不预留折叠按钮命中区；标题无有效子内容时保持禁用或 no-op，不应触发文本选区、链接点击、IME 输入、行拖拽或对象块工具栏。

---

## REQ-013-P007 · 自动化与视觉回归验证

来源：需求 13 / P007。`docs/plan/plan_requirement_13_20260626-024112.md` 是 AutoPlan 只读上下文，本节只记录当前任务的自动化、golden 和手工验收入口，不勾选 plan checkbox，不更新进度区。

| 覆盖项 | 自动化记录 | 结论 |
|--------|------------|------|
| H1-H6 与边界范围 | `outline_controller_test.dart` 覆盖 H1-H6、多级嵌套、连续标题、空标题、无子内容标题、文档首尾标题和父子同时折叠投影 | 通过 |
| 动态编辑后重算 | `recomputes ranges after heading delete level change and move` 与 `recomputes first and tail heading ranges after dynamic edits` 覆盖删除、层级变化、移动、首尾插入/删除后的范围和失效折叠清理 | 通过 |
| widget 交互回归 | `wenz_rich_text_editor_test.dart` 覆盖折叠按钮点击、Enter/Space 键盘激活、隐藏 block 不命中、展开后选区恢复、查找命中隐藏内容、大纲跳转和只读模式切换 | 通过 |
| 视觉回归 | `editor_golden_test.dart` 的 `golden: paragraph code and image placeholder` 更新 `editor_blocks.png`，覆盖展开态、折叠态、禁用态、hover/focus 态以及与左侧拖拽把手相邻布局 | 通过 |

验证命令：
- `flutter test test/controller/outline_controller_test.dart --reporter expanded`：通过，`+14`。
- `flutter test test/widgets/wenz_rich_text_editor_test.dart --name "^(renders heading collapse affordance and toggles by keyboard|read-only mode toggles heading collapse without editing|programmatic selection in hidden block expands its heading|Delete at collapsed heading boundary expands before editing|tap at a hidden block position does not target hidden content|find match inside hidden content expands and restores selection|outline jump to hidden heading reveals it and moves selection)$" --reporter expanded`：通过，`+7`。
- `flutter test test/widgets/editor_golden_test.dart --plain-name "golden: paragraph code and image placeholder" --update-goldens --reporter expanded`：通过，`+1`，用于同步 `editor_blocks.png`。
- `flutter test test/widgets/editor_golden_test.dart --plain-name "golden: paragraph code and image placeholder" --reporter expanded`：通过，`+1`。

手工验收：运行 `example/`，准备至少包含 H1-H6、多级嵌套、连续标题、叶子标题和只读切换的文档，按三端抽样确认视觉与手势。

| 端 | 展开/折叠按钮 | 禁用态 | Hover/Focus | 隐藏内容不命中 | 只读可切换 | 备注 |
|----|----------------|--------|-------------|----------------|------------|------|
| Windows | [ ] | [ ] | [ ] | [ ] | [ ] | |
| Web (Chrome) | [ ] | [ ] | [ ] | [ ] | [ ] | |
| Android | [ ] | [ ] | [ ] | [ ] | [ ] | |

预期：
- 标题左侧折叠按钮与左侧拖拽把手保持独立命中区；hover、focus、禁用态和折叠计数在不同 DPI / 缩放下不遮挡标题文本。
- 折叠后被隐藏 block 不响应点击、拖拽、选区、对象工具栏或媒体 resolver；展开、查找命中和大纲跳转后选区回到可见目标。
- 只读模式下仍允许切换折叠视图，但不写入文档 JSON / Markdown / HTML，不产生 undo 记录。

---

## ADV-030 · 富文本设计稿样式基线

来源：`ui/richtext_design.html`。实现侧基线记录在 `WenzRichTextDesignBaseline`，用于后续 P002-P008 对齐默认渲染；其中 P008 已补齐综合排版 golden 与必要 widget 记录，不新增 block 类型，不改变 JSON / Markdown / HTML 编解码协议。

| 验收项 | 结论 | 备注 |
|--------|------|------|
| 默认 renderer 覆盖仍等于现有 `BlockType.values` | [ ] | `paragraph/heading/quote/listItem/code/image/table/divider/video/embed/callout/file` |
| `BlockRendererRegistry` 外部覆盖能力不变 | [ ] | `register/registerEmbed/resolveForBlock` 仍是业务接入点 |
| `InlineEmbedRenderer` 外部接管能力不变 | [ ] | mention/formula/image 等默认样式后续只做 fallback 优化 |
| 文档模型与导入导出协议不变 | [ ] | 本需求只优化默认视觉，不改 schema/codec/command 数据结构 |
| golden 覆盖缺口已标记 | [x] | 综合排版 golden 已在 P008 更新，见 `editor_advanced_blocks.png` |

设计稿 token 摘要：
- 颜色：`primary #4f6df5`、`surface #fbfaff`、`surface-container #f2f0f7`、`on-surface #1b1b21`、`on-surface-variant #46464f`、`outline #777680`、`blue-link #1976d2`、`code-bg #1e1e2e`、`code-text #e6e6f0`。
- 圆角/阴影：主圆角 `12px`，小圆角 `8px`，chip `6px`；卡片阴影为 `0 1px 3px rgba(20,20,40,.08)` + `0 1px 2px rgba(20,20,40,.06)`。
- 字号/行高：正文 `16px / 1.75`；H1-H4 为 `24/21/18/16px`；代码块 `13.5px / 1.6`；表格 `15px`；caption/元信息 `13px`；语言标签 `11px`。
- 间距：段落 `.55em`；常规块 `1em`；媒体块 `1.2em`；分割线 `1.6em`；列表左缩进 `26px`；引用 `8x18px`；代码 `18x20px`；表格 cell `10x14px`。
- 状态：todo 完成态弱化 + 删除线；文件 hover/focus 使用主色边框 + 阴影；callout 覆盖 info/success/warning/danger；embed/formula/mention 使用 chip 或 pill fallback。

当前默认渲染差异基线：

| 元素 | 当前覆盖 | 后续处理分类 |
|------|----------|--------------|
| 正文/行内属性 | 文本属性、链接色、颜色/高亮/字号/字体已走 `TextStyle` | P002 调样式；高亮 padding/圆角和 remark dotted 下划线需 Flutter 等价方案 |
| 行内嵌入 | mention/formula 有默认 `TextSpan` fallback，业务可接管 | P002/P006 补 pill 视觉与 inline image 占位 golden |
| 标题 | H1-H4 尺寸已接近设计稿，H5/H6 弱化缺失 | P003 调权重/颜色/上下间距 |
| 对齐/缩进 | alignment 与 indent 已存在，缩进当前为 `24px` | P003 只调视觉基线，不改选择/滚动逻辑 |
| 引用/列表/todo | 引用、列表 marker、checkbox 和完成态已渲染 | P004 改左边框引用、列表节奏、task 首行对齐 |
| 代码/分割线/callout | 代码块、分割线、callout 四变体已有结构 | P005 改暗色代码、分割线圆点、callout 精确 token |
| 图片/视频/文件/embed | 对象块 fallback、工具条、媒体 resolver 接入已存在 | P006 补 figure/card/preview/chip 视觉与 golden |
| 表格 | 表格模型、合并 cell、列宽拖拽和 toolbar 已存在 | P007 只调表格视觉，不改表格命令协议 |
| golden | 已有基础 block、合并表格、选区、光标、advanced blocks | P008 已更新综合排版 golden（`editor_advanced_blocks.png`）与必要 widget 覆盖 |

### P008 验证记录

| 覆盖项 | 自动化记录 | 结论 |
|--------|------------|------|
| 综合排版 golden | `test/widgets/editor_golden_test.dart` 的 `golden: advanced blocks and inline embeds` 覆盖标题、callout、列表、代码、图片、文件、表格与 inline embed 组合；基线图 `test/widgets/goldens/editor_advanced_blocks.png` 已同步 | 通过，baseline 已更新 |
| 关键 widget 回归 | `test/widgets/wenz_rich_text_editor_test.dart` 的 `todo checkbox toggles checked state without selecting text`、`object block toolbar copies duplicates moves and deletes`、`table floating toolbar edits rows columns and cells`、`paragraph inline embeds select atomically by tap drag keyboard`、`feedback #4 visual regressions keep formula todo and toolbar metrics` | 通过，选区命中、对象块选择、表格操作、todo 交互和公式/工具栏基线未回归 |
| MediaResolver fallback | `test/widgets/media_resolver_test.dart` 的 `resolver returning null falls back to placeholder`、`video resolver returning null falls back to placeholder` 和 `a throwing resolver falls back to placeholder, no crash` | 通过，返回 `null` 和抛异常时均回落到 placeholder 且不崩溃 |

验证命令：
- `flutter test test/widgets/editor_golden_test.dart --plain-name "golden: advanced blocks and inline embeds" --reporter expanded`：通过，`+1`。
- `flutter test test/widgets/wenz_rich_text_editor_test.dart --name "^(todo checkbox toggles checked state without selecting text|object block toolbar copies duplicates moves and deletes|table floating toolbar edits rows columns and cells|paragraph inline embeds select atomically by tap drag keyboard)$" --reporter expanded`：通过，`+4`。
- `flutter test test/widgets/media_resolver_test.dart --name "MediaResolver injection.*(resolver returning null falls back to placeholder|a throwing resolver falls back to placeholder, no crash)" --reporter expanded`：通过，`+3`。

未覆盖风险与后续建议：
- 真实 Windows / Web / Android 的字体栅格化、设备像素比和原生控件绘制差异仍需按清单手验抽样确认。
- 本次未扩大到全量 `flutter test`；当前只跑与 P008 直接相关的 golden / widget / fallback 最小集。

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
