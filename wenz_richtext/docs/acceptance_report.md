# Wenz RichText 验收报告

> 生成日期：2026-06-22
> 对应文档：`docs/optimization_roadmap.md`（阶段 0 ~ 阶段 8）
> 验收方法：roadmap 声明 + 源码/测试现状核对，状态以代码为准。

## 使用说明（checkbox 约定）

本文档所有验收点都用 `- [ ]` checkbox 列出，**逐项验收**：

- **勾选语义**：`[ ]` 待验收 / 验收未通过 → `[x]` 验收通过。
- **现状标记**（与勾选正交，描述客观实现状态）：
  - ✅ 已实现且有测试覆盖
  - 🟡 已实现但缺测试或体验不完整
  - 🔴 未实现或仅占位
  - ⚪ 暂不在当前阶段范围（预留/外部依赖）
- 验收流程：看「现状标记」判断要不要先开发 → 按「验收动作/验收标准」执行 → 通过后把 `[ ]` 改成 `[x]`。
- 每个任务 ID 建议对应一个 commit/PR，message 带前缀 `[accept-XXX]`。

---

## Part 1 · 模块功能验收清单

按模块归类的功能点，用于核对当前实现现状。

### 1. 文档模型层（Document Model）

- [ ] **1.1** Block 体系（paragraph/heading/quote/listItem/code/table/image/video/file/divider/callout）｜现状 ✅｜验收：`block_node.dart` 类型齐 + default renderers 全覆盖，example 渲染正常
- [x] **1.2** Inline 体系（TextRun + link/formula/mention/embed attributes）｜现状 ✅｜验收：TextRun/InlineEmbed 模型、link/embed 命令、formula/mention controller wrapper、默认渲染与 `InlineEmbedRenderer` 自定义 span contract 已落地（C8）
- [ ] **1.3** TableModel（cell/row/col/span/header/bg/width）｜现状 ✅｜验收：`table_model.dart` + 表格命令族完整 + JSON round-trip
- [ ] **1.4** Schema/normalizers｜现状 🟡｜验收：逐条核验"空文档保 paragraph / cell 内结构约束 / 非法 block 自动修正"用例
- [ ] **1.5** DocumentSelection / PositionPath 三形态 + 结构化排序｜现状 ✅｜验收：`document_position_test.dart` 全绿
- [ ] **1.6** 跨 block / 跨表格 cell selection 模型｜现状 ✅｜验收：selection_model.md §5 对应命令链已接入
- [x] **1.7** 评论线程模型与 inline anchor｜现状 ✅｜验收：`comment_model_test.dart` 覆盖 `RichTextDocument.comments`、`TextAttributes.commentIds`、anchor selection 和 resolved/open round-trip

### 2. 命令体系（Commands）

- [ ] **2.1** 文本：Insert / DeleteBackward / DeleteForward / DeleteSelection / Enter｜现状 ✅｜验收：`text_commands_test.dart` 全绿
- [ ] **2.2** 样式：FormatText / ClearStyle / SetBlockType / SetAlignment｜现状 ✅｜验收：`style_commands_test.dart` 全绿
- [ ] **2.3** Inline：SetLink / AutoLinkUrls / ToggleMark / InsertInlineEmbed｜现状 ✅｜验收：`inline_commands_test.dart` 全绿；URL 自动识别覆盖标点裁剪、`www.` 归一化和 undo 合并
- [ ] **2.4** Block 结构：Indent / ToggleTodo / SetCodeLanguage / ToggleQuote｜现状 ✅｜验收：`block_structure_commands_test.dart` 全绿
- [ ] **2.5** Selection：Move(↔↕)/ByWord/ToBlockBoundary/ToDocumentBoundary/SelectAll/TableCell↔↕｜现状 ✅｜验收：`selection_commands_test.dart` 全绿
- [ ] **2.6** 表格结构：行列增删/列宽/对齐/表头/背景/合并/拆分｜现状 ✅｜验收：`table_commands_test.dart` 全绿
- [ ] **2.7** 命令注册表 + middleware pipeline｜现状 ✅｜验收：`command_pipeline_test.dart` 全绿，插件可注册新命令
- [x] **2.8** 命令合并（连续输入/删除合一 undo step）｜现状 ✅｜验收：`command_merging_test.dart` 覆盖连续输入/连续删除/方向键打断/格式切换边界/光标移动不入历史四类合并边界（A4）
- [ ] **2.9** 命令结果 metadata / before-after hooks｜现状 🟡｜验收：middleware before/after 已有；result metadata 是否暴露给业务需核验

### 3. 输入系统（Input）

- [ ] **3.1** DeltaTextInputClient IME 桥（中文输入/选词/提交）｜现状 🟡｜验收：Win/Web/Android 三端手验 → 见任务 A1
- [ ] **3.2** 组合输入 composing region 渲染（下划线 span）｜现状 ✅｜验收：`composition_state.dart` + renderer 支持，example 输入中文看下划线
- [x] **3.3** 键盘：Enter/Backspace/Delete/方向键/Shift 扩选/Ctrl 按词/Home/End/Ctrl+A｜现状 ✅｜验收：PageUp/PageDown 已补真实"跳一屏"语义（A2，4 widget 测试）
- [x] **3.4** 复制/剪切/粘贴（纯文本 + 同块富 JSON）｜现状 ✅｜验收：`clipboard_service_test.dart` 全绿
- [x] **3.5** 跨块富文本复制粘贴｜现状 ✅｜验收：跨块 copy 输出 `type:blocks` rich payload 保留 block 结构与 inline 属性；`PasteBlocksCommand` 还原多 block（A3，6 新测试）
- [x] **3.6** HTML / Markdown 粘贴解析｜现状 ✅｜验收：`ClipboardService.parse(..., format: html/markdown)` 把 HTML / Markdown fragment 还原多 block（走 `PasteBlocksCommand`）；controller 提供 `pasteHtml` / `pasteMarkdown` 统一入口。

### 4. Selection 与布局引擎

- [ ] **4.1** TextLayoutService（offset↔坐标 / selection boxes / caret rect）｜现状 ✅｜验收：`text_layout_service.dart` 单块缓存可用
- [ ] **4.2** 跨块拖拽选择｜现状 ✅｜验收：`selection_gesture_overlay.dart` + keep-alive 端点，example 跨段拖拽
- [x] **4.3** 双击选词 / 三击选段｜现状 ✅｜验收：block_geometry_registry_test.dart word/paragraph boundary 单测覆盖词首/词尾/词中/第二词/单词/越界 clamp/CJK/多行段落/空文本 9 例（B1）+ widget 双击/三击已有
- [x] **4.4** 拖拽自动滚动｜现状 ✅｜验收：同步边缘滚动（全设备，每 move 一步）+ 鼠标/触控笔 Ticker 持续滚动（指针停边缘不动仍滚），3 widget 测试覆盖底边/顶边/释放停止（B2）
- [ ] **4.5** Selection handles（移动端）｜现状 ⚪｜验收：预留，阶段 8 以后 → 见任务 C9
- [ ] **4.6** 只读模式选择/复制｜现状 🟡｜验收：核对 editor readonly 概念覆盖度

### 5. 表格编辑器（阶段 4）

