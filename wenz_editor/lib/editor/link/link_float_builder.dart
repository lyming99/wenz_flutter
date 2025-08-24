import 'dart:ui';

import 'package:wenz_editor/editor/edit_controller.dart';

import '../../commons/widget/popup_stack.dart';
import '../block/text/link.dart';

class LinkBuilderResult {
  bool isHandle;
  PopupPositionWidget? widget;

  LinkBuilderResult.handle({
    this.isHandle = true,
    this.widget,
  });

  LinkBuilderResult.ignore({
    this.isHandle = false,
  });
}

typedef LinkFloatBuilder = LinkBuilderResult Function(
    WenzEditController controller, BlockLink link, Rect startCursorRect);
