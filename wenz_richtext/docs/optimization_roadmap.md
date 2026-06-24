# Wenz RichText 优化阶段性计划

## 目标

把当前原型编辑器推进为可用于业务集成的自研富文本编辑器。核心原则：

- 不依赖 ydart/Yjs 作为文档模型或编辑内核。
- 文档模型、命令、渲染、输入、历史、序列化各层边界清晰。
- 先保证单机编辑体验稳定，再预留协作、插件、跨端扩展能力。
- 每个阶段都要有可演示功能、自动化测试和明确验收标准。

## 当前状态

已完成：

- 自研文档模型：block、inline、table、attributes。
- 自研命令层：插入、删除、回车、样式、块替换、表格结构、表格单元格文本。
- controller：命令执行、undo/redo、JSON/legacy JSON 加载。
- Widget 原型：文本、代码、表格、图片/视频占位、分割线渲染。
- 基础输入：字符输入、Enter、Backspace、Delete、左右方向键、Shift+方向键。
- 鼠标交互原型：文本/代码块点击定位、拖拽选择、selection 高亮、caret 绘制。
- example：Web/Windows 可运行演示。

主要短板：

- 还没有完整 IME/组合输入/TextInputClient。
- 选择能力仍以单块文本为主，跨块拖拽、表格单元格选择还不完整。
- 文本布局和 selection overlay 还在 Widget 层，后续需要沉淀成稳定渲染层。
- 表格、图片、链接、公式、附件等复杂块的编辑体验还只是骨架。
- 缺少剪贴板、快捷键体系、命令合并、自动格式化、导入导出等生产级功能。

## 阶段 0：稳定现有原型

周期：1 周

任务：

- 梳理当前 public API，标记 experimental API。
- 修复鼠标点击、拖拽选择、caret 绘制在 Windows/Web 下的差异。
- 统一 `DocumentSelection` 在文本块、代码块、表格单元格里的路径语义。
- 给 Widget 层增加 debug 开关，显示 selection path、offset、block id。
- 整理 example，把 Web 和 Windows 两端的启动说明写进 docs。

验收标准：

- Windows/Web 均可点击文本任意位置定位 caret。
- 文本块和代码块可拖拽选择并显示高亮。
- 基础键盘输入、删除、回车、undo/redo 不回退。
- `flutter analyze` 无问题，核心测试和 example 测试通过。

## 阶段 1：输入系统完善

周期：2-3 周

任务：

- 实现 TextInputClient 或等价输入桥，支持系统输入法、组合输入、候选词提交。
- 支持复制、剪切、粘贴：
  - 纯文本粘贴。
  - 富文本 JSON 粘贴。
  - HTML/Markdown 粘贴预留解析入口。
- 完善快捷键：
  - Ctrl/Cmd+A/C/X/V/Z/Y。
  - Home/End/PageUp/PageDown。
  - Ctrl/Cmd+Left/Right 按词移动。
  - Shift 组合扩选。
- 增加命令合并策略：
  - 连续输入合并为一个 undo step。
  - 连续删除合并。
  - 光标移动不进入历史。

验收标准：

- 中文输入法可正常输入、选词、提交。
- 复制粘贴在 Windows/Web 可用。
- undo/redo 粒度符合常见编辑器体验。
- 输入相关测试覆盖命令层、controller、Widget。

## 阶段 2：Selection 与布局引擎

周期：3-4 周

任务：

- 抽出 `TextLayoutService`：
  - offset 到坐标。
  - 坐标到 offset。
  - selection boxes。
  - caret rect。
- 支持跨块拖拽选择。
- 支持双击选词、三击选段。
- 支持拖拽选择自动滚动。
- 支持 selection overlay handles，为移动端预留。
- 支持只读模式下选择和复制。

验收标准：

- 鼠标可从一个段落拖到另一个段落形成跨块 selection。
- selection 高亮覆盖多行、多块、代码块。
- 双击选词、三击选段行为稳定。
- selection/caret 绘制不改变文本布局和文档 offset。