- [ ] **5.1** cell 点击定位 / cell 内文本选择/编辑｜现状 ✅｜验收：阶段 4 主命令链接入，example 点 cell 输入
- [ ] **5.2** 行列选择 / 整表选择｜现状 🟡｜验收：tableCellRange 模型已有，浮动工具条已可对当前 cell/range 触发行列与多 cell 样式操作；整表选择手验
- [ ] **5.3** 插入/删除行列、合并/拆分｜现状 ✅｜验收：表格命令族 + 默认浮动工具条入口；新增 widget 用例覆盖工具条行列操作
- [ ] **5.4** 列宽 / 表头 / 对齐 / 背景色｜现状 ✅｜验收：命令齐 + 默认浮动工具条支持表头、背景、列对齐、列宽重置，列边界拖拽写入 `columnWidths`
- [ ] **5.5** 键盘导航 Tab/Shift+Tab/Enter/↔↕｜现状 ✅｜验收：selection_model.md §5 对应，example 手验
- [ ] **5.6** 合并单元格**视觉**横跨（rowSpan/columnSpan 占满）｜现状 ✅｜验收：默认 table renderer 已按 rowSpan/columnSpan 定位 origin cell；covered cell 不渲染/不命中；三端手验见任务 B3
- [ ] **5.7** 表格 JSON round-trip｜现状 ✅｜验收：`rich_text_json_codec_test.dart` 全绿

### 6. 渲染与性能（阶段 5）

- [ ] **6.1** BlockRendererRegistry 扩展点｜现状 ✅｜验收：`block_renderer_registry.dart` + rendering.md，自定义 renderer 可注入
- [ ] **6.2** 大文档虚拟化（ListView.separated + keep-alive）｜现状 ✅｜验收：1k blocks 虚拟化与滚动 benchmark 全绿，当前参考值见 `docs/rendering.md`
- [ ] **6.3** 增量 rebuild（lastChangedBlockIds）｜现状 ✅｜验收：controller + `_KeepAliveBlock`，局部变更不触发整篇重建
- [ ] **6.4** SharedTextLayoutCache（跨 remount 复用 painter）｜现状 ✅｜验收：`shared_text_layout_cache_test.dart` 全绿
- [ ] **6.5** Benchmark 套件｜现状 ✅｜验收：`flutter test test/benchmarks/editor_benchmarks.dart` 通过；已补 6 项场景（1k blocks mount / editing tick / 10k inline runs / 50×20 table / advanced mixed document / 1k blocks scroll remount）
- [x] **6.6** 远距离 caret 跳转自动滚动｜现状 ✅｜验收：程序化 setSelection 到 block 400 自动滚到位（C10，估算偏移 + 二帧精修，2 widget 测试）

### 7. 导入导出与兼容（阶段 6）

- [ ] **7.1** Rich JSON codec（版本化）｜现状 ✅｜验收：`rich_text_json_codec_test.dart` 全绿
- [ ] **7.2** Legacy JSON import｜现状 ✅｜验收：`legacy_wen_json_codec_test.dart` 全绿
- [x] **7.3** Schema version migration｜现状 ✅｜验收：`DocumentMigration` / `DocumentMigrationRegistry` + `V1ToV2DocumentMigration` 示例（补 block id + 规范化 listType），11 单测全绿（C1）
- [x] **7.4** Markdown import/export｜现状 ✅｜验收：`MarkdownCodec` 覆盖 heading/段落/quote/ordered+unordered+task list/code/table/image/divider + bold/italic/strike/underline/link inline；file block reimport 可读降级为 linked paragraph，`![video](src)` placeholder 恢复为 `VideoBlockNode`；export golden 文本对照 + import 行级状态机（C2）
- [x] **7.5** HTML import/export｜现状 ✅｜验收：`HtmlCodec` 覆盖同 C2 标签矩阵（h1-6/p/blockquote/ul/ol/li/pre+code/table/img/hr/video + Wenz file + strong/em/s/u/a 嵌套合并）；引 `package:html` 依赖；export golden 文本对照 + import DOM walk（C3）
- [x] **7.6** Plain text export｜现状 ✅｜验收：`PlainTextCodec` 段落空行分隔 + 媒体块 sentinel；`controller.toPlainText()` 暴露（C4，8 单测）
- [x] **7.7** 版本快照模型｜现状 ✅｜验收：`DocumentVersionSnapshot` + `DocumentVersionSnapshotJsonCodec` 覆盖 id/时间/作者/说明、恢复文档、列表 round-trip 和 diff base 预留；`WenzRichTextController` 暴露创建/恢复 helper（ADV-020）

### 8. 工具栏与业务集成 API（阶段 7）

- [x] **8.1** ToolbarController（active styles / block type / 命令 enable 状态）｜现状 ✅｜验收：`ToolbarController` + `ToolbarState` 快照跟随选区；active bool marks（collapsed 取左侧 run 的 typing attributes，range 取全选区一致语义）/ 统一 link url / 统一 block type + heading level / 各命令 enable 状态严格镜像命令 execute 开头 noop 判定（B4，26 单测）
- [x] **8.2** onChanged / onSelectionChanged / onCommandExecuted 回调｜现状 ✅｜验收：`WenzRichTextController` 暴露三个可空回调字段，在 `notifyListeners` 之前同步触发；`test/controller/controller_callbacks_test.dart` 9 单测覆盖触发时机（文档变/选区变/noop/undo 不触发 onCommandExecuted/回调先于 notify/registry 命令）；example InspectorPanel Events 节实时展示最近一条（B5）
- [x] **8.3** media resolver/uploader 钩子｜现状 ✅｜验收：`MediaResolver` 注入点（`resolve(block) → Widget?`，返回 null 回退占位、抛异常不崩）；editor + controller 双注入；example 用 `Image.network` 渲染 picsum 图片（B6）
- [x] **8.4** Example：格式工具栏 / 块插入菜单 / 表格菜单 / JSON inspector｜现状 ✅｜验收：bold/italic/underline/strikethrough/remark/clear style/link（复用 `WenzLinkEditDialog` 弹框输入 URL，可清除）/T1-T3/paragraph/quote/todo/ordered list/unordered list/indent/outdent 全接 ToolbarController 的 active+enable 态；Bold/Italic 改走 ToggleMarkCommand 修正"不可取消"的语义 bug；表格结构按钮跟随 `canTableStruct`（B4）
- [x] **8.5** 插件 API 收敛｜现状 ✅｜验收：`WenzRichTextPlugin` / `WenzPluginBundle` / `WenzPluginContext` 统一安装 command、middleware、block renderer、inline embed renderer、slash item、headless toolbar item、paste transformer；`test/plugins/editor_plugin_test.dart` 覆盖聚合安装与重复 id 防护（ADV-027）

### 9. 质量、可访问性与发布准备（阶段 8）

- [x] **9.1** Golden tests｜现状 ✅｜验收：`test/widgets/editor_golden_test.dart` 覆盖段落/代码/图片占位、合并 cell、selection、caret、高级块 + inline embed 5 张 baseline（C5 / ADV-028）
- [ ] **9.2** Windows/Web 差异测试清单｜现状 🟡｜验收：integration_test 目录内容核验
- [x] **9.3** 语义化节点 / a11y 标签｜现状 ✅｜验收：编辑器整体 Semantics 提供可配置 label/hint/readOnly 文案、focusable multiline text field 状态和高对比焦点框；block/table/media 语义节点覆盖类型、选区、行列/span；TalkBack/Narrator 抽测保留在手验清单中复核（ADV-029）
- [x] **9.4** 错误处理（JSON decode / 无效命令 / media 失败）｜现状 ✅｜验收：`DocumentDecodeException` / `UnknownCommandException` 结构化异常 + `tryLoadJson` / `tryExecuteCommand` 不抛入口；常见异常不崩（C7）
- [x] **9.5** 架构/API/migration/example/发布文档｜现状 ✅｜验收：`architecture.md` / `api_reference.md` / `migration_guide.md` / `running_guide.md` / `docs/release_checklist.md` / 根 `README.md` / `CHANGELOG.md` 覆盖安装、初始化、命令、序列化、扩展、FAQ 与发布门禁（C7 / ADV-030）
- [x] **9.6** `flutter analyze` 干净 + `flutter test` 全绿｜现状 ✅｜验收：2026-06-23 本机复核：根目录 analyze 0 issues；根目录 `flutter test` 381 tests 全绿；benchmark 5 项全绿；example analyze 0 issues；example test 1 项全绿；2026-06-24 ADV-028 增量补高级 golden 与第 6 个 benchmark，最小验证见计划当前进度

