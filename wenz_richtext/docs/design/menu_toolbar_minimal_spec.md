# 菜单与悬浮工具栏简约风设计约束

## HTML 设计稿

- 文件：`ui/menu_toolbar_minimal_design.html`，纯 HTML/CSS，无外部依赖，可直接在浏览器打开预览。
- 覆盖：slash 菜单、block 操作菜单、表格悬浮工具栏、通用悬浮按钮组、长菜单滚动和搜索为空状态。
- 状态：浅色主题下展示 default、hover、selected、pressed、disabled、分组、readonly/canEdit=false 的禁用语义和移动端触控命中参考。
- 落地：页面内的关键参数面板对应本文件的视觉 Token；后续 Flutter 实现应优先映射共享 token/helper，再调整具体组件。

## 覆盖范围

- Slash 菜单：`WenzSlashMenuOverlay`，由 `/` 或等价输入触发，覆盖空态外的打开态、键盘高亮项、鼠标 hover、点击 pressed 与移动端触控选择。
- 块操作菜单：图片、视频、附件、分割线等对象块的 `_ObjectBlockToolbar`、`_ObjectMoreMenu`、`_FileBlockActionMenu` 及 `showMenu` 入口，覆盖普通、hover、focus、pressed、disabled、readonly/canEdit=false 状态。
- 块悬浮工具栏：`_FloatingObjectBlockToolbar`、`_BlockFloatingToolbarSurface` 和文件块 hover/focus 外层，覆盖对象块选中态、hover/focus 触发态、只读态下仅保留安全动作的场景。
- 表格悬浮工具栏：`TableFloatingToolbarOverlayHost`、`TableFloatingToolbarOverlayEntry` 承载的表格 toolbar，覆盖选区变化、贴近表格顶部定位、视口顶部夹紧、窄屏宽度收敛和触控命中。
- 编辑器级 overlay：`WenzRichTextEditor` 内 slash 菜单定位、popup 菜单定位与系统 `OverlayPortal` 宿主，覆盖桌面鼠标、键盘导航、移动端软键盘遮挡和 viewport inset。

## 状态约束

- 打开态：浮层出现时不改变编辑器内容布局，使用 overlay 承载；浮层需阻断穿透点击，点击项后由现有 controller/action 分发关闭或更新。
- Hover/focus：只提升当前项或当前块的可见性，不引入大面积背景；focus 与 hover 的视觉强度应一致或接近，便于键盘与鼠标用户获得同等反馈。
- Pressed：使用主色低透明度叠加作为瞬时反馈，不改变组件尺寸、圆角或图标布局。
- Disabled：禁用项保留位置和文案，降低前景色透明度，不允许触发 mutation；readonly/canEdit=false 视为 mutation 动作 disabled，仅保留复制、预览等安全动作。
- Selected/highlighted：slash 当前高亮项与对象块选中态使用主色的低饱和容器色，避免整块强色填充。
- 移动端触控：交互目标不小于现有 32px 工具栏按钮；菜单项垂直内边距不得继续压缩；软键盘出现时 slash 菜单优先保持在可视区域内。

## 视觉 Token

- 圆角：菜单容器 12px；菜单项与工具栏按钮 8px；对象卡片或媒体块继续使用其现有块级圆角，不因工具栏样式重置。
- 间距：菜单容器内边距 4–6px；菜单项水平内边距 10–12px；图标与文字间距 10px；工具栏按钮固定 32px，图标 18px，slash 菜单图标 20px。
- 阴影：浮层使用轻量阴影，当前实现等价于 elevation 6、shadow alpha 48；hover/focus 只在需要区分层级时复用 `_kSurfaceBoxShadow`。
- 边框：浮层统一使用 `outlineVariant` 低透明度描边；分割线只表达分组，不承担装饰性强调。
- 背景：浮层背景使用 `colorScheme.surfaceContainerLow`；内容选中或高亮使用 `primaryContainer`/`primary` 的低透明度变体；避免新增硬编码亮色背景。
- 文字层级：主标题使用 `bodyMedium` 中等字重；说明、快捷键和辅助文案使用 `labelSmall`/`onSurfaceVariant`；禁用态沿用 Flutter `PopupMenuItem.enabled=false` 与按钮 disabled 前景色。
- 高亮色：主色只用于当前项图标、pressed 叠加和少量选中态，不用于大面积工具栏底色；危险动作只在图标/文本层表达，不改变菜单容器风格。

## 现有样式入口

- Slash 菜单：`lib/src/widgets/slash_menu_overlay.dart` 内的 `Material`、`_SlashMenuTile`、`selectedColor`、`InkWell` 反馈色和 icon/title/description 样式是后续落地入口。
- Popup 菜单：`lib/src/widgets/wenz_rich_text_editor.dart` 内 `_kPopupMenuRadius`、`_kPopupMenuElevation`、`_kPopupMenuPadding`、`_kPopupMenuItemPadding`、`_popupMenuColor`、`_popupMenuShadowColor`、`_popupMenuShape` 是公共入口。
- 工具栏按钮：`_kBlockToolbarButtonSize`、`_kBlockToolbarIconSize`、`_kBlockToolbarButtonRadius`、`_blockToolbarIconButtonStyle` 控制对象块与表格工具栏的按钮尺度和状态色。
- 悬浮工具栏承载：`_BlockFloatingToolbarSurface` 控制对象块工具栏 chrome；`TableFloatingToolbarOverlayRequest` 的 `minWidth`、`gap`、`fallbackHeight` 与 `_TableFloatingToolbarOverlayEntry` 的 clamp 定位控制表格浮层布局。
- 编辑器定位：`_kSlashMenuGap`、`_kPopupViewportInset`、`_kPopupMenuMaxWidth`、`_kPopupMenuMaxHeight` 控制 slash/popup 菜单在桌面与移动端视口中的可见区域。

## 后续抽取建议

- 将菜单容器、菜单项、工具栏按钮、浮层阴影等值收敛为同一组 menu/toolbar token，避免 slash 菜单与 popup 菜单各自硬编码。
- 表格 toolbar 的视觉 chrome 应复用对象块 `_BlockFloatingToolbarSurface` 或同源 token，`table_floating_toolbar_overlay.dart` 继续只负责 overlay 生命周期、测量和定位。
- 若新增 HTML 设计稿，应逐项映射本文件 token，并在 Flutter 落地时优先更新 token/helper，而不是在具体菜单项内散落新颜色或尺寸。
