# 项目验收、Roadmap 与完善计划

> 整理日期：2026-06-23
> 基于：`docs/acceptance_report.md`、`docs/optimization_roadmap.md`、`docs/acceptance_manual_checklist.md`、`docs/architecture.md`、`docs/running_guide.md`

## 1. 当前验收结论

`wenz_richtext` 已经从原型推进到可内部试用的 Flutter 富文本编辑器包：自研文档模型、命令体系、事务/历史、Widget 渲染、输入桥、剪贴板、导入导出、工具栏状态、业务回调、media resolver、错误处理和核心文档都已落地。

本次本地复核结果：

- `flutter analyze`：通过，0 issues。
- `flutter test`：通过，381 tests passed。
- `flutter test test/benchmarks/editor_benchmarks.dart`：通过，5 benchmarks passed。
- `cd example && flutter analyze`：通过，0 issues。
- `cd example && flutter test`：通过，1 test passed。
- `rg "ydart|package:ydart|YDoc|YMap|YArray|YText|UndoManager" pubspec.yaml lib test`：无命中，源码/测试/pubspec 未残留 ydart/Yjs 依赖。

验收报告中仍有不少 checkbox 未勾选，但其中一部分是“实现已完成、尚未逐项手验或补勾”的状态。真正影响 `0.1.0-alpha` 收口的主线是下面这些未决任务。

## 2. Roadmap 完成度

| 阶段 | 当前判断 | 说明 |
| --- | --- | --- |
| 阶段 0：稳定原型 | 基本完成 | API、example、基础输入/选择、测试基线已建立。 |
| 阶段 1：输入系统 | 基本完成，需三端手验 | `EditorTextInputClient`、组合输入、快捷键、复制粘贴已实现；A1 仍需 Win/Web/Android 手动验收。 |
| 阶段 2：Selection 与布局 | 大部分完成 | 跨块拖拽、双击/三击、自动滚动已完成；移动端 selection handles、只读复制体验仍需补齐或确认。 |
| 阶段 3：模型与命令增强 | 完成 | schema、命令、pipeline 已可用；formula/mention inline 已有模型、插入命令、默认渲染与 `InlineEmbedRenderer` 自定义 span contract。 |
| 阶段 4：表格编辑器 | 自动化完成，待三端手验 | 行列、合并/拆分、导航、JSON round-trip 已有；B3 合并单元格视觉横跨已落地自定义 Stack grid layout。 |
| 阶段 5：渲染与性能 | 完成 | renderer registry、虚拟化、增量 rebuild、layout cache、benchmark 已有；当前 benchmark 数字已回填到文档。 |
| 阶段 6：导入导出与兼容 | 主线完成 | rich JSON、legacy JSON、migration、Markdown、HTML、plain text 已完成；表格 colspan/rowspan 导入受 B3 影响。 |
| 阶段 7：工具栏与业务集成 | 完成 | ToolbarController、callbacks、MediaResolver、example 主流程均已落地。 |
| 阶段 8：质量、可访问性与发布 | 部分完成 | 错误处理、文档、基础 Golden 矩阵和自动化 Semantics 节点已补齐；屏幕阅读器与跨端手验仍是发布前缺口。 |

## 3. 未决项优先级

### P0：验收文档同步与发布口径

周期：0.5-1 天

状态：2026-06-23 已完成主体同步，剩余 `nul` 文件需人工确认后再处理。

- 已更新 `docs/acceptance_report.md` 中旧的测试数量（当前本机为 381 tests passed，不再是 346/373）。
- 已将 benchmark 当前结果回填到验收记录。
- 已完善 `docs/acceptance_manual_checklist.md`，把 A1/B3/C9 拆成可逐项打勾的表格。
- 确认根目录未跟踪的 `nul` 是否误生成；它会让 `rg` 在 Windows 下报 `os error 1`，建议确认后清理或加入排除规则。

### P1：A1 IME 三端验收

周期：2 天

- Win/Web/Android 各跑 example，分别验证中文拼音、五笔、日文输入：组合区下划线、候选提交、退格、选区替换、表格 cell 输入。
- Windows 额外记录微软输入法与第三方输入法表现。`docs/windows_ime_third_party_position_issue.md` 已说明第三方 IME 候选框偏移可能来自 Flutter Windows engine 兼容层，验收应区分“本库额外问题”和“Flutter/TextField 同样复现的问题”。
- 输出已知问题清单，决定是否把第三方 IME 候选框位置列为 alpha 已知限制。

### P1：B3 合并单元格视觉横跨

