import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ZoomableWidget extends StatefulWidget {
  final Widget Function(BuildContext context, double scale) builder;
  final ValueChanged<double>? onChanged;

  const ZoomableWidget({
    super.key,
    required this.builder,
    this.onChanged,
  });

  @override
  State createState() => _ZoomableWidgetState();
}

class _ZoomableWidgetState extends State<ZoomableWidget> {
  double _scale = 1.0;
  bool isControl = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (PointerSignalEvent event) {
        if (event is PointerScrollEvent) {
          final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
          if (isCtrlPressed) {
            setState(() {
              _scale = (_scale + event.scrollDelta.dy * -0.01).clamp(0.8, 4.0);
            });
            widget.onChanged?.call(_scale);
          }
          if (isCtrlPressed != isControl) {
            setState(() {
              isControl = isCtrlPressed;
            });
          }
        }
      },
      child: widget.builder.call(context, _scale),
    );
  }
}
