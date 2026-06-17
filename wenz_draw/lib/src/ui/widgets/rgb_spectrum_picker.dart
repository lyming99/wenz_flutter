import 'package:flutter/material.dart';

import 'color_picker_painters.dart';

class RgbSpectrumPicker extends StatelessWidget {
  const RgbSpectrumPicker({
    super.key,
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  final double hue;
  final double saturation;
  final double value;
  final void Function(double hue, double saturation, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RGB spectrum', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        GestureDetector(
          onPanDown: (details) => _pickSv(details.localPosition),
          onPanUpdate: (details) => _pickSv(details.localPosition),
          child: SizedBox(
            width: 240,
            height: 150,
            child: CustomPaint(
              painter: RgbSpectrumPainter(hue: hue),
              foregroundPainter: SpectrumThumbPainter(
                x: saturation,
                y: 1 - value,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onPanDown: (details) => _pickHue(details.localPosition),
          onPanUpdate: (details) => _pickHue(details.localPosition),
          child: SizedBox(
            width: 240,
            height: 18,
            child: CustomPaint(
              painter: const HueBarPainter(),
              foregroundPainter: HueThumbPainter(hue: hue),
            ),
          ),
        ),
      ],
    );
  }

  void _pickSv(Offset localPosition) {
    final nextSaturation = (localPosition.dx / 240).clamp(0.0, 1.0).toDouble();
    final nextValue = (1 - localPosition.dy / 150).clamp(0.0, 1.0).toDouble();
    onChanged(hue, nextSaturation, nextValue);
  }

  void _pickHue(Offset localPosition) {
    final nextHue = (localPosition.dx / 240 * 360).clamp(0.0, 360.0).toDouble();
    onChanged(nextHue, saturation, value);
  }
}
