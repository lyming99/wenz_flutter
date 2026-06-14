import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

import 'app.dart';
import 'builders/sticky_note_builder.dart';
import 'builders/counter_button_builder.dart';
import 'mindmap/mindmap_builder.dart';
import 'mindmap/mindmap_node_builder.dart';

void main() {
  WidgetElementRegistry.register('sticky_note', const StickyNoteBuilder());
  WidgetElementRegistry.register(
    'counter_button',
    const CounterButtonBuilder(),
  );
  // 旧组件模式（单个封装 widget）——保留作为对照。
  WidgetElementRegistry.register('mindmap', const MindmapBuilder());
  // 新非组件模式：每个节点是独立画布元素。
  WidgetElementRegistry.register('mindmap_node', const MindmapNodeBuilder());
  runApp(const WenzDrawExampleApp());
}
