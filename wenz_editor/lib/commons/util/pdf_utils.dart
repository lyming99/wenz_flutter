import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

extension on InlineSpan? {
  toPdfTextSpan() {
    // todo 如果是公式，则需要增加公式支持
    return this is TextSpan ? toPdfTextSpan() : null;
  }
}

extension on TextSpan {
  pw.InlineSpan toPdfTextSpan() {
    return pw.TextSpan(
        text: text,
        style: pw.TextStyle(
          color: style?.color?.toPdfColor(),
          fontSize: style?.fontSize,
          fontWeight: style?.fontWeight?.toPdfFontWeight(),
          fontStyle: style?.fontStyle?.toPdfFontStyle(),
          decoration:
              style?.decoration?.toPdfDecoration() ?? pw.TextDecoration.none,
          decorationColor: style?.decorationColor?.toPdfColor(),
          decorationStyle: style?.decorationStyle?.toPdfDecorationStyle(),
          height: style?.height,
          letterSpacing: style?.letterSpacing,
          wordSpacing: style?.wordSpacing,
        ),
        children: [
          for (var child in children ?? []) child.toPdfTextSpan(),
        ]);
  }
}

extension on ui.TextDecorationStyle? {
  toPdfDecorationStyle() {
    return this == ui.TextDecorationStyle.solid
        ? pw.TextDecorationStyle.solid
        : pw.TextDecoration.none;
  }
}

extension on ui.FontWeight? {
  toPdfFontWeight() {
    return this == ui.FontWeight.bold
        ? pw.FontWeight.bold
        : pw.FontWeight.normal;
  }
}

extension on ui.FontStyle? {
  toPdfFontStyle() {
    return this == ui.FontStyle.italic
        ? pw.FontStyle.italic
        : pw.FontStyle.normal;
  }
}

extension on ui.TextDecoration? {
  pw.TextDecoration toPdfDecoration() {
    return this == ui.TextDecoration.underline
        ? pw.TextDecoration.underline
        : pw.TextDecoration.none;
  }
}

extension on IconData {
  pw.IconData toPdfIconData() {
    return pw.IconData(codePoint);
  }
}

extension on ui.Color {
  toPdfColor() {
    return PdfColor.fromInt(value);
  }
}

extension on Alignment {
  pw.Alignment toPdfElement() {
    return pw.Alignment(x, y);
  }
}
