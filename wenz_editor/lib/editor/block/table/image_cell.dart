import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wenz_editor/commons/widget/popup_stack.dart';
import 'package:wenz_editor/editor/block/image/image_block.dart';
import '../../edit_controller.dart';
import '../../utils/popup_utils.dart';
import 'table_block.dart';
import 'table_cell.dart';

class ImageTableCell extends ImageBlock with TableBaseCell {
  double maxCellImageWidth = 400;

  ImageTableCell({
    required super.context,
    required super.element,
    required super.editController,
    required TableBlock tableBlock,
  }) {
    this.tableBlock = tableBlock;
  }

  @override
  bool get isFocusBlock =>
      tableBlock.isFocusBlock &&
      this ==
          tableBlock.getCell(
              editController.cursorState.cursorPosition?.textPosition?.offset ??
                  0);

  @override
  void updateImageSize(double deltaX, double deltaY) {
    relayoutFlag = true;
    super.updateImageSize(deltaX, deltaY);
  }

  @override
  List<PopupPositionWidget> buildFloatWidgets() {
    if (!isFocusBlock) {
      return [];
    }
    var textPosition = editController.cursorState.cursorPosition?.textPosition;
    if (textPosition == null) {
      return [];
    }
    // 1.得到cell的rowIndex和colIndex
    // 2.得到cell的偏移位置
    // 3.计算工具栏偏移位置
    var rowIndex = tableBlock.getRowIndex(textPosition.offset);
    var colIndex = tableBlock.getColIndex(rowIndex, textPosition.offset);
    if (rowIndex == -1 || colIndex == -1) {
      return [];
    }
    var offset = Offset(
        -tableBlock.getColumnLeft(colIndex) -
            tableBlock.getCellColLeftOffset(rowIndex, colIndex) +
            tableBlock.horizontalOffset,
        tableBlock.getRowTop(rowIndex) +
            tableBlock.getCellRowTopOffset(rowIndex, colIndex));
    offset += Offset(tableBlock.width - width, 0);
    var floatWidgets = super.buildFloatWidgets();
    return PopupUtils.translatePopupPositionWidget(
        floatWidgets, offset.dx, offset.dy);
  }

  PopupPositionWidget translateToCellPosition(
      PopupPositionWidget item, Offset offset) {
    return item;
  }

  @override
  Alignment calcAlignment({String? alignment}) {
    var rowIndex = tableBlock.getRowIndex(offset);
    var colIndex = tableBlock.getColIndex(rowIndex, offset);
    var alignType = tableBlock.getColAlignment(colIndex);
    return super.calcAlignment(alignment: alignType);
  }

  @override
  bool get isSelected =>
      tableBlock.selected &&
      (tableBlock.selectedStart?.offset ?? 0) <= offset &&
      (tableBlock.selectedEnd?.offset ?? 0) >= offset + 1;

  @override
  void calcOriginSize(BuildContext context) {
    var mq = MediaQuery.of(context);
    var ratio = mq.devicePixelRatio;
    if (ratio <= 0) {
      ratio = 1;
    }
    var w = element.width;
    var h = element.height;
    var viewMaxImageHeight = (maxCellImageWidth - padding * 2) * h / w;
    var maxImageHeight = viewMaxImageHeight;
    var imageHeight = h / ratio;
    imageHeight = min(element.showHeight ?? imageHeight, imageHeight);
    if (imageHeight < maxImageHeight) {
      height = imageHeight + padding * 2;
    } else {
      imageHeight = maxImageHeight;
      height = maxImageHeight + padding * 2;
    }
    originWidth = imageHeight * w / h;
    originHeight = imageHeight;
  }

  @override
  Rect? getCursorRect(TextPosition textPosition) {
    var rowIndex = tableBlock.getRowIndex(textPosition.offset);
    var colIndex = tableBlock.getColIndex(rowIndex, textPosition.offset);
    var alignType = tableBlock.getColAlignment(colIndex);
    var alignment = calcAlignment(alignment: alignType);
    var offset = calcAlignmentOffset(Size(imageWidth, imageHeight), alignment);
    if (delete || textPosition.offset == 0) {
      return Rect.fromLTWH(
          offset.dx + padding - 1, offset.dy + padding, 1, imageHeight);
    } else {
      return Rect.fromLTWH(imageWidth + offset.dx + padding - 1,
          offset.dy + padding, 1, imageHeight);
    }
  }
}
