import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';
import '../components/color_picker/color_picker_dialog.dart';
import 'inspector_utils.dart';

void showExportDialog(BuildContext context, String title, String content) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('导出 $title'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: TextEditingController(text: content),
            readOnly: true,
            maxLines: 16,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      );
    },
  );
}

void showImportDialog(
  BuildContext context,
  CanvasController controller, {
  required bool importDrawio,
}) {
  final textController = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(importDrawio ? '导入 draw.io' : '导入 JSON'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: textController,
            maxLines: 16,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: importDrawio ? '粘贴 draw.io XML' : '粘贴画布 JSON',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              try {
                if (importDrawio) {
                  final elements = DrawioImporter.fromXml(textController.text);
                  controller.replaceElements(elements);
                } else {
                  final json = jsonDecode(textController.text);
                  if (json is! Map<String, dynamic>) {
                    throw const FormatException('JSON 根节点必须是对象');
                  }
                  CanvasSerializer.load(controller, json);
                }
                Navigator.pop(context);
              } catch (error) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('导入失败：$error')));
              }
            },
            child: const Text('导入'),
          ),
        ],
      );
    },
  );
}

String prettyJson(Object value) {
  return const JsonEncoder.withIndent('  ').convert(value);
}

Future<T?> showAnchoredMenu<T>({
  required BuildContext context,
  required List<PopupMenuEntry<T>> items,
}) {
  final button = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (button == null || overlay == null) {
    return Future<T?>.value();
  }
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    ),
    Offset.zero & overlay.size,
  );
  return showMenu<T>(context: context, position: position, items: items);
}

Future<void> showTextColorPicker(
  BuildContext context,
  CanvasElement selected,
  CanvasController controller,
) async {
  final initialColor =
      textColorOf(selected) ?? controller.brushSettings.color;
  final color = await showDialog<Color>(
    context: context,
    builder: (context) => ColorPickerDialog(
      initialColor: initialColor,
      swatches: toolbarColorSwatches,
    ),
  );
  if (color != null) {
    if (selected is TextElement) {
      controller.updateTextElementStyle(selected.id, color: color);
    } else {
      controller.updateShapeLabelStyle(selected.id, color: color);
    }
  }
}

Future<void> showShapeColorPicker(
  BuildContext context,
  CanvasElement selected,
  CanvasController controller, {
  required bool fill,
}) async {
  final initialColor = fill
      ? fillColorOf(selected) ?? Colors.white
      : strokeColorOf(selected) ?? Colors.black;
  final color = await showDialog<Color>(
    context: context,
    builder: (context) => ColorPickerDialog(
      initialColor: initialColor,
      swatches: toolbarColorSwatches,
    ),
  );
  if (color != null) {
    controller.updateShapePaint(
      selected.id,
      fillColor: fill ? color : null,
      strokeColor: fill ? null : color,
    );
  }
}

Future<void> showColorMenu(
  BuildContext context,
  CanvasController controller,
) async {
  final color = await showDialog<Color>(
    context: context,
    builder: (context) => ColorPickerDialog(
      initialColor: controller.brushSettings.color,
      swatches: toolbarColorSwatches,
    ),
  );
  if (color != null) {
    final brush = controller.brushSettings;
    controller.updateBrushSettings(
      brush.copyWith(color: color, fillColor: color.withValues(alpha: 0.12)),
    );
  }
}
