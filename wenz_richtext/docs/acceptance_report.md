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
- [ ] **1.2** Inline 体系（TextRun + link/formula/mention/embed attributes）｜现状 🟡｜验收：link/embed 命令已落；**formula/mention 仅 attributes 预留无命令/渲染**，列为已知 gap
- [ ] **1.3** TableModel（cell/row/col/span/header/bg/width）｜现状 ✅｜验收：`table_model.dart` + 表格命令族完整 + JSON round-trip
- [ ] **1.4** Schema/normalizers｜现状 🟡｜验收：逐条核验"空文档保 paragraph / cell 内结构约束 / 非法 block 自动修正"用例
- [ ] **1.5** DocumentSelection / PositionPath 三形态 + 结构化排序｜现状 ✅｜验收：`document_position_test.dart` 全绿
- [ ] **1.6** 跨 block / 跨表格 cell selection 模型｜现状 ✅｜验收：selection_model.md §5 对应命令链已接入

### 2. 命令体系（Commands）

- [ ] **2.1** 文本：Insert / DeleteBackward / DeleteForward / DeleteSelection / Enter｜现状 ✅｜验收：`text_commands_test.dart` 全绿
- [ ] **2.2** 样式：FormatText / ClearStyle / SetBlockType / SetAlignment｜现状 ✅｜验收：`style_commands_test.dart` 全绿
- [ ] **2.3** Inline：SetLink / ToggleMark / InsertInlineEmbed｜现状 ✅｜验收：`inline_commands_test.dart` 全绿
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
- [x] **3.6** HTML / Markdown 粘贴解析｜现状 ✅｜验收：`ClipboardService.pasteHtml` 把 HTML fragment 还原多 block（走 `PasteBlocksCommand`）；Markdown 粘贴仍预留（`pasteMarkdown` 返回 null），业务可经 `MarkdownCodec.decode` 自处理（C3）

### 4. Selection 与布局引擎

- [ ] **4.1** TextLayoutService（offset↔坐标 / selection boxes / caret rect）｜现状 ✅｜验收：`text_layout_service.dart` 单块缓存可用
- [ ] **4.2** 跨块拖拽选择｜现状 ✅｜验收：`selection_gesture_overlay.dart` + keep-alive 端点，example 跨段拖拽
- [x] **4.3** 双击选词 / 三击选段｜现状 ✅｜验收：block_geometry_registry_test.dart word/paragraph boundary 单测覆盖词首/词尾/词中/第二词/单词/越界 clamp/CJK/多行段落/空文本 9 例（B1）+ widget 双击/三击已有
- [x] **4.4** 拖拽自动滚动｜现状 ✅｜验收：同步边缘滚动（全设备，每 move 一步）+ 鼠标/触控笔 Ticker 持续滚动（指针停边缘不动仍滚），3 widget 测试覆盖底边/顶边/释放停止（B2）
- [ ] **4.5** Selection handles（移动端）｜现状 ⚪｜验收：预留，阶段 8 以后 → 见任务 C9
- [ ] **4.6** 只读模式选择/复制｜现状 🟡｜验收：核对 editor readonly 概念覆盖度

### 5. 表格编辑器（阶段 4）

- [ ] **5.1** cell 点击定位 / cell 内文本选择/编辑｜现状 ✅｜验收：阶段 4 主命令链接入，example 点 cell 输入
- [ ] **5.2** 行列选择 / 整表选择｜现状 🟡｜验收：tableCellRange 模型已有，整表选择手验
- [ ] **5.3** 插入/删除行列、合并/拆分｜现状 ✅｜验收：表格命令族 + 测试全绿
- [ ] **5.4** 列宽 / 表头 / 对齐 / 背景色｜现状 ✅｜验收：命令齐 + example 演示
- [ ] **5.5** 键盘导航 Tab/Shift+Tab/Enter/↔↕｜现状 ✅｜验收：selection_model.md §5 对应，example 手验
- [ ] **5.6** 合并单元格**视觉**横跨（rowSpan/columnSpan 占满）｜现状 🔴｜验收：origin cell 真正横跨 → 见任务 B3
- [ ] **5.7** 表格 JSON round-trip｜现状 ✅｜验收：`rich_text_json_codec_test.dart` 全绿

### 6. 渲染与性能（阶段 5）

