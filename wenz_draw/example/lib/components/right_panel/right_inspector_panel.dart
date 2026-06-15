import 'dart:math' as math;

import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:wenz_draw/wenz_draw.dart';

import '../../theme/ui_colors.dart';
import '../../mindmap/mindmap_actions.dart';
import '../../mindmap/mindmap_node_data.dart';
import '../../mindmap/mindmap_theme.dart';
import '../../mindmap/mindmap_tree.dart';
import '../../utils/example_helpers.dart';
import '../../utils/inspector_utils.dart';
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
        final selectedMindmapRoot = _mindmapRootData(selected);
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
                  if (selectedMindmapRoot != null)
                    PanelSection(
                      title: '思维导图',
                      children: [
                        _MindmapThemeDropdown(
                          canvasController: canvasController,
                          rootId: selected!.id,
                          data: selectedMindmapRoot,
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
                        onChanged: selected is DrawioShapeElement
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

MindmapNodeData? _mindmapRootData(CanvasElement? element) {
  if (element is! CanvasWidgetElement) return null;
  if (element.widgetType != kMindmapNodeWidgetType) return null;
  final data = MindmapNodeData.fromWidgetData(element.widgetData);
  return data.isRoot ? data : null;
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
        MindmapThemes.simpleFill.id;
    final currentTheme =
        MindmapThemes.byId(currentThemeId) ?? MindmapThemes.simpleFill;

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
