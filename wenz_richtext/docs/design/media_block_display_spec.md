# 图片/视频块显示设计约束

## HTML 设计稿

- 文件：`ui/media_block_display_design.html`，纯 HTML/CSS、无外部依赖、可直接在浏览器打开预览。由需求 #63 P001 产出，是图片/视频块「显示」的**唯一视觉来源**。
- 风格同源：与 `ui/slash_popup_electron_design.html` 一致（Electron 桌面克制：弱化高程、两层阴影、清晰层级、紧凑节奏），复用 colorScheme token，不引入硬编码亮色；全部文案为简体中文。
- 覆盖（与 P003/P004 落地点逐项对应）：
  - 图片块 figure chrome（圆角 / 阴影 / 最大宽度 / `caption` / `altText`）、显示尺寸 `showWidth/showHeight`、选中后左右边缘 resize 手柄、状态全集（空占位 / 加载上传中 / 已加载 / 加载失败，各含 默认 / 悬停 / 选中描边 / 只读裁剪）。
  - 视频块封面预览 + 播放覆盖层（默认 / 悬停 / 按下）、播放中 / 缓冲中 / 加载失败 / 占位态、宽高比处理（`aspectRatio`）、选中描边、只读裁剪。
  - 图片 / 视频对象工具栏 Overlay：选中态工具栏由编辑器级 `ObjectBlockToolbarOverlayHost` 承载，锚定媒体 frame 顶部，不作为块布局子节点；覆盖定位、viewport 夹紧、命中范围与选中描边关系。
  - 明色 + 暗色双 token 版本（圆角 / 阴影层数 / 描边线宽 / caption 布局在两色下一致，仅颜色随主题切换）。
  - 设计 Token 参数面板：逐项给出圆角、阴影、垂直外边距、最大宽度、播放按钮尺寸、选中描边等，并标注对应 Flutter 常量名，作为本文件「视觉 Token」小节的来源。
- 总览稿联动：`ui/richtext_design.html` 的图片（section 9）/视频（section 10）已各补一句指向本稿的说明，保持两稿口径一致；本约束不重写总览稿。
- 范围边界：只动图片/视频块的**显示与交互态**（figure chrome、caption、占位、状态、选中描边、图片边缘 resize、只读裁剪、对象工具栏承载位置）；不新增视频播放器 / 网络图片插件依赖（维持 `MediaResolver` 注入式架构），不改 `VideoBlockNode` / `ImageBlockNode` schema、`MediaResolver` 注入、预览 API、序列化、导入导出、插入 / 删除命令与既有选区 / 双击预览。

## 覆盖范围

- 图片块已加载内容：`_ImageBlockContent`（`lib/src/widgets/wenz_rich_text_editor.dart`），承载 `MediaResolver` 解析成功后的图片 widget；外层 figure chrome 由其包装（surface 底 + `_kMediaCornerRadius` 圆角 + `_kSurfaceBoxShadow` 阴影 + `ClipRRect`），并经 `SizedBox` 落实 `showWidth/showHeight`、经 `_MediaSelectionStroke` 落实选中描边、经 `_ImageResizeHandle` 落实可编辑选中态的左右边缘拖拽。
- 图片块占位：`_ImageBlockPlaceholder`，承载无 resolver / resolver 抛错 / 资源未就绪时的回退显示（需由「固定 112×72 小图标盒」重做为撑满内容宽度的 chrome 空态，并补加载中 / 加载失败两态）。
- 视频块已加载 / 占位：`_VideoBlockContent`、`_VideoBlockPlaceholder`，承载封面背景 `_VideoCoverBackdrop`、渐变蒙层、封面 chip `_VideoCoverChip`、播放按钮（`_videoPlayButtonSizeFor` / `_kVideoPlayIconSize`），并经 `_safeVideoAspectRatio` / `_videoFrameHeight` 做宽高比归一与帧高夹紧；视频占位需补一个加载失败回退态。
- 选中态：`_MediaSelectionStroke` 在媒体框自身矩形绘制 `primary` 2px 描边（非通用 `_BlockObjectSelectionSurface`），图片 / 视频块统一口径。
- 对象工具栏 Overlay：图片 / 视频块选中时由 `_MediaBlockChrome` 发布 `ObjectBlockToolbarOverlayRequest`，经 `ObjectBlockToolbarOverlayAnchor` 锚定媒体 frame，再由编辑器级 `ObjectBlockToolbarOverlayHost` 承载；工具栏不再作为媒体块 `Column` / `Stack` 的可测量子节点。
- 无障碍与预览：`_imageAccessibleLabel` / `_videoAccessibleLabel` 供读屏朗读，`_showImagePreview` / `_showVideoPreview` 提供双击 / 激活预览；本约束保留其行为，仅在图片块把 `altText` 接入 `Semantics`。

