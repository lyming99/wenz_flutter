import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

MermaidRenderRequest _request(
  String source, {
  required String id,
  Size viewport = const Size(800, 450),
  MermaidRenderLimits limits = const MermaidRenderLimits(),
  String themeKey = 'test-light',
}) {
  return MermaidRenderRequest(
    source: source,
    sourceDigest: mermaidSourceDigest(source),
    theme: MermaidRenderTheme(
      key: themeKey,
      style: const MermaidStyle(),
    ),
    viewport: viewport,
    limits: limits,
    requestId: id,
  );
}

Future<MermaidRenderResult> _result(
  NativeMermaidRenderService service,
  MermaidRenderRequest request,
) async {
  final outcome = await service.render(request);
  expect(outcome, isA<MermaidRenderResult>());
  return outcome as MermaidRenderResult;
}

String _linearFlowchart(int nodes) {
  final source = StringBuffer('flowchart TD\n');
  for (var index = 0; index < nodes; index++) {
    source.writeln('  N$index[节点 $index]');
    if (index > 0) source.writeln('  N${index - 1} --> N$index');
  }
  return source.toString();
}

Rect _nodeBounds(Iterable<MermaidNode> nodes) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (final node in nodes) {
    minX = math.min(minX, node.x);
    minY = math.min(minY, node.y);
    maxX = math.max(maxX, node.x + node.width);
    maxY = math.max(maxY, node.y + node.height);
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

const _compoundRelayFlowchart = r'''flowchart TB
    WEB[Vue Web / 管理后台] -->|HTTPS 查询与写操作| EDGE[CDN / WAF / API Gateway]
    DEVICEA[Device A / 查询或文件发送端] -->|① HTTPS 获取分配与 Peer/File Ticket| EDGE
    DEVICEB[Device B / 数据拥有或文件接收端] -->|① HTTPS 获取分配| EDGE

    subgraph CONTROL[Control Plane - 管理主机集群]
        API[Control API\n认证、管理查询、任务落库、Peer/File Ticket]
        SCHED[Relay Scheduler\n用户到 Cell 的动态分配]
        DIR[Relay Directory\n节点健康、容量、租约]
        OUT[Command Dispatcher]
        RT[Realtime Gateway\n浏览器 SSE]
        LOG[Log Ingest\nHTTPS 批量摄取]
    end

    EDGE --> API
    EDGE --> RT
    EDGE --> LOG
    API --> SCHED
    SCHED --> DIR
    API --> PG[(PostgreSQL HA\n业务事实 + Assignment + Outbox/Inbox)]
    DIR --> REDIS[(Redis HA\nDevice Route / Presence / Node Lease)]
    SCHED --> PG
    OUT --> PG

    subgraph DATA[Relay Data Plane - 独立长连接服务]
        CELLA[Relay Cell A\n可配置域名/IP + 2~N Relay Nodes]
        CELLB[Relay Cell B\n可配置域名/IP + 2~N Relay Nodes]
        CELLN[Relay Cell N\n可配置域名/IP + 2~N Relay Nodes]
    end

    API -->|② Cell URL + 短期 Ticket| DEVICEA
    API -->|② Cell URL + 短期 Ticket| DEVICEB
    DEVICEA <-->|③ WSS:443 + Protobuf| CELLA
    DEVICEB <-->|③ WSS:443 + Protobuf| CELLB
    CELLA <-->|④ mTLS Relay Interconnect\nE2EE 文件分块| CELLB
    CELLA -->|连接注册/心跳| REDIS
    CELLB -->|连接注册/心跳| REDIS
    CELLN -->|连接注册/心跳| REDIS

    OUT -->|查 device route| REDIS
    OUT -->|Core NATS: relay.node.{nodeId}.downlink| NATS[(NATS Cluster\nCore 下行/Peer/File 控制 + JetStream 上行)]
    NATS --> CELLA
    NATS --> CELLB
    NATS --> CELLN
    CELLA -->|Peer Query / File Control / device.events.*| NATS
    CELLB -->|Peer Response / File Control / device.events.*| NATS
    CELLN -->|device.events.*| NATS

    NATS --> PROJ[Project / Task Projectors]
    NATS --> RT
    PROJ --> PG

    DEVICEA -->|HTTPS mTLS / 短期上传凭证| LOG
    DEVICEB -->|HTTPS mTLS / 短期上传凭证| LOG
    LOG --> OBJ[(S3 / OSS 对象存储)]
    LOG --> PG
    LOG --> NATS''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DefaultNativeMermaidRenderService', () {
    test('parses and lays out once, then returns a warm render-cache hit',
        () async {
      final service = DefaultNativeMermaidRenderService();
      addTearDown(service.dispose);
      const source = 'flowchart TD\n  A[开始] --> B[完成]';

      final cold = await _result(service, _request(source, id: 'cold'));
      final warm = await _result(service, _request(source, id: 'warm'));

      expect(cold.metrics.cacheStatus, MermaidCacheStatus.miss);
      expect(warm.metrics.cacheStatus, MermaidCacheStatus.hit);
      expect(warm.metrics.parseDuration, Duration.zero);
      expect(warm.metrics.layoutDuration, Duration.zero);
      expect(service.stats.parseCount, 1);
      expect(service.stats.layoutCount, 1);
      expect(service.stats.workerSpawnCount, 1);
    });

    test('viewport changes reuse the parsed model and only redo layout',
        () async {
      final service = DefaultNativeMermaidRenderService();
      addTearDown(service.dispose);
      const source = 'flowchart LR\n  A --> B --> C';

      await _result(
        service,
        _request(source, id: 'narrow', viewport: const Size(480, 270)),
      );
      final wide = await _result(
        service,
        _request(source, id: 'wide', viewport: const Size(1200, 675)),
      );

      expect(wide.metrics.cacheStatus, MermaidCacheStatus.miss);
      expect(wide.metrics.parseCacheHit, isTrue);
      expect(service.stats.parseCount, 1);
      expect(service.stats.layoutCount, 2);
    });

    test('theme invalidation drops paint/layout results but retains parsing',
        () async {
      final service = DefaultNativeMermaidRenderService();
      addTearDown(service.dispose);
      const source = 'flowchart TD\n  A --> B';

      await _result(service, _request(source, id: 'first'));
      service.invalidateTheme('test-light');
      final rerendered = await _result(service, _request(source, id: 'second'));

      expect(rerendered.metrics.cacheStatus, MermaidCacheStatus.miss);
      expect(rerendered.metrics.parseCacheHit, isTrue);
      expect(service.stats.parseCount, 1);
      expect(service.stats.layoutCount, 2);
    });

    test('class/state are unsupported and unknown input is a syntax failure',
        () async {
      final service = DefaultNativeMermaidRenderService();
      addTearDown(service.dispose);

      final classOutcome = await service.render(
        _request('classDiagram\n  class Foo', id: 'class'),
      );
      final stateOutcome = await service.render(
        _request('stateDiagram-v2\n  [*] --> Idle', id: 'state'),
      );
      final unknownOutcome = await service.render(
        _request('not a Mermaid diagram', id: 'unknown'),
      );

      expect(
        (classOutcome as MermaidRenderFailure).code,
        MermaidRenderErrorCode.unsupportedType,
      );
      expect(
        (stateOutcome as MermaidRenderFailure).code,
        MermaidRenderErrorCode.unsupportedType,
      );
      expect(
        (unknownOutcome as MermaidRenderFailure).code,
        MermaidRenderErrorCode.syntax,
      );
    });

    test('rejects character, node, edge, iteration, and time limits', () async {
      final service = DefaultNativeMermaidRenderService();
      addTearDown(service.dispose);

      final sourceLimit = await service.render(
        _request(
          'flowchart TD\n  A --> B',
          id: 'characters',
          limits: const MermaidRenderLimits(maxSourceCharacters: 5),
        ),
      );
      final nodeLimit = await service.render(
        _request(
          _linearFlowchart(3),
          id: 'nodes',
          limits: const MermaidRenderLimits(maxNodes: 2),
        ),
      );
      final edgeLimit = await service.render(
        _request(
          _linearFlowchart(4),
          id: 'edges',
          limits: const MermaidRenderLimits(maxEdges: 2),
        ),
      );
      final iterationLimit = await service.render(
        _request(
          'flowchart TD\n  A --> B',
          id: 'iterations',
          limits: const MermaidRenderLimits(maxLayoutIterations: 0),
        ),
      );
      final timeout = await service.render(
        _request(
          'flowchart TD\n  A --> B',
          id: 'timeout',
          limits: const MermaidRenderLimits(
            maxTotalDuration: Duration.zero,
          ),
        ),
      );

      expect((sourceLimit as MermaidRenderFailure).code,
          MermaidRenderErrorCode.sourceTooLong);
      expect((nodeLimit as MermaidRenderFailure).code,
          MermaidRenderErrorCode.tooManyNodes);
      expect((edgeLimit as MermaidRenderFailure).code,
          MermaidRenderErrorCode.tooManyEdges);
      expect((iterationLimit as MermaidRenderFailure).code,
          MermaidRenderErrorCode.layoutIterationLimit);
      expect((timeout as MermaidRenderFailure).code,
          MermaidRenderErrorCode.timeout);
      expect(service.stats.limitRejectedCount, 4);
      expect(service.stats.timeoutCount, 1);
    });

    test('warm cache cannot bypass stricter node, edge, or time limits',
        () async {
      final service = DefaultNativeMermaidRenderService();
      addTearDown(service.dispose);
      final source = _linearFlowchart(4);

      await _result(service, _request(source, id: 'warm-cache-seed'));
      final nodeLimit = await service.render(
        _request(
          source,
          id: 'warm-cache-nodes',
          limits: const MermaidRenderLimits(maxNodes: 2),
        ),
      );
      final edgeLimit = await service.render(
        _request(
          source,
          id: 'warm-cache-edges',
          limits: const MermaidRenderLimits(maxNodes: 10, maxEdges: 2),
        ),
      );
      final timeout = await service.render(
        _request(
          source,
          id: 'warm-cache-timeout',
          limits: const MermaidRenderLimits(
            maxTotalDuration: Duration.zero,
          ),
        ),
      );

      expect((nodeLimit as MermaidRenderFailure).code,
          MermaidRenderErrorCode.tooManyNodes);
      expect(nodeLimit.metrics!.cacheStatus, MermaidCacheStatus.hit);
      expect((edgeLimit as MermaidRenderFailure).code,
          MermaidRenderErrorCode.tooManyEdges);
      expect(edgeLimit.metrics!.cacheStatus, MermaidCacheStatus.hit);
      expect((timeout as MermaidRenderFailure).code,
          MermaidRenderErrorCode.timeout);
      expect(service.stats.parseCount, 1);
      expect(service.stats.layoutCount, 1);
    });

    test('a timed-out waiter does not start a duplicate in-flight parse',
        () async {
      final service = DefaultNativeMermaidRenderService();
      addTearDown(service.dispose);
      final source = _linearFlowchart(500);

      final timedOut = await service.render(
        _request(
          source,
          id: 'short-waiter',
          limits: const MermaidRenderLimits(
            maxTotalDuration: Duration(microseconds: 1),
          ),
        ),
      );
      final completed = await _result(
        service,
        _request(source, id: 'shared-waiter'),
      );

      expect((timedOut as MermaidRenderFailure).code,
          MermaidRenderErrorCode.timeout);
      expect(completed.nodeCount, 500);
      expect(service.stats.parseCount, 1);
      expect(service.stats.workerSpawnCount, 1);
    });

    test('active cancellation returns a distinct cancelled outcome', () async {
      final service = DefaultNativeMermaidRenderService();
      addTearDown(service.dispose);
      final request = _request(_linearFlowchart(500), id: 'cancel-me');

      final pending = service.render(request);
      service.cancel(request.requestId);
      final outcome = await pending;

      expect(outcome, isA<MermaidRenderFailure>());
      expect((outcome as MermaidRenderFailure).code,
          MermaidRenderErrorCode.cancelled);
      expect(service.stats.cancelledCount, 1);
    });

    test('LRU obeys both entry and estimated-memory boundaries', () async {
      final service = DefaultNativeMermaidRenderService(
        maxCacheEntries: 2,
        maxCacheBytes: 4096,
      );
      addTearDown(service.dispose);

      for (var index = 0; index < 4; index++) {
        await _result(
          service,
          _request(
            'flowchart TD\n  A$index --> B$index',
            id: 'lru-$index',
          ),
        );
      }

      expect(service.stats.cacheEntryCount, lessThanOrEqualTo(2));
      expect(service.stats.cacheEstimatedBytes, lessThanOrEqualTo(4096));
    });

    test('metrics contain counts/timings but no source text', () async {
      final events = <MermaidRenderDiagnosticEvent>[];
      final service = DefaultNativeMermaidRenderService(
        diagnostics: events.add,
      );
      addTearDown(service.dispose);
      const source = 'flowchart TD\n  PRIVATE_NODE --> B';

      final result = await _result(service, _request(source, id: 'metrics'));

      expect(result.metrics.characterCount, source.length);
      expect(result.metrics.nodeCount, 2);
      expect(result.metrics.edgeCount, 1);
      expect(
          events.map((event) => event.stage),
          containsAll(<MermaidRenderStage>[
            MermaidRenderStage.parser,
            MermaidRenderStage.layout,
            MermaidRenderStage.textMeasurement,
            MermaidRenderStage.total,
          ]));
      expect(events.join(' '), isNot(contains('PRIVATE_NODE')));
    });

    test('layout is finite and deterministic for identical input', () async {
      final service = DefaultNativeMermaidRenderService();
      addTearDown(service.dispose);
      const source = 'flowchart TD\n  A --> B\n  B --> C\n  C --> A';

      final first = await _result(
        service,
        _request(source, id: 'deterministic-1'),
      );
      service.invalidateTheme('test-light');
      final second = await _result(
        service,
        _request(source, id: 'deterministic-2'),
      );

      List<(String, double, double, double, double)> geometry(
        MermaidRenderResult result,
      ) {
        return result.diagram.nodes
            .map((node) => (node.id, node.x, node.y, node.width, node.height))
            .toList(growable: false);
      }

      expect(geometry(second), geometry(first));
      for (final node in second.diagram.nodes) {
        expect(
            <double>[node.x, node.y, node.width, node.height],
            everyElement(isNot(anyOf(isNaN, equals(double.infinity),
                equals(double.negativeInfinity)))));
      }
      expect(second.contentSize.width.isFinite, isTrue);
      expect(second.contentSize.height.isFinite, isTrue);
      expect(second.contentSize.width, greaterThan(0));
      expect(second.contentSize.height, greaterThan(0));
      expect(math.max(second.contentSize.width, second.contentSize.height),
          lessThan(double.infinity));
    });

    test('compound flowchart lays out standalone and subgraph nodes', () async {
      final service = DefaultNativeMermaidRenderService();
      addTearDown(service.dispose);

      final result = await _result(
        service,
        _request(_compoundRelayFlowchart, id: 'compound-relay'),
      );

      expect(result.nodeCount, 18);
      expect(result.edgeCount, 36);
      expect(result.diagram.subgraphs.map((subgraph) => subgraph.id),
          <String>['CONTROL', 'DATA']);
      expect(result.diagram.getNode('API')!.label, contains('\n'));
      expect(
        result.diagram.edges
            .where((edge) => edge.from == 'DEVICEA' && edge.to == 'CELLA')
            .single
            .bidirectional,
        isTrue,
      );

      final nodes = result.diagram.nodes;
      for (var firstIndex = 0; firstIndex < nodes.length; firstIndex++) {
        final first = nodes[firstIndex];
        final firstBounds = Rect.fromLTWH(
          first.x,
          first.y,
          first.width,
          first.height,
        );
        expect(firstBounds.left, greaterThanOrEqualTo(0), reason: first.id);
        expect(firstBounds.top, greaterThanOrEqualTo(0), reason: first.id);
        expect(firstBounds.right, lessThanOrEqualTo(result.contentSize.width),
            reason: first.id);
        expect(firstBounds.bottom, lessThanOrEqualTo(result.contentSize.height),
            reason: first.id);
        for (var secondIndex = firstIndex + 1;
            secondIndex < nodes.length;
            secondIndex++) {
          final second = nodes[secondIndex];
          final secondBounds = Rect.fromLTWH(
            second.x,
            second.y,
            second.width,
            second.height,
          );
          expect(
            firstBounds.overlaps(secondBounds),
            isFalse,
            reason: '${first.id} overlaps ${second.id}',
          );
        }
      }

      for (final subgraph in result.diagram.subgraphs) {
        final members = subgraph.nodeIds
            .map(result.diagram.getNode)
            .whereType<MermaidNode>();
        final bounds = _nodeBounds(members);
        expect(bounds.left - 20, greaterThanOrEqualTo(0), reason: subgraph.id);
        expect(bounds.top - 50, greaterThanOrEqualTo(0), reason: subgraph.id);
        expect(bounds.right + 20, lessThanOrEqualTo(result.contentSize.width),
            reason: subgraph.id);
        expect(bounds.bottom + 20, lessThanOrEqualTo(result.contentSize.height),
            reason: subgraph.id);
      }

      expect(result.contentSize.height,
          greaterThan(result.contentSize.width * 0.2));
    });
  });
}
