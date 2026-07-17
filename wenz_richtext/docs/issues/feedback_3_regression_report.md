# 反馈 #3 回归验证记录

- 验证日期：2026-06-25
- 对应计划：`docs/plan/plan_feedback_3_20260625-014905.md`
- 记录范围：P007「补充自动化与手工回归验证」；计划文件保持只读，未勾选 checkbox，未更新计划进度区。

## 自动化覆盖

| 验收点 | 覆盖入口 | 结论 |
| --- | --- | --- |
| 正文切换引用后立即选择、撤销/重做后选择 | `paragraph converted to quote remains immediately selectable` | 已覆盖点击定位、Shift+方向键扩选、拖拽选择和复制文本。 |
| 代码高亮与不支持语言降级 | `code block syntax highlights supported languages and leaves unsupported plain` | 已覆盖 Dart/JavaScript/JSON/Markdown token 色彩，以及未知语言纯文本降级。 |
| 图片最小化展示与单独选中悬浮菜单 | `image object toolbar updates and resets display size` | 已覆盖不显示标题/文件名、菜单在图片上方、宽度设置与重置。 |
| 附件简化展示与操作菜单 | `file block stays compact and updates status from action menu` | 已覆盖只显示文件图标、文件名和附件操作菜单，不展示大小、MIME、URL 等冗余信息。 |
| 主要操作 tooltip 中文化 | `feedback 3 primary operation tooltips stay localized` | 已覆盖代码、图片、附件、表格主要操作入口的中文 tooltip 与附件菜单中文项。 |

## 验证命令

| 命令 | 结果 |
| --- | --- |
| `flutter test test/widgets/wenz_rich_text_editor_test.dart --name "file block stays compact\|feedback 3 primary operation tooltips\|paragraph converted to quote\|code block syntax highlights\|image object toolbar" --reporter expanded` | 通过，5 项 P007 直接相关 widget 回归全部通过。 |
| `flutter analyze` | 通过，`No issues found!`。 |

## 手工回归清单

| 场景 | 操作 | 预期 |
| --- | --- | --- |
| 引用选择 | 在示例编辑器中输入普通段落，切换为引用后立即点击、拖拽、Shift+方向键扩选并复制。 | 引用文字无需重新输入即可选择和复制；撤销/重做后仍稳定。 |
| 代码高亮 | 插入 Dart/JavaScript/JSON/Markdown/未知语言代码块，切换明暗主题抽样查看。 | 支持语言有清晰 token 高亮；未知语言按等宽纯文本显示且可编辑/选择。 |
| 中文 tooltip | 逐一悬停工具栏、代码、图片、附件、表格主要按钮。 | 可见 tooltip 为中文短句，同一操作文案一致。 |
| 图片块 | 插入带标题/文件名的图片块，分别查看未选中和单独选中状态。 | 未选中只显示图片本体；单独选中时仅在图片上方显示悬浮操作菜单。 |
| 附件块 | 插入普通文件和图片附件，使用长文件名、失败/上传中状态抽样。 | 只显示图标/缩略图、文件名和操作菜单；长文件名不撑破编辑器宽度。 |

## 未覆盖风险与建议

- 本次未运行全量测试；P007 只执行反馈 #3 直接相关 widget 回归与 `flutter analyze`。
- 本次未启动 Windows/Web/Android 示例应用做真实三端人工点击；建议发布前按「手工回归清单」在目标平台各抽样一次。
- 代码高亮的视觉对比度已由主题色断言覆盖基础映射，仍建议在业务自定义主题下做截图抽检。
- 图片上方悬浮菜单在强裁剪父容器或极窄宽度下可能受宿主布局影响，建议集成方在真实页面复核。

## 范围确认

- 未修改计划文件、checkbox 或计划进度区。
- 未扩展反馈 #3 以外的新功能；本次业务代码未改动，仅补充 P007 直接相关测试与验证记录。
