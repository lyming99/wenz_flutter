import 'package:wenz_editor/editor/block/block.dart';
import 'package:wenz_editor/editor/block/element/element.dart';

import '../block/text/text.dart';

class ItemUtils {
  ItemUtils._();

  static void calcDynamicElementListIndex(
      List<WenElement> elements, int index) {
    var element = elements[index];
    if (element is! WenTextElement) {
      return;
    }
    if (element.itemType != 'oli') {
      return;
    }
    var level = elements[index].level;
    var startIndex = 0;
    var isQuote = elements[index].type == "quote";
    if (level == 0) {
      startIndex = elements.lastIndexWhere(
          (element) =>
              element.level != 0 && (isQuote == (element.type == "quote")),
          index);
    } else {
      startIndex = elements.lastIndexWhere(
          (element) =>
              element.level < level && (isQuote == (element.type == "quote")),
          index);
    }
    if (startIndex < 0) {
      startIndex = 0;
    }
    for (var i = startIndex; i <= index; i++) {
      calcElementListIndex(elements, index);
    }
  }

  static void calcAllElementListIndex(List<WenElement> elements) {
    for (var i = 0; i < elements.length; i++) {
      calcElementListIndex(elements, i);
    }
  }

  static void calcElementListIndex(List<WenElement> elements, int index) {
    var current = elements[index];
    if (current is! WenTextElement) {
      return;
    }
    if (current.itemType != 'oli') {
      return;
    }
    if (index == 0) {
      current.listIndex = 1;
      return;
    }
    var isQuote = current.type == "quote";
    var preIndex = index - 1;
    while (preIndex >= 0) {
      var pre = elements[preIndex];
      if (pre is! WenTextElement) {
        // 前面不是文本，继续
        preIndex--;
        continue;
      }
      if (isQuote != (pre.type == 'quote')) {
        // 前面的引用模式和现在不一样
        preIndex--;
        continue;
      }
      if (pre.level > current.level) {
        // 前面level较大，继续
        if (current.level == 0) {
          break;
        }
        preIndex--;
        continue;
      }
      if (pre.level < current.level) {
        // 前面的level较小，结束
        break;
      }
      var preIndent = pre.indent ?? 0;
      var curIndent = current.indent ?? 0;
      if (pre.itemType == 'oli') {
        // 前面是有序列表
        if (pre.level > 0) {
          // 前面为标题，不需要判断indent缩进，+1
          current.listIndex = pre.listIndex + 1;
          break;
        }
        // 判断缩进
        if (preIndent > curIndent) {
          // 前面缩进较大，继续
          preIndex--;
          continue;
        }
        if (curIndent > preIndent) {
          // 前面缩进较小，结束
          break;
        }
        // 缩进一致，+1
        current.listIndex = pre.listIndex + 1;
        break;
      } else {
        // 前面不是有序列表
        if (pre.level > 0) {
          // 如果是标题，不用考虑缩进，直接结束
          break;
        }
        if (preIndent <= curIndent) {
          // 前面缩进较小或相同，结束
          break;
        }
        if (preIndent > curIndent) {
          // 前面缩进较大，继续
          preIndex--;
          continue;
        }
      }
      preIndex--;
    }
  }

  static void calcDynamicBlockListIndex(List<WenzBlock> elements, int index) {
    var element = elements[index].element;
    if (element is! WenTextElement) {
      return;
    }
    if (element.itemType != 'oli') {
      return;
    }
    var level = elements[index].element.level;
    var startIndex = 0;
    var isQuote = elements[index].element.type == "quote";
    if (level == 0) {
      startIndex = elements.lastIndexWhere(
          (element) =>
              element.element.level != 0 &&
              (isQuote == (element.element.type == "quote")),
          index);
    } else {
      startIndex = elements.lastIndexWhere(
          (element) =>
              element.element.level < level &&
              (isQuote == (element.element.type == "quote")),
          index);
    }
    if (startIndex < 0) {
      startIndex = 0;
    }
    for (var i = startIndex; i <= index; i++) {
      calcBlockListIndex(elements, index);
    }
  }

  static void calcAllBlockListIndex(List<WenzBlock> elements) {
    for (var i = 0; i < elements.length; i++) {
      calcBlockListIndex(elements, i);
    }
  }

  static void calcBlockListIndex(List<WenzBlock> elements, int index) {
    var current = elements[index].element;
    if (current is! WenTextElement) {
      return;
    }
    if (current.itemType != 'oli') {
      return;
    }
    if (index == 0) {
      current.listIndex = 1;
      return;
    }
    current.listIndex = 1;
    var isQuote = current.type == "quote";
    var preIndex = index - 1;
    while (preIndex >= 0) {
      var pre = elements[preIndex].element;
      if (pre is! WenTextElement) {
        // 前面不是文本，继续
        preIndex--;
        continue;
      }
      if (isQuote != (pre.type == 'quote')) {
        // 前面的引用模式和现在不一样
        preIndex--;
        continue;
      }
      if (pre.level > current.level) {
        // 前面level较大，继续
        if (current.level == 0) {
          break;
        }
        preIndex--;
        continue;
      }
      if (pre.level < current.level) {
        // 前面的level较小，结束
        break;
      }
      var preIndent = pre.indent ?? 0;
      var curIndent = current.indent ?? 0;
      if (pre.itemType == 'oli') {
        // 前面是有序列表
        if (pre.level > 0) {
          // 前面为标题，不需要判断indent缩进，+1
          current.listIndex = pre.listIndex + 1;
          break;
        }
        // 判断缩进
        if (preIndent > curIndent) {
          // 前面缩进较大，继续
          preIndex--;
          continue;
        }
        if (curIndent > preIndent) {
          // 前面缩进较小，结束
          break;
        }
        // 缩进一致，+1
        current.listIndex = pre.listIndex + 1;
        break;
      } else {
        // 前面不是有序列表
        if (pre.level > 0) {
          // 如果是标题，不用考虑缩进，直接结束
          break;
        }
        if (preIndent <= curIndent) {
          // 前面缩进较小或相同，结束
          break;
        }
        if (preIndent > curIndent) {
          // 前面缩进较大，继续
          preIndex--;
          continue;
        }
      }
      preIndex--;
    }
  }
}
