import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  testWidgets('shape label painter supports drawio label positions', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    ShapeLabelPainter.paint(
      canvas,
      rect: const Rect.fromLTWH(0, 0, 120, 80),
      label: 'Top Left',
      style: ShapeLabelPainter.defaultStyle,
      textAlign: TextAlign.center,
      padding: EdgeInsets.zero,
      opacity: 1,
      labelPosition: 'left',
      verticalAlign: 'top',
    );

    final picture = recorder.endRecording();
    addTearDown(picture.dispose);
    expect(picture.approximateBytesUsed, greaterThan(0));
  });
}
