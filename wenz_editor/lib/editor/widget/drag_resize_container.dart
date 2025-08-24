import 'package:flutter/material.dart';
import 'package:wenz_editor/commons/widget/ignore_parent_pointer.dart';

import 'move_gesture_widget.dart';

typedef OnResized = void Function(double deltaX, double deltaY);

class DragResizeContainer extends StatefulWidget {
  final Widget child;
  final double strokeWidth;
  final OnResized? onResized;

  const DragResizeContainer({
    super.key,
    required this.child,
    this.onResized,
    this.strokeWidth = 10,
  });

  @override
  State<DragResizeContainer> createState() => _DragResizeContainerState();
}

class _DragResizeContainerState extends State<DragResizeContainer> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.all(widget.strokeWidth / 2),
          child: widget.child,
        ),
        // left
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: widget.strokeWidth,
          child: IgnoreParentPointer(
            child: MoveGestureWidget(
              onMove: (details) {
                widget.onResized?.call(-details.delta.dx, 0);
                if (context.mounted) {
                  setState(() {});
                }
              },
              child: const MouseRegion(
                hitTestBehavior: HitTestBehavior.translucent,
                cursor: SystemMouseCursors.resizeLeftRight,
              ),
            ),
          ),
        ),
        // top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: widget.strokeWidth,
          child: IgnoreParentPointer(
            child: MoveGestureWidget(
              onMove: (details) {
                widget.onResized?.call(0, -details.delta.dy);
                if (context.mounted) {
                  setState(() {});
                }
              },
              child: const MouseRegion(
                hitTestBehavior: HitTestBehavior.translucent,
                cursor: SystemMouseCursors.resizeUpDown,
              ),
            ),
          ),
        ),
        // right
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: widget.strokeWidth,
          child: IgnoreParentPointer(
            child: MoveGestureWidget(
              onMove: (details) {
                widget.onResized?.call(details.delta.dx, 0);
                if (context.mounted) {
                  setState(() {});
                }
              },
              child: const MouseRegion(
                hitTestBehavior: HitTestBehavior.translucent,
                cursor: SystemMouseCursors.resizeLeftRight,
              ),
            ),
          ),
        ),

        // bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: widget.strokeWidth,
          child: MoveGestureWidget(
            onMove: (details) {
              widget.onResized?.call(0, details.delta.dy);
              if (context.mounted) {
                setState(() {});
              }
            },
            child: const MouseRegion(
              hitTestBehavior: HitTestBehavior.translucent,
              cursor: SystemMouseCursors.resizeUpDown,
            ),
          ),
        ),
        // left top
        Positioned(
          top: 0,
          left: 0,
          width: widget.strokeWidth,
          height: widget.strokeWidth,
          child: IgnoreParentPointer(
            child: MoveGestureWidget(
              onMove: (details) {
                widget.onResized?.call(-details.delta.dx, -details.delta.dy);
                if (context.mounted) {
                  setState(() {});
                }
              },
              child: const MouseRegion(
                hitTestBehavior: HitTestBehavior.translucent,
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
              ),
            ),
          ),
        ),
        // right top
        Positioned(
          top: 0,
          right: 0,
          width: widget.strokeWidth,
          height: widget.strokeWidth,
          child: IgnoreParentPointer(
            child: MoveGestureWidget(
              onMove: (details) {
                widget.onResized?.call(details.delta.dx, -details.delta.dy);
                if (context.mounted) {
                  setState(() {});
                }
              },
              child: const MouseRegion(
                hitTestBehavior: HitTestBehavior.translucent,
                cursor: SystemMouseCursors.resizeUpRightDownLeft,
              ),
            ),
          ),
        ),
        // left bottom
        Positioned(
          bottom: 0,
          left: 0,
          width: widget.strokeWidth,
          height: widget.strokeWidth,
          child: IgnoreParentPointer(
            child: MoveGestureWidget(
              onMove: (details) {
                widget.onResized?.call(-details.delta.dx, details.delta.dy);
                if (context.mounted) {
                  setState(() {});
                }
              },
              child: const MouseRegion(
                hitTestBehavior: HitTestBehavior.translucent,
                cursor: SystemMouseCursors.resizeUpRightDownLeft,
              ),
            ),
          ),
        ),
        // right bottom
        Positioned(
          bottom: 0,
          right: 0,
          width: widget.strokeWidth,
          height: widget.strokeWidth,
          child: IgnoreParentPointer(
            child: MoveGestureWidget(
              onMove: (details) {
                widget.onResized?.call(details.delta.dx, details.delta.dy);
                if (context.mounted) {
                  setState(() {});
                }
              },
              child: const MouseRegion(
                hitTestBehavior: HitTestBehavior.translucent,
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void onResizePanStart(DragStartDetails details) {
    ResizeStateNotification(true).dispatch(context);
  }

  void onResizePanEnd(DragEndDetails details) {
    onResizePanCancel();
  }

  void onResizePanCancel() {
    ResizeStateNotification(false).dispatch(context);
  }
}

class ResizeStateNotification extends Notification {
  final bool resizing;

  ResizeStateNotification(this.resizing);
}
