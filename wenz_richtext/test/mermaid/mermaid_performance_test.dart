import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

String _flowchart(int nodes, {int? edges}) {
  final edgeTarget = edges ?? nodes - 1;
  final source = StringBuffer('flowchart TD\n');
  for (var index = 0; index < nodes; index++) {
    source.writeln('  N$index[节点 $index]');
  }
  var written = 0;
  for (var index = 1; index < nodes && written < edgeTarget; index++) {
    source.writeln('  N${index - 1} --> N$index');
    written++;
  }
  for (var offset = 2; written < edgeTarget; offset++) {
    for (var index = 0;
        index + offset < nodes && written < edgeTarget;
        index++) {
      source.writeln('  N$index --> N${index + offset}');
      written++;
    }
  }
  return source.toString();
}

MermaidRenderRequest _request(String source, String id) {
  return MermaidRenderRequest(
    source: source,
    sourceDigest: mermaidSourceDigest(source),
    theme: const MermaidRenderTheme(
      key: 'performance-light',
      style: MermaidStyle(),
    ),
    viewport: const Size(1200, 675),
    limits: const MermaidRenderLimits(),
    requestId: id,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('repeatable 10/100/500 node parser-layout baseline', () async {
    final service = DefaultNativeMermaidRenderService();
    addTearDown(service.dispose);

    for (final nodes in <int>[10, 100, 500]) {
      final source = _flowchart(nodes);
      final outcome = await service.render(_request(source, 'baseline-$nodes'));

      expect(outcome, isA<MermaidRenderResult>());
      final result = outcome as MermaidRenderResult;
      expect(result.nodeCount, nodes);
      expect(result.edgeCount, nodes - 1);
      expect(result.contentSize.width.isFinite, isTrue);
      expect(result.contentSize.height.isFinite, isTrue);
      // Deliberately records only cardinalities and timings, never source text.
      // ignore: avoid_print
      print(
        'mermaid-baseline nodes=$nodes edges=${result.edgeCount} '
        'parse_us=${result.metrics.parseDuration.inMicroseconds} '
        'layout_us=${result.metrics.layoutDuration.inMicroseconds} '
        'text_us=${result.metrics.textMeasurementDuration.inMicroseconds} '
        'total_us=${result.metrics.totalDuration.inMicroseconds}',
      );
    }
  });

  test('100-node/150-edge warm P95 stays below 250 ms', () async {
    final service = DefaultNativeMermaidRenderService();
    addTearDown(service.dispose);
    final source = _flowchart(100, edges: 150);

    final cold = await service.render(_request(source, 'warmup'));
    expect(cold, isA<MermaidRenderResult>());
    final samples = <int>[];
    for (var index = 0; index < 20; index++) {
      final watch = Stopwatch()..start();
      final outcome = await service.render(_request(source, 'warm-$index'));
      watch.stop();
      expect((outcome as MermaidRenderResult).metrics.cacheStatus,
          MermaidCacheStatus.hit);
      samples.add(watch.elapsedMicroseconds);
    }
    samples.sort();
    final p95 = samples[(samples.length * 0.95).ceil() - 1];

    expect(p95, lessThanOrEqualTo(250000));
    // ignore: avoid_print
    print('mermaid-warm-p95 nodes=100 edges=150 p95_us=$p95');
  });

  test('warm scheduling synchronous occupancy stays below 8 ms', () async {
    final service = DefaultNativeMermaidRenderService();
    addTearDown(service.dispose);
    final source = _flowchart(100, edges: 150);
    await service.render(_request(source, 'occupancy-warmup'));

    final watch = Stopwatch()..start();
    final pending = service.render(_request(source, 'occupancy'));
    watch.stop();
    final synchronousMicros = watch.elapsedMicroseconds;
    final outcome = await pending;

    expect(outcome, isA<MermaidRenderResult>());
    expect(synchronousMicros, lessThanOrEqualTo(8000));
    // ignore: avoid_print
    print('mermaid-scheduling-sync occupancy_us=$synchronousMicros');
  });

  test('twenty-diagram document workload completes without invalid geometry',
      () async {
    final service = DefaultNativeMermaidRenderService();
    addTearDown(service.dispose);

    final outcomes = await Future.wait(<Future<MermaidRenderOutcome>>[
      for (var index = 0; index < 20; index++)
        service.render(
          _request(
            '${_flowchart(10)}\n  N9 --> END$index[文档图 $index]',
            'document-$index',
          ),
        ),
    ]);

    expect(outcomes, everyElement(isA<MermaidRenderResult>()));
    for (final outcome in outcomes.cast<MermaidRenderResult>()) {
      expect(outcome.contentSize.width.isFinite, isTrue);
      expect(outcome.contentSize.height.isFinite, isTrue);
    }
  });
}
