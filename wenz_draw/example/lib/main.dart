import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';
import 'package:wenz_draw/wenz_draw_mindmap.dart';

import 'app.dart';
import 'builders/sticky_note_builder.dart';
import 'builders/counter_button_builder.dart';
import 'utils/url_launcher_link_opener.dart';

void main() {
  // Host-level widget registrations.
  WidgetElementRegistry.register('sticky_note', const StickyNoteBuilder());
  WidgetElementRegistry.register(
    'counter_button',
    const CounterButtonBuilder(),
  );

  // Register the optional mind map module. The module itself lives in the SDK
  // (`wenz_draw_mindmap`); it just needs a host-supplied link opener because
  // the SDK does not depend on platform plugins.
  registerMindmapModule(linkOpener: const UrlLauncherLinkOpener());

  runApp(const WenzDrawExampleApp());
}