## 状态约束

- 已加载（默认）：媒体框仅呈现 `surface` chrome + 两层弱阴影，不绘制描边；`MediaResolver` 返回非空 widget 永远胜过任何占位态，注入优先级不变。
- 空占位（待上传 / 无资源）：撑满内容宽度的 figure chrome 空态（图标 + 简体中文提示），圆角 / 阴影对齐 figure token；与已加载态共用同一外框，仅内容为图标 + 文案。
- 加载上传中（图片块新增态）：环形进度 + 中文「上传中」提示，chrome 不变；语义上区别于空占位。
- 加载失败（图片 / 视频块新增态）：对接 `media_resolver.dart` 的 catch-and-fallback 契约（无 resolver 或 resolver 抛错 → 失败态）；使用 `error` / `errorContainer` 色调与中文失败文案，在视觉与语义上与空占位 / 封面占位可区分。
- 悬停 / 按下：悬停 `onSurface` 约 5% 中性反馈，按下 `primary` 约 18% 叠加；只作轻量反馈，**不改变尺寸 / 圆角 / 图标布局**。
- 选中描边：`_MediaSelectionStroke` 在框自身矩形（非整块 overlay）绘 `primary` 2px，圆角对齐 `_kMediaCornerRadius`；媒体块禁用通用 overlay，命中测试 / 几何注册 / 双击预览不受影响。
- 选中工具栏：选中图片 / 视频时工具栏浮在媒体 frame 上方，由编辑器级 Overlay 承载；不插入布局占位，不改变 frame / caption / 后续正文的位置，也不扩大媒体块自身命中区域。
- 图片 resize：仅在图片块选中且可编辑时显示左右边缘手柄；拖拽改变显示宽度，并按有效宽高比派生高度，预览期间 frame、选中描边和 caption 布局实时跟随，拖拽结束只通过 `updateImageBlock(showWidth/showHeight)` 提交一次。
- 只读裁剪：`readOnly` 或 `canEdit=false` 下，圆角 / 阴影 / 裁剪与可编辑态一致，仅保留预览等安全动作，无破坏性 mutation 入口；图片 resize 手柄隐藏且不响应尺寸提交，图片 / 视频块口径统一。
- 明暗主题：圆角 / 阴影层数 / 描边线宽 / caption 布局在明暗两色下保持一致，仅 colorScheme 颜色随主题切换；视频 frame 在明暗两色下均为黑色（`Colors.black`）。

## 视觉 Token

下列 Token 把 P001 设计稿的 chrome / spacing / typography / selection / motion 值**显式映射到 Flutter 常量名**，并给出建议值与现状对比。标「已对齐」者 P003/P004 无需改值，仅复用；标「需补」者为本期落地项。

### Chrome（容器圆角 / 阴影 / 外边距）

