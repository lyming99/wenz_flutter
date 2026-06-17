import 'dart:math' as math;

import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:wenz_draw/wenz_draw.dart';
import 'package:wenz_draw/wenz_draw_mindmap.dart';

import '../widgets/color_picker_dialog.dart';
import '../theme/ui_colors.dart';
import '../editor/editor_actions.dart';
import 'inspector_utils.dart';
import 'inspector_fields.dart';
import 'layer_row.dart';
import 'panel_section.dart';

class RightInspectorPanel extends StatelessWidget {
  const RightInspectorPanel({required this.canvasController});

  final CanvasController canvasController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: canvasController,
      builder: (context, _) {
        final selected = canvasController.selectedElements.firstOrNull;
        final bounds = selected?.bounds;
        final brush = canvasController.brushSettings;
        final selectedFill = fillColorOf(selected) ?? brush.fillColor;
        final selectedStroke = strokeColorOf(selected) ?? brush.color;
        final selectedStrokeWidth =
            strokeWidthOf(selected) ?? brush.strokeWidth;
        final selectedMindmapNode = _mindmapNodeData(selected);
        final selectedMindmapRoot = selectedMindmapNode?.isRoot == true
            ? selectedMindmapNode
            : null;
        return Container(
          width: 292,
          color: UiColors.panel,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: UiColors.line)),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  PanelSection(
                    title: '图层',
                    actionLabel: '新建',
                    onAction: () => canvasController.addLayer(),
                    children: [
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: canvasController.layers.length,
                        onReorder: (oldIndex, newIndex) {
                          final adjusted = newIndex > oldIndex
                              ? newIndex - 1
                              : newIndex;
                          canvasController.reorderLayer(oldIndex, adjusted);
                        },
                        itemBuilder: (context, index) {
                          final layer = canvasController.layers[index];
                          return LayerRow(
                            key: ValueKey(layer.id),
                            layer: layer,
                            index: index,
                            active: layer.id == canvasController.activeLayerId,
                            canDelete: canvasController.layers.length > 1,
                            onSelect: () =>
                                canvasController.setActiveLayer(layer.id),
                            onToggleVisible: () => canvasController
                                .toggleLayerVisibility(layer.id),
                            onDelete: () =>
                                canvasController.removeLayer(layer.id),
                          );
                        },
                      ),
                    ],
                  ),
                  if (selectedMindmapNode != null)
                    PanelSection(
                      title: '思维导图',
                      children: [
                        if (selectedMindmapRoot != null) ...[
                          _MindmapThemeDropdown(
                            canvasController: canvasController,
                            rootId: selected!.id,
                            data: selectedMindmapRoot,
                          ),
                          const SizedBox(height: 14),
                        ],
                        _MindmapNodeStyleEditor(
                          canvasController: canvasController,
                          nodeId: selected!.id,
                          data: selectedMindmapNode,
                        ),
                      ],
                    ),
                  PanelSection(
                    title: '位置与尺寸',
                    children: [
                      FieldGrid(
                        children: [
                          ReadoutField(label: 'X', value: bounds?.left),
                          ReadoutField(label: 'Y', value: bounds?.top),
                          ReadoutField(label: '宽', value: bounds?.width),
                          ReadoutField(label: '高', value: bounds?.height),
                        ],
                      ),
                    ],
                  ),
                  PanelSection(
                    title: '填充与描边',
                    children: [
                      FieldGrid(
                        children: [
                          ColorButtonField(
                            label: '填充',
                            color: selectedFill,
                            enabled: canEditPaint(selected),
                            onPressed: selected == null
                                ? null
                                : () => showShapeColorPicker(
                                    context,
                                    selected,
                                    canvasController,
                                    fill: true,
                                  ),
                          ),
                          ColorButtonField(
                            label: '描边',
                            color: selectedStroke,
                            enabled: canEditPaint(selected),
                            onPressed: selected == null
                                ? null
                                : () => showShapeColorPicker(
                                    context,
                                    selected,
                                    canvasController,
                                    fill: false,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SliderField(
                        label: '描边宽度',
                        value: selectedStrokeWidth,
                        min: 1,
                        max: 20,
                        onChanged: canEditPaint(selected)
                            ? (value) => canvasController.updateShapePaint(
                                selected!.id,
                                strokeWidth: value,
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      const FieldLabel('常用颜色'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final color in inspectorSwatches)
                            ColorSwatch(
                              color: color,
                              selected: selectedStroke == color,
                              onPressed: canEditPaint(selected)
                                  ? () => canvasController.updateShapePaint(
                                      selected!.id,
                                      strokeColor: color,
                                    )
                                  : () {
                                      canvasController.updateBrushSettings(
                                        canvasController.brushSettings.copyWith(
                                          color: color,
                                        ),
                                      );
                                    },
                            ),
                        ],
                      ),
                    ],
                  ),
                  PanelSection(
                    title: '文本',
                    children: [
                      TextReadout(
                        selected: selected,
                        onChanged: (text) {
                          if (selected != null) {
                            canvasController.updateTextContent(
                              selected.id,
                              text,
                              record: false,
                            );
                          }
                        },
                        onCommitted: (text) {
                          if (selected != null) {
                            canvasController.updateTextContent(
                              selected.id,
                              text,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      SliderField(
                        label: '字号',
                        value: fontSizeOf(selected) ?? 14,
                        min: 8,
                        max: 48,
                        onChanged: selected != null
                            ? (value) {
                                if (selected is TextElement) {
                                  canvasController.updateTextElementStyle(
                                    selected.id,
                                    fontSize: value,
                                  );
                                } else {
                                  canvasController.updateShapeLabelStyle(
                                    selected.id,
                                    fontSize: value,
                                  );
                                }
                              }
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const FieldLabel('颜色'),
                          const Spacer(),
                          TextSwatchButton(
                            color:
                                textColorOf(selected) ??
                                canvasController.brushSettings.color,
                            onPressed: selected == null
                                ? null
                                : () => showTextColorPicker(
                                    context,
                                    selected,
                                    canvasController,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const FieldLabel('常用颜色'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final color in inspectorSwatches)
                            ColorSwatch(
                              color: color,
                              selected: textColorOf(selected) == color,
                              onPressed: selected != null
                                  ? () {
                                      if (selected is TextElement) {
                                        canvasController.updateTextElementStyle(
                                          selected.id,
                                          color: color,
                                        );
                                      } else {
                                        canvasController.updateShapeLabelStyle(
                                          selected.id,
                                          color: color,
                                        );
                                      }
                                    }
                                  : () {
                                      canvasController.updateBrushSettings(
                                        canvasController.brushSettings.copyWith(
                                          color: color,
                                        ),
                                      );
                                    },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const FieldLabel('字重'),
                      const SizedBox(height: 6),
                      FontWeightDropdown(
                        selected: selected,
                        onChanged: (weight) {
                          if (selected != null) {
                            if (selected is TextElement) {
                              canvasController.updateTextElementStyle(
                                selected.id,
                                fontWeight: weight,
                              );
                            } else {
                              canvasController.updateShapeLabelStyle(
                                selected.id,
                                fontWeight: weight,
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      const FieldLabel('对齐'),
                      const SizedBox(height: 6),
                      AlignmentControl(
                        selected: selected,
                        onChanged: (align) {
                          if (selected != null) {
                            if (selected is TextElement) {
                              canvasController.updateTextElementStyle(
                                selected.id,
                                textAlign: align,
                              );
                            } else {
                              canvasController.updateShapeLabelStyle(
                                selected.id,
                                textAlign: align,
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  PanelSection(
                    title: '旋转',
                    children: [
                      SliderField(
                        label: '角度',
                        value: rotationDegreesOf(selected),
                        min: -180,
                        max: 180,
                        onChanged:
                            canRotateElement(selected) && selected != null
                            ? (value) {
                                canvasController.updateElementRotation(
                                  selected.id,
                                  value * math.pi / 180,
                                );
                              }
                            : null,
                      ),
                    ],
                  ),
                  PanelSection(
                    title: '外观',
                    children: [
                      SliderField(
                        label: '圆角',
                        value: radiusOf(selected),
                        min: 0,
                        max: 24,
                        onChanged: selected is RectElement
                            ? (value) {
                                canvasController.updateElement(
                                  selected.id,
                                  selected.copyWith(borderRadius: value),
                                );
                              }
                            : null,
                      ),
                      const SizedBox(height: 12),
                      SliderField(
                        label: '透明度',
                        value: opacityOf(selected) ?? brush.opacity,
                        min: 0,
                        max: 1,
                        fractionDigits: 2,
                        onChanged: (value) {
                          if (canEditPaint(selected)) {
                            canvasController.updateShapePaint(
                              selected!.id,
                              fillColor: fillColorOf(selected),
                              strokeColor: strokeColorOf(selected),
                              strokeWidth: strokeWidthOf(selected),
                              opacity: value,
                            );
                          } else {
                            canvasController.updateBrushSettings(
                              brush.copyWith(opacity: value),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

MindmapNodeData? _mindmapNodeData(CanvasElement? element) {
  if (element is! CanvasWidgetElement) return null;
  if (element.widgetType != kMindmapNodeWidgetType) return null;
  return MindmapNodeData.fromWidgetData(element.widgetData);
}

class _MindmapNodeStyleEditor extends StatelessWidget {
  const _MindmapNodeStyleEditor({
    required this.canvasController,
    required this.nodeId,
    required this.data,
  });

  final CanvasController canvasController;
  final String nodeId;
  final MindmapNodeData data;

  @override
  Widget build(BuildContext context) {
    final actions = MindmapActions.of(canvasController);
    final style =
        actions?.styleForNode(nodeId) ??
        MindmapThemeController().styleFor(
          MindmapThemeNodeContext.fromNodeData(
            data,
            depth: data.isRoot ? 0 : 1,
            siblingIndex: data.order,
            siblingCount: 1,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('节点样式'),
        const SizedBox(height: 8),
        _MindmapTodoControl(
          data: data,
          enabled: actions != null,
          onEnabledChanged: (value) =>
              actions?.setNodeTodo(nodeId, enabled: value),
          onDoneChanged: data.todoEnabled
              ? (value) => actions?.setNodeTodo(nodeId, done: value)
              : null,
        ),
        const SizedBox(height: 12),
        _MindmapLinkControl(
          data: data,
          enabled: actions != null,
          onChanged: (url) => actions?.setNodeLink(nodeId, url),
        ),
        const SizedBox(height: 12),
        _MindmapStyleColorControl(
          label: '底色',
          color: style.fillColor,
          overridden: data.fillColor != null,
          enabled: actions != null,
          onPick: () async {
            final color = await _pickMindmapColor(context, style.fillColor);
            if (color != null) {
              actions?.setNodeStyle(nodeId, fillColor: color.toARGB32());
            }
          },
          onReset: () => actions?.setNodeStyle(nodeId, fillColor: null),
        ),
        const SizedBox(height: 10),
        _MindmapStyleColorControl(
          label: '边框',
          color: style.borderColor,
          overridden: data.borderColor != null,
          enabled: actions != null,
          onPick: () async {
            final color = await _pickMindmapColor(context, style.borderColor);
            if (color != null) {
              actions?.setNodeStyle(nodeId, borderColor: color.toARGB32());
            }
          },
          onReset: () => actions?.setNodeStyle(nodeId, borderColor: null),
        ),
        const SizedBox(height: 10),
        _MindmapStyleColorControl(
          label: '字体',
          color: style.textColor,
          overridden: data.fontColor != null,
          enabled: actions != null,
          onPick: () async {
            final color = await _pickMindmapColor(context, style.textColor);
            if (color != null) {
              actions?.setNodeStyle(nodeId, fontColor: color.toARGB32());
            }
          },
          onReset: () => actions?.setNodeStyle(nodeId, fontColor: null),
        ),
      ],
    );
  }
}

class _MindmapTodoControl extends StatelessWidget {
  const _MindmapTodoControl({
    required this.data,
    required this.enabled,
    required this.onEnabledChanged,
    required this.onDoneChanged,
  });

  final MindmapNodeData data;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool>? onDoneChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: UiColors.panelSoft,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: UiColors.line),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                const FieldLabel('TODO'),
                const Spacer(),
                Switch(
                  value: data.todoEnabled,
                  onChanged: enabled ? onEnabledChanged : null,
                ),
              ],
            ),
            if (data.todoEnabled) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Checkbox(
                    value: data.todoDone,
                    visualDensity: VisualDensity.compact,
                    onChanged: enabled && onDoneChanged != null
                        ? (value) => onDoneChanged!(value ?? false)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '已完成',
                    style: TextStyle(fontSize: 13, color: UiColors.text),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MindmapLinkControl extends StatelessWidget {
  const _MindmapLinkControl({
    required this.data,
    required this.enabled,
    required this.onChanged,
  });

  final MindmapNodeData data;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  bool get _hasLink => data.linkUrl != null && data.linkUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: UiColors.panelSoft,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: UiColors.line),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const FieldLabel('链接'),
                const Spacer(),
                TextButton(
                  onPressed: enabled ? () => _editLink(context) : null,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(_hasLink ? '编辑' : '插入'),
                ),
              ],
            ),
            if (_hasLink) ...[
              const SizedBox(height: 6),
              Text(
                data.linkUrl!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: UiColors.muted),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: enabled ? () => _openLink(context) : null,
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('打开'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: enabled ? () => onChanged(null) : null,
                    child: const Text('清除'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _editLink(BuildContext context) {
    final controller = TextEditingController(text: data.linkUrl ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_hasLink ? '编辑链接' : '插入链接'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '链接地址',
              hintText: 'https://example.com',
            ),
            onSubmitted: (_) {
              onChanged(controller.text);
              Navigator.pop(ctx);
            },
          ),
          actions: [
            if (_hasLink)
              TextButton(
                onPressed: () {
                  onChanged(null);
                  Navigator.pop(ctx);
                },
                child: const Text('清除'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                onChanged(controller.text);
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _openLink(BuildContext context) async {
    final uri = _uriFromLink(data.linkUrl);
    if (uri == null) return;
    final opened = await MindmapLinkOpenerHolder.current.open(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
  }

  Uri? _uriFromLink(String? url) {
    final text = url?.trim();
    if (text == null || text.isEmpty) return null;
    final parsed = Uri.tryParse(text);
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed;
    return Uri.tryParse('https://$text');
  }
}

class _MindmapStyleColorControl extends StatelessWidget {
  const _MindmapStyleColorControl({
    required this.label,
    required this.color,
    required this.overridden,
    required this.enabled,
    required this.onPick,
    required this.onReset,
  });

  final String label;
  final Color color;
  final bool overridden;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FieldLabel(label),
            const Spacer(),
            if (overridden)
              TextButton(
                onPressed: enabled ? onReset : null,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('跟随主题'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Material(
          color: UiColors.panelSoft,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: UiColors.line),
            borderRadius: BorderRadius.circular(7),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: enabled ? onPick : null,
            child: Container(
              height: 34,
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: const Color(0x3318232E)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<Color?> _pickMindmapColor(BuildContext context, Color initialColor) {
  return showDialog<Color>(
    context: context,
    builder: (context) => ColorPickerDialog(
      initialColor: initialColor,
      swatches: toolbarColorSwatches,
    ),
  );
}

class _MindmapThemeDropdown extends StatelessWidget {
  const _MindmapThemeDropdown({
    required this.canvasController,
    required this.rootId,
    required this.data,
  });

  final CanvasController canvasController;
  final String rootId;
  final MindmapNodeData data;

  @override
  Widget build(BuildContext context) {
    final actions = MindmapActions.of(canvasController);
    final currentThemeId =
        data.themeId ??
        actions?.themeIdForNode(rootId) ??
        MindmapThemes.defaultThemeId;
    final currentTheme =
        MindmapThemes.byId(currentThemeId) ?? MindmapThemes.defaultTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('样式'),
        const SizedBox(height: 6),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: UiColors.panelSoft,
            border: Border.all(color: UiColors.line),
            borderRadius: BorderRadius.circular(7),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentTheme.id,
              isExpanded: true,
              style: const TextStyle(fontSize: 14, color: UiColors.text),
              items: [
                for (final theme in MindmapThemes.presets)
                  DropdownMenuItem(value: theme.id, child: Text(theme.label)),
              ],
              onChanged: actions == null
                  ? null
                  : (themeId) {
                      if (themeId == null) return;
                      actions.setRootTheme(rootId, themeId);
                    },
            ),
          ),
        ),
      ],
    );
  }
}