- [ ] **6.1** BlockRendererRegistry 扩展点｜现状 ✅｜验收：`block_renderer_registry.dart` + rendering.md，自定义 renderer 可注入
- [ ] **6.2** 大文档虚拟化（ListView.separated + keep-alive）｜现状 ✅｜验收：1k blocks 滚动 ~30–80µs/帧
- [ ] **6.3** 增量 rebuild（lastChangedBlockIds）｜现状 ✅｜验收：controller + `_KeepAliveBlock`，局部变更不触发整篇重建
- [ ] **6.4** SharedTextLayoutCache（跨 remount 复用 painter）｜现状 ✅｜验收：`shared_text_layout_cache_test.dart` 全绿
- [ ] **6.5** Benchmark 套件｜现状 ✅｜验收：`flutter test test/benchmarks/editor_benchmarks.dart` 通过
- [x] **6.6** 远距离 caret 跳转自动滚动｜现状 ✅｜验收：程序化 setSelection 到 block 400 自动滚到位（C10，估算偏移 + 二帧精修，2 widget 测试）

### 7. 导入导出与兼容（阶段 6）

- [ ] **7.1** Rich JSON codec（版本化）｜现状 ✅｜验收：`rich_text_json_codec_test.dart` 全绿
- [ ] **7.2** Legacy JSON import｜现状 ✅｜验收：`legacy_wen_json_codec_test.dart` 全绿
- [x] **7.3** Schema version migration｜现状 ✅｜验收：`DocumentMigration` / `DocumentMigrationRegistry` + `V1ToV2DocumentMigration` 示例（补 block id + 规范化 listType），11 单测全绿（C1）
- [x] **7.4** Markdown import/export｜现状 ✅｜验收：`MarkdownCodec` 覆盖 heading/段落/quote/ordered+unordered+task list/code/table/image/divider + bold/italic/strike/underline/link inline；export golden 文本对照 + import 行级状态机（C2）
- [x] **7.5** HTML import/export｜现状 ✅｜验收：`HtmlCodec` 覆盖同 C2 标签矩阵（h1-6/p/blockquote/ul/ol/li/pre+code/table/img/hr + strong/em/s/u/a 嵌套合并）；引 `package:html` 依赖；export golden 文本对照 + import DOM walk（C3）
- [x] **7.6** Plain text export｜现状 ✅｜验收：`PlainTextCodec` 段落空行分隔 + 媒体块 sentinel；`controller.toPlainText()` 暴露（C4，8 单测）

### 8. 工具栏与业务集成 API（阶段 7）

- [x] **8.1** ToolbarController（active styles / block type / 命令 enable 状态）｜现状 ✅｜验收：`ToolbarController` + `ToolbarState` 快照跟随选区；active bool marks（collapsed 取左侧 run 的 typing attributes，range 取全选区一致语义）/ 统一 link url / 统一 block type + heading level / 各命令 enable 状态严格镜像命令 execute 开头 noop 判定（B4，26 单测）
- [x] **8.2** onChanged / onSelectionChanged / onCommandExecuted 回调｜现状 ✅｜验收：`WenzRichTextController` 暴露三个可空回调字段，在 `notifyListeners` 之前同步触发；`test/controller/controller_callbacks_test.dart` 9 单测覆盖触发时机（文档变/选区变/noop/undo 不触发 onCommandExecuted/回调先于 notify/registry 命令）；example InspectorPanel Events 节实时展示最近一条（B5）
- [x] **8.3** media resolver/uploader 钩子｜现状 ✅｜验收：`MediaResolver` 注入点（`resolve(block) → Widget?`，返回 null 回退占位、抛异常不崩）；editor + controller 双注入；example 用 `Image.network` 渲染 picsum 图片（B6）
- [x] **8.4** Example：格式工具栏 / 块插入菜单 / 表格菜单 / JSON inspector｜现状 ✅｜验收：bold/italic/underline/strikethrough/remark/clear style/link（弹框输入 URL，可清除）/H1-H3/paragraph/quote/todo/ordered list/unordered list/indent/outdent 全接 ToolbarController 的 active+enable 态；Bold/Italic 改走 ToggleMarkCommand 修正"不可取消"的语义 bug；表格结构按钮跟随 `canTableStruct`（B4）

### 9. 质量、可访问性与发布准备（阶段 8）

