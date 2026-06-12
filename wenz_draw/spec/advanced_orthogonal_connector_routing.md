# 复杂成熟连接线正交避障路由开发规格

## 1. 背景

`wenz_draw` 当前已有基础折线连接能力：

- `PolylineElement` 支持 `points`、`startBinding`、`endBinding`，可以保存连接点绑定关系。
- `PolylineTool` 在创建折线时调用 `OrthogonalRouter.route`，并传入起终点绑定元素的 bounds 与附近障碍物。
- `CanvasController._syncSnapBoundElements` 在被绑定元素移动后会重新计算 `PolylineElement.points`。
- `OrthogonalRouter` 已具备基于正交 lane 的 A* 搜索、候选路径回退、矩形障碍避让和简单评分。

但当前实现仍偏基础：路由配置不可外部控制，端口方向语义不够完整，障碍物模型只看矩形 bounds，连接线之间没有线束分离，动态重路由缺少缓存和影响范围控制，复杂场景下路径质量、性能和可测试性都需要进一步系统化。

本规格目标是把现有能力升级为“成熟的复杂连接方式”，接近 draw.io / mxGraph / libavoid 类正交连接器的核心体验，同时保持 Dart/Flutter 项目内可维护、可渐进落地。

## 2. 目标

### 2.1 用户体验目标

- 两个绘图组件、Widget 组件或混合元素之间可以自动生成水平/垂直正交折线。
- 连接线尽量从合理端口离开元素，并尊重用户选择的吸附点。
- 连接线自动绕开其他可见、未锁定元素，避免穿过节点主体。
- 多条连接线相邻或共享通道时具备分离能力，减少完全重叠。
- 被连接元素移动、缩放、层级或可见性变化后，相关连接线自动重新路由。
- 拖动预览时保持响应流畅，释放后生成更高质量路径。
- 结果路径稳定，不因轻微移动产生大幅跳变。

### 2.2 工程目标

- 在现有 `OrthogonalRouter` 基础上演进，避免重写现有工具链。
- 引入可配置的路由模型，支持质量/性能权衡。
- 将几何、图搜索、路径评分、缓存、连接线同步拆成清晰模块。
- 支持单元测试覆盖复杂避障、端口方向、线束分离、动态重路由。
- 保持旧数据兼容：已有 `PolylineElement` JSON 不需要迁移即可读取。

## 3. 非目标

- 本阶段不做任意角度自由曲线避障。
- 本阶段不实现完整商业级自动布局，例如自动摆放节点。
- 本阶段不引入 C++ `libavoid` 原生依赖。
- 本阶段不要求连接线跨图层时改变元素层级，只负责路径计算。

## 4. 总体方案

采用“正交可见图 + A* / Dijkstra + 多目标评分 + 路径后处理”的路由架构。

核心流程：

1. 从 `PolylineElement.startBinding/endBinding` 和当前吸附结果解析连接端口。
2. 将画布元素转换为路由障碍物 `RoutingObstacle`。
3. 根据起终点、障碍物、连接线、配置生成正交候选通道 lane。
4. 构建正交可见图 `OrthogonalVisibilityGraph`。
5. 使用 A* 搜索最优路径。
6. 对路径进行去重、共线合并、端口短引线保留、线束偏移与稳定化。
7. 返回 `ConnectorRouteResult`，由 `PolylineElement` 存储实际 points。

## 5. 数据模型设计

### 5.1 路由配置

新增 `lib/src/routing/connector_routing.dart` 或拆分到 `lib/src/routing/`：

```dart
enum ConnectorRoutingMode {
  simpleManhattan,
  obstacleAvoiding,
  advancedOrthogonal,
}

class ConnectorRoutingOptions {
  const ConnectorRoutingOptions({
    this.mode = ConnectorRoutingMode.advancedOrthogonal,
    this.margin = 16,
    this.portLead = 18,
    this.searchPadding = 320,
    this.maxObstacles = 64,
    this.maxLanesPerAxis = 32,
    this.turnPenalty = 24,
    this.nodeCrossingPenalty = 100000,
    this.nodeTouchPenalty = 8,
    this.parallelLineGap = 8,
    this.stabilityPenalty = 18,
    this.previewQuality = ConnectorRouteQuality.fast,
    this.finalQuality = ConnectorRouteQuality.high,
  });

  final ConnectorRoutingMode mode;
  final double margin;
  final double portLead;
  final double searchPadding;
  final int maxObstacles;
  final int maxLanesPerAxis;
  final double turnPenalty;
  final double nodeCrossingPenalty;
  final double nodeTouchPenalty;
  final double parallelLineGap;
  final double stabilityPenalty;
  final ConnectorRouteQuality previewQuality;
  final ConnectorRouteQuality finalQuality;
}

enum ConnectorRouteQuality { fast, balanced, high }
```

