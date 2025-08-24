import 'package:flutter/material.dart';

import '../mindmap.dart';

typedef NodeContentBuilder = Widget Function(
    BuildContext context, NodeEditController controller);
typedef NodeLayout = Size Function(MindNode node);
typedef CopyFunction = void Function(List<MindNode> copyList);
typedef PasteFunction = Future<List<MindNode>> Function();
