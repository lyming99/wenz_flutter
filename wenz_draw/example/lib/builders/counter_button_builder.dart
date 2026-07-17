import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

class CounterButtonBuilder extends WidgetElementBuilder {
  const CounterButtonBuilder();

  @override
  Widget build(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    final count = element.widgetData['count'] as int? ?? 0;
    final label = element.widgetData['label'] as String? ?? 'Clicks';
    final colorValue =
        int.tryParse(element.widgetData['color'] as String? ?? '0xFF2563EB') ??
        0xFF2563EB;

    if (canvas.renderDetail != CanvasWidgetRenderDetail.full) {
      return _buildPreview(
        count: count,
        label: label,
        color: Color(colorValue),
        detail: canvas.renderDetail,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Color(colorValue),
        borderRadius: BorderRadius.circular(8),
        border: canvas.selected
            ? Border.all(color: Colors.white, width: 2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            canvas.updateProps(element.id, {
              ...element.widgetData,
              'count': count + 1,
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFBFDBFE),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview({
    required int count,
    required String label,
    required Color color,
    required CanvasWidgetRenderDetail detail,
  }) {
    return switch (detail) {
      CanvasWidgetRenderDetail.color => ColoredBox(color: color),
      CanvasWidgetRenderDetail.colorWithText => ColoredBox(
        color: color,
        child: Center(
          child: Text(
            '$count',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
      CanvasWidgetRenderDetail.thumbnail => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: const Color(0x33000000)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$count',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontSize: 9, color: Color(0xFFBFDBFE)),
            ),
          ],
        ),
      ),
      CanvasWidgetRenderDetail.full => ColoredBox(color: color),
    };
  }
}
