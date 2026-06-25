# 反馈 #2 回归验证记录

- 验证日期：2026-06-25
- 对应计划：`docs/plan/plan_feedback_2_20260625-004108.md`
- 记录范围：P010「执行回归验证并更新记录」；计划文件保持只读，未勾选 checkbox，未更新计划进度区。

## 任务结论

| 任务 | 修复/覆盖范围 | 验证结论 | 遗留风险与建议 |
| --- | --- | --- | --- |
| P001 | 冻结包含 mention、quote、todo、info、table、formula 的最小反馈文档与异常边界。 | 后续回归均沿该组合场景补充自动化覆盖。 | 视觉类细节仍建议结合示例页人工复核。 |
| P002 | mention 原子内联节点后的普通文本选择、光标落点与表格单元格内一致性。 | 已纳入 `wenz_rich_text_editor_test.dart` 回归。 | 自定义 mention renderer 需保持单字符占位语义。 |
| P003 | quote 使用主题背景块、内边距、圆角和选择面，替代文本前缀渲染。 | quote 背景与选择行为已由 widget 测试覆盖。 | 主题自定义时需复核浅/深色对比度。 |
| P004 | todo 使用可交互 checkbox 切换 checked 状态，并保留文本选择能力。 | checkbox 状态、回调、重渲染保留与选择隔离已覆盖。 | 自定义 listItem renderer 需接入 todo 状态同步回调。 |
| P005 | info/callout 正文接入选择面、跨块选择与复制 offset。 | callout 正文点击、拖拽、键盘扩选、复制已覆盖。 | callout 标题仍按元数据展示，不作为正文 offset 编辑。 |
| P006 | 表格工具栏改为表格上方浮层，不再占用正文流空间。 | 工具栏位置与单元格布局不位移已覆盖。 | 宿主外层强裁剪容器可能影响顶部浮层可见性。 |
| P007 | 表格内部共享边框改为单侧绘制，消除重复双线。 | 2x2 单元格边框责任分配已覆盖。 | 自定义表格装饰需继续遵守共享边单侧绘制。 |
| P008 | 公式改用专用数学组件渲染，覆盖行内/块级与失败降级。 | 行内公式、块级公式、复制源文本与降级已覆盖。 | `flutter_math_fork` 布局差异仍建议在目标平台抽样手验。 |
| P009 | 补齐 mention、quote、todo、callout、table、formula 自动化回归。 | 本次 P010 已运行相关 widget 与 selection core 测试。 | 纯视觉间距可继续用人工截图比对补强。 |
| P010 | 执行静态分析与最小相关回归；清理验证中发现的阻断项。 | 见「验证命令」；当前相关验证均通过。 | 本次未运行全量测试，因 P010 仅要求富文本 widget 与选择器 core 回归。 |

## 验证命令

| 命令 | 结果 |
| --- | --- |
| `flutter analyze` | 先发现 3 个阻断项；已最小修正后复跑通过，`No issues found!`。 |
| `flutter test test\widgets\wenz_rich_text_editor_test.dart test\core\selection_commands_test.dart --reporter expanded` | 通过，113 项测试全部通过。 |
| `flutter test test\plugins\editor_plugin_test.dart --reporter expanded` | 通过，2 项测试全部通过；用于确认本次类型断言清理。 |

## 本次验证清理

- `MeasuredWidgetSpan` 在直接进入 `TextPainter` 且未显式设置 placeholder dimensions 的路径中提供自身 fallback 尺寸，避免公式 `WidgetSpan` 触发布局断言。
- 插件测试按 `InlineEmbedRendererRegistry.buildTextSpan` 当前返回类型 `InlineSpan?` 显式转换为 `TextSpan?` 后读取文本。
- quote 回归测试移除未使用的 raw 文本变量，保持 `flutter analyze` 干净。

## 范围确认

- 未修改计划文件、checkbox 或计划进度区。
- 未运行全量测试；本次只运行 P010 直接要求的 `flutter analyze`、富文本编辑器 widget 测试、选择器 core 测试，以及一个受本次清理影响的插件测试。
- 未扩展反馈 #2 以外的新功能；本次业务代码变更仅用于消除公式 `WidgetSpan` 回归验证中的布局断言。
