import 'package:flutter/material.dart';

import 'rgb_spectrum_picker.dart';

/// A color swatch used by [WenzRichTextColorPickerDialog].
class WenzRichTextColorDot extends StatelessWidget {
  const WenzRichTextColorDot({
    super.key,
    required this.color,
    required this.selected,
  });

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

/// Shared rich-text color picker used by desktop and mobile toolbars.
///
/// The dialog returns the selected [Color] when the user applies it and `null`
/// when it is cancelled or dismissed.
class WenzRichTextColorPickerDialog extends StatefulWidget {
  const WenzRichTextColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.swatches,
  });

  final Color initialColor;
  final List<Color> swatches;

  @override
  State<WenzRichTextColorPickerDialog> createState() =>
      _WenzRichTextColorPickerDialogState();
}

class _WenzRichTextColorPickerDialogState
    extends State<WenzRichTextColorPickerDialog> {
  late double _alpha;
  late double _hue;
  late double _saturation;
  late double _value;
  late final TextEditingController _hexController;

  Color get _color =>
      HSVColor.fromAHSV(_alpha, _hue, _saturation, _value).toColor();

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _alpha = hsv.alpha;
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('颜色选择器'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final color in widget.swatches)
                  InkResponse(
                    key: ValueKey<int>(color.toARGB32()),
                    radius: 14,
                    onTap: () => _setColor(color),
                    child: WenzRichTextColorDot(
                      color: color,
                      selected: color.toARGB32() == _color.toARGB32(),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            WenzRgbSpectrumPicker(
              hue: _hue,
              saturation: _saturation,
              value: _value,
              onChanged: _setSpectrumColor,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                WenzRichTextColorDot(color: _color, selected: true),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey<String>('wenz-color-hex-input'),
                    controller: _hexController,
                    decoration: const InputDecoration(
                      labelText: 'HEX',
                      prefixText: '#',
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: _setHex,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_color),
          child: const Text('应用'),
        ),
      ],
    );
  }

  void _setColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    setState(() {
      _alpha = hsv.alpha;
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
      _syncHexField();
    });
  }

  void _setSpectrumColor(double hue, double saturation, double value) {
    setState(() {
      _hue = hue;
      _saturation = saturation;
      _value = value;
      _syncHexField();
    });
  }

  void _setHex(String value) {
    final color = _parseHex(value);
    if (color == null) {
      return;
    }
    _setColor(color);
  }

  void _syncHexField() {
    final selection = _hexController.selection;
    final text = _hexFor(_color);
    _hexController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: selection.isValid
            ? selection.extentOffset.clamp(0, text.length)
            : text.length,
      ),
    );
  }

  static String _hexFor(Color color) {
    final argb = color.toARGB32();
    final alpha = (argb >> 24) & 0xFF;
    final value = alpha == 0xFF ? argb & 0xFFFFFF : argb;
    return value
        .toRadixString(16)
        .padLeft(alpha == 0xFF ? 6 : 8, '0')
        .toUpperCase();
  }

  static Color? _parseHex(String value) {
    var normalized = value.trim();
    if (normalized.startsWith('#')) {
      normalized = normalized.substring(1);
    } else if (normalized.toLowerCase().startsWith('0x')) {
      normalized = normalized.substring(2);
    }
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
