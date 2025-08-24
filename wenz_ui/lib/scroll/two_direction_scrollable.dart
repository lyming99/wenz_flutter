import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'scroll_container.dart';

typedef ContentBuilder = Widget Function(
    BuildContext context, ViewportOffset xOffset, ViewportOffset yOffset);
typedef OnContentLayout = void Function(
    Size size, ViewportOffset xOffset, ViewportOffset yOffset);
typedef OnScrollZoomChanged = void Function(
    Offset eventOffset, double scrollDelta);

class TwoDirectionScrollable extends StatefulWidget {
  final OnContentLayout onLayout;
  final ContentBuilder? contentBuilder;
  final bool showScrollbar;
  final ScrollPhysics? scrollPhysics;
  final VoidCallback? onScrollUpdate;
  final ScrollController? horizontalController;

  final ScrollController? verticalController;
  final OnScrollZoomChanged? onScrollZoomChanged;

  const TwoDirectionScrollable({
    super.key,
    required this.onLayout,
    this.scrollPhysics,
    this.contentBuilder,
    this.onScrollUpdate,
    this.verticalController,
    this.horizontalController,
    this.showScrollbar = false,
    this.onScrollZoomChanged,
  });

  @override
  State<TwoDirectionScrollable> createState() => _TwoDirectionScrollableState();
}

class _TwoDirectionScrollableState extends State<TwoDirectionScrollable> {
  late ScrollController horizontalController;
  late ScrollController verticalController;
  StateSetter? contentState;
  ScrollPhysics? scrollPhysics;
  bool isCtrlDown = false;

  @override
  void initState() {
    super.initState();
    verticalController = widget.verticalController ?? ScrollController();
    horizontalController = widget.horizontalController ?? ScrollController();
    verticalController.addListener(onScroll);
    horizontalController.addListener(onScroll);
    HardwareKeyboard.instance.addHandler(handleEvent);
  }

  bool handleEvent(KeyEvent event) {
    if (HardwareKeyboard.instance.isControlPressed != isCtrlDown) {
      setState(() {
        isCtrlDown = HardwareKeyboard.instance.isControlPressed;
      });
    }
    return false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    scrollPhysics = widget.scrollPhysics ?? const SlowScrollPhysicals();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(handleEvent);
    verticalController.removeListener(onScroll);
    horizontalController.removeListener(onScroll);
    super.dispose();
  }

  void onScroll() {
    contentState?.call(() {});
    widget.onScrollUpdate?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if(isCtrlDown) {
          if (event is PointerScrollEvent) {
            widget.onScrollZoomChanged
                ?.call(event.localPosition, event.scrollDelta.dy);
          }
        }
      },
      child: Stack(
        children: [
          Scrollbar(
            controller: horizontalController,
            thumbVisibility: widget.showScrollbar,
            child: Scrollbar(
              controller: verticalController,
              thumbVisibility: widget.showScrollbar,
              child: TwoDimensionalScrollable(
                diagonalDragBehavior: DiagonalDragBehavior.free,
                horizontalDetails: ScrollableDetails.horizontal(
                    controller: horizontalController,
                    physics: isCtrlDown
                        ? const NeverScrollableScrollPhysics()
                        : scrollPhysics),
                verticalDetails: ScrollableDetails.vertical(
                    controller: verticalController,
                    physics: isCtrlDown
                        ? const NeverScrollableScrollPhysics()
                        : scrollPhysics),
                viewportBuilder: (BuildContext context,
                    ViewportOffset yPosition, ViewportOffset xPosition) {
                  return StatefulBuilder(builder: (context, state) {
                    contentState = state;
                    return ScrollContainer(
                      onLayout: (size) {
                        widget.onLayout.call(size, xPosition, yPosition);
                      },
                      child: RepaintBoundary(
                        child: widget.contentBuilder
                                ?.call(context, xPosition, yPosition) ??
                            Container(),
                      ),
                    );
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SlowScrollPhysicals extends BouncingScrollPhysics {
  const SlowScrollPhysicals({
    super.parent,
  });

  @override
  SlowScrollPhysicals applyTo(ScrollPhysics? ancestor) {
    return SlowScrollPhysicals(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    assert(offset != 0.0);
    assert(position.minScrollExtent <= position.maxScrollExtent);

    if (!position.outOfRange) {
      return offset;
    }

    final double overscrollPastStart =
        max(position.minScrollExtent - position.pixels, 0.0);
    final double overscrollPastEnd =
        max(position.pixels - position.maxScrollExtent, 0.0);
    final double overscrollPast = max(overscrollPastStart, overscrollPastEnd);
    final bool easing = (overscrollPastStart > 0.0 && offset < 0.0) ||
        (overscrollPastEnd > 0.0 && offset > 0.0);

    final double friction = easing
        // Apply less resistance when easing the overscroll vs tensioning.
        ? frictionFactor(
            (overscrollPast - offset.abs()) / position.viewportDimension)
        : frictionFactor(overscrollPast / position.viewportDimension);
    final double direction = offset.sign;

    if (easing) {
      return direction * offset.abs();
    }
    return direction * _applyFriction(overscrollPast, offset.abs(), friction);
  }

  static double _applyFriction(
      double extentOutside, double absDelta, double gamma) {
    assert(absDelta > 0);
    double total = 0.0;
    if (extentOutside > 0) {
      final double deltaToLimit = extentOutside / gamma;
      if (absDelta < deltaToLimit) {
        return absDelta * gamma;
      }
      total += extentOutside;
      absDelta -= deltaToLimit;
    }
    return total + absDelta;
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    var maxValue = 2000.0;
    if (velocity > maxValue) {
      velocity = maxValue;
    }
    if (velocity < -maxValue) {
      velocity = -maxValue;
    }
    var simulation = super.createBallisticSimulation(position, velocity);
    if (simulation is BouncingScrollSimulation) {
      return BouncingScrollSimulation(
          position: position.pixels,
          velocity: velocity,
          leadingExtent: position.minScrollExtent,
          trailingExtent: position.maxScrollExtent,
          tolerance: simulation.tolerance,
          spring: spring,
          constantDeceleration: 700);
    }
    return simulation;
  }
}
