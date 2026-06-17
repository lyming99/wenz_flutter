import 'package:flutter/material.dart';

import 'rgb_spectrum_picker.dart';

class ColorDot extends StatelessWidget {
  const ColorDot({super.key, required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: selected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
          width: selected ? 2.5 : 1.5,
        ),
      ),
      child: const SizedBox.square(dimension: 22),
    );
  }
}

class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.swatches,
  });

  final Color initialColor;
  final List<Color> swatches;

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _hexController = TextEditingController(text: _hexFor(_color));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _color => HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('颜色选择器'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in widget.swatches)
                  InkResponse(
                    radius: 14,
                    onTap: () => _setColor(color),
                    child: ColorDot(color: color, selected: color == _color),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            RgbSpectrumPicker(
              hue: _hue,
              saturation: _saturation,
              value: _value,
              onChanged: _setSpectrumColor,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ColorDot(color: _color, selected: true),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    decoration: const InputDecoration(
                      labelText: 'HEX',
                      prefixText: '#',
                      isDense: true,
                    ),
                    onChanged: _setHex,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('应用'),
        ),
      ],
    );
  }

  void _setColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    setState(() {
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
      _hexController.text = _hexFor(_color);
    });
  }

  void _setSpectrumColor(double hue, double saturation, double value) {
    setState(() {
      _hue = hue;
      _saturation = saturation;
      _value = value;
      _hexController.text = _hexFor(_color);
    });
  }

  void _setHex(String value) {
    final color = _parseHex(value);
    if (color != null) {
      _setColor(color);
    }
  }

  static String _hexFor(Color color) {
    return (color.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
  }

  static Color? _parseHex(String value) {
    final normalized = value.replaceAll('#', '').trim();
    if (normalized.length != 6 && normalized.length != 8) {
      return null;
    }
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) {
      return null;
    }
    return Color(normalized.length == 6 ? 0xFF000000 | parsed : parsed);
  }
}
