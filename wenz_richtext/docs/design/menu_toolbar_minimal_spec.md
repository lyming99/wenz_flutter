# 菜单与悬浮工具栏简约风设计约束

## HTML 设计稿

- 文件：`ui/menu_toolbar_minimal_design.html`，纯 HTML/CSS，无外部依赖，可直接在浏览器打开预览。
- 覆盖：slash 菜单、block 操作菜单、表格悬浮工具栏、通用悬浮按钮组、长菜单滚动和搜索为空状态。
- 状态：浅色主题下展示 default、hover、selected、pressed、disabled、分组、readonly/canEdit=false 的禁用语义和移动端触控命中参考。
- 落地：页面内的关键参数面板对应本文件的视觉 Token；后续 Flutter 实现应优先映射共享 token/helper，再调整具体组件。
- 斜杆 popup（Electron 风格）：`ui/slash_popup_electron_design.html`，纯 HTML/CSS、无外部依赖、可直接浏览器打开。覆盖默认扁平列表、完整 13 项默认菜单项、单项状态对照（default/hover/selected/pressed）、长列表滚动与「未找到命令」空状态、可选分组态，以及 Electron 设计 Token 与色板；全部文案为简体中文。本文件是下文「Electron 风格斜杆 popup 规范」小节的视觉来源，`slash_menu_overlay.dart` 的 chrome 据此对齐。

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

- 圆角：popup 菜单容器 10px，菜单项与工具栏按钮 8px；对象卡片或媒体块继续使用其现有块级圆角，不因工具栏样式重置。
- 间距：popup 菜单容器内边距 4px；`PopupMenuItem.padding` 归零，菜单项内容统一由 `_kMinimalMenuItemContentPadding` 提供 10px 水平内边距；图标与文字间距 10px；工具栏按钮固定 32px，图标 18px，slash 菜单图标 20px。
- 阴影：popup 浮层使用轻量桌面阴影，当前实现等价于 elevation 3、shadow alpha 30；hover/focus 只在需要区分层级时复用 `_kSurfaceBoxShadow`。
- 边框：popup 浮层统一使用 `outlineVariant` 低透明度描边，浅色 alpha 112、深色 alpha 96；分割线只表达分组，不承担装饰性强调。
- 背景：浮层背景使用 `colorScheme.surfaceContainerLow`；内容选中或高亮使用 `primaryContainer`/`primary` 的低透明度变体；避免新增硬编码亮色背景。
- 文字层级：主标题使用 `bodyMedium` 中等字重；说明、快捷键和辅助文案使用 `labelSmall`/`onSurfaceVariant`；禁用态沿用 Flutter `PopupMenuItem.enabled=false` 与按钮 disabled 前景色。
- 工具栏按钮背景：图标按钮默认背景透明（`Colors.transparent`），不各自绘制独立胶囊背景。连体胶囊的共享容器背景由 `_MinimalFloatingToolbarSurface` 的 `Material.color`（`_floatingToolbarSurfaceColor`）统一承载，按钮透明地坐于其上。仅 hover/focus/pressed 状态下单个按钮才显示半透明叠加高亮（`hoverColor`/`focusColor`/`highlightColor`），提供瞬时视觉反馈；禁用态按钮同样不显示独立背景，仅前景色降透明度表达禁用语义。
- 高亮色：主色只用于当前项图标、pressed 叠加和少量选中态，不用于大面积工具栏底色；popup 选中项使用整行 primary 低透明铺底（浅色 alpha 22、深色 alpha 34）和 primary 图标/文字；危险动作只在图标/文本层表达，不改变菜单容器风格。

## 统一 Chrome 风格 popup 规范

本小节针对 `WenzSlashMenuOverlay`、mention 搜索、link hover、link edit dialog、公式编辑 popup、代码语言菜单和表格 floating toolbar 的统一 chrome。视觉来源仍参考 `ui/slash_popup_electron_design.html` 的桌面应用观感，但 chrome/阴影/圆角/描边需与上方「视觉 Token」保持一致：扁平克制、清晰层级、紧凑节奏，且只动外观与文案，不动定位/触发/键盘路由等行为。

- Chrome（容器）：
  - 圆角：`10px`（由既有 12 收敛，更桌面克制）。对应 `_kSlashMenuSurfaceRadius`。
  - 内边距：`6px`，紧凑节奏。对应 `_kSlashMenuPadding`。
  - 描边：`outlineVariant` 低透明描边，浅色 alpha `112`、深色 alpha `96`。对应各浮层 `*BorderAlphaLight/Dark`。
  - 背景：`colorScheme.surfaceContainerLow`，不引入硬编码亮色背景。
  - 阴影：弱化高程至 elevation ≈ `3`（原 6），shadow alpha 收敛至 `30`。对应各浮层 `*SurfaceElevation` / `*ShadowAlpha`。