---

## Part 2 · 阶段性推进任务表

把所有 🔴/🟡 整理成可逐项推进的任务。**约定**：完成一个任务 = 代码 + 测试 + docs 三处闭环。

### A 组 · 验收前置 + 第一优先级

- [x] **A0** 跑 `flutter analyze` + 全量 `flutter test`，记录红项（对应 9.6）
  - 验收标准：analyze 0 error；test 全绿或列出已知失败清单
  - 周期：0.5d｜依赖：—
  - ✅ 结果：analyze 0 issues / 197 tests 全绿（基线）
- [ ] **A1** IME 三端手验清单（Win/Web/Android）（对应 3.1）
  - 验收标准：输出手验 checklist + 已知问题清单；中文拼音/五笔/日文各测一次
  - 周期：2d｜依赖：A0
- [x] **A2** 补 PageUp/PageDown + 核对 Home/End/Ctrl+Left/Right（对应 3.3）
  - 验收标准：单测覆盖 + example 手验
  - 周期：1d｜依赖：A0
  - ✅ 结果：PageUp/PageDown 改为按视口高度翻屏 + 自动滚到 caret；4 widget 测试；Home/End/Ctrl 按词已有覆盖
- [x] **A3** 跨块富文本复制粘贴（对应 3.5）
  - 验收标准：跨块 copy 保留 block 结构与 inline 属性；paste 还原多 block；单测 + 手验
  - 周期：3d｜依赖：A0
  - ✅ 结果：`type:blocks` rich payload + `PasteBlocksCommand`；6 新测试
- [x] **A4** 命令合并用例补全（含"光标移动不入历史"）（对应 2.8）
  - 验收标准：command_merging_test 覆盖连续输入/连续删除/方向键/格式切换四种合并边界
  - 周期：1d｜依赖：A0
  - ✅ 结果：补 formatText 不合并 + 光标移动不入历史 2 用例

### B 组 · Selection / 表格视觉 / 工具栏（第二优先级）

- [x] **B1** 双击选词 / 三击选段 手验 + 单测（对应 4.3）
  - 验收标准：example 三击选整段；单测覆盖 word/paragraph boundary
  - 周期：1.5d｜依赖：A0
  - ✅ 结果：block_geometry_registry_test.dart 补 9 例 boundary 单测（词首/词尾/词中/第二词/单词/越界 clamp/CJK/多行段落/空文本）；widget 双击选词/三击选段已有
- [x] **B2** 拖拽自动滚动（对应 4.4）
  - 验收标准：拖到视口边缘自动滚动并持续扩展选区
  - 周期：2d｜依赖：A0
  - ✅ 结果：selection_gesture_overlay 拆分为同步边缘滚动（全设备，每次 pointer-move 推进一步）+ 鼠标/触控笔 Ticker 持续滚动（指针停边缘不动仍滚）；3 widget 测试（底边向下/顶边向上/释放停止）+ extent 跟随断言。注：ticker 每帧滚动后用最后指针坐标重算 extent，editor 对 range selection 跳过 caret-scroll-into-view 回拉，避免两个滚动源冲突。
- [ ] **B3** 合并单元格视觉横跨（自定义 table layout）（对应 5.6）
  - 验收标准：origin cell 真正 rowSpan/columnSpan 占满；covered cell 不渲染；JSON round-trip 不丢
  - 周期：4d（预留 30% buffer）｜依赖：A0
  - ✅ 自动化结果：默认 `_TableBlockRenderer` 改为自定义 Stack grid layout，非 covered cell 根据 `rowSpan`/`columnSpan` 定位真实跨格矩形；covered cell 不渲染、不参与 hit testing；新增 2 个 widget 回归测试覆盖横向合并右侧命中与 2×2 合并右下命中；`wenz_rich_text_editor_test.dart`、`block_geometry_registry_test.dart`、`table_commands_test.dart`、`selection_commands_test.dart`、`flutter analyze` 已通过。三端手验仍在 `acceptance_manual_checklist.md` 勾选。
- [x] **B4** ToolbarController + example 工具栏（对应 8.1 / 8.4）
  - 验收标准：active styles 跟随选区；bold/italic/link/块类型/H1-H3/列表/quote/code/todo 按钮；禁用态准确
  - 周期：4d｜依赖：A0
  - ✅ 结果：新增 `lib/src/controller/toolbar_controller.dart`（`ToolbarController` + 不可变 `ToolbarState` 快照 + `InlineAttributeSummary`），挂在 `WenzRichTextController` 上随其 `notifyListeners` 重算；active 计算（collapsed 取光标左侧 run 的 typing attributes；range 取选区内全部 TextRun 一致才 active）、统一 link url、统一 block type/heading level/listType（legacy `oli`/`check` 规范化）；`canFormatInline`/`canToggleMark`/`canSetLink`/`canSetBlockType`/`canIndent`/`canOutdent`/`canToggleTodo`/`canToggleQuote`/`canTableStruct` 严格镜像各命令 execute 开头 noop 判定；mutating helpers 转发到 `ToggleMarkCommand`/`SetLinkCommand`/`SetBlockTypeCommand`。example 工具栏补 underline/strikethrough/remark/link/H1-H3/quote/todo/ordered/unordered/indent/outdent，Bold/Italic 改走 toggle 修"不可取消"bug，全部接 active+enable 态。导出到 `lib/wenz_richtext.dart` tier 2。26 单测（`test/controller/toolbar_controller_test.dart`）。
- [x] **B5** 对外回调：onChanged / onSelectionChanged / onCommandExecuted（对应 8.2）
  - 验收标准：三个回调在 example 演示；单测覆盖触发时机
  - 周期：1.5d｜依赖：A0
  - ✅ 结果：`WenzRichTextController` 新增 `onChanged` / `onSelectionChanged` / `onCommandExecuted` 三个可空回调字段，均在 `notifyListeners()` 之前同步触发。触发矩阵：`execute`/`executeCommand` 文档变→onChanged、选区变→onSelectionChanged、且非 noop→onCommandExecuted；`setSelection` 仅选区变→onSelectionChanged；`replaceDocument`→onChanged；`undo`/`redo`→onChanged+onSelectionChanged（不触发 onCommandExecuted）；`setCompositionState` 不触发任何回调（视觉刷新走 notify）。`executeCommand` 改为经 `CommandRegistry.build` 解析命令后委托 `execute`，统一分发点。`test/controller/controller_callbacks_test.dart` 9 单测（文档变/仅选区变/noop 三者不触发/setSelection 同值不触发/replaceDocument/undo 不触发 onCommandExecuted/回调先于 notify/registry 命令/命令实例同一性）。example InspectorPanel 新增 Events 节实时展示最近一条。`docs/schema_and_commands.md` 补「Controller callbacks」节。