- [ ] **9.1** Golden tests｜现状 🔴｜验收：覆盖段落/代码/表格/合并 cell/图片占位/caret/selection → 见任务 C5
- [ ] **9.2** Windows/Web 差异测试清单｜现状 🟡｜验收：integration_test 目录内容核验
- [ ] **9.3** 语义化节点 / a11y 标签｜现状 🔴｜验收：Semantics 节点描述 block 类型与选区 → 见任务 C6
- [x] **9.4** 错误处理（JSON decode / 无效命令 / media 失败）｜现状 ✅｜验收：`DocumentDecodeException` / `UnknownCommandException` 结构化异常 + `tryLoadJson` / `tryExecuteCommand` 不抛入口；常见异常不崩（C7）
- [x] **9.5** 架构/API/migration/example 文档｜现状 ✅｜验收：`architecture.md` / `api_reference.md` / `migration_guide.md` 新增 + `running_guide.md` 刷新 + `schema_and_commands.md` 补「Error handling」节 + README 索引（C7）
- [x] **9.6** `flutter analyze` 干净 + `flutter test` 全绿｜现状 ✅｜验收：analyze 0 issues；346 tests 全绿（A0 基线 + A2/A4/A3/C4/C10/C1 累计 32 + B1 9 + B2 3 + B4 26 + B5 9 + C7 18 - 旧断言重写 2 + B6 7 + C2 21 + C3 24 = 346）

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
- [ ] **B3** 合并单元格视觉横跨（自定义 table layout）（对应 5.6）⚠️ 风险项
  - 验收标准：origin cell 真正 rowSpan/columnSpan 占满；covered cell 不渲染；JSON round-trip 不丢
  - 周期：4d（预留 30% buffer）｜依赖：A0
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
  - ✅ 结果：引 `package:html ^0.15.6`（纯 Dart、Dart 团队官方、4.96M 周下载、`flutter_markdown` 同款）做 HTML5 解析——**本库首个第三方运行时依赖**（pubspec 从零运行时依赖变为一个纯 Dart 依赖，docs 显式标注）。新增 `lib/src/codecs/html_codec.dart`（`HtmlCodec`，`encode` 模型→HTML fragment + `decode` HTML→模型 via `parseFragment` DOM walk）。Block 双向映射：`<h1>`-`<h6>`（level 取数字）/ `<p>` / `<blockquote>`（含 callout 归入）/ `<ul>`/`<ol>`/`<li>`（`<input type=checkbox>` → task + checked）/ `<pre><code class="language-x">`（language 取 class）/ `<table><thead/tr/th/td>`（th→isHeader，span 不还原 B3）/ `<img>`（assetId=src,file=alt）/ `<hr>`。Inline 双向：`<strong>`/`<b>`→bold、`<em>`/`<i>`→italic、`<s>`/`<del>`/`<strike>`→lineThrough、`<u>`→underline、`<a href>`→url、`<img>`→embed、`<br>`→换行；嵌套递归合并 attributes（`<strong><em>`→bold+italic）；HTML-escape `&<>`/`"`。import 容错：`html` 包 HTML5 spec 自纠正 malformed，decode 不抛；未知标签（div/span）递归子节点不丢内容；HTML entity 自动 decode/re-encode。`ClipboardService.pasteHtml` 从占位改为真实：解析 HTML fragment 成 `ClipboardPaste.blocks`（走 `PasteBlocksCommand` 还原多 block，3.6 验收核心）；构造加 `htmlCodec` 参数（有默认值，向后兼容）。`WenzRichTextController` 加 `htmlCodec` 构造参数 + `toHtml()`/`loadHtml()`/`tryLoadHtml()`（与 tryLoadJson/tryLoadMarkdown 对称）。导出 `html_codec.dart` tier 2。24 单测（`test/codecs/html_codec_test.dart`：export 8 例 golden 文本对照 heading/inline/link/quote/list/code/table+img/hr/escape + import 12 例 heading/nested-inline/link/list/task/pre-code/blockquote/table/img/hr/malformed-不抛/纯文本/entity-unescape + round-trip 1 例 + controller helpers 1 例 + clipboard pasteHtml 2 例）。docs：`api_reference.md` Codec 表 + 序列化段补；`architecture.md` Codec 层补 + 标注首第三方依赖；`migration_guide.md` 新增「HTML import/export」小节（用法 + 标签矩阵 + paste 还原 + 依赖说明）+ 边界从"未实现"改为"已支持"；`schema_and_commands.md` 补「HTML leniency」节；`running_guide.md` 剪贴板 + 边界更新。platform 剪贴板 HTML flavor 读取层仍留给业务（Flutter `Clipboard` API 限制）。video/file 无标准 HTML 语义（import 不还原）。colspan/rowspan 不还原（B3 范围）。全量 346 tests 全绿（+24）。analyze 根 + example 均 0 issues。⚠️ 风险项验收通过。
- [x] **C4** Plain text export（对应 7.6）
  - 验收标准：整篇导出纯文本，段落空行分隔
  - 周期：0.5d｜依赖：A0
  - ✅ 结果：`PlainTextCodec`（段落空行分隔 + 媒体 sentinel + omitEmptyBlocks 选项）；`controller.toPlainText()`；8 单测