周期：4 天，预留 30% buffer

状态：2026-06-23 自动化完成，剩余三端手验。

- 已重构默认 table renderer，让 origin cell 根据 `rowSpan/columnSpan` 真正占满跨行/跨列区域。
- covered cell 不渲染、不参与点击命中，但结构仍保留，保证 undo/redo 和 JSON round-trip 不丢。
- 已补 widget test：横向合并 covered 区域命中 anchor、2×2 合并右下 covered 区域命中 anchor。
- 下一步可推进 C5 Golden，因为 Golden 矩阵需要覆盖合并 cell。

### P2：C5 Golden tests 矩阵

周期：3 天，依赖 B3

状态：2026-06-23 基础矩阵完成。

- 已覆盖段落/heading、code、merged cell、image placeholder、caret、selection highlight。
- 已固定 surface size 与主题，baseline 位于 `test/widgets/goldens/`。
- Golden 已纳入默认 `flutter test`，也可单独运行 `flutter test test/widgets/editor_golden_test.dart`。

### P2：C6 a11y 语义节点

周期：3 天

状态：2026-06-23 自动化语义节点已完成，屏幕阅读器抽样手验待补。
- 已为 block 类型、表格 cell、选区状态增加 Semantics 描述；表格 cell 标签包含 row/column/header/span/selected。
- 已补 widget 语义测试；Windows Narrator / Android TalkBack 仍需抽样手验。
- 公式、mention、media 等非文本节点已有可朗读 fallback；屏幕阅读器实际体验待手验记录。

### P2：C8 formula / mention inline

周期：3 天

状态：2026-06-23 自动化完成。
- `InlineEmbed` 中 formula/mention 的数据结构、插入命令和 controller wrapper 已有；本轮新增 `InlineEmbedRenderer` / `InlineEmbedRendererCallback` renderer contract。
- 默认 text/callout/table cell renderer 已显示 formula 文本与 mention `@label`，并允许业务返回自定义 `TextSpan`。
- JSON round-trip 已覆盖；Markdown/HTML 仍按既有降级策略输出可读文本，不还原为公式/mention embed。

### P3：C9 移动端 selection handles

周期：4 天，依赖 B2

- Android/iOS 上实现手柄拖拽修改选区，处理跨块、表格 cell、滚动边缘。
- 与现有桌面拖拽选择共享 selection model，不引入新的路径语义。
- 补 Android 手验记录；iOS 若暂无设备，至少在文档中标注未覆盖风险。

### P3：D1 发布准备

周期：1 天，依赖 A1/B3/C6/C8/C9 取舍拍板

- 补 `CHANGELOG.md` 与 `0.1.0-alpha` 发布说明。
- 冻结 public API tier，确认哪些是 stable / stabilising / experimental。
- 跑发布前命令：`flutter analyze`、`flutter test`、benchmark、example analyze/test、三端手验清单。
- 根据是否完成 C9 与屏幕阅读器手验决定 alpha 边界；未完成则必须写入 known limitations。

## 4. 建议推进顺序

```text
Week 1:
  P0 文档同步
  A1 IME 三端手验
  B3 table merged-cell renderer

Week 2:
  C5 Golden tests
  C6 a11y
  C8 formula / mention inline

Week 3:
  C9 mobile selection handles
  D1 0.1.0-alpha 发布准备
```

如果需要尽快出内部 alpha，可以采用“功能边界拍板版”：

- 必做：P0、A1、B3、D1。（C5 基础矩阵已完成）
- 可作为 alpha known limitations：C6 屏幕阅读器抽样手验、C9。
- 条件：文档必须明确 a11y 手验和移动端 handles 的限制；formula/mention 自动化能力已完成，不再作为 inline 能力缺口。

## 5. 发布前验收门禁

发布 `0.1.0-alpha` 前建议固定以下门禁：

```powershell
flutter analyze
flutter test
flutter test test\benchmarks\editor_benchmarks.dart
cd example
flutter analyze
flutter test
```

手动门禁：

- `docs/acceptance_manual_checklist.md` 中 A1/B1/B2/B3/C9 三端记录齐全。
- 合并单元格视觉横跨有截图或 Golden 证据。
- Windows 第三方 IME 候选框问题已归类：本库可修的问题必须修；Flutter engine 层问题写入 known limitations。
- `rg "ydart|package:ydart|YDoc|YMap|YArray|YText|UndoManager" pubspec.yaml lib test` 无命中。
- README、API reference、migration guide、running guide 与实际能力一致。
