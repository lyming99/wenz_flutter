import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/polyline_element.dart';
import '../infinite_canvas/canvas_event.dart';
import '../snap/snap_resolver.dart';
import '../routing/connector_routing.dart';
import '../utils/uuid_generator.dart';
import 'canvas_tool.dart';

class PolylineTool extends CanvasTool {
  PolylineTool();

  static const idValue = 'polyline';

  Offset? _start;
  Offset? _current;
  SnapResult? _startSnap;
  SnapResult? _currentSnap;

  @override
  String get id => idValue;

  @override
  String get name => 'Polyline';

  @override
  IconData get icon => Icons.account_tree_outlined;

  @override
  void cancel(CanvasController controller) {
    _start = null;
    _current = null;
    _startSnap = null;
    _currentSnap = null;
    controller.setSnapPreview(null);
  }

  @override
  ToolResult handleEvent(CanvasEvent event, CanvasController controller) {
    switch (event) {
      case CanvasPointerDownEvent():
        _startSnap = _resolveSnap(
          controller,
          event.worldPoint,
          event.transform.scale,
        );
        _start = _startSnap?.position ?? event.worldPoint;
        _currentSnap = _startSnap;
        _current = _start;
        controller.setSnapPreview(_currentSnap);
        return ToolResultPreview(_buildPreview(controller));
      case CanvasPointerMoveEvent():
        if (_start == null) {
          return const ToolResultNone();
        }
        _currentSnap = _resolveSnap(
          controller,
          event.worldPoint,
          event.transform.scale,
        );
        _current = _currentSnap?.position ?? event.worldPoint;
        controller.setSnapPreview(_currentSnap);
        return ToolResultPreview(_buildPreview(controller));
      case CanvasPointerUpEvent():
        final start = _start;
        final endSnap = _resolveSnap(
          controller,
          event.worldPoint,
          event.transform.scale,
        );
        final end = endSnap?.position ?? event.worldPoint;
        final startBinding = _startSnap?.binding;
        final endBinding = endSnap?.binding;
        cancel(controller);
        if (start == null || (start - end).distance < 1) {
          return const ToolResultNone();
        }
        return ToolResultElement(
          PolylineElement(
            id: UuidGenerator.create(),
            points: _route(
              controller,
              start,
              end,
              startBinding,
              endBinding,
              quality: controller.connectorRoutingOptions.finalQuality,
            ),
            style: controller.brushSettings.strokeStyle,
            startBinding: startBinding,
            endBinding: endBinding,
          ),
        );
      default:
        return const ToolResultNone();
    }
  }

  PolylineElement _buildPreview(CanvasController controller) {
    final start = _start ?? Offset.zero;
    final end = _current ?? start;
    return PolylineElement(
      id: '__preview_polyline__',
      points: _route(
        controller,
        start,
        end,
        _startSnap?.binding,
        _currentSnap?.binding,
        quality: controller.connectorRoutingOptions.finalQuality,
      ),
      style: controller.brushSettings.strokeStyle.copyWith(opacity: 0.72),
    );
  }

  List<Offset> _route(
    CanvasController controller,
    Offset start,
    Offset end,
    SnapBinding? startBinding,
    SnapBinding? endBinding, {
    ConnectorRouteQuality quality = ConnectorRouteQuality.high,
  }) {
    return controller.routeConnector(
      start: start,
      end: end,
      startBinding: startBinding,
      endBinding: endBinding,
      connectorId: '__preview_polyline__',
      quality: quality,
    );
  }

  SnapResult? _resolveSnap(
    CanvasController controller,
    Offset worldPoint,
    double scale,
  ) {
    return controller.snapResolver.resolve(
      controller,
      worldPoint,
      scale: scale,
    );
  }
}