## 阶段 3：文档模型与命令体系增强

周期：3-4 周

任务：

- 增加 schema/normalizer：
  - 空文档自动保持一个 paragraph。
  - 不合法 block/inline 自动修正或拒绝。
  - table cell 内 block 结构约束。
- 完善 inline：
  - link。
  - remark/comment anchor。
  - formula。
  - mention。
  - inline image/embed 预留。
- 完善 block：
  - todo/list 层级。
  - quote 嵌套。
  - code language。
  - callout。
  - file/media block。
- 增加命令注册表和可扩展 command pipeline：
  - before/after hooks。
  - command validation。
  - command result metadata。

验收标准：

- 任意命令执行后文档都满足 schema。
- 复杂样式跨 TextRun 拆分/合并稳定。
- block/list/table 的增删改都有单元测试。
- 插件可以注册新命令而不修改核心 executor。

## 阶段 4：表格编辑器

周期：3 周

状态：已完成。基础编辑、选择、行列操作、列宽/表头/背景色、模型级合并/拆分、Tab 末尾新增行、Enter cell 内换行、Left/Right 跨 cell 与 Up/Down 同列跨行导航、JSON round-trip 均已接入并覆盖单测/widget 测试。默认 table renderer 已从 Flutter `Table` 改为自定义 Stack grid layout，合并单元格的 origin cell 会按 `rowSpan`/`columnSpan` 真正横跨多行多列，covered cell 不渲染、不参与点击命中。

任务：

- 表格 cell 点击定位、cell 内文本 selection。
- 行/列选择、整表选择。
- 插入/删除行列、合并/拆分单元格。
- 列宽调整。
- 表头、对齐、背景色。
- 表格键盘导航：Tab、Shift+Tab、Enter、方向键。

验收标准：

- 表格内可以像普通文本一样输入、删除、选择。
- Tab 能在单元格之间移动，最后一个单元格可新增行。
- 行列操作进入 undo/redo。
- 表格 JSON round-trip 不丢结构。

## 阶段 5：渲染与性能

周期：3-5 周

任务：

- ~~抽象 block renderer registry。~~ ✅ 已完成（`BlockRendererRegistry` / `BlockRenderContext` / `WenzRichTextEditor.installDefaultRenderers`，详见 `docs/rendering.md`）。
- ~~大文档虚拟化渲染：~~ ✅ 已完成（`ListView.separated` 惰性构建 + `AutomaticKeepAlive` 保活光标/选区端点 block；选区模型按 blockIndex 工作，跨不可见区域状态正确；已知边界见 `docs/rendering.md`）。
  - ~~只布局可视区域附近 block。~~
  - ~~selection 跨不可见区域时保持状态正确。~~
- ~~增量 rebuild：~~ ✅ 已完成（controller 通过 `lastChangedBlockIds` 暴露变更 block id 集，编辑器 `_KeepAliveBlock` 仅在内容变更或选区/光标/IME 命中时重建，未变更 block 复用缓存 child 跳过 span 重建）。
  - ~~block-level dirty 标记。~~
  - ~~controller change metadata。~~
- ~~性能基准：~~ ✅ 已完成（`test/benchmarks/editor_benchmarks.dart`，覆盖 1k blocks / 10k inline runs / 50×20 大表格 / 高级混合文档，宽松 guard + 打印 µs，与常规 `*_test.dart` 套件隔离，手动运行）。
  - ~~1k blocks。~~
  - ~~10k inline runs。~~
  - ~~大表格。~~
  - ~~高级混合文档。~~
- ~~避免每帧重复构建 TextPainter。~~ ✅ 已完成（`SharedTextLayoutCache` 跨 remount 复用已布局 painter，脏 block 变更时失效；benchmark 含 scroll/remount 场景）。

验收标准：

