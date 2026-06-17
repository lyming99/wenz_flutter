import 'package:wenz_draw/wenz_draw.dart';

class DrawioShapePaletteEntry {
  const DrawioShapePaletteEntry({
    required this.label,
    required this.shapeKey,
    required this.group,
  });

  final String label;
  final String shapeKey;
  final String group;

  String get toolId => ShapeTool.idFor(shapeKey);
}

final flowchartShapePalette = [
  for (final key in FlowchartStencils.keys)
    DrawioShapePaletteEntry(
      label: FlowchartStencils.labels[key] ?? key,
      shapeKey: key,
      group: 'flowchart',
    ),
];

final basicSymbolShapePalette = [
  for (final key in BasicStencils.keys)
    DrawioShapePaletteEntry(
      label: BasicStencils.labels[key] ?? key,
      shapeKey: key,
      group: 'basicSymbols',
    ),
];

final arrowShapePalette = [
  for (final key in ArrowStencils.keys)
    DrawioShapePaletteEntry(
      label: ArrowStencils.labels[key] ?? key,
      shapeKey: key,
      group: 'arrows',
    ),
];

const drawioShapePalette = [
  DrawioShapePaletteEntry(label: '菱形', shapeKey: 'rhombus', group: 'basic'),
  DrawioShapePaletteEntry(label: '三角形', shapeKey: 'triangle', group: 'basic'),
  DrawioShapePaletteEntry(label: '六边形', shapeKey: 'hexagon', group: 'basic'),
  DrawioShapePaletteEntry(label: '加号', shapeKey: 'plus', group: 'basic'),
  DrawioShapePaletteEntry(label: '交叉', shapeKey: 'cross', group: 'basic'),
  DrawioShapePaletteEntry(
    label: '流程',
    shapeKey: 'parallelogram',
    group: 'flowchart',
  ),
  DrawioShapePaletteEntry(
    label: '梯形',
    shapeKey: 'trapezoid',
    group: 'flowchart',
  ),
  DrawioShapePaletteEntry(
    label: '文档',
    shapeKey: 'document',
    group: 'flowchart',
  ),
  DrawioShapePaletteEntry(label: '步骤', shapeKey: 'step', group: 'flowchart'),
  DrawioShapePaletteEntry(
    label: '圆柱',
    shapeKey: 'cylinder',
    group: 'flowchart',
  ),
  DrawioShapePaletteEntry(
    label: '泳道',
    shapeKey: 'swimlane',
    group: 'container',
  ),
  DrawioShapePaletteEntry(label: '便签形', shapeKey: 'note', group: 'container'),
  DrawioShapePaletteEntry(
    label: '标注',
    shapeKey: 'callout',
    group: 'container',
  ),
  DrawioShapePaletteEntry(
    label: '双椭圆',
    shapeKey: 'doubleEllipse',
    group: 'container',
  ),
  DrawioShapePaletteEntry(
    label: '角色',
    shapeKey: 'actor',
    group: 'container',
  ),
  DrawioShapePaletteEntry(label: '云', shapeKey: 'cloud', group: 'container'),
  DrawioShapePaletteEntry(label: '立方体', shapeKey: 'cube', group: 'container'),
];