| 维度 | 设计稿建议值 | Flutter 常量 | 现状 | 处置 |
| --- | --- | --- | --- | --- |
| figure 圆角 | 12px | `_kMediaCornerRadius` | `12.0` | 已对齐，图片 / 视频共享 |
| figure 阴影 | 两层弱阴影（alpha ≈ 8% / 6%，blur 3 / 2，offset 0,1） | `_kSurfaceBoxShadow` | 已是两层 `Color(0x14141428)` / `Color(0x0F141428)`（≈8% / 6%），blur 3 / 2，offset (0,1) | 已对齐 |
| 垂直外边距 | 19.2（块上下各 9.6） | `_kMediaBlockMarginVertical` | `_kRichTextBodyFontSize(16.0) * 1.2 = 19.2`，块以 `vertical: _kMediaBlockMarginVertical / 2` 包裹 | 已对齐 |
| 最大宽度 | 受编辑器内容宽约束（建议正文 ≤ 720px） | （内联 `ConstrainedBox(maxWidth: 内容宽)`） | 图片 / 视频块以 `ConstrainedBox(maxWidth: 内容宽)` 居中，无额外硬编码上限 | 保留内容宽约束，不引入硬编码 720 |
| 图片占位 chrome | 整宽 chrome，圆角 / 阴影对齐 figure token | `_ImageBlockPlaceholder` | 固定 `112×72`、`borderRadius: 6`、`surfaceContainerHighest.withAlpha(90)`、`outlineVariant` 边、无阴影，**不撑满内容宽** | 需重做（P003）：圆角改 `_kMediaCornerRadius`、补 `_kSurfaceBoxShadow`、撑满内容宽 |
| 图片 resize 尺寸边界 | 最小 96px，最大为当前内容宽；无内容宽时回退 520px | `_kMinImageDisplayWidth` / `_kFallbackImageDisplayMaxWidth` | 已用于 `_ImageDisplayMetrics`、固定宽度菜单和边缘拖拽 | 保持统一 clamp，不引入第二套尺寸算法 |
| 图片 resize 手柄 | 命中宽 18px，视觉宽 3px | `_kImageResizeHandleHitWidth` / `_kImageResizeHandleVisualWidth` | 左右边缘各一个 `_ImageResizeHandle` | 可编辑选中态显示，只读 / 非编辑态隐藏 |

### Spacing（视频块专属）

| 维度 | 设计稿建议值 | Flutter 常量 | 现状 | 处置 |
| --- | --- | --- | --- | --- |
| 播放按钮 | 64px | `_kVideoPlayButtonSize` | `64.0`（经 `_videoPlayButtonSizeFor` 按帧宽缩放） | 已对齐 |
| 播放图标 | 24px | `_kVideoPlayIconSize` | `24.0`（按按钮尺寸 `min(24, buttonSize*0.45)` 夹紧） | 已对齐 |
| 视频帧回退宽 | 320px | `_kVideoFrameFallbackWidth` | `320.0`（内容宽无限时回退） | 已对齐 |
| 宽高比夹紧 | [1/3, 4] | `_kVideoMinAspectRatio` / `_kVideoMaxAspectRatio` | `1/3` ~ `4.0` | 已对齐 |
| 帧高夹紧 | [96, 420] | `_kVideoMinFrameHeight` / `_kVideoMaxFrameHeight` | `96.0` ~ `420.0` | 已对齐 |

### Typography（caption / altText）

- caption（仅图片块）：figure 外框下方渲染 `block.caption` 为 figcaption，**居中**、`onSurfaceVariant`、小号文案（建议 ~12.5px / `bodySmall` 量级）、受 `maxWidth` 约束；`caption` 为空字符串时不渲染 figcaption、不产生额外占位高度。现状：`_ImageBlockContent` 仅构建 figure 外框，**完全未渲染 caption**——属 P003 必补。
- altText（仅图片块，无障碍）：`block.altText` 接入 `Semantics(label:)` 供读屏朗读，与既有 `_imageAccessibleLabel` 协同（不破坏读屏），不在视觉层额外占位。
- 视频：`VideoBlockNode` 模型无 caption 字段，本期不引入 caption 渲染；`_videoAccessibleLabel` 朗读不变。

### Selection（选中 / 悬停 / 按下）