- [x] **B6** media resolver/uploader 钩子 + image/video 真渲染（对应 8.3）
  - 验收标准：业务可注入 resolver；默认 renderer 走占位；example 用 NetworkImage 渲染一张图
  - 周期：3d｜依赖：B4
  - ✅ 结果：新增 `lib/src/widgets/media_resolver.dart`（`MediaResolver` 抽象，单方法 `resolve(context, block) → Widget?`，返回 null 回退占位；doc 注明 image/video/file 三类块咨询它，业务自组装 `Image`/video/任意 widget，库不引 `video_player` 等依赖）。`BlockRenderContext` 加可选字段 `mediaResolver`；`WenzRichTextEditor` 加构造参数 `mediaResolver`，经 `_KeepAliveBlock` → `_BlockRenderer` 一路下发到 context。default image/video/file renderer 重写：先问 resolver（统一 `_resolveMedia` helper 包 try/catch，抛异常经 `FlutterError.reportError` 上报后回退占位，不崩 editor），null 才走 `_MediaPlaceholder`。`WenzRichTextController` 加可选 final 字段 `mediaResolver`（业务层引用把手；editor 仍需单独拿它驱动渲染）。导出 `media_resolver.dart` + tier 2 注释补 `MediaResolver`。example：`_NetworkImageResolver`（assetId 是 http url 时返回 `Image.network` + `loadingBuilder` 进度 + `errorBuilder` 失败兜底），controller + editor 双注入；sample-image 与 `_insertImage` 改 picsum.photos 真实 url。7 widget 单测（`test/widgets/media_resolver_test.dart`：resolver 覆盖占位 / null 回退占位 / 不注入走占位回归 / video+file 同效 / 抛异常回退占位不崩 + `takeException` 断言 / showWidth/Height 字段透传 / controller 暴露 mediaResolver）。docs：`rendering.md` 补「Media resolver」节（接口、双注入、null/抛异常语义、与 BlockRendererRegistry 优先级）+ 默认 renderer 表格更新；`api_reference.md` Widget/Controller 节补；`architecture.md` widget 层补；`migration_guide.md`/`running_guide.md` 边界从"待 B6"改为"已支持"。全量 301 tests 全绿（+7）。analyze 0 issues。media 加载失败兜底：业务侧 `errorBuilder` + resolver 抛异常 editor 捕获双保险，呼应 9.4。

### C 组 · 导入导出 / 插件 / 质量（第三优先级）

- [x] **C1** Schema migration 框架 + v1→v2 示例（对应 7.3）
  - 验收标准：migration 注册器 + 一个 migration 单测
  - 周期：2d｜依赖：A0
  - ✅ 结果：`DocumentMigration` / `DocumentMigrationRegistry` + `V1ToV2DocumentMigration`；11 单测；`RichTextJsonCodec(migrations:)` 接入
- [x] **C2** Markdown import/export（对应 7.4）
  - 验收标准：覆盖标题/段落/列表/代码/表格/链接/图片占位；golden 文本对照
  - 周期：5d｜依赖：C1
  - ✅ 结果：新增 `lib/src/codecs/markdown_codec.dart`（`MarkdownCodec`，`encode` 模型→GFM Markdown + `decode` 行级状态机 Markdown→模型，零第三方依赖，语法矩阵参照 `gpt_markdown` 对本库有模型对应的子集）。Block 双向映射：ATX heading（`#{1,6}`，level 取 # 数）/ paragraph / blockquote（`> ` 连续行聚合）/ unordered（`- `/`* `）/ ordered（`\d+.`）/ task（`- [x] `/`- [ ] `，checked 状态）/ fenced code（``` ``` 语言）/ GFM pipe table（含 `:---` 对齐）/ thematic break（`---`/`***`）/ image（`![alt](url)`→assetId=url,file=alt）。Inline 双向：`**bold**`/`*italic*`/`~~strike~~`/`<u>underline</u>`（GFM 无原生下划线，用 HTML 标签保 round-trip）/`[text](url)` 递归解析嵌套 emphasis / `![alt](url)` embed；最小转义 `\`*_[\`` 等触发字符。import 容错：任何无法识别内容降级段落不抛（Markdown 惯例）；fence 内 `#` 不当标题；listItem indent 按前导空格恢复。`WenzRichTextController` 加 `markdownCodec` 构造参数 + `toMarkdown()`/`loadMarkdown()`/`tryLoadMarkdown()`（与 tryLoadJson 对称）。导出 `markdown_codec.dart` tier 2。21 单测（`test/codecs/markdown_codec_test.dart`：export 8 例 golden 文本对照 heading/inline/link/quote/list/code/table/image + import 10 例 heading/inline/link/list/task/code-fence/quote/table/hr/image/降级 + round-trip 2 例 + controller helpers 1 例）。docs：`api_reference.md` Codec 表 + 序列化段补；`architecture.md` Codec 层补；`migration_guide.md` 新增「Markdown import/export」小节（用法 + 语法矩阵 + 降级说明）+ 边界从"未实现"改为"已支持"；`schema_and_commands.md` 补「Markdown leniency」节。video/file 无标准 Markdown 语法，import 不还原（export 发占位）。LaTeX/radio button（gpt_markdown 支持但本库无模型）不覆盖。全量 322 tests 全绿（+21）。analyze 0 issues。
- [x] **C3** HTML import/export（含 paste）（对应 3.6 / 7.5）⚠️ 风险项
  - 验收标准：同 C2 范围；paste HTML → block 还原
  - 周期：5d（预留 30% buffer）｜依赖：C2
  - ✅ 结果：引 `package:html ^0.15.6`（纯 Dart、Dart 团队官方、4.96M 周下载、`flutter_markdown` 同款）做 HTML5 解析——**本库首个第三方运行时依赖**（pubspec 从零运行时依赖变为一个纯 Dart 依赖，docs 显式标注）。新增 `lib/src/codecs/html_codec.dart`（`HtmlCodec`，`encode` 模型→HTML fragment + `decode` HTML→模型 via `parseFragment` DOM walk）。Block 双向映射：`<h1>`-`<h6>`（level 取数字）/ `<p>` / `<blockquote>` / Wenz callout `<aside>`（variant/title/icon 结构化保留）/ `<ul>`/`<ol>`/`<li>`（`<input type=checkbox>` → task + checked）/ `<pre><code class="language-x">`（language 取 class）/ `<table><thead/tr/th/td>`（th→isHeader，rowspan/colspan→rowSpan/columnSpan + covered 占位）/ `<img>`（assetId=src,file=alt）/ `<hr>`。Inline 双向：`<strong>`/`<b>`→bold、`<em>`/`<i>`→italic、`<s>`/`<del>`/`<strike>`→lineThrough、`<u>`→underline、`<a href>`→url、`<img>`→embed、`<br>`→换行；嵌套递归合并 attributes（`<strong><em>`→bold+italic）；HTML-escape `&<>`/`"`。import 容错：`html` 包 HTML5 spec 自纠正 malformed，decode 不抛；未知标签（div/span）递归子节点不丢内容；HTML entity 自动 decode/re-encode。`ClipboardService.pasteHtml` 从占位改为真实：解析 HTML fragment 成 `ClipboardPaste.blocks`（走 `PasteBlocksCommand` 还原多 block，3.6 验收核心）；构造加 `htmlCodec` 参数（有默认值，向后兼容）。`WenzRichTextController` 加 `htmlCodec` 构造参数 + `toHtml()`/`loadHtml()`/`tryLoadHtml()`（与 tryLoadJson/tryLoadMarkdown 对称）。导出 `html_codec.dart` tier 2。24 单测（`test/codecs/html_codec_test.dart`：export 8 例 golden 文本对照 heading/inline/link/quote/list/code/table+img/hr/escape + import 12 例 heading/nested-inline/link/list/task/pre-code/blockquote/table/img/hr/malformed-不抛/纯文本/entity-unescape + round-trip 1 例 + controller helpers 1 例 + clipboard pasteHtml 2 例）。docs：`api_reference.md` Codec 表 + 序列化段补；`architecture.md` Codec 层补 + 标注首第三方依赖；`migration_guide.md` 新增「HTML import/export」小节（用法 + 标签矩阵 + paste 还原 + 依赖说明）+ 边界从"未实现"改为"已支持"；`schema_and_commands.md` 补「HTML leniency」节；`running_guide.md` 剪贴板 + 边界更新。platform 剪贴板 HTML flavor 读取层仍留给业务（Flutter `Clipboard` API 限制）。video/file 无标准 HTML 语义（import 不还原）。HTML colspan/rowspan 已由 ADV-021 增量补齐；Markdown/GFM 仍只能降级为空 covered slot。全量测试全绿。analyze 根 + example 均 0 issues。⚠️ 风险项验收通过。
