import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class MoveGestureWidget extends StatefulWidget {
  final Widget child;
  final PointerMoveEventListener? onMove;

  const MoveGestureWidget({
    super.key,
    required this.child,
    this.onMove,
  });

  @override
  State<MoveGestureWidget> createState() => _MoveGestureWidgetState();
}

class _MoveGestureWidgetState extends State<MoveGestureWidget> {
  final _gestureRecognizer = ImmediateMultiDragGestureRecognizer();

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _gestureRecognizer.addPointer(event);
      },
      onPointerMove: (event) {
        widget.onMove?.call(event);
      },
      child: widget.child,
    );
  }
}
