# wenz_draw Example Development Plan

本计划面向 `example` 应用和 SDK 集成体验。当前仓库的无限画布内核已经具备
pan/zoom、元素、工具、图层、历史、序列化、导出、小地图、Widget 嵌入、draw.io
形状和思维导图示例；后续重点是把它从“能力示例”推进到“可被业务 App 直接参考的
产品化样板”。

## Current Baseline

- `flutter test` 当前暴露 1 个失败用例：`CanvasWidgetElement` 在选择工具中拖拽角点时被当作移动处理，而不是缩放处理。
- `flutter analyze` 当前暴露 1 个 error：`example/test/widget_test.dart` 从 `main.dart` 导入，无法解析 `WenzDrawExampleApp`。
- PNG/SVG 导出对 Widget 元素仍是占位表现，Image 的 SVG 导出也是占位表现。
- 文档模型已有版本号，但缺少迁移管线、未知元素保留、资产清单和视图状态。
- 示例 App 已有完整编辑器外壳雏形，但缺少正式文件保存/打开、自动保存、导出设置和错误恢复。

## Phase 0: Stabilize The Baseline

目标：让示例应用和 SDK 测试回到可信状态。

- 修复 `CanvasWidgetElement` 角点缩放行为。
- 修复 example widget test 的导入。
- 跑通 `flutter test`。
- 跑通 `flutter analyze`，至少清零 error。

验收标准：

- `flutter test` 全部通过。
- `flutter analyze` 无 error。

## Phase 1: Make Export Match What Users See

目标：导出结果不再只是占位，而是尽量接近画布显示结果。

- PNG 导出支持真实 `ImageElement` 绘制。
- Widget 导出支持 snapshot provider，失败时再降级为占位。
- SVG 导出支持 image href/base64 策略。
- SVG 导出为 Widget 暴露业务 serializer 或 `foreignObject` 策略。
- 导出面板支持透明背景、指定区域、仅选中元素和 pixel ratio。

验收标准：

- 常规形状、文本、图片、Widget 混合画布导出后可识别且布局一致。
- 导出失败时有明确降级表现，不抛未处理异常。

## Phase 2: Harden Documents And Assets

目标：让保存/加载适合真实业务文档，而不是只适合 demo。

- 扩展文档字段：`schemaVersion`、`metadata`、`viewport`、`assets`。
- 增加版本迁移管线。
- 增加 `UnknownElement` 或等价保留机制，未知类型不能被静默替换成线段。
- 图片资产支持 base64、文件 URI、远端 URL 三种来源。
- 示例 App 增加保存、打开、另存为、自动恢复入口。

验收标准：

- 老文档可加载，新文档可迁移。
- 未知元素 round-trip 后不丢数据。
- 图片资产保存和恢复稳定。

## Phase 3: Productize The Example App

目标：把 example 变成业务 App 集成模板。

- 完善顶部工具栏：打开、保存、导入、导出、撤销、重做、缩放。
- 完善右侧 inspector：位置、尺寸、旋转、颜色、字体、层级、锁定。
- 增加右键菜单：复制、粘贴、删除、成组、取消成组、置顶、置底、导出选中。
- 增加 Frame/Artboard，用于固定区域导出和演示。
- 增加模板库：流程图、便签、思维导图、业务节点。

验收标准：

- 新业务页面可以直接照着 example 的结构接入 SDK。
- 常见白板/流程图操作不需要写额外胶水代码。

## Phase 4: Performance And Scale

目标：明确大画布边界，避免只在小 demo 中表现良好。

- 建立 500、2k、5k、10k 元素基准。
- 强化 Widget LOD：远距离 snapshot，近距离 live。
- 优化大文档序列化和导出，必要时放到 isolate。
- 完善 snapshot 缓存失效策略。

验收标准：

- 2k 元素流畅编辑。
- 5k 元素可用。
- 10k 元素可浏览和导出。

## Phase 5: Collaboration-Ready APIs

目标：不在 SDK 内强绑后端，但提供多人协作所需的操作边界。

- 抽象本地 operation log。
- 暴露远端操作应用接口。
- 增加 presence 模型：用户光标、用户选区、昵称颜色。
- 示例 App 提供最小本地回放 demo。

验收标准：

- 业务方可以用 WebSocket/CRDT/OT 接入自己的协作层。
- 远端操作应用后不会破坏本地历史和选择状态。