- [ ] **C5** Golden tests 矩阵（对应 9.1）
  - 验收标准：覆盖段落/代码/表格/合并 cell/图片占位/caret/selection 高亮
  - 周期：3d｜依赖：B3
- [ ] **C6** a11y 语义节点 + a11y 标签（对应 9.3）
  - 验收标准：Semantics 节点描述 block 类型与选区；talkback/narrator 抽测
  - 周期：3d｜依赖：B4
- [x] **C7** 错误处理加固 + 文档（架构/API/migration/running guide）（对应 9.4 / 9.5）
  - 验收标准：JSON decode/无效命令/media 失败均不崩；docs 章节齐
  - 周期：3d｜依赖：C1
  - ✅ 结果：新增 `lib/src/codecs/document_errors.dart`（`DocumentDecodeException` 带 `reason`/`jsonPath`/`raw`，`UnknownCommandException` 带 `name`）；`RichTextJsonCodec` / `LegacyWenJsonCodec` / `decodeWithMigrations` 把裸 `FormatException`/`StateError`/cast 错误统一 catch 重抛结构化异常，保留 originating error 在 `.raw`；修掉 legacy 表格非数字 alignment key 裸抛（改 `_asNullableInt` 容错跳过）+ 非 Map block 条目静默丢失（保留跳过 + `kDebugMode` 下 `debugPrint`）；`CommandRegistry.build`/`executeFromJson` 改抛结构化异常。`WenzRichTextController` 新增 `tryLoadJson`（返回不可变 `TryLoadResult`：`ok`/`document?`/`error?`，失败不动文档/选区/历史/回调）+ `tryExecuteCommand`（返回 bool，失败不动文档）；`loadJson`/`executeCommand` 保持原抛错语义（向后兼容）。导出 `document_errors.dart` + tier 2 注释更新。docs：新增 `architecture.md`（分层 + 数据流 + tier 说明）、`api_reference.md`（按模块分组公共 API）、`migration_guide.md`（legacy 接入 + migration 框架 + 0.1.0 边界）；刷新 `running_guide.md`（删过时阶段 0 边界，改为「已支持」+ 当前边界）；`schema_and_commands.md` 补「Error handling」节；`README.md` 索引补 3 个新条目。media 加载失败随 B6 走（当前 media 全占位无加载路径）。11 codec/controller 单测（`test/codecs/document_errors_test.dart` 11 + `test/controller/controller_try_load_test.dart` 7）+ 修 2 处旧断言（migration `throwsFormatException`→`isA<DocumentDecodeException>`、command `throwsArgumentError`→`isA<UnknownCommandException>`）。
- [ ] **C8** formula / mention inline 渲染 + 命令（对应 1.2）
  - 验收标准：两种 inline 有 renderer 与插入命令；JSON round-trip
  - 周期：3d｜依赖：B4
- [ ] **C9** 移动端 selection handles（对应 4.5）
  - 验收标准：iOS/Android 手柄拖拽改选区
  - 周期：4d｜依赖：B2
- [x] **C10** 远距离 caret 跳转自动滚动（对应 6.6）
  - 验收标准：程序化跳到 block 400 自动滚到位（评估是否引入 positioned-list）
  - 周期：2d｜依赖：A0
  - ✅ 结果：估算偏移（平均块高 × index）+ 二帧精修，未引入 positioned-list；2 widget 测试

### D 组 · 发布准备

- [ ] **D1** 打 tag `0.1.0-alpha`
  - 验收标准：CHANGELOG + migration guide + example 可跑 + analyze/test 全绿
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

- **关键路径**：A0 → A3 → B4 → C2/C3 → D1（导入导出主线最长）— **C2/C3 已完成，主线已通**，剩 B3（表格合并视觉）为最大未决项
- **风险项**：B3（表格合并视觉）仍是最不确定项；C3（HTML）已验收通过（引 `package:html` 依赖）

---

## Part 4 · 验收方式

1. 每个任务 ID 对应一个 PR / 一个 commit，message 带 `[accept-XXX]` 前缀，便于回溯。
2. **🟡 项**：补测试即视为通过，无需改实现。
3. **🔴 项**：必须实现 + 测试 + docs 三件齐全。
4. **每周一次回归**：跑 A0 的 analyze + test，确保不回退。
5. **手验项**（A1/B1/B2/B3/C9）：在 `docs/acceptance_manual_checklist.md` 单独维护勾选表，三端（Win/Web/Android）各勾一遍。

---

## Part 5 · 与 roadmap 的差异说明