- [x] **C4** Plain text export（对应 7.6）
  - 验收标准：整篇导出纯文本，段落空行分隔
  - 周期：0.5d｜依赖：A0
  - ✅ 结果：`PlainTextCodec`（段落空行分隔 + 媒体 sentinel + omitEmptyBlocks 选项）；`controller.toPlainText()`；8 单测
- [x] **C5** Golden tests 矩阵（对应 9.1）
  - 验收标准：覆盖段落/代码/表格/合并 cell/图片占位/caret/selection 高亮
  - 周期：3d｜依赖：B3
  - ✅ 结果：新增 `test/widgets/editor_golden_test.dart` 与 4 张 baseline：`editor_blocks.png`（段落/代码/图片占位）、`editor_merged_table.png`（合并 cell 视觉横跨）、`editor_selection.png`（selection 高亮）、`editor_caret.png`（collapsed caret）；`flutter test --update-goldens test/widgets/editor_golden_test.dart` 生成基线后，普通 `flutter test test/widgets/editor_golden_test.dart` 校验通过。
- [ ] **C6** a11y 语义节点 + a11y 标签（对应 9.3）
  - 验收标准：Semantics 节点描述 block 类型与选区；talkback/narrator 抽测
  - 周期：3d｜依赖：B4
  - 🟡 自动化结果：默认 renderer 已为 text/code/table/media/callout 等 block 加 `Semantics` 容器；文本/代码 block 会在选区覆盖时标记 `selected`；table cell 语义包含 row/column/header/rowSpan/columnSpan/selected。新增 2 个 widget 测试覆盖 block 语义标签与合并 cell 语义标签。剩余：Windows Narrator / Android TalkBack 抽样手验。
- [x] **C7** 错误处理加固 + 文档（架构/API/migration/running guide）（对应 9.4 / 9.5）
  - 验收标准：JSON decode/无效命令/media 失败均不崩；docs 章节齐
  - 周期：3d｜依赖：C1
  - ✅ 结果：新增 `lib/src/codecs/document_errors.dart`（`DocumentDecodeException` 带 `reason`/`jsonPath`/`raw`，`UnknownCommandException` 带 `name`）；`RichTextJsonCodec` / `LegacyWenJsonCodec` / `decodeWithMigrations` 把裸 `FormatException`/`StateError`/cast 错误统一 catch 重抛结构化异常，保留 originating error 在 `.raw`；修掉 legacy 表格非数字 alignment key 裸抛（改 `_asNullableInt` 容错跳过）+ 非 Map block 条目静默丢失（保留跳过 + `kDebugMode` 下 `debugPrint`）；`CommandRegistry.build`/`executeFromJson` 改抛结构化异常。`WenzRichTextController` 新增 `tryLoadJson`（返回不可变 `TryLoadResult`：`ok`/`document?`/`error?`，失败不动文档/选区/历史/回调）+ `tryExecuteCommand`（返回 bool，失败不动文档）；`loadJson`/`executeCommand` 保持原抛错语义（向后兼容）。导出 `document_errors.dart` + tier 2 注释更新。docs：新增 `architecture.md`（分层 + 数据流 + tier 说明）、`api_reference.md`（按模块分组公共 API）、`migration_guide.md`（legacy 接入 + migration 框架 + 0.1.0 边界）；刷新 `running_guide.md`（删过时阶段 0 边界，改为「已支持」+ 当前边界）；`schema_and_commands.md` 补「Error handling」节；`README.md` 索引补 3 个新条目。media 加载失败随 B6 走（当前 media 全占位无加载路径）。11 codec/controller 单测（`test/codecs/document_errors_test.dart` 11 + `test/controller/controller_try_load_test.dart` 7）+ 修 2 处旧断言（migration `throwsFormatException`→`isA<DocumentDecodeException>`、command `throwsArgumentError`→`isA<UnknownCommandException>`）。
- [x] **C8** formula / mention / emoji inline 渲染 + 命令（对应 1.2）
  - 验收标准：三种 inline 有 renderer 与插入命令；JSON round-trip
  - 周期：3d｜依赖：B4
  - ✅ 结果：`InlineEmbed` 复用 formula/mention/emoji 数据结构与 `InsertInlineEmbedCommand`；`WenzRichTextController.insertFormula` / `insertMention` 保持可用，新增 `insertEmoji` 写入 `embedType: 'emoji'`、unicode 字符和可选 shortName。`InlineEmbedRenderer` + `InlineEmbedRendererCallback`（`buildTextSpan(context, embed, textStyle) → TextSpan?`，返回 null 走默认）经 `WenzRichTextEditor.inlineEmbedRenderer` 与 `BlockRenderContext.inlineEmbedRenderer` 下发到默认 text/callout/table cell renderer。默认 formula 显示 `data.text/latex/value`，mention 显示 `@label/@id`，emoji 显示 unicode 字符，表格 cell 也走同一 inline span 渲染；Markdown/HTML 导出按可读文本降级。JSON round-trip 已由 `rich_text_json_codec_test.dart` 覆盖；widget 测试覆盖默认 formula/mention/emoji 渲染、表格 cell inline 渲染和自定义 renderer fallback。
- [ ] **C9** 移动端 selection handles（对应 4.5）
  - 验收标准：iOS/Android 手柄拖拽改选区
  - 周期：4d｜依赖：B2
- [x] **C10** 远距离 caret 跳转自动滚动（对应 6.6）
  - 验收标准：程序化跳到 block 400 自动滚到位（评估是否引入 positioned-list）
  - 周期：2d｜依赖：A0
  - ✅ 结果：估算偏移（平均块高 × index）+ 二帧精修，未引入 positioned-list；2 widget 测试

### 进阶功能 · 阶段 0

- [x] **ADV-001** 建立进阶功能矩阵
  - 验收标准：有一份进阶功能矩阵文档；每个后续阶段都有明确数据结构影响和测试入口；不引入会破坏现有 JSON round-trip 的 schema 变更。
  - ✅ 结果：`docs/advanced_feature_matrix.md` 已覆盖当前能力基线、状态定义、功能矩阵、schema 影响矩阵和推荐下一步；`docs/advanced_feature_development_plan.md` 的任务列表已补齐 `[done]` 标记。本轮仅做文档状态收敛，无代码 schema 变更。

- [x] **ADV-002** 评估 schema 与 JSON migration 影响
  - 验收标准：每个后续阶段都有数据结构影响和测试入口；不引入破坏现有 JSON round-trip 的 schema 变更。
  - ✅ 结果：新增 `docs/schema_migration_impact.md`，固定当前 rich JSON v2 基线、schema bump 规则、后续进阶功能影响矩阵、future v3 候选和必测清单；同步 `advanced_feature_matrix.md`、`advanced_feature_development_plan.md`、API/architecture/migration/schema 文档入口。本轮无代码 schema 变更，结论为已完成增量不需要新的 migration，评论/修订/内建链接预览/document metadata 进入编码前必须先出 v3 schema 方案。

### 进阶功能 · 阶段 1