集成点：

- `CanvasController` 增加 `connectorRoutingOptions`，默认开启高级正交路由。
- `PolylineTool` 预览阶段使用 `previewQuality`，落点阶段使用 `finalQuality`。
- 后续可开放给业务方配置。

### 5.2 端口模型

新增：

```dart
enum ConnectorSide { left, right, top, bottom, center, free }

class ConnectorPort {
  const ConnectorPort({
    required this.position,
    required this.side,
    required this.normal,
    this.elementId,
    this.anchorId,
    this.bounds,
    this.locked = false,
  });

  final Offset position;
  final ConnectorSide side;
  final Offset normal;
  final String? elementId;
  final String? anchorId;
  final Rect? bounds;
  final bool locked;
}
```

规则：

- 如果来自 `SnapBinding`，根据 `anchorId` 推断 side：`left/right/top/bottom` 对应外法线；corner 根据目标方向选择更合适的相邻边；center 使用 `free` 或最近边投影。
- 如果没有绑定，则使用 `free` 起终点。
- 用户明确吸附的端口应被视为 `locked`，路由必须从该端口出发，但可以生成 port lead 作为离开节点的第一段。
- 自动端口选择时，从四边中生成候选端口并参与评分。

### 5.3 障碍物模型

新增：

```dart
class RoutingObstacle {
  const RoutingObstacle({
    required this.id,
    required this.bounds,
    this.kind = RoutingObstacleKind.node,
    this.margin = 0,
    this.cost = 1,
  });

  final String id;
  final Rect bounds;
  final RoutingObstacleKind kind;
  final double margin;
  final double cost;

  Rect inflated(double defaultMargin) => bounds.inflate(defaultMargin + margin);
}

enum RoutingObstacleKind { node, widget, label, connectorLabel, temporary }
```

障碍物来源：

- `CanvasController.elementsNear(queryRect)` 提供附近元素。
- 排除当前连接线、source element、target element。
- 可见且图层可见的元素参与避障。
- 锁定图层上的元素仍应作为障碍物；锁定只影响编辑，不代表可穿过。
- 连接线 label 区域可作为软障碍，降低标签和线相互遮挡。

### 5.4 路由结果

```dart
class ConnectorRouteResult {
  const ConnectorRouteResult({
    required this.points,
    required this.score,
    required this.strategy,
    this.usedFallback = false,
  });

  final List<Offset> points;
  final double score;
  final ConnectorRouteStrategy strategy;
  final bool usedFallback;
}

enum ConnectorRouteStrategy {
  directOrthogonal,
  visibilityGraph,
  candidateFallback,
  straightFallback,
}
```

## 6. 算法设计

### 6.1 正交可见图

构建 lane：

- 必选 lane：`start.dx`、`end.dx`、`start.dy`、`end.dy`。
- 中线 lane：`(start.dx + end.dx) / 2`、`(start.dy + end.dy) / 2`。
- 端口引线 lane：端口沿 normal 推出 `portLead` 后的位置。
- 障碍物边界 lane：每个 inflated obstacle 的 `left/right/top/bottom`。
- 障碍物外侧安全 lane：边界再外扩 `margin` 或 `parallelLineGap`。
- 历史路径 lane：旧路径的 x/y，可提升路径稳定性。
- 连接线通道 lane：已有连接线段的相邻偏移 lane，用于线束分离。

lane 裁剪：

- 只保留 query corridor 内 lane。
- 按离起终点矩形中心距离排序，限制到 `maxLanesPerAxis`。
- 必选 lane 不参与裁剪。

图节点：

- x lane 与 y lane 的交点。
- 起点、终点、端口引线点。
- 仅保留不在硬障碍物内部的节点。

图边：

- 同一 x lane 上相邻 y 节点可连边；同一 y lane 上相邻 x 节点可连边。
- 边段穿过硬障碍物 interior 时禁止。
- 边段贴边或靠近障碍物时增加软惩罚。

### 6.2 A* 搜索

代价函数：

```text
cost = segmentLength
     + turnPenalty * turns
     + obstacleTouchPenalty
     + crossingExistingConnectorPenalty
     + overlapExistingConnectorPenalty
     + portDirectionPenalty
     + stabilityPenalty
```

启发函数：

```text
heuristic = manhattanDistance(current, end)
```

优先队列：

- 当前 `OrthogonalRouter` 使用 list sort 作为 open set，复杂场景应改为二叉堆或轻量 priority queue。
- 如不引入第三方依赖，可在 `lib/src/utils/priority_queue.dart` 实现最小堆。

转弯处理：

- 搜索状态需要包含进入方向，而不仅是节点位置。
- 同一节点不同进入方向应视作不同状态，否则会丢失最优拐点组合。

### 6.3 路径评分

评分项建议：