- **阶段 5（渲染与性能）**：roadmap 声明全部完成，核对源码后**确认完成**，仅 6.6（远距离 caret 自动滚动）未做，列为 C10。
- **阶段 4（表格）**：roadmap 声明完成，但合并单元格**视觉横跨**明确未做（rendering.md 自陈），本报告降级为 🟡 并拆出 B3 单独推进——**这是验收时最需要拍板的点**：接受当前"结构正确、视觉占 1×1"作为阶段 4 验收通过，还是要求 B3 完成才算阶段 4 收尾。
- **阶段 6/7/8**：C7 已完成（9.4 错误处理 + 9.5 文档）；B6 已完成（8.3 media resolver）；C2 已完成（7.4 Markdown）；C3 已完成（3.6 + 7.5 HTML）；C1/C4 已完成。其余 🔴（C5/C6/C8/C9 + B3/A1），符合预期（未到时间），任务表已覆盖。
- **阶段 6（导入导出）**：C2 + C3 已完成，导入导出主线收尾。`MarkdownCodec` 自写行级状态机（零第三方依赖，语法矩阵参照 `gpt_markdown`）；`HtmlCodec` 引 `package:html`（**本库首个第三方运行时依赖**，纯 Dart 官方库）做 HTML5 解析，覆盖同 Markdown 的标签矩阵 + 嵌套 emphasis 合并 + entity decode/re-encode。两者均容错降级段落不抛（Markdown/HTML 惯例）。`ClipboardService.pasteHtml` 把 HTML fragment 还原多 block（3.6）。video/file 无标准语法（import 不还原）；callout 映射为 quote/blockquote；LaTeX/radio button（gpt_markdown 支持）不覆盖；表格 colspan/rowspan 不还原（B3）。
- **阶段 2（Selection 与布局）**：B1（双击选词/三击选段 boundary 单测）与 B2（拖拽自动滚动）已完成，4.3 / 4.4 验收通过。B2 实现拆为「同步边缘滚动（全设备，每次 pointer-move 推进一步）」+「鼠标/触控笔 Ticker 持续滚动」两层：前者保证 touch 拖拽时列表跟随滚动（scrollable 自身 pan 手势在本 overlay 下不赢 arena，同步 jumpTo 是实际滚动源），后者让鼠标拖到边缘停留时持续滚动并持续重算 selection extent；editor 对 range selection 跳过 caret-scroll-into-view 回拉以避免冲突。
- **阶段 7（工具栏与业务集成 API）**：B4 已完成，B5 已完成，B6 已完成。`ToolbarController` 作为 `WenzRichTextController` 的派生 `ChangeNotifier`，随 host 通知重算 `ToolbarState` 快照——这是 toolbar 状态跟随选区的入口；B5 在 controller 上补齐 `onChanged`/`onSelectionChanged`/`onCommandExecuted` 三个业务集成回调（均在 `notifyListeners` 之前同步触发），作为比 `addListener` 粗粒度信号更细粒度的事件源。B6 补 `MediaResolver`（`resolve(block) → Widget?`）作为 media 块真渲染的快捷注入点：default image/video/file renderer 先问 resolver，返回 null 回退占位，抛异常经 `FlutterError.reportError` 上报后回退（呼应 9.4）；editor + controller 双注入，业务自组装 `Image`/video/任意 widget，库不引 `video_player` 等依赖——media 块从此可真渲染，加载失败兜底（业务侧 `errorBuilder` + resolver 抛异常 editor 捕获双保险）一并落地。Bold/Italic 在 example 原走 `FormatTextCommand`（不可取消 bool），B4 改走 `ToggleMarkCommand` 修掉该语义 bug。
- **阶段 8（质量、可访问性与发布准备）**：C7 已完成（9.4 + 9.5）。错误处理采用「结构化异常 + tryLoadJson/tryExecuteCommand 不抛入口」双轨：`DocumentDecodeException`/`UnknownCommandException` 带 `reason`/`raw` 链保留 originating error，业务可在 typed catch 与 no-throw 两种风格间二选一；codec/registry/migration 全部接入，`loadJson`/`executeCommand` 保持原抛错语义向后兼容。docs 补齐 `architecture.md`（分层总览，原本散在 refactor_plan/rendering/input_system）/ `api_reference.md`（按模块分组公共 API 表面）/ `migration_guide.md`（面向消费者的 legacy 接入 + migration 框架 + 0.1.0 边界），`running_guide.md` 刷新掉阶段 0 过时边界。media 加载失败兜底明确归入 B6（当前 media 全占位无加载路径，不在本任务造假）。