- [x] **ADV-003** Markdown 快捷输入引擎
  - 验收标准：`#`/`##`/`###`、列表、任务列表、引用、代码块和分割线触发后能转换为对应 block，并可通过 undo 回到原输入。
  - ✅ 结果：`ApplyMarkdownShortcutCommand` 已接入控制器输入路径，覆盖标题、无序/有序/任务列表、引用、代码块和 divider 转换；`test/core/markdown_shortcut_commands_test.dart` 覆盖核心触发与撤销路径。本轮仅同步完成状态，无代码变更。

- [x] **ADV-004** 快捷键集中管理
  - 验收标准：常用编辑、导航、查找替换、表格导航快捷键统一解析，并支持 readOnly/IME 场景降级。
  - ✅ 结果：`EditorShortcutManager` / `EditorShortcutIntent` 统一管理复制、剪切、粘贴、撤销/重做、查找/替换、光标移动、删除、Enter、字符输入和表格 Tab 导航；`test/input/shortcut_manager_test.dart` 覆盖主要解析分支。本轮仅同步完成状态，无代码变更。

- [x] **ADV-005** 粘贴清洗 pipeline
  - 验收标准：纯文本、Markdown、HTML 和 Wenz 内部富文本粘贴均经统一 pipeline，导入结果不破坏 document schema。
  - ✅ 结果：`ClipboardService` 提供 `ClipboardPasteFormat`、plugin transformer、内部 rich payload、Markdown/HTML 解析与 plain fallback；`WenzRichTextController.pasteText` / `pasteMarkdown` / `pasteHtml` 复用同一路径；`test/input/clipboard_service_test.dart` 及 codec 粘贴测试覆盖主要场景。本轮仅同步完成状态，无代码变更。

- [x] **ADV-006** 查找替换 controller 与基础 UI
  - 验收标准：当前命中、全部命中高亮、上/下一个、替换当前/全部替换；跨 block 文档可用；大小写和全词匹配预留并可用。
  - ✅ 结果：新增 `WenzFindReplaceController`（监听宿主 `WenzRichTextController`，匹配普通文本块、代码块、表格单元格首个文本块；输出 `FindReplaceMatch`/`DocumentSelection`；支持 `next`/`previous`/`replaceCurrent`/`replaceAll`/`FindReplaceOptions`）。`WenzRichTextEditor.findController` 绘制全部命中和当前命中高亮；`EditorShortcutManager` 增加按需启用的 Ctrl/Cmd+F、Ctrl/Cmd+T intent；新增 `WenzFindReplacePanel` 可嵌入基础 UI。导出 public API，并更新 `docs/advanced_feature_matrix.md`、`docs/advanced_feature_development_plan.md`、`docs/input_system.md`、`docs/api_reference.md`。验证：`flutter analyze` 通过；`flutter test test\controller\find_replace_controller_test.dart test\widgets\find_replace_panel_test.dart test\input\shortcut_manager_test.dart` 通过；`flutter test test\widgets\wenz_rich_text_editor_test.dart` 通过。全量相关组合回归仅复现既有 `test/widgets/block_geometry_registry_test.dart:288` 失败。
- [x] **ADV-007** Slash 菜单基础框架
  - 验收标准：`/heading`、`/list`、`/todo`、`/quote`、`/code`、`/table`、`/image`；支持键盘上下选择、Enter 确认、Esc 取消；菜单项由 registry 提供，业务侧可扩展；执行路径转成命令。
  - ✅ 结果：新增 `SlashMenuController` / `SlashMenuRegistry` / `SlashMenuItem`（监听 host selection/document，检测 collapsed caret 前的 `/query`，过滤 registry，维护 highlighted item，激活时先删除触发文本再执行 action）。默认 registry 覆盖 heading/list/todo/quote/code/table/image；文本类走 `setBlockType`/`toggleTodo`，代码/图片/表格走 `insertBlocks`/`replaceBlocks`/`insertTable`，保持 undo/redo 路径。新增 `WenzSlashMenuOverlay` 基础 UI；`WenzRichTextEditor.slashMenuController` 接入 overlay，并在菜单打开时优先处理 ArrowUp/ArrowDown/Enter/Escape。导出 public API，并更新 `docs/advanced_feature_matrix.md`、`docs/advanced_feature_development_plan.md`、`docs/input_system.md`、`docs/api_reference.md`。验证：`flutter analyze` 通过；`flutter test test\controller\slash_menu_controller_test.dart test\widgets\slash_menu_overlay_test.dart` 通过；`flutter test test\widgets\wenz_rich_text_editor_test.dart` 通过。
- [x] **ADV-008** 列表模型与命令增强
  - 验收标准：有序/无序/任务列表复用统一模型；多级缩进走命令；非空列表项 Enter 自动延续列表；空列表项 Enter 退出列表；任务列表延续项默认未勾选。
  - ✅ 结果：列表继续复用 `BlockAttributes.listType/checked/indent`，未新增 schema。增强 `EnterCommand`：非空 listItem split 后生成同级同类型的新 listItem；task list 新项 `checked=false`，不会继承上一项勾选状态；空 listItem Enter 转回 paragraph 并保留 indent/alignment/anchor 等 block-level metadata。`SetBlockTypeCommand` 支持 canonical `listType: 'task'` 的 checked 初值，并可在 ordered/task/unordered 三类列表间切换；`IndentCommand` / `ToggleTodoCommand` / `ToggleQuoteCommand` / `SetBlockTypeCommand` / `SetAlignmentCommand` 重建 attrs 时保留 `anchor`，避免与 ADV-017 冲突。新增/更新测试：`test/core/block_commands_test.dart`、`test/core/block_structure_commands_test.dart`、`test/core/style_commands_test.dart`。验证：`flutter analyze` 通过；`flutter test test\core\block_commands_test.dart test\core\block_structure_commands_test.dart test\core\style_commands_test.dart` 通过；`flutter test test\controller\toolbar_controller_test.dart test\controller\slash_menu_controller_test.dart test\widgets\wenz_rich_text_editor_test.dart` 通过；`flutter test` 全量通过。
- [x] **ADV-009** 代码块语言与工具条
  - 验收标准：代码块可从默认 UI 切换语言；复制代码可用；Tab/Shift+Tab 在代码块内缩进/反缩进并走命令历史；代码块 selection/caret 行为继续复用既有 `_TextSelectionSurface`。
  - ✅ 结果：默认 `_CodeBlockRenderer` 增加 `_CodeBlockToolbar`，展示语言下拉与 `Copy code` 按钮；语言下拉通过 `BlockRenderContext.onCodeLanguageChanged` 调用 `WenzRichTextController.setCodeLanguage` / `SetCodeLanguageCommand`，语言会 trim 且进入 undo/redo；复制按钮通过 `BlockRenderContext.onCodeCopied` 复用编辑器剪贴板写入入口。新增 `IndentCodeBlockCommand` 与 `WenzRichTextController.indentCodeBlock`，支持 selection 覆盖多行时按行缩进/反缩进并修正 selection offset；`WenzRichTextEditor` 在 code selection 内优先处理 Tab/Shift+Tab。示例文档和插入按钮已有 `CodeBlockNode(language: 'dart')` 可直接演示。新增/更新测试：`test/core/block_structure_commands_test.dart`、`test/widgets/wenz_rich_text_editor_test.dart`。验证：`flutter test test\core\block_structure_commands_test.dart test\widgets\wenz_rich_text_editor_test.dart` 通过。