- 总长度：基础分。
- 拐点数：每个拐点 `turnPenalty`。
- 穿越节点：直接不可用或极大惩罚。
- 贴近节点：小惩罚，避免线贴边。
- 端口方向：第一段/最后一段与端口 normal 不一致时惩罚。
- 端口短引线：未满足 `portLead` 时惩罚。
- 与已有连接线完全重叠：高惩罚。
- 与已有连接线交叉：中高惩罚。
- 路径稳定：新路径偏离旧路径越多惩罚越高。
- 路径视觉复杂度：连续 U 型回绕、短碎段、过近平行段增加惩罚。

### 6.4 后处理

路径生成后执行：

- 去除重复点。
- 合并共线点，但保留 source/target port lead 点。
- 删除长度小于阈值的短碎段。
- 对共线重叠连接线执行线束偏移。
- 将浮点值按 0.5 或 1.0 网格归一化，降低抖动。
- 校验最终路径不得穿越硬障碍物；失败则回退候选路径。

### 6.5 线束分离

输入已有连接线：

- 从 `CanvasController.elementsNear(queryRect)` 收集 `PolylineElement`。
- 排除当前连接线。
- 将已有 path 拆成水平/垂直 segment。

分离策略：

- 如果新线段与已有线段同向且重叠超过阈值，给新线段分配 `parallelLineGap` 的偏移 lane。
- 对同一 source-target 的多条连接线，按稳定 key 排序后分配对称偏移：`-gap, +gap, -2gap, +2gap...`。
- 只偏移中间段，端口引线段尽量保持贴合端口，避免端点脱离组件。

### 6.6 动态重路由

现状：`CanvasController._syncSnapBoundElements` 已在绑定元素变化时同步 `LineElement` 和 `PolylineElement`。

增强：

- 新增 `ConnectorRoutingService`，由 controller 调用。
- 当元素移动时，只重新路由绑定到该元素的连接线。
- 如果被移动元素变成其他连接线的障碍物，也应查询附近连接线并触发重路由。
- 拖动中使用 fast 质量，拖动结束后用 high 质量补算。
- 记录旧路径作为 `previousRoute`，用于稳定性评分。

## 7. 模块拆分

建议新增目录：

```text
lib/src/routing/
  connector_router.dart
  connector_routing_options.dart
  connector_port.dart
  routing_obstacle.dart
  orthogonal_visibility_graph.dart
  connector_path_scorer.dart
  connector_path_post_processor.dart
  connector_routing_service.dart
```

兼容层：

- 保留 `lib/src/utils/orthogonal_router.dart`，让它委托到新的 `ConnectorRouter`。
- 外部已有调用 `OrthogonalRouter.route` 的代码不需要立即修改。

## 8. 与现有代码集成

### 8.1 `PolylineTool`

- `_route` 改为调用 `controller.routeConnector(...)` 或 `ConnectorRoutingService.route(...)`。
- pointer move 预览传入 `quality: fast`。
- pointer up 创建元素传入 `quality: high`。
- 将 `_boundsForBinding`、`_obstacles` 逻辑尽量迁移到 service，避免工具层重复路由知识。

### 8.2 `CanvasController`

新增能力：

```dart
List<Offset> routeConnector({
  required Offset start,
  required Offset end,
  SnapBinding? startBinding,
  SnapBinding? endBinding,
  String? connectorId,
  List<Offset>? previousRoute,
  ConnectorRouteQuality quality = ConnectorRouteQuality.high,
});
```

调整：

- `_resolveSnapBoundElement` 中 `PolylineElement` 的重算改用 `routeConnector`。
- `_routingObstacles` 返回 `RoutingObstacle` 而不是 `Rect`。
- 变更元素后，除绑定线外，可以按影响区域查询附近连接线进行可选重路由。

### 8.3 `PolylineElement`

短期保持数据结构不变。

后续可选增强：

```dart
final ConnectorRoutingMode? routingMode;
final Map<String, dynamic>? routingMetadata;
```

第一阶段不强制加入，避免 JSON 兼容面扩大。

### 8.4 `SnapResolver`

- 增加从 `SnapPoint` / `anchorId` 推断 `ConnectorSide` 的工具函数。
- 角点和中心点需要结合目标方向选择出口边。
- Widget、Rect、Ellipse 等元素 bounds 统一映射到端口模型。

## 9. 开发阶段计划

### 阶段 1：规格化现有路由入口

任务：

- 新建 `lib/src/routing/` 基础模型：options、port、obstacle、result。
- 新建 `ConnectorRoutingService`，将 `PolylineTool` 与 `CanvasController` 中的障碍物收集逻辑集中。
- 保留 `OrthogonalRouter.route` 作为底层实现。
- 增加 `CanvasController.routeConnector`。

验收：

- 当前 polyline 创建、预览、绑定元素移动后重算行为保持不变。
- 旧测试通过。
- 新增基础 route service 单元测试。

