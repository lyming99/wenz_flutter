import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class MultiPlatformDraggable<T extends Object> extends StatelessWidget {
  const MultiPlatformDraggable({
    super.key,
    required this.child,
    required this.feedback,
    this.data,
    this.axis,
    this.childWhenDragging,
    this.feedbackOffset = Offset.zero,
    this.dragAnchorStrategy = childDragAnchorStrategy,
    this.affinity,
    this.maxSimultaneousDrags,
    this.onDragStarted,
    this.onDragUpdate,
    this.onDraggableCanceled,
    this.onDragEnd,
    this.onDragCompleted,
    this.ignoringFeedbackSemantics = true,
    this.ignoringFeedbackPointer = true,
    this.rootOverlay = false,
    this.hitTestBehavior = HitTestBehavior.deferToChild,
    this.allowedButtonsFilter,
    this.isLongDrag = false,
  });

  final bool isLongDrag;

  final T? data;

  final Axis? axis;

  final Widget child;

  final Widget? childWhenDragging;

  final Widget feedback;

  final Offset feedbackOffset;

  final DragAnchorStrategy dragAnchorStrategy;

  final bool ignoringFeedbackSemantics;

  final bool ignoringFeedbackPointer;

  final Axis? affinity;

  final int? maxSimultaneousDrags;

  final VoidCallback? onDragStarted;

  final DragUpdateCallback? onDragUpdate;

  final DraggableCanceledCallback? onDraggableCanceled;

  final VoidCallback? onDragCompleted;

  final DragEndCallback? onDragEnd;
  final bool rootOverlay;

  final HitTestBehavior hitTestBehavior;

  final AllowedButtonsFilter? allowedButtonsFilter;

  @override
  Widget build(BuildContext context) {
    if (isLongDrag) {
      return LongPressDraggable<T>(
        feedback: this.feedback,
        data: this.data,
        axis: this.axis,
        childWhenDragging: childWhenDragging,
        feedbackOffset: feedbackOffset,
        dragAnchorStrategy: dragAnchorStrategy,
        maxSimultaneousDrags: maxSimultaneousDrags,
        onDragStarted: onDragStarted,
        onDragUpdate: onDragUpdate,
        onDraggableCanceled: onDraggableCanceled,
        onDragEnd: onDragEnd,
        onDragCompleted: onDragCompleted,
        ignoringFeedbackSemantics: ignoringFeedbackSemantics,
        ignoringFeedbackPointer: ignoringFeedbackPointer,
        rootOverlay: rootOverlay,
        hitTestBehavior: hitTestBehavior,
        allowedButtonsFilter: allowedButtonsFilter,
        child: child,
      );
    }
    return Draggable<T>(
      feedback: this.feedback,
      data: this.data,
      axis: this.axis,
      childWhenDragging: childWhenDragging,
      feedbackOffset: feedbackOffset,
      dragAnchorStrategy: dragAnchorStrategy,
      affinity: affinity,
      maxSimultaneousDrags: maxSimultaneousDrags,
      onDragStarted: onDragStarted,
      onDragUpdate: onDragUpdate,
      onDraggableCanceled: onDraggableCanceled,
      onDragEnd: onDragEnd,
      onDragCompleted: onDragCompleted,
      ignoringFeedbackSemantics: ignoringFeedbackSemantics,
      ignoringFeedbackPointer: ignoringFeedbackPointer,
      rootOverlay: rootOverlay,
      hitTestBehavior: hitTestBehavior,
      allowedButtonsFilter: allowedButtonsFilter,
      child: child,
    );
  }
}