- [x] **ADV-012** 图片尺寸、caption、alt text
  - 验收标准：`ImageBlockNode` 支持 caption/alt text 与尺寸 JSON round-trip；controller 提供可撤销的图片元数据更新 API；默认 renderer 展示 caption、语义优先 alt；Markdown/HTML/plain text codec 保留图片文本信息。
  - ✅ 结果：`ImageBlockNode` 新增 `caption` / `altText`（JSON 写 `altText`，读入兼容旧 `alt` key，`plainText` 使用 caption）；新增 `UpdateImageBlockCommand` 与 `WenzRichTextController.updateImageBlock`，支持更新 `assetId/file/width/height/showWidth/showHeight/caption/altText`，并可 `clearShowWidth/clearShowHeight`，走命令历史与 undo/redo。默认图片 renderer 统一包装 resolver widget / placeholder，应用 `showWidth/showHeight`，caption 显示在媒体下方，Semantics 优先 `altText`。Markdown 图片支持 `![alt](src "caption")`，HTML caption 使用 `<figure><img ...><figcaption>`，plain text image sentinel 优先 caption/alt。新增/更新测试：`test/core/model_test.dart`、`test/controller/image_block_controller_test.dart`、`test/codecs/*_codec_test.dart`、`test/widgets/media_resolver_test.dart`。验证：`flutter analyze` 通过；`flutter test test\core\model_test.dart test\controller\image_block_controller_test.dart test\codecs\rich_text_json_codec_test.dart test\codecs\markdown_codec_test.dart test\codecs\html_codec_test.dart test\codecs\plain_text_codec_test.dart test\widgets\media_resolver_test.dart` 通过。
- [x] **ADV-013** 文件附件块
  - 验收标准：文件块模型保存文件名、大小、类型、下载地址；上传状态和失败重试预留可 JSON 保存恢复；默认渲染不阻塞普通文本编辑，业务侧可通过 `MediaResolver` 替换展示。
  - ✅ 结果：`FileBlockNode` 保留 `assetId/name/size/file` 兼容字段，并新增 `mimeType`、`downloadUrl`、`uploadStatus`、`uploadError`、`displayName`、`effectiveDownloadUrl` 与 `FileUploadStatus`；新增 `UpdateFileBlockCommand` 和 `WenzRichTextController.updateFileBlock`，`insertFile` 支持可选插入位置和完整附件元数据，更新走 undo/redo。默认文件 renderer 从占位文本升级为附件卡片，显示名称、大小、MIME、上传状态和失败信息；`MediaResolver` 仍可完全替换展示并承载重试按钮。Markdown/HTML/plain text 导出优先使用显示名与下载地址，HTML 附带 data 元数据；example 增加附件插入按钮和示例附件。新增/更新测试：`test/controller/file_block_controller_test.dart`、`test/core/block_structure_commands_test.dart`、`test/codecs/markdown_codec_test.dart`、`test/codecs/html_codec_test.dart`、`test/widgets/media_resolver_test.dart`。验证：`dart format --page-width 80 --trailing-commas automate --set-exit-if-changed` 通过；`flutter test --no-pub` 相关测试因 Flutter wrapper 180 秒无输出超时未完成；`dart analyze` 因 `dartaotruntime.exe` 访问权限失败未完成。
- [x] **ADV-015** mention、emoji、formula inline embed
  - 验收标准：formula/mention/emoji 可通过命令插入、默认 renderer 可读展示、JSON 保存恢复、Markdown/HTML 有明确可读降级。
  - ✅ 结果：复用 `InlineEmbed` 和 `InsertInlineEmbedCommand`，新增 `WenzRichTextController.insertEmoji`；默认 renderer 显示 formula 文本、mention `@label/@id`、emoji 字符，自定义 `InlineEmbedRenderer` 仍可覆盖；Markdown/HTML 导出输出可读 fallback。新增/更新测试覆盖 controller helper、JSON round-trip、Markdown/HTML 导出和 widget 默认/自定义渲染。
- [x] **ADV-016** Block embed 与业务 renderer 注入
  - 验收标准：提供 block-level custom embed placeholder；业务侧可按 embed type 注入 renderer；新增 block 可 JSON/HTML round-trip，Markdown/plain text 有明确可读降级；renderer 注入不影响普通文本编辑。
  - ✅ 结果：新增 `BlockEmbedNode(embedType,data,fallbackText)`、`WenzRichTextController.insertBlockEmbed`、`BlockRendererRegistry.registerEmbed/hasEmbed`、`WenzObjectBlockSurface`；默认 renderer 显示 embed type 与 fallback，业务 renderer 可按 `embedType` 覆盖并保留对象块 selection/geometry/debug 行为。rich JSON 与 HTML 保留结构化数据，Markdown/plain text 输出可读 fallback；example 增加 CRM card renderer 与插入按钮。新增/更新测试覆盖 controller helper、model/schema、rich JSON、HTML、Markdown、plugin registry 和 widget renderer 注入。验证：相关 codec/controller/plugin 测试通过，新增 widget 用例通过，`flutter analyze --no-pub` 通过；整文件 widget 测试仍有既有表格 toolbar/resize 两项失败，本轮未改这些无关项。
- [x] **ADV-017** 大纲目录与 block anchor
  - 验收标准：从 heading 自动派生 outline；目录项携带 blockId/blockIndex/level/title/anchor；点击目录可跳转到目标 heading；block anchor 可 JSON round-trip 且通过命令更新，进入 undo/redo。
  - ✅ 结果：新增 `WenzOutlineController` 与不可变 `OutlineItem`，监听宿主 `WenzRichTextController` 并从非空 heading 派生目录；支持 `selectByBlockId` / `selectByAnchor` 把宿主 selection 移到 heading 起点，复用编辑器既有 selection scroll 逻辑。`BlockAttributes` 新增 `anchor` 字段并进入 JSON/schema normalize；新增 `SetBlockAnchorCommand` 与 `WenzRichTextController.setBlockAnchor`，空白 anchor 清除字段，命令链支持 undo/redo。导出 public API，并更新 `docs/advanced_feature_matrix.md`、`docs/advanced_feature_development_plan.md`、`docs/api_reference.md`、`docs/architecture.md`、`docs/schema_and_commands.md`。验证：`flutter analyze` 通过；`flutter test test\core\model_test.dart test\core\document_schema_test.dart test\core\block_commands_test.dart test\controller\outline_controller_test.dart` 通过；`flutter test` 全量通过。
- [x] **ADV-023** 评论线程模型与 UI
  - 验收标准：comment anchor inline 标记、评论线程模型、open/resolved 状态、评论侧栏、点击评论可定位到 selection；评论信息可随 rich JSON 保存恢复。
  - ✅ 结果：新增 `CommentAnchor` / `CommentEntry` / `CommentThread`，`RichTextDocument.comments` 顶层保存线程，`TextAttributes.commentIds` 标记 inline anchor；`WenzCommentSidebar` 渲染 open/resolved 线程并通过 `onRevealAnchor(thread, selection)` 返回定位 selection，resolve/reopen 作为业务回调。新增 `docs/comments_and_revisions.md`，并同步 API、architecture、schema impact、advanced matrix/plan。验证：`git diff --check -- <本轮相关文件>` 通过（仅 CRLF 工作区换行警告）；`dart format`、定向 `flutter test --no-pub` 和定向 `dart analyze` 均无输出超时，待本机 Dart/Flutter 进程恢复后复跑。评论 mutation command、内联高亮和 composer 留给后续任务。

### D 组 · 发布准备

- [ ] **D1** 打 tag `0.1.0-alpha`
  - 验收标准：CTANGELOG + migration guide + example 可跑 + analyze/test 全绿
  - 周期：1d｜依赖：A/B/C 主干完成

---

## Part 3 · 建议推进顺序

```
Week 1:  A0 ──> A1 ──> A2
                └── A4（并行）
Week 2:  A3 ──────────────────────>
Week 3:  B1 + B2（并行）
Week 4:  B3（表格视觉，独立流）⚠️
Week 5:  B4 ──> B5 ──> B6
Week 6:  C1 + C4（并行）
Week 7-8: C2 / C3（导入导出主线）⚠️
Week 9:  C5（golden，依赖 B3）+ C8（inline 扩展）
Week 10: C6 + C7 + C9 + C10（收尾）
Week 11: D1
```

