import 'package:wenz_editor/editor/edit_controller.dart';

import '../block/block.dart';
import '../block/code/code.dart';
import '../block/text/text.dart';

const kListItemType = ["oli", "li", "check"];

class TextUtils {
  TextUtils._();

  static void dealInsertIndent(
      WenzEditController controller, List<WenzBlock> insertBlocks) {
    if (insertBlocks.isEmpty) {
      return;
    }
    var minIndent = insertBlocks
            .reduce((a, b) {
              var aIndent = a.element.indent ?? 0;
              var bIndent = b.element.indent ?? 0;
              return aIndent < bIndent ? a : b;
            })
            .element
            .indent ??
        0;
    var addition = -minIndent;
    var blockIndex = controller.cursorState.cursorPosition?.blockIndex;
    if (blockIndex != null) {
      var block = controller.blockManager.blocks[blockIndex];
      var indent = block.element.indent ?? 0;
      addition = indent + addition;
    }
    for (var block in insertBlocks) {
      block.element.indent = (block.element.indent ?? 0) + addition;
      if (block.element.indent == 0) {
        block.element.indent = null;
      }
    }
  }

  static void dealInsertItemType(
      WenzEditController controller, List<WenzBlock> insertBlocks) {
    if (insertBlocks.isEmpty) {
      return;
    }
    var blockIndex = controller.cursorState.cursorPosition?.blockIndex;
    if (blockIndex == null) {
      return;
    }
    var block = controller.blockManager.blocks[blockIndex];
    if (block is! TextBlock) {
      return;
    }
    var itemType = block.textElement.itemType;
    if (itemType == null || !kListItemType.contains(itemType)) {
      return;
    }
    for (var block in insertBlocks) {
      if (block is TextBlock) {
        block.textElement.itemType = itemType;
      }
    }
  }

  static void dealInsertQuoteType(
      WenzEditController controller, List<WenzBlock> insertBlocks) {
    if (insertBlocks.isEmpty) {
      return;
    }
    var blockIndex = controller.cursorState.cursorPosition?.blockIndex;
    if (blockIndex == null) {
      return;
    }
    var block = controller.blockManager.blocks[blockIndex];
    if (block is! TextBlock) {
      return;
    }
    var type = block.textElement.type;
    if (type != "quote") {
      return;
    }
    for (var block in insertBlocks) {
      if (block is TextBlock) {
        block.textElement.type = "quote";
      }
    }
  }

  static List<WenzBlock> preDealInsertBlocks(
      WenzEditController controller, List<WenzBlock> insertBlocks) {
    if (insertBlocks.length == 1) {
      var first = insertBlocks.first;
      if (first is CodeBlock) {
        var code = first.element.code;
        if (!code.contains("\n")) {
          return [
            TextBlock(
              context: first.context,
              editController: first.editController,
              textElement: WenTextElement(text: code),
            ),
          ];
        }
      }
    }
    List<WenzBlock> result = [];
    bool preIsEmpty = false;
    for (var block in insertBlocks) {
      if (block is TextBlock) {
        var text = block.element.getText();
        if (text.isEmpty) {
          if (preIsEmpty) {
            continue;
          }
          preIsEmpty = true;
        } else {
          preIsEmpty = false;
        }
        if (text.contains("\n")) {
          var lines = text.split("\n");
          for (var line in lines) {
            result.add(
              TextBlock(
                context: block.context,
                editController: block.editController,
                textElement: block.textElement.copyStyle(line, []),
              ),
            );
          }
        }
      } else {
        preIsEmpty = false;
      }
      result.add(block);
    }
    return result;
  }

  static List<WenzBlock> dealInsertBlocks(
      WenzEditController controller, List<WenzBlock> insertBlocks) {
    var blocks = preDealInsertBlocks(controller, insertBlocks);
    dealInsertIndent(controller, blocks);
    dealInsertItemType(controller, blocks);
    dealInsertQuoteType(controller, insertBlocks);
    return blocks;
  }
}