- Spacing（条目）：
  - 圆角：`8px`。对应 `_kSlashMenuItemRadius`。
  - 高度：`34–38px`（建议 36px），垂直内边距收紧至约 `7px`、水平 `10px`。对应 `_kSlashMenuItemPadding`。
  - 图标位：`20px`，与文字间距 `10px`。对应 `_kSlashMenuIconSize` / `_kSlashMenuIconTextGap`。
  - 长列表：保留 `maxWidth` 184–320、`maxHeight` 约 320 的滚动约束，滚动不破坏容器圆角与内边距，且不隐藏分组/空状态语义。
- Typography（层级）：
  - 标题：`13px`、字重 600（semibold / medium 偏上）。
  - 描述：`11.5px`、字重 400，色用 `onSurfaceVariant`，与标题形成清晰主次。
  - 分组标题（可选增强）：`onSurfaceVariant`、小号大写字样；分隔线只表达分组，不承担强调。
- Selection（选中/键盘高亮）：
  - 背景使用 `primary` 低透明度：浅色 alpha `22`、暗色 alpha `34`，不整块强色填充。对应 `_kSlashMenuSelectedAlphaLight/Dark`、mention 选中态和 popup menu selected token。
  - 选中项的图标与标题回退 `primary`，描述保持 `onSurfaceVariant`。
  - 悬停（与键盘 focus 同强度）使用 `onSurface` 约 `5%` 的中性反馈。对应 `_kSlashMenuHoverAlpha`。
  - 按下使用 `primary` 约 `18%` 叠加 + 向下位移 1px，不改变尺寸/圆角。对应 `_kSlashMenuSplashAlpha`。
  - 禁用项保留位置与文案，前景透明度降至约 46%。
- Motion（动效）：
  - 背景/前景/位移统一 `120ms ease`（较一般 140ms 更利落），仅作轻量反馈，不改变 overlay 定位与尺寸。
- 文案与无障碍（与本计划中文化口径一致）：
  - 菜单项 `title` / `description`、空状态主副提示均为简体中文；`id` / `keywords` 不变。
  - 空状态 `Semantics` label 同步中文化（如「未找到斜杆命令」），保证读屏朗读为中文。
- 对齐说明：各浮层文件顶部或局部 token 指向本文件；落地时仅更新 chrome/spacing/typography/selection 相关常量与渲染，不改菜单项动作（`action`）、overlay 定位、输入焦点或键盘路由。

## 现有样式入口

- Slash 菜单：`lib/src/widgets/slash_menu_overlay.dart` 内的 `Material`、`_SlashMenuTile`、`selectedColor`、`InkWell` 反馈色和 icon/title/description 样式是后续落地入口。
- Popup 菜单：`lib/src/widgets/wenz_rich_text_editor.dart` 内 `_kPopupMenuRadius`、`_kPopupMenuElevation`、`_kPopupMenuPadding`、`_kPopupMenuItemPadding`、`_kMinimalMenuItemContentPadding`、`_kPopupMenuItemContentMinWidth`、`_kPopupMenuItemContentMaxWidth`、`_popupMenuColor`、`_popupMenuShadowColor`、`_popupMenuShape`、`_PopupMenuItemContent` 是公共入口。
- 其它编辑器浮层：`mention_search_overlay.dart`、`link_hover_overlay.dart`、`link_edit_dialog.dart` 中的 surface radius/elevation/shadow/border alpha 与 selected/hover token 应与 popup/slash chrome 同步；`_FormulaEditPopup`、代码语言菜单和表格更多菜单复用 `wenz_rich_text_editor.dart` 的 `_kPopupMenu*` helper。
- 工具栏按钮：`_kBlockToolbarButtonSize`、`_kBlockToolbarIconSize`、`_kBlockToolbarButtonRadius`、`_blockToolbarIconButtonStyle` 控制对象块与表格工具栏的按钮尺度和状态色。按钮默认背景透明，不绘制独立胶囊；`_MinimalFloatingToolbarSurface` 的 surface 颜色作为连体胶囊统一背景承载所有按钮；hover/focus/pressed 时单个按钮通过 `hoverColor`/`focusColor`/`highlightColor` 显示半透明高亮叠加。
- 悬浮工具栏承载：`_BlockFloatingToolbarSurface` 控制对象块工具栏 chrome；`TableFloatingToolbarOverlayRequest` 的 `minWidth`、`gap`、`fallbackHeight` 与 `_TableFloatingToolbarOverlayEntry` 的 clamp 定位控制表格浮层布局。
- 编辑器定位：`_kSlashMenuGap`、`_kPopupViewportInset`、`_kPopupMenuMaxWidth`、`_kPopupMenuMaxHeight` 控制 slash/popup 菜单在桌面与移动端视口中的可见区域。

## 后续抽取建议

- 将菜单容器、菜单项、工具栏按钮、浮层阴影等值收敛为同一组 menu/toolbar token，避免 slash 菜单与 popup 菜单各自硬编码。
- 表格 toolbar 的视觉 chrome 应复用对象块 `_BlockFloatingToolbarSurface` 或同源 token，`table_floating_toolbar_overlay.dart` 继续只负责 overlay 生命周期、测量和定位。
- 若新增 HTML 设计稿，应逐项映射本文件 token，并在 Flutter 落地时优先更新 token/helper，而不是在具体菜单项内散落新颜色或尺寸。
