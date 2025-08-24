import 'package:super_clipboard/super_clipboard.dart';
import 'package:wenz_editor/editor/block/text/text.dart';
import 'package:wenz_editor/editor/edit_controller.dart';

import '../../commons/service/copy_service.dart';
import '../block/element/element.dart';

class CopyUtils {
  CopyUtils._();

  static void copyInternalLink({
    required CopyService copyService,
    required String url,
    required String title,
  }) async {
    var copyId = copyService.generateCopyId();
    StringBuffer html = StringBuffer("<!DOCTYPE html>\n"
        "<html>\n<head>\n"
        "<meta charset=\"utf-8\"></meta></head><body copyid='$copyId'>");
    StringBuffer text = StringBuffer();
    var copyElements = <WenElement>[];
    var element = WenTextElement(
      url: url,
      text: title,
    );
    text.write(url);
    copyElements.add(element);
    await copyService.saveCopyCache(copyElements, copyId: copyId);
    html.write("</body></html>");
    // RichClipboard.setData(RichClipboardData(html: html, text: text));
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return;
    }
    final item = DataWriterItem();
    item.add(Formats.htmlText(html.toString()));
    item.add(Formats.plainText(text.toString()));
    await clipboard.write([item]);
  }

  static void copyAll({
    required WenzEditController controller,
    bool copyText = false,
  }) async {
    var copyService = controller.copyService;
    var copyId = copyService.generateCopyId();
    StringBuffer html = StringBuffer("<!DOCTYPE html>\n"
        "<html>\n<head>\n"
        "<meta charset=\"utf-8\"></meta></head><body copyid='$copyId'>");
    StringBuffer text = StringBuffer();

    var copyElements = <WenElement>[];
    for (var block in controller.blockManager.blocks) {
      var element = block.element;
      copyElements.add(element);
      if (!copyText) html.write(element.getHtml());
      text.write("\n${element.getText()}");
    }
    await copyService.saveCopyCache(copyElements, copyId: copyId);
    html.write("</body></html>");
    // RichClipboard.setData(RichClipboardData(html: html, text: text));
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return;
    }
    final item = DataWriterItem();
    if (!copyText) {
      item.add(Formats.htmlText(html.toString()));
    }
    item.add(Formats.plainText(text.toString()));
    await clipboard.write([item]);
  }

  static void copySelect({
    required WenzEditController controller,
    bool copyText = false,
  }) async {
    var copyService = controller.copyService;
    if (controller.selectState.hasSelect) {
      var start = controller.selectState.realStart;
      var end = controller.selectState.realEnd;
      if (start!.block! == end!.block) {
        WenElement element =
            start.block!.copyElement(start.textPosition!, end.textPosition!);
        await copyService.saveCopyCache([element]);
        String html = "<!DOCTYPE html>\n"
            "<html>\n<head>\n"
            "<meta charset=\"utf-8\"></meta></head><body copyid='${copyService.copyId}'>";
        html += element.getHtml();
        html += "</body></html>";
        // RichClipboard.setData(
        //     RichClipboardData(html: html, text: element.getText()));
        final clipboard = SystemClipboard.instance;
        if (clipboard == null) {
          return;
        }
        final item = DataWriterItem();
        item.add(Formats.htmlText(html.toString()));
        item.add(Formats.plainText(element.getText()));
        await clipboard.write([item]);
      } else {
        var copyId = copyService.generateCopyId();
        String html = "<!DOCTYPE html>\n"
            "<html>\n<head>\n"
            "<meta charset=\"utf-8\"></meta></head><body copyid='$copyId'>";
        String text = "";
        var copyElements = <WenElement>[];
        var startSubElement = start.block!
            .copyElement(start.textPosition!, start.block!.endPosition);
        copyElements.add(startSubElement);
        html += startSubElement.getHtml();
        text += startSubElement.getText();
        int startIndex =
            controller.blockManager.indexOfBlockByBlock(start.block!);
        int endIndex = controller.blockManager.indexOfBlockByBlock(end.block!);
        for (int i = startIndex + 1; i < endIndex; i++) {
          var element = controller.blockManager.blocks[i].element;
          copyElements.add(element);
          html += element.getHtml();
          text += "\n" + element.getText();
        }
        var endSubElement =
            end.block!.copyElement(end.block!.startPosition, end.textPosition!);
        copyElements.add(endSubElement);
        await copyService.saveCopyCache(copyElements, copyId: copyId);
        html += endSubElement.getHtml();
        text += "\n" + endSubElement.getText();
        html += "</body></html>";
        // RichClipboard.setData(RichClipboardData(html: html, text: text));
        final clipboard = SystemClipboard.instance;
        if (clipboard == null) {
          return;
        }
        final item = DataWriterItem();
        item.add(Formats.htmlText(html.toString()));
        item.add(Formats.plainText(text.toString()));
        await clipboard.write([item]);
      }
    }
  }
}