| 维度 | 设计稿建议值 | Flutter 常量 / 入口 | 现状 | 处置 |
| --- | --- | --- | --- | --- |
| 选中描边 | `primary` 2px，圆角 `_kMediaCornerRadius` | `_MediaSelectionStroke`（`Border.all(color: primary, width: 2)`） | 已对齐（框自身矩形，非通用 overlay） | 保持，仅核对圆角 / 线宽 |
| 悬停 | `onSurface` 约 5% | （P003/P004 内联） | 图片 / 视频块当前无 hover 叠加 | 可选增补：仅作轻量反馈，不改尺寸 / 圆角 |
| 按下 | `primary` 约 18% | （P003/P004 内联） | 无 | 同上 |

## 媒体工具栏 Overlay 契约

图片 / 视频块的对象工具栏属于编辑器级 Overlay，而不是媒体块布局的一部分。选中媒体只发布或撤销 `ObjectBlockToolbarOverlayRequest`，不得向媒体块内部插入工具栏、`SizedBox` 间距、负偏移占位或其它会改变测量结果的节点。

- 承载：编辑器 shell 安装 `ObjectBlockToolbarOverlayHost`，媒体 renderer 通过 `ObjectBlockToolbarOverlayController` 发布请求；自定义媒体 renderer 若要保持同一行为，也必须走这条路径。
- 锚点：`ObjectBlockToolbarOverlayAnchor` 放在媒体 frame 顶部，锚点宽度等于实际 frame 宽度（图片尊重 `showWidth/showHeight` 推导宽度，视频尊重内容宽与安全宽高比）。
- 水平定位：工具栏右边缘与 frame end 对齐，并夹在 overlay 可见宽度内；不要用整行宽度替代 frame 宽度。
- 垂直定位：工具栏位于 frame 上方，间距为 `_kBlockFloatingToolbarInset`；当媒体靠近 viewport 顶部时，`top` 取 `visibleTop` 夹紧后的值，避免工具栏滚出可见区域。
- 图片 resize 同步：拖拽提交后，图片 toolbar anchor 以新的 frame 宽度重新测量，更多菜单 / 预览按钮仍右对齐 frame end；工具栏不得停留在旧尺寸位置，也不得覆盖 caption。
- 命中测试：Overlay 只让实际工具栏区域参与命中拦截；不得铺设全屏透明 blocker，媒体预览、选区拖拽、正文点击不应被工具栏以外的区域吞掉。
- 选中视觉：选中描边继续由 `_MediaSelectionStroke` 绘制在 frame 自身矩形上；通用 full-block overlay 对图片 / 视频保持禁用，caption 和块外边距不被描边覆盖。
- 兼容边界：该契约不修改 `VideoBlockNode` 模型 / schema、不修改 `MediaResolver` 注入方式、不修改图片 / 视频预览 API，也不改变 rich JSON / HTML / Markdown / plain-text 的序列化、导入或导出协议。file / divider / embed 等非媒体对象块仍沿用既有块级浮动工具栏路径，除非对应 renderer 显式迁移到对象工具栏 Overlay。

## 图片 resize 交互契约

