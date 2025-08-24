import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef OnLayout = void Function(Size realSize);

class ScrollContainer extends SingleChildRenderObjectWidget {
  const ScrollContainer({
    super.key,
    this.onLayout,
    required Widget super.child,
  });

  final OnLayout? onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderScrollContainer(onLayout: onLayout);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderScrollContainer renderObject) {
    renderObject.onLayout = onLayout;
    renderObject.markNeedsLayout();
  }
}

class RenderScrollContainer extends RenderProxyBox {
  OnLayout? onLayout;

  RenderScrollContainer({
    this.onLayout,
    RenderBox? child,
  });

  @override
  void performLayout() {
    super.performLayout();
    size = constraints.biggest;
    onLayout?.call(size);
  }
}
