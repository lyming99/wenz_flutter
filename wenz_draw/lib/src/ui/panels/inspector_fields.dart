import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

import '../theme/ui_colors.dart';

class FieldGrid extends StatelessWidget {
  const FieldGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.45,
      children: children,
    );
  }
}

class ReadoutField extends StatelessWidget {
  const ReadoutField({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final display = value == null ? '-' : value!.round().toString();
    return StaticField(label: label, value: display);
  }
}

class StaticField extends StatelessWidget {
  const StaticField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: UiColors.panelSoft,
              border: Border.all(color: UiColors.line),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: UiColors.text),
            ),
          ),
        ),
      ],
    );
  }
}

class ColorField extends StatelessWidget {
  const ColorField({required this.label, required this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: UiColors.panelSoft,
              border: Border.all(color: UiColors.line),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: color ?? Colors.white,
                border: Border.all(color: const Color(0x3318232E)),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ColorButtonField extends StatelessWidget {
  const ColorButtonField({
    required this.label,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final Color? color;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        const SizedBox(height: 6),
        Expanded(
          child: Material(
            color: UiColors.panelSoft,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: UiColors.line),
              borderRadius: BorderRadius.circular(7),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(7),
              onTap: enabled ? onPressed : null,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color ?? Colors.transparent,
                    border: Border.all(color: const Color(0x3318232E)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Center(
                    child: color == null
                        ? Icon(
                            Icons.format_color_reset_outlined,
                            size: 16,
                            color: enabled
                                ? UiColors.muted
                                : const Color(0xFFB8C2CC),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TextSwatchButton extends StatelessWidget {
  const TextSwatchButton({required this.color, this.onPressed});

  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: const Color(0x3318232E)),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class TextReadout extends StatefulWidget {
  const TextReadout({
    required this.selected,
    required this.onChanged,
    required this.onCommitted,
  });

  final CanvasElement? selected;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCommitted;

  @override
  State<TextReadout> createState() => _TextReadoutState();
}

class _TextReadoutState extends State<TextReadout> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _editingElementId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _textOf(widget.selected));
    _editingElementId = widget.selected?.id;
    _focusNode = FocusNode(debugLabel: 'TextReadout');
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      widget.onCommitted(_controller.text);
    }
  }

  @override
  void didUpdateWidget(covariant TextReadout oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextId = widget.selected?.id;
    final nextText = _textOf(widget.selected);
    // Don't clobber the controller while the user is actively typing.
    if (_focusNode.hasFocus && nextId == _editingElementId) {
      return;
    }
    if (nextId != _editingElementId || _controller.text != nextText) {
      _editingElementId = nextId;
      _controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('内容'),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.selected != null,
          minLines: 1,
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: UiColors.text),
          decoration: InputDecoration(
            hintText: widget.selected == null ? '未选择对象' : '输入文字内容',
            isDense: true,
            filled: true,
            fillColor: UiColors.panelSoft,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: UiColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: UiColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: Color(0xFF9FC4E8)),
            ),
          ),
          onSubmitted: (value) {
            widget.onCommitted(value);
            _focusNode.requestFocus();
          },
          onChanged: widget.onChanged,
        ),
      ],
    );
  }

  static String _textOf(CanvasElement? selected) {
    return switch (selected) {
      final TextElement e => e.text,
      final DrawioShapeElement e => e.label ?? '',
      final RectElement e => e.label ?? '',
      final EllipseElement e => e.label ?? '',
      final LineElement e => e.label ?? '',
      final ArrowElement e => e.label ?? '',
      final PolylineElement e => e.label ?? '',
      _ => '',
    };
  }
}

class AlignmentControl extends StatelessWidget {
  const AlignmentControl({required this.selected, required this.onChanged});

  final CanvasElement? selected;
  final ValueChanged<TextAlign> onChanged;

  TextAlign get _currentAlign {
    return switch (selected) {
      final TextElement e => e.textAlign,
      final DrawioShapeElement e => e.labelAlign,
      final RectElement e => e.labelAlign,
      final EllipseElement e => e.labelAlign,
      _ => TextAlign.center,
    };
  }

  @override
  Widget build(BuildContext context) {
    final align = _currentAlign;
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: UiColors.panelSoft,
        border: Border.all(color: UiColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: AlignSegment(
              label: '左',
              active: align == TextAlign.left,
              onTap: () => onChanged(TextAlign.left),
            ),
          ),
          Expanded(
            child: AlignSegment(
              label: '中',
              active: align == TextAlign.center,
              onTap: () => onChanged(TextAlign.center),
            ),
          ),
          Expanded(
            child: AlignSegment(
              label: '右',
              active: align == TextAlign.right,
              onTap: () => onChanged(TextAlign.right),
            ),
          ),
        ],
      ),
    );
  }
}

class AlignSegment extends StatelessWidget {
  const AlignSegment({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? UiColors.accent : UiColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class FontWeightDropdown extends StatelessWidget {
  const FontWeightDropdown({required this.selected, required this.onChanged});

  final CanvasElement? selected;
  final ValueChanged<FontWeight> onChanged;

  static const _weights = [
    (FontWeight.w100, '细'),
    (FontWeight.w300, '轻'),
    (FontWeight.w400, '常规'),
    (FontWeight.w500, '中等'),
    (FontWeight.w600, '半粗'),
    (FontWeight.w700, '粗体'),
    (FontWeight.w900, '特粗'),
  ];

  FontWeight get _currentWeight {
    final style = switch (selected) {
      final TextElement e => e.style,
      final DrawioShapeElement e => e.labelStyle,
      final RectElement e => e.labelStyle,
      final EllipseElement e => e.labelStyle,
      final LineElement e => e.labelStyle,
      final ArrowElement e => e.labelStyle,
      final PolylineElement e => e.labelStyle,
      _ => null,
    };
    return style?.fontWeight ?? FontWeight.w600;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentWeight;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: UiColors.panelSoft,
        border: Border.all(color: UiColors.line),
        borderRadius: BorderRadius.circular(7),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _weights.firstWhere((w) => w.$1 == current).$2,
          isExpanded: true,
          style: const TextStyle(fontSize: 14, color: UiColors.text),
          items: [
            for (final w in _weights)
              DropdownMenuItem(value: w.$2, child: Text(w.$2)),
          ],
          onChanged: selected == null
              ? null
              : (label) {
                  final weight =
                      _weights.firstWhere((w) => w.$2 == label).$1;
                  onChanged(weight);
                },
        ),
      ),
    );
  }
}

class SliderField extends StatelessWidget {
  const SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.fractionDigits = 0,
    this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int fractionDigits;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: UiColors.accent,
                  thumbColor: UiColors.accent,
                  inactiveTrackColor: UiColors.line,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: UiColors.panelSoft,
                border: Border.all(color: UiColors.line),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                value.toStringAsFixed(fractionDigits),
                style: const TextStyle(fontSize: 12, color: UiColors.text),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: UiColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class ColorSwatch extends StatelessWidget {
  const ColorSwatch({
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Container(
          width: 34,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(
              color: selected ? UiColors.accent : const Color(0x2918232E),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