- 入口：只有图片块处于 object selection 且 `canEdit=true`、`onImageBlockResize` 存在时，显示左右两个边缘手柄；手柄语义分别为「拖拽左边缘调整图片宽度」和「拖拽右边缘调整图片宽度」，鼠标 cursor 使用水平 resize。
- 尺寸边界：显示宽度下限为 `_kMinImageDisplayWidth`（96px），上限为当前图片 block 可用内容宽；当没有可用内容宽时，回退 `_kFallbackImageDisplayMaxWidth`（520px）。最小宽度不能大于最大宽度，宽度输入需过滤 NaN / Infinity / 负值。
- 比例：宽高比优先使用 `ImageBlockNode.width/height`；原始尺寸缺失或非法时使用当前 frame 实测尺寸；仍不可用时使用安全默认比例，并夹在 `_kMinImageAspectRatio` 到 `_kMaxImageAspectRatio`。拖拽和固定宽度菜单都必须用同一套比例与 clamp 逻辑。
- 拖拽预览：左边缘向内拖窄、向外拖宽；右边缘向外拖宽、向内拖窄。拖拽过程中只更新临时预览尺寸，不写文档 history，图片 frame、`_MediaSelectionStroke`、caption 位置和块测量必须跟随预览尺寸，图片块 id 与文档位置不变。
- 提交：drag end 时如尺寸变化超过 `_kImageResizeChangeEpsilon`（0.5px），通过 controller/command pipeline 调用 `updateImageBlock(showWidth/showHeight)` 写入一次历史；取消或未产生有效变化时不提交。提交后虚拟列表测量、对象 toolbar anchor、选中描边和滚动几何都以新 frame 尺寸为准。
- 权限与动作边界：`readOnly` 或非编辑权限下不显示手柄、不响应尺寸提交。图片对象菜单和左侧块操作菜单不提供「创建块副本」，外部旧入口派发图片 duplicate 也应被防御性忽略；段落、分割线、文件、视频、embed 等非图片对象块按既有规则保留副本能力。
- 遮挡约束：手柄不得触发图片预览、对象选择、文本选区拖拽、块拖拽排序或外层滚动误操作；caption 位于 frame 下方，toolbar 位于 frame 上方，两者均不得被 resize 手柄或 overlay 遮挡。

### Motion（动效）

- 悬停 / 按下 / 描边反馈统一 `120ms ease`（与 `slash_popup_electron_design.html` 口径一致），仅作轻量反馈，不改变 overlay 定位、尺寸与几何注册。现状：媒体块无显式过渡时长，可在 P003/P004 按需补 `AnimatedContainer` / `AnimatedSwitcher` 实现，不强制引入。

### 色板（复用 colorScheme，不引入硬编码亮色）

`surface`（figure 外框底）、`surfaceContainerHighest`（图片占位底）、`outlineVariant`（占位描边）、`primary`（选中描边）、`primaryContainer`（少量强调底）、`onSurface`（标题）、`onSurfaceVariant`（caption / 辅助文案）、`error` / `errorContainer`（加载失败态）、`Colors.black`（视频 frame 底）。暗色版仅替换 colorScheme 取值，圆角 / 阴影层数 / 描边线宽 / caption 布局与明色一致。

## caption 与占位状态契约

> 下列契约为 P003（图片块）/ P004（视频块）的逐项验收口径；本规范不实现，只约定。

- caption 渲染契约（仅图片块）：
  - `_ImageBlockContent` 在 figure 外框（`ClipRRect` 包裹的 media）**下方**渲染 `block.caption` 为 figcaption（居中、`onSurfaceVariant` 小号文案、受 `maxWidth` 约束）。
  - `caption` 为空（null / 空串）时不渲染 figcaption、不产生额外占位高度（figure 与正文紧凑衔接）。
  - `block.altText` 接入 `Semantics(label:)`，与既有 `_imageAccessibleLabel` 协同，保证读屏朗读为中文且不重复。
  - 视频块模型无 caption 字段，本期不引入 caption 渲染。
- 图片块占位 / 状态契约：
  - 区分三态：**空占位**（图标 + 中文「图片占位」类提示）、**加载上传中**（环形进度 + 中文「上传中」）、**加载失败**（`error` 色调 + 中文失败提示）。
  - 失败态对接 `media_resolver.dart` 的 catch-and-fallback：无 resolver 或 resolver 抛错 → 失败态，且与空态在视觉（色调）与语义（文案）上可区分。
  - 三态均复用 figure chrome（圆角 / 阴影对齐 `_kMediaCornerRadius` / `_kSurfaceBoxShadow`），撑满内容宽度。
- 视频块占位 / 状态契约：
  - 区分：**封面占位**（封面背景 + 渐变 + 封面 chip + 播放按钮，沿用现状）与**加载失败**回退态（`error` 色调 + 中文失败提示）。
  - 失败态对接 resolver catch-and-fallback，区别于封面占位；保留封面背景 `_VideoCoverBackdrop`、渐变、封面 chip、播放按钮尺寸逻辑不变。
  - 播放 / 缓冲态在稿中表达观感即可，不强制引入真实播放器。
