import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class CustomDraggable<T extends Object> extends Draggable<T> {
  const CustomDraggable({
    super.key,
    required super.child,
    required super.feedback,
    super.data,
    super.axis,
    super.childWhenDragging,
    super.feedbackOffset = Offset.zero,
    super.dragAnchorStrategy = childDragAnchorStrategy,
    super.affinity,
    super.maxSimultaneousDrags,
    super.onDragStarted,
    super.onDragUpdate,
    super.onDraggableCanceled,
    super.onDragEnd,
    super.onDragCompleted,
    super.ignoringFeedbackSemantics = true,
    super.ignoringFeedbackPointer = true,
    super.rootOverlay = false,
    super.hitTestBehavior = HitTestBehavior.deferToChild,
    super.allowedButtonsFilter,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(
      GestureMultiDragStartCallback onStart) {
    return CustomMultiDragGestureRecognizer(
        allowedButtonsFilter: allowedButtonsFilter)
      ..onStart = onStart;
  }
}

class CustomMultiDragGestureRecognizer extends MultiDragGestureRecognizer {
  /// Create a gesture recognizer for tracking multiple pointers at once.
  ///
  /// {@macro flutter.gestures.GestureRecognizer.supportedDevices}
  CustomMultiDragGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) {
    return _CustomPointerState(event.position, event.kind, gestureSettings);
  }

  @override
  String get debugDescription => 'multidrag';
}

class _CustomPointerState extends MultiDragPointerState {
  _CustomPointerState(
    super.initialPosition,
    super.kind,
    super.gestureSettings,
  );

  @override
  void checkForResolutionAfterMove() {
    assert(pendingDelta != null);
    if (pendingDelta!.dx.abs() > computeHitSlop(kind, gestureSettings)) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}