### 阶段 2：正交可见图升级

任务：

- 从 `OrthogonalRouter` 抽出 lane 生成和 A* 搜索到 `OrthogonalVisibilityGraph`。
- 搜索状态加入进入方向。
- 将 open set 从 list sort 改为 priority queue。
- 增加 route quality：fast 限制 lane 和 obstacle，high 使用完整评分。

验收：

- 复杂矩形障碍物场景能稳定绕行。
- 不穿越 source/target 外的节点主体。
- 100 个障碍物内一次 high route 在可接受时间内完成，目标小于 16ms 到 30ms，具体以测试机器基准记录。

### 阶段 3：端口方向和路径稳定性

任务：

- 实现 `ConnectorPortResolver`。
- 根据 `SnapBinding.anchorId` 解析出口 side 和 normal。
- 增加 port lead、方向惩罚、旧路径稳定惩罚。
- 在元素轻微移动时减少路径大幅跳变。

验收：

- right-to-left、left-to-right、top-to-bottom、bottom-to-top 端口连接方向符合预期。
- 用户吸附到指定边时，连接线从对应边离开。
- 小幅移动节点时，路径变化局部且稳定。

### 阶段 4：线束分离与连接线避让

任务：

- 收集附近已有 `PolylineElement` 作为软障碍或线束参考。
- 实现同向重叠检测、平行偏移 lane 生成和后处理。
- 对连接线交叉、重叠加入评分惩罚。

验收：

- 多条连接相同两个节点的线不会完全重叠。
- 多条通过同一通道的线能按 gap 分离。
- 端点仍精确落在绑定吸附点上。

### 阶段 5：动态重路由和性能优化

任务：

- 在 controller 更新元素后，除了绑定线，也可查询受影响区域内连接线并重算。
- 增加 route cache，key 包含起终点、绑定 id、障碍物版本、options hash。
- 拖动中 fast route，拖动结束 high route。
- 为空间索引查询、路由耗时加入 debug benchmark。

验收：

- 拖动被连接节点时线条实时跟随。
- 拖动障碍物穿过已有连接线时，相关连接线可绕开。
- 500 元素场景下交互不出现明显卡顿。

### 阶段 6：测试、文档与示例

任务：

- 增加 `test/routing/` 单元测试。
- 在 example 中增加复杂连接线 demo：多节点、多障碍、多连接线、移动节点。
- 更新 README 或 docs，说明连接线能力与配置项。

验收：

- 单测覆盖端口、避障、线束、动态重路由、序列化兼容。
- 示例可人工验证高级连接线效果。
- 文档说明默认行为和如何降级为简单 Manhattan。

## 10. 测试计划

新增测试文件建议：

```text
test/routing/connector_port_resolver_test.dart
test/routing/orthogonal_visibility_graph_test.dart
test/routing/connector_router_test.dart
test/routing/connector_path_post_processor_test.dart
test/canvas/connector_reroute_test.dart
```

关键用例：

- 无障碍时生成最短正交路径。
- 单个矩形障碍物位于中间时绕行。
- 多个障碍物形成通道时选择可通行路径。
- 起点在 source bounds 内时，先沿端口 normal 推出。
- 绑定到 `right` anchor 时第一段向右。
- 绑定到 `left` anchor 时第一段向左。
- 端口在 corner 时能根据目标方向选边。
- 路径不得穿过非 source/target 障碍物 interior。
- 旧路径存在时，小幅移动优先保留相似通道。
- 多条同向重叠线段被分离。
- 旧 JSON 中没有路由 metadata 时仍可正常反序列化。

## 11. 风险与应对

- 路由质量和性能冲突：通过 `ConnectorRouteQuality` 区分 preview 和 final。
- A* 节点过多：限制 lane 数、query corridor、max obstacles，并保留候选路径回退。
- 路径抖动：引入 previousRoute lane 与稳定性惩罚。
- 端口语义不完整：优先支持现有 `SnapResolver` 的边/角/中心，后续再扩展自定义端口。
- 线束偏移导致穿障碍：偏移后必须再次校验，失败则取消该段偏移。

## 12. 优先级建议

建议先实现阶段 1 到阶段 3，能够明显提升连接线的工程可控性和端口质量；随后再做阶段 4 的线束分离。阶段 5 的动态重路由和缓存可以跟 500 元素性能任务协同推进。

最小可交付版本：

- `ConnectorRoutingService`
- `ConnectorRoutingOptions`
- `ConnectorPortResolver`
- 升级版 `OrthogonalRouter` 入口
- controller/tool 统一接入
- 核心避障与端口方向测试

完整成熟版本：

- 正交可见图独立模块
- 方向状态 A*
- priority queue
- 线束分离
- route cache
- 动态障碍影响范围重路由
- example 复杂 demo
