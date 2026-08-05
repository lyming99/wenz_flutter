import 'package:flutter/material.dart';

import '../../mermaid/models/diagram.dart';
import '../../mermaid/painter/flowchart_painter.dart';
import '../../mermaid/painter/gantt_painter.dart';
import '../../mermaid/painter/kanban_painter.dart';
import '../../mermaid/painter/mindmap_painter.dart';
import '../../mermaid/painter/pie_chart_painter.dart';
import '../../mermaid/painter/radar_painter.dart';
import '../../mermaid/painter/sequence_painter.dart';
import '../../mermaid/painter/timeline_painter.dart';
import '../../mermaid/painter/xy_chart_painter.dart';
import '../../mermaid/render/render_models.dart';

/// Paints one already parsed and laid-out Mermaid result.
///
/// Parsing and layout deliberately live in [NativeMermaidRenderService]. This
/// widget and every painter below are pure consumers of [result].
class MermaidDiagram extends StatelessWidget {
  const MermaidDiagram({
    super.key,
    required this.result,
    this.onNodeTap,
    this.diagnostics,
  });

  final MermaidRenderResult result;
  final void Function(String nodeId)? onNodeTap;
  final MermaidRenderDiagnostics? diagnostics;

  @override
  Widget build(BuildContext context) {
    final painter = _timedPainter(_painterFor(result));
    final diagram = SizedBox(
      width: result.contentSize.width,
      height: result.contentSize.height,
      child: ColoredBox(
        color: Color(result.style.backgroundColor),
        child: CustomPaint(
          painter: painter,
          size: result.contentSize,
          isComplex: true,
          willChange: false,
        ),
      ),
    );

    return Semantics(
      container: true,
      image: true,
      label: result.semanticSummary,
      child: RepaintBoundary(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onNodeTap == null ? null : _handleTap,
          child: diagram,
        ),
      ),
    );
  }

  void _handleTap(TapDownDetails details) {
    final callback = onNodeTap;
    if (callback == null) return;
    for (final node in result.diagram.nodes) {
      final bounds = Rect.fromLTWH(
        node.x,
        node.y,
        node.width,
        node.height,
      );
      if (bounds.contains(details.localPosition)) {
        callback(node.id);
        return;
      }
    }
  }

  CustomPainter _painterFor(MermaidRenderResult renderResult) {
    final parsed = renderResult.parseResult;
    final diagram = parsed.diagram;
    final style = renderResult.style;
    final deviceConfig = renderResult.deviceConfig;

    switch (diagram.type) {
      case DiagramType.flowchart:
        return FlowchartPainter(
          diagram: diagram,
          style: style,
          deviceConfig: deviceConfig,
        );
      case DiagramType.sequence:
        return SequencePainter(
          diagram: diagram,
          style: style,
          deviceConfig: deviceConfig,
        );
      case DiagramType.mindmap:
        return MindmapPainter(
          diagram: diagram,
          style: style,
          deviceConfig: deviceConfig,
        );
      case DiagramType.pieChart:
        return PieChartPainter(
          pieData: parsed.pieChartData!,
          style: style,
          deviceConfig: deviceConfig,
        );
      case DiagramType.ganttChart:
        return GanttPainter(
          ganttData: parsed.ganttChartData!,
          style: style,
          deviceConfig: deviceConfig,
        );
      case DiagramType.timeline:
        return TimelinePainter(
          timelineData: parsed.timelineChartData!,
          style: style,
          deviceConfig: deviceConfig,
        );
      case DiagramType.kanban:
        return KanbanPainter(
          kanbanData: parsed.kanbanChartData!,
          style: style,
          deviceConfig: deviceConfig,
        );
      case DiagramType.radar:
        return RadarPainter(
          radarData: parsed.radarChartData!,
          style: style,
          deviceConfig: deviceConfig,
        );
      case DiagramType.xyChart:
        return XYChartPainter(
          xyData: parsed.xyChartData!,
          style: style,
          deviceConfig: deviceConfig,
        );
      case DiagramType.classDiagram:
      case DiagramType.stateDiagram:
      case DiagramType.unknown:
        throw StateError('Unsupported Mermaid render result: ${diagram.type}');
    }
  }

  CustomPainter _timedPainter(CustomPainter delegate) {
    return _TimedMermaidPainter(
      delegate: delegate,
      onPaint: (duration) {
        final callback = diagnostics;
        if (callback == null) return;
        try {
          callback(
            MermaidRenderDiagnosticEvent(
              stage: MermaidRenderStage.paint,
              duration: duration,
              characterCount: result.metrics.characterCount,
              nodeCount: result.nodeCount,
              edgeCount: result.edgeCount,
              diagramType: result.diagramType,
              cacheStatus: result.metrics.cacheStatus,
            ),
          );
        } catch (_) {
          // Instrumentation must not affect painting.
        }
      },
    );
  }
}

/// Minimal pan/zoom wrapper for hosts that already own a render result.
class InteractiveMermaidDiagram extends StatefulWidget {
  const InteractiveMermaidDiagram({
    super.key,
    required this.result,
    this.minScale = 0.1,
    this.maxScale = 5.0,
    this.onNodeTap,
    this.diagnostics,
  });

  final MermaidRenderResult result;
  final double minScale;
  final double maxScale;
  final void Function(String nodeId)? onNodeTap;
  final MermaidRenderDiagnostics? diagnostics;

  @override
  State<InteractiveMermaidDiagram> createState() =>
      _InteractiveMermaidDiagramState();
}

class _InteractiveMermaidDiagramState extends State<InteractiveMermaidDiagram> {
  final TransformationController _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      child: MermaidDiagram(
        result: widget.result,
        onNodeTap: widget.onNodeTap,
        diagnostics: widget.diagnostics,
      ),
    );
  }
}

class _TimedMermaidPainter extends CustomPainter {
  const _TimedMermaidPainter({required this.delegate, required this.onPaint});

  final CustomPainter delegate;
  final ValueChanged<Duration> onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    final watch = Stopwatch()..start();
    try {
      delegate.paint(canvas, size);
    } finally {
      watch.stop();
      onPaint(watch.elapsed);
    }
  }

  @override
  bool shouldRepaint(covariant _TimedMermaidPainter oldDelegate) {
    return delegate.runtimeType != oldDelegate.delegate.runtimeType ||
        delegate.shouldRepaint(oldDelegate.delegate);
  }

  @override
  bool? hitTest(Offset position) => delegate.hitTest(position);

  @override
  SemanticsBuilderCallback? get semanticsBuilder => delegate.semanticsBuilder;

  @override
  bool shouldRebuildSemantics(covariant _TimedMermaidPainter oldDelegate) {
    return delegate.shouldRebuildSemantics(oldDelegate.delegate);
  }
}
