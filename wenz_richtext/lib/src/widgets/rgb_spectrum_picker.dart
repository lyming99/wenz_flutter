import 'package:flutter/material.dart';

import 'color_picker_painters.dart';

/// An HSV saturation/value spectrum paired with a hue slider.
class WenzRgbSpectrumPicker extends StatelessWidget {
  const WenzRgbSpectrumPicker({
    super.key,
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  static const double spectrumWidth = 240;
  static const double spectrumHeight = 150;
  static const double hueBarHeight = 18;

  final double hue;
  final double saturation;
  final double value;
  final void Function(double hue, double saturation, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('RGB spectrum', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        GestureDetector(
          key: const ValueKey<String>('wenz-color-sv-spectrum'),
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => _pickSaturationValue(details.localPosition),
          onPanUpdate: (details) => _pickSaturationValue(details.localPosition),
          child: SizedBox(
            width: spectrumWidth,
            height: spectrumHeight,
            child: CustomPaint(
              painter: WenzRgbSpectrumPainter(hue: hue),
              foregroundPainter: WenzSpectrumThumbPainter(
                x: saturation,
                y: 1 - value,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          key: const ValueKey<String>('wenz-color-hue-spectrum'),
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => _pickHue(details.localPosition),
          onPanUpdate: (details) => _pickHue(details.localPosition),
          child: SizedBox(
            width: spectrumWidth,
            height: hueBarHeight,
            child: CustomPaint(
              painter: const WenzHueBarPainter(),
              foregroundPainter: WenzHueThumbPainter(hue: hue),
            ),
          ),
        ),
      ],
    );
  }

  void _pickSaturationValue(Offset localPosition) {
    final nextSaturation =
        (localPosition.dx / spectrumWidth).clamp(0.0, 1.0).toDouble();
    final nextValue =
        (1 - localPosition.dy / spectrumHeight).clamp(0.0, 1.0).toDouble();
    onChanged(hue, nextSaturation, nextValue);
  }

  void _pickHue(Offset localPosition) {
    final nextHue =
        (localPosition.dx / spectrumWidth * 360).clamp(0.0, 360.0).toDouble();
    onChanged(nextHue, saturation, value);
  }
}