- 选中描边 / 只读口径统一：图片 / 视频块统一经 `_MediaSelectionStroke` 绘制 `primary` 2px（圆角对齐 `_kMediaCornerRadius`），禁用通用 overlay；`readOnly` / `canEdit=false` 下裁剪 / 圆角 / 阴影与可编辑态一致，仅安全动作（预览），无破坏性 mutation 入口。

## 现有样式入口

媒体显示、图片 resize 与工具栏承载仅更新下列入口的显示 / 交互层（chrome token、caption、占位 / 失败态、对象工具栏 Overlay、图片边缘拖拽），不改 `VideoBlockNode` / `ImageBlockNode` schema、`MediaResolver` 注入接口、预览 API、序列化 / 导入导出协议、插入删除命令与既有选区 / 双击预览：

- 图片块：`_ImageBlockContent`（caption figcaption + `altText` 的 `Semantics` + resize 预览状态）、`_ImageResizeHandle`（左右边缘拖拽手柄）、`_ImageBlockPlaceholder`（重做为整宽 chrome 空态 + 加载中 / 加载失败两态）。
- 视频块：`_VideoBlockContent`、`_VideoBlockPlaceholder`（补加载失败回退态，圆角 / 阴影 token 与图片块共享）。
- 选中描边：`_MediaSelectionStroke`（核对 `primary` 2px + `_kMediaCornerRadius` 圆角，行为不变）。
- 工具栏 Overlay：`_MediaBlockChrome`、`ObjectBlockToolbarOverlayAnchor`、`ObjectBlockToolbarOverlayRequest`、`ObjectBlockToolbarOverlayHost`（图片 / 视频选中工具栏浮在 frame 上方，不作为媒体布局子节点；图片 resize 提交后 anchor 使用新 frame 尺寸）。
- 共享 token 常量：`_kMediaCornerRadius`、`_kMediaBlockMarginVertical`、`_kSurfaceBoxShadow`；视频专属 `_kVideoFrameFallbackWidth`、`_kVideoPlayButtonSize`、`_kVideoPlayIconSize`、`_kVideoMinAspectRatio` / `_kVideoMaxAspectRatio`、`_kVideoMinFrameHeight` / `_kVideoMaxFrameHeight`。
- 图片尺寸与 resize：`_ImageDisplayMetrics`（当前显示尺寸、比例、min/max clamp、比例高度）、`_preferredImageFrameWidth`（toolbar anchor 宽度）、`_handleImageBlockResize`（提交 `showWidth/showHeight`）、`_kImageResizeChangeEpsilon`（无效变更过滤）。
- 视频几何：`_videoPlayButtonSizeFor`（按帧宽缩放播放按钮）、`_safeVideoAspectRatio`（宽高比夹紧）、`_videoFrameHeight`（帧高夹紧）。
- 无障碍 / 预览：`_imageAccessibleLabel` / `_videoAccessibleLabel`（朗读）、`_showImagePreview` / `_showVideoPreview`（双击预览，行为不变）。

## 后续抽取建议

- 图片 / 视频块占位态应收敛为同一组「media placeholder」子组件（空态 / 加载中 / 失败态），共用 figure chrome token，避免图片三态与视频失败态各自硬编码圆角 / 阴影 / 文案。
- 失败态的 catch-and-fallback 入口建议统一在 `MediaResolver` 调用处收敛（无 resolver / 抛错 → 失败占位），使图片 / 视频块的失败判定口径一致，不在渲染层重复 try-catch。
- 若后续扩展视频块 caption（需先在 `VideoBlockNode` schema 增字段），应复用本规范的 caption 渲染契约（居中、`onSurfaceVariant`、受 `maxWidth` 约束、空值不占位），保持图片 / 视频 caption 口径一致。
- 悬停 / 按下 / 描边过渡若统一引入 `AnimatedContainer`，应复用 `120ms ease`，避免图片 / 视频块各自设动画时长。