- **关键路径**：A0 → A3 → B4 → C2/C3 → D1（导入导出主线最长）— **C2/C3 已完成，主线已通**；B3 自动化已落地，剩三端手验
- **风险项**：B3（表格合并视觉）自动化风险已收敛；C3（HTML）已验收通过（引 `package:html` 依赖）

---

## Part 4 · 验收方式

1. 每个任务 ID 对应一个 PR / 一个 commit，message 带 `[accept-XXX]` 前缀，便于回溯。
2. **🟡 项**：补测试即视为通过，无需改实现。
3. **🔴 项**：必须实现 + 测试 + docs 三件齐全。
4. **每周一次回归**：跑 A0 的 analyze + test，确保不回退。
5. **手验项**（A1/B1/B2/B3/C9）：在 `docs/acceptance_manual_checklist.md` 单独维护勾选表，三端（Win/Web/Android）各勾一遍。

---

## Part 5 · 与 roadmap 的差异说明

- **阶段 5（渲染与性能）**：roadmap 声明全部完成，核对源码后**确认完成**；6.6（远距离 caret 自动滚动）已由 C10 补齐。
- **阶段 4（表格）**：roadmap 声明完成，B3 已补默认 renderer 的合并单元格视觉横跨；ADV-011 已补默认表格浮动工具条和列宽拖拽，交互全部回落到 controller/command 层；结构、undo/redo、JSON round-trip 仍沿用既有模型，三端视觉手验待在 checklist 勾选。
- **阶段 4（文档级能力）**：ADV-018 已补文档统计；ADV-019 已补 `WenzAutoSaveController`，通过 rich JSON 快照派生 dirty/scheduled/saving/failed 状态，支持防抖外部保存、`saveNow`、`markClean` 和失败保留 dirty/error。example Inspector 新增 Autosave 区与内存草稿 adapter，草稿持久化仍由业务侧保存 rich JSON，不新增 schema。ADV-022 已补 PDF/DOCX 方案：新增 `WenzDocumentConversionPlan` 与 app-owned importer/exporter 合约，明确平台、依赖、资源和降级边界，不引入核心 PDF/print/OOXML 依赖。
- **阶段 5（评论、修订与协作预留）**：ADV-023 已补评论线程基础模型与 UI；ADV-024 已补修订基础模型与同块文本命令；ADV-025 已补协作 adapter 接口；ADV-026 已补 `WenzEditorPermission.read/comment/edit` 权限态与命令禁用。评论线程随 rich JSON 保存恢复，inline `commentIds` 提供 anchor 标记，侧栏点击可回传 `DocumentSelection`；修订通过 `RichTextDocument.revisions` 与 inline `revisionIds` 保存恢复，controller 修订模式可将同块 insert/delete/format 转为可 undo/redo 的接受/拒绝命令；协作层通过 `WenzCollaborationAdapter` / `WenzCollaborationController` 发布本地变更、应用远端快照并维护 remote selection runtime state，不写入协作运行时状态、不绑定 CRDT/服务端；权限态由 controller 命令守卫和 toolbar enable 态承载，不写入文档正文。
- **阶段 6/7/8**：ADV-027 已完成（8.5 插件 API 收敛）；ADV-029 已完成（9.3 可访问性增强）；C7 已完成（9.4 错误处理 + 9.5 文档）；B6 已完成（8.3 media resolver）；C2 已完成（7.4 Markdown）；C3 已完成（3.6 + 7.5 HTML）；C1/C4/C8 已完成；B3/C5 自动化已完成。其余待人工确认项为 A1/B3/ADV-029 屏幕阅读器抽测/C9，任务表已覆盖。
- **阶段 6（导入导出）**：C2 + C3 已完成，导入导出主线收尾。`MarkdownCodec` 自写行级状态机（零第三方依赖，语法矩阵参照 `gpt_markdown`）；`HtmlCodec` 引 `package:html`（**本库首个第三方运行时依赖**，纯 Dart 官方库）做 HTML5 解析，覆盖同 Markdown 的标签矩阵 + 嵌套 emphasis 合并 + entity decode/re-encode，并可通过 Wenz `data-*` 元数据 round-trip file/video 块。ADV-021 已补 `docs/import_export_strategy.md` 主流 block/inline 验收矩阵，并通过 example Import/export demo 覆盖 HTML inline image、合并单元格、video 和 file 元数据。两者均容错降级段落不抛（Markdown/HTML 惯例）。`ClipboardService.pasteHtml` 把 HTML fragment 还原多 block（3.6）。Markdown video/file 无标准结构化语法（仅导出为可读降级）；Markdown callout 降级为 quote/blockquote，HTML Wenz callout 保留 variant/title/icon；LaTeX/radio button（gpt_markdown 支持）不覆盖；HTML 表格 colspan/rowspan 已可还原为 rowSpan/columnSpan + covered 占位。
- **阶段 2（Selection 与布局）**：B1（双击选词/三击选段 boundary 单测）与 B2（拖拽自动滚动）已完成，4.3 / 4.4 验收通过。B2 实现拆为「同步边缘滚动（全设备，每次 pointer-move 推进一步）」+「鼠标/触控笔 Ticker 持续滚动」两层：前者保证 touch 拖拽时列表跟随滚动（scrollable 自身 pan 手势在本 overlay 下不赢 arena，同步 jumpTo 是实际滚动源），后者让鼠标拖到边缘停留时持续滚动并持续重算 selection extent；editor 对 range selection 跳过 caret-scroll-into-view 回拉以避免冲突。
- **阶段 7（工具栏与业务集成 API）**：B4 已完成，B5 已完成，B6 已完成。`ToolbarController` 作为 `WenzRichTextController` 的派生 `ChangeNotifier`，随 host 通知重算 `ToolbarState` 快照——这是 toolbar 状态跟随选区的入口；B5 在 controller 上补齐 `onChanged`/`onSelectionChanged`/`onCommandExecuted` 三个业务集成回调（均在 `notifyListeners` 之前同步触发），作为比 `addListener` 粗粒度信号更细粒度的事件源。B6 补 `MediaResolver`（`resolve(block) → Widget?`）作为 media 块真渲染的快捷注入点：default image/video/file renderer 先问 resolver，返回 null 回退占位，抛异常经 `FlutterError.reportError` 上报后回退（呼应 9.4）；editor + controller 双注入，业务自组装 `Image`/video/任意 widget，库不引 `video_player` 等依赖——media 块从此可真渲染，加载失败兜底（业务侧 `errorBuilder` + resolver 抛异常 editor 捕获双保险）一并落地。Bold/Italic 在 example 原走 `FormatTextCommand`（不可取消 bool），B4 改走 `ToggleMarkCommand` 修掉该语义 bug。
- **阶段 8（质量、可访问性与发布准备）**：C7 已完成（9.4 + 9.5）。错误处理采用「结构化异常 + tryLoadJson/tryExecuteCommand 不抛入口」双轨：`DocumentDecodeException`/`UnknownCommandException` 带 `reason`/`raw` 链保留 originating error，业务可在 typed catch 与 no-throw 两种风格间二选一；codec/registry/migration 全部接入，`loadJson`/`executeCommand` 保持原抛错语义向后兼容。docs 补齐 `architecture.md`（分层总览，原本散在 refactor_plan/rendering/input_system）/ `api_reference.md`（按模块分组公共 API 表面）/ `migration_guide.md`（面向消费者的 legacy 接入 + migration 框架 + 0.1.0 边界），`running_guide.md` 刷新掉阶段 0 过时边界。media 加载失败兜底明确归入 B6（当前 media 全占位无加载路径，不在本任务造假）。

