import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

class StickyNoteBuilder extends WidgetElementBuilder {
  const StickyNoteBuilder();

  @override
  Widget build(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    final text = element.widgetData['text'] as String? ?? 'Double tap to edit';
    final colorValue =
        int.tryParse(element.widgetData['color'] as String? ?? '0xFFFFEB3B') ??
        0xFFFFEB3B;

    if (canvas.renderDetail != CanvasWidgetRenderDetail.full) {
      return _buildPreview(text, Color(colorValue), canvas.renderDetail);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        canvas.canvasController.setSelection({element.id});
      },
      onDoubleTap: () => _showEditDialog(context, element, canvas),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(colorValue),
          borderRadius: BorderRadius.circular(4),
          border: canvas.selected
              ? Border.all(color: const Color(0xFF2563EB), width: 1.5)
              : null,
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 4,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1F2937),
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(
    String text,
    Color color,
    CanvasWidgetRenderDetail detail,
  ) {
    return switch (detail) {
      CanvasWidgetRenderDetail.color => ColoredBox(color: color),
      CanvasWidgetRenderDetail.colorWithText => ColoredBox(
        color: color,
        child: Center(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ),
      CanvasWidgetRenderDetail.thumbnail => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: const Color(0x33000000)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
              style: const TextStyle(
                fontSize: 11,
                height: 1.2,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ),
      ),
      CanvasWidgetRenderDetail.full => ColoredBox(color: color),
    };
  }

  void _showEditDialog(
    BuildContext context,
    CanvasWidgetElement element,
    CanvasWidgetBuildContext canvas,
  ) {
    final controller = TextEditingController(
      text: element.widgetData['text'] as String? ?? '',
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit note'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Note text',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              canvas.updateProps(element.id, {
                ...element.widgetData,
                'text': controller.text,
              });
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