- ~~1k 段文档滚动不卡顿。~~ ✅（虚拟化 benchmark 全绿；当前参考值见 `docs/rendering.md`）
- ~~连续输入平均帧耗时稳定。~~ ✅（增量 rebuild + 虚拟化）
- ~~block 局部变更不会触发整篇文档重建。~~ ✅（`lastChangedBlockIds` + `_KeepAliveBlock` 缓存）
- ~~有可重复运行的 benchmark。~~ ✅

## 阶段 6：导入导出与兼容

周期：2-3 周

任务：

- 完善 legacy JSON import。
- 输出稳定 rich text JSON schema。
- Markdown import/export。
- HTML paste/import/export。
- plain text export。
- 增加 schema version migration。

验收标准：

- legacy 数据可批量迁移到新模型。
- rich JSON 版本升级有 migration 测试。
- Markdown/HTML 覆盖标题、段落、列表、代码、表格、链接、图片占位。

## 阶段 7：工具栏与业务集成 API

周期：2 周

任务：

- 增加 toolbar controller：
  - 当前 selection active styles。
  - 当前 block type。
  - command enable/disable 状态。
- 完善 example：
  - 格式工具栏。
  - 块插入菜单。
  - 表格菜单。
  - JSON inspector。
- 提供业务集成回调：
  - onChanged。
  - onSelectionChanged。
  - onCommandExecuted。
  - media resolver/uploader。

验收标准：

- toolbar 状态跟随 selection 变化。
- 禁用状态准确，例如无 selection 时部分命令不可用。
- example 能覆盖主要编辑路径。
- API 文档包含最小接入示例。

## 阶段 8：质量、可访问性与发布准备

周期：2-3 周

任务：

- 增加 Golden tests。
- 增加 Windows/Web 差异测试清单。
- 增加语义化节点与可访问性标签。
- 增加错误处理：
  - JSON decode 错误。
  - 无效命令。
  - media 加载失败。
- 文档：
  - 架构说明。
  - API 文档。
  - migration guide。
  - example 使用说明。

验收标准：

- 关键渲染场景有 Golden tests。
- 常见异常不会导致 editor 崩溃。
- docs 覆盖安装、初始化、命令、序列化、扩展。
- 可打 tag 作为 `0.1.0-alpha` 内部试用版。

## 优先级建议

第一优先级：

- IME/TextInputClient。
- 跨块 selection。
- 复制/粘贴。
- 命令合并和 undo 粒度。

第二优先级：

- 表格完整编辑。
- toolbar state。
- JSON schema/migration。
- 性能虚拟化。

第三优先级：

- Markdown/HTML。
- 插件注册。
- 移动端 selection handles。
- Golden/benchmark 完整矩阵（ADV-028 已补高级块 + inline embed golden 与高级混合文档 benchmark）。

## 近期两周任务拆分

第 1 周：

- 抽出 `TextLayoutService`。
- 将文本/代码块 selection 绘制从 Widget 内部拆出。
- 补跨块 selection 数据结构和测试。
- 实现 Ctrl/Cmd+A、Home/End。
- 完善 example 中 selection debug 信息。

第 2 周：

- 接 TextInputClient，优先打通中文输入。
- 实现复制/剪切/粘贴纯文本。
- 实现连续输入命令合并。
- 补 Windows/Web 手动验收清单。
- 更新 docs 和 example。

## 风险点

- IME 是最大风险，必须尽早做，避免后期重构输入层。
- 跨块 selection 如果和表格 cell selection 混在一起实现，会导致路径语义混乱，需要先统一 selection model。
- RichText/Widget 组合渲染简单但性能上限有限，长期要考虑专门布局缓存或 RenderObject。
- 表格编辑复杂度高，应当单独作为阶段，不要和普通文本 selection 混做。

## 阶段完成定义

每个阶段必须满足：

- 有可运行 example。
- 有核心单元测试。
- 有 Widget 测试或 Golden 测试。
- `flutter analyze` 无问题。
- `flutter test` 通过。
- docs 更新。
- 不引入 ydart/Yjs 依赖。
