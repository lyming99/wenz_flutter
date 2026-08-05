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
  });
}
