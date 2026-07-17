# 图片/视频块显示设计约束

## 当前口径

图片块在编辑器正文内默认只显示媒体 frame、占位/失败/上传中的非文本状态视觉、选中描边、resize 命中区和对象工具栏交互。`ImageBlockNode.caption` 与 `altText` 继续作为模型 metadata、导入导出字段、描述编辑内容和无障碍标签来源保留，但不再作为图片 frame 下方的可见 figcaption 渲染，也不产生 caption gap 或额外块高度。

视频块沿用现有封面、播放覆盖层、失败态和对象工具栏口径；本文件不引入视频 caption 字段，也不新增播放器或网络图片依赖。

## HTML 设计稿

- 文件：`ui/media_block_display_design.html`，纯 HTML/CSS、无外部依赖、可直接在浏览器打开预览。
- 设计稿用于表达图片/视频块的默认编辑器内显示：figure chrome、显示尺寸、占位/加载/失败视觉、选中描边、只读裁剪、图片 resize、对象工具栏锚点、明暗色 token。
- 图片示例不得展示可见 caption 或图片占位说明文案；caption/altText 仅作为 metadata 和语义标签说明出现。

## 图片块显示契约

- 已加载或 resolver 成功：`_ImageBlockContent` 只呈现图片 frame。frame 由 `surface` 底、`_kMediaCornerRadius` 圆角、`_kSurfaceBoxShadow` 阴影、`ClipRRect` 裁剪和实际媒体内容组成。
- 占位/状态：`_ImageBlockPlaceholder` 在同一 frame 内只显示图标、进度或状态色。empty、loading、failed 状态均不显示“图片占位”“插入后将在此显示图片”“图片上传中”“图片加载失败”“无法显示该图片”等可见说明文字。
- caption：`block.caption` 不在编辑器正文中渲染，不创建 `Text`、figcaption、padding、gap 或额外块高度。有 caption 和无 caption 的图片块几何都以同一图片 frame 为准。
- altText：`block.altText` 不在视觉层占位；无障碍标签仍按 `_imageAccessibleLabel` 优先级解析。
- resolver 优先级：`MediaResolver` 返回非空 widget 时仍胜过内置 placeholder；返回 `null` 使用 empty placeholder；抛错进入 failed placeholder 并报告 FlutterError。

## 数据与导入导出契约

- `caption` 与 `altText` 继续保存在 `ImageBlockNode`，图片描述编辑入口、复制粘贴、撤销重做、controller 更新、rich JSON 和业务集成不得删除或清空这些字段。
- 无障碍标签继续使用 `_imageAccessibleLabel`：优先 `altText`，其次 `caption`，最后 asset/file label。隐藏可见 caption 不应降低读屏和预览 dialog 的语义标签。
- Markdown 导入导出继续使用图片 title 表示 caption：`![alt](src "caption")`。这表示数据协议，不代表编辑器正文默认可见展示。
- HTML 导入导出继续保留 `<figure><img ...><figcaption>...</figcaption></figure>` 对 caption 的映射。`figcaption` 是 codec 兼容协议，不要求默认编辑器渲染可见 figcaption。
- Plain text 导出继续使用媒体 sentinel，图片 sentinel 可优先使用 caption 再使用 altText，以保持纯文本可读性；这同样不代表编辑器内可见 caption。
- 本变更不新增配置开关，不要求业务方迁移 schema。

## 几何与交互契约

- 选中描边：`_MediaSelectionStroke` 只贴合媒体 frame 矩形，使用 `primary` 2px 和 `_kMediaCornerRadius`。通用 full-block overlay 对图片/视频保持禁用。
- 对象工具栏：图片/视频选中工具栏由编辑器级 Overlay 承载，锚点为媒体 frame 顶边，宽度与实际 frame 一致；工具栏不作为媒体块布局子节点，不改变块高度。
- 图片 resize：只有图片 object selection 且可编辑时启用左右透明命中区。拖拽预览和提交后，frame、选中描边、resize 命中区、对象工具栏 anchor 都跟随当前 frame；不存在 caption 位置需要同步。
- 对齐：`ImageBlockNode.attributes.alignment` 移动的是同一个图片 frame。`left`、`center`、`right` 只改变 frame 在内容宽内的位置，不拉伸图片，也不影响 caption metadata。
- 双击/激活预览、选区命中、虚拟列表测量和 block geometry registry 均以图片 frame 为准。

## 视觉 Token

| 维度 | Flutter 入口 | 当前契约 |
| --- | --- | --- |
| 图片/视频圆角 | `_kMediaCornerRadius` | frame 圆角统一为 12px。 |
| 图片/视频阴影 | `_kSurfaceBoxShadow` | 两层弱阴影，图片和视频共享。 |
| 垂直外边距 | `_kMediaBlockMarginVertical` | 块上下各半个媒体外边距；不因 caption 增高。 |
| 图片占位比例 | `_kImagePlaceholderAspectRatio` | 缺少尺寸时使用 2:1 frame。 |
| 图片最小宽 | `_kMinImageDisplayWidth` | resize 和菜单宽度 clamp 共享。 |
| 图片 resize hit zone | `_kImageResizeHandleHitWidth` | 左右透明命中区，无常驻视觉线。 |
| 选中描边 | `_MediaSelectionStroke` | 贴合 frame 的 `primary` 2px 描边。 |
| 状态色 | `ColorScheme` | empty 使用中性 surface，failed 使用 error/errorContainer，loading 使用进度视觉；均无可见文案。 |

## 实现入口

- 图片块：`_ImageBlockContent`、`_ImageBlockPlaceholder`、`_ImageDisplayMetrics`、`_ImageResizeHandle`、`_preferredImageFrameWidth`、`_handleImageBlockResize`。
- 视频块：`_VideoBlockContent`、`_VideoBlockPlaceholder`、`_VideoDisplayMetrics`、`_preferredVideoFrameWidth`。
- 共享交互：`_MediaSelectionStroke`、`_MediaBlockChrome`、`ObjectBlockToolbarOverlayAnchor`、`ObjectBlockToolbarOverlayHost`。
- 无障碍/预览：`_imageAccessibleLabel`、`_showImagePreview`、`_videoAccessibleLabel`、`_showVideoPreview`。

## 边界

- 不改 `ImageBlockNode` / `VideoBlockNode` schema。
- 不改 `MediaResolver` 接口或 resolver 优先级。
- 不改图片描述编辑入口、复制粘贴、撤销重做和 controller 更新逻辑。
- 不改 Markdown / HTML / plain text / rich JSON 的数据协议。
- 不新增“显示 caption”配置开关；如业务需要可通过自定义 `BlockRendererRegistry` 或 `MediaResolver` 自行渲染业务 UI。