import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  // ============================================================
  // CanvasWidgetElement 单元测试
  // ============================================================
  group('CanvasWidgetElement', () {
    test('creates with required fields', () {
      const element = CanvasWidgetElement(
        id: 'widget-1',
        worldRect: Rect.fromLTWH(100, 200, 300, 150),
        widgetType: 'test_type',
      );

      expect(element.id, 'widget-1');
      expect(element.type, 'widget');
      expect(element.worldRect, const Rect.fromLTWH(100, 200, 300, 150));
      expect(element.widgetType, 'test_type');
      expect(element.widgetData, isEmpty);
      expect(element.layerId, 'default');
      expect(element.visible, isTrue);
      expect(element.opacity, 1.0);
      expect(element.zIndex, 0);
      expect(element.isLocked, isFalse);
      expect(element.interactive, isTrue);
      expect(element.scaleMode, CanvasWidgetScaleMode.layoutScale);
    });

    test('bounds returns worldRect', () {
      const element = CanvasWidgetElement(
        id: 'w',
        worldRect: Rect.fromLTWH(10, 20, 30, 40),
        widgetType: 't',
      );

      expect(element.bounds, const Rect.fromLTWH(10, 20, 30, 40));
    });

    test('hitTest returns true for point inside rect', () {
      const element = CanvasWidgetElement(
        id: 'w',
        worldRect: Rect.fromLTWH(0, 0, 100, 100),
        widgetType: 't',
      );

      expect(element.hitTest(const Offset(50, 50)), isTrue);
      expect(element.hitTest(const Offset(0, 0)), isTrue);
      expect(element.hitTest(const Offset(100, 100)), isTrue);
    });

    test('hitTest returns false for point outside rect', () {
      const element = CanvasWidgetElement(
        id: 'w',
        worldRect: Rect.fromLTWH(0, 0, 100, 100),
        widgetType: 't',
      );

      expect(element.hitTest(const Offset(200, 200)), isFalse);
    });

    test('hitTest respects tolerance', () {
      const element = CanvasWidgetElement(
        id: 'w',
        worldRect: Rect.fromLTWH(0, 0, 100, 100),
        widgetType: 't',
      );

      // Just outside without tolerance
      expect(element.hitTest(const Offset(-1, 50), tolerance: 0), isFalse);
      // Just outside with tolerance
      expect(element.hitTest(const Offset(-1, 50), tolerance: 2), isTrue);
    });

    test('translate shifts worldRect', () {
      const element = CanvasWidgetElement(
        id: 'w',
        worldRect: Rect.fromLTWH(10, 20, 30, 40),
        widgetType: 't',
      );

      final translated = element.translate(const Offset(5, -3));

      expect(translated.worldRect, const Rect.fromLTWH(15, 17, 30, 40));
      expect(translated.id, element.id); // id unchanged
    });

    test('scaleElement scales around center', () {
      const element = CanvasWidgetElement(
        id: 'w',
        worldRect: Rect.fromLTWH(0, 0, 100, 100),
        widgetType: 't',
      );

      final scaled = element.scaleElement(2.0);

      expect(scaled.worldRect, const Rect.fromLTWH(-50, -50, 200, 200));
    });

    test('scaleElement scales around pivot', () {
      const element = CanvasWidgetElement(
        id: 'w',
        worldRect: Rect.fromLTWH(0, 0, 100, 100),
        widgetType: 't',
      );

      final scaled = element.scaleElement(2.0, pivot: Offset.zero);

      expect(scaled.worldRect, const Rect.fromLTWH(0, 0, 200, 200));
    });

    test('copyWith creates new instance with changed fields', () {
      const element = CanvasWidgetElement(
        id: 'w',
        worldRect: Rect.fromLTWH(0, 0, 100, 100),
        widgetType: 't',
      );

      final copied = element.copyWith(
        widgetData: {'key': 'value'},
        isLocked: true,
        interactive: false,
        minScreenSize: const Size(40, 30),
        maxScreenSize: const Size(400, 300),
      );

      expect(copied.widgetData, {'key': 'value'});
      expect(copied.isLocked, isTrue);
      expect(copied.interactive, isFalse);
      expect(copied.minScreenSize, const Size(40, 30));
      expect(copied.maxScreenSize, const Size(400, 300));
      // unchanged
      expect(copied.id, 'w');
      expect(copied.worldRect, const Rect.fromLTWH(0, 0, 100, 100));
    });

    test('operator == returns true for equal elements', () {
      const a = CanvasWidgetElement(
        id: 'w',
        worldRect: Rect.fromLTWH(0, 0, 100, 100),
        widgetType: 't',
      );
      const b = CanvasWidgetElement(
        id: 'w',
        worldRect: Rect.fromLTWH(0, 0, 100, 100),
        widgetType: 't',
      );

      expect(a, equals(b));
    });

    test('operator == returns false for different elements', () {
      const a = CanvasWidgetElement(
        id: 'w',
        worldRect: Rect.fromLTWH(0, 0, 100, 100),
        widgetType: 't',
      );
      const b = CanvasWidgetElement(
        id: 'w2',
        worldRect: Rect.fromLTWH(0, 0, 100, 100),
        widgetType: 't',
      );

      expect(a, isNot(equals(b)));
    });
  });

  // ============================================================
  // JSON 序列化/反序列化测试
  // ============================================================
  group('CanvasWidgetElement JSON serialization', () {
    test('toJson produces correct structure', () {
      const element = CanvasWidgetElement(
        id: 'widget-001',
        worldRect: Rect.fromLTWH(200, 150, 160, 60),
        widgetType: 'counter_button',
        widgetData: {'count': 5, 'label': '测试'},
        layerId: 'layer_1',
        visible: true,
        opacity: 0.8,
        zIndex: 10,
        isLocked: true,
        interactive: false,
        scaleMode: CanvasWidgetScaleMode.paintScale,
        minScreenSize: Size(40, 30),
        maxScreenSize: Size(400, 300),
      );

      final json = element.toJson();

      expect(json['id'], 'widget-001');
      expect(json['type'], 'widget');
      expect(json['widgetType'], 'counter_button');
      expect(json['layerId'], 'layer_1');
      expect(json['visible'], true);
      expect(json['opacity'], 0.8);
      expect(json['zIndex'], 10);
      expect(json['isLocked'], true);
      expect(json['interactive'], false);
      expect(json['scaleMode'], 'paintScale');
      expect(json['minScreenSize']['width'], 40);
      expect(json['minScreenSize']['height'], 30);
      expect(json['maxScreenSize']['width'], 400);
      expect(json['maxScreenSize']['height'], 300);
      expect(json['worldRect']['left'], 200);
      expect(json['worldRect']['top'], 150);
      expect(json['worldRect']['right'], 360);
      expect(json['worldRect']['bottom'], 210);
      expect(json['widgetData']['count'], 5);
      expect(json['widgetData']['label'], '测试');
    });

    test('fromJson deserializes correctly via CanvasSerializer', () {
      final json = {
        'id': 'widget-001',
        'type': 'widget',
        'widgetType': 'counter_button',
        'layerId': 'default',
        'visible': true,
        'opacity': 1.0,
        'zIndex': 5,
        'isLocked': false,
        'interactive': true,
        'scaleMode': 'layoutScale',
        'minScreenSize': {'width': 40, 'height': 30},
        'maxScreenSize': {'width': 400, 'height': 300},
        'worldRect': {'left': 100, 'top': 200, 'right': 300, 'bottom': 320},
        'widgetData': {'count': 42},
      };

      final element = CanvasSerializer.elementFromJson(json);

      expect(element, isA<CanvasWidgetElement>());
      final widget = element as CanvasWidgetElement;
      expect(widget.id, 'widget-001');
      expect(widget.widgetType, 'counter_button');
      expect(widget.worldRect, const Rect.fromLTRB(100, 200, 300, 320));
      expect(widget.widgetData['count'], 42);
      expect(widget.isLocked, isFalse);
      expect(widget.interactive, isTrue);
      expect(widget.scaleMode, CanvasWidgetScaleMode.layoutScale);
      expect(widget.minScreenSize, const Size(40, 30));
      expect(widget.maxScreenSize, const Size(400, 300));
    });

    test('fromJson with missing scaleMode defaults to layoutScale', () {
      final json = {
        'id': 'w1',
        'type': 'widget',
        'widgetType': 'test',
        'worldRect': {'left': 0, 'top': 0, 'right': 100, 'bottom': 100},
      };

      final element = CanvasSerializer.elementFromJson(json);

      expect(element, isA<CanvasWidgetElement>());
      expect(
        (element as CanvasWidgetElement).scaleMode,
        CanvasWidgetScaleMode.layoutScale,
      );
    });

    test('fromJson with unknown type returns fallback', () {
      final json = {'id': 'unknown', 'type': 'unknown_type'};

      final element = CanvasSerializer.elementFromJson(json);

      // Falls back to LineElement for unknown types
      expect(element, isA<LineElement>());
    });
  });

  // ============================================================
  // WidgetElementRegistry 测试
  // ============================================================
  group('WidgetElementRegistry', () {
    setUp(() {
      WidgetElementRegistry.clear();
    });

    test('register and getBuilder', () {
      const builder = _MockBuilder();
      WidgetElementRegistry.register('test_type', builder);

      expect(WidgetElementRegistry.getBuilder('test_type'), same(builder));
    });

    test('hasBuilder returns true after registration', () {
      WidgetElementRegistry.register('test_type', const _MockBuilder());

      expect(WidgetElementRegistry.hasBuilder('test_type'), isTrue);
    });

    test('hasBuilder returns false for unregistered type', () {
      expect(WidgetElementRegistry.hasBuilder('nonexistent'), isFalse);
    });

    test('unregister removes builder', () {
      WidgetElementRegistry.register('test_type', const _MockBuilder());
      WidgetElementRegistry.unregister('test_type');

      expect(WidgetElementRegistry.hasBuilder('test_type'), isFalse);
      expect(WidgetElementRegistry.getBuilder('test_type'), isNull);
    });

    test('register overwrites existing builder', () {
      const builder1 = _MockBuilder();
      const builder2 = _MockBuilder();
      WidgetElementRegistry.register('test_type', builder1);
      WidgetElementRegistry.register('test_type', builder2);

      expect(WidgetElementRegistry.getBuilder('test_type'), same(builder2));
    });

    test('registeredTypes returns all keys', () {
      WidgetElementRegistry.register('a', const _MockBuilder());
      WidgetElementRegistry.register('b', const _MockBuilder());

      final types = WidgetElementRegistry.registeredTypes.toSet();
      expect(types, containsAll(['a', 'b']));
    });

    test('clear removes all builders', () {
      WidgetElementRegistry.register('a', const _MockBuilder());
      WidgetElementRegistry.register('b', const _MockBuilder());
      WidgetElementRegistry.clear();

      expect(WidgetElementRegistry.registeredTypes, isEmpty);
    });
  });

  // ============================================================
  // CanvasWidgetBuildContext 测试
  // ============================================================
  group('CanvasWidgetBuildContext', () {
    test('stores provided values', () {
      final canvasController = CanvasController();
      final viewController = InfiniteCanvasController(
        canvasController: canvasController,
      );

      final ctx = CanvasWidgetBuildContext(
        canvasController: canvasController,
        viewController: viewController,
        selected: true,
        scale: 2.5,
        renderDetail: CanvasWidgetRenderDetail.thumbnail,
      );

      expect(ctx.canvasController, same(canvasController));
      expect(ctx.viewController, same(viewController));
      expect(ctx.selected, isTrue);
      expect(ctx.scale, 2.5);
      expect(ctx.renderDetail, CanvasWidgetRenderDetail.thumbnail);
    });
  });

  group('CanvasWidgetLayout', () {
    test('paint scale keeps world position and size proportional', () {
      const element = CanvasWidgetElement(
        id: 'w',
        worldRect: Rect.fromLTWH(10, 20, 100, 50),
        widgetType: 't',
        scaleMode: CanvasWidgetScaleMode.paintScale,
      );
      const transform = CanvasTransform(scale: 2, offset: Offset(5, 7));

      final layout = CanvasWidgetLayout.resolve(element, transform);

      expect(layout.screenRect, const Rect.fromLTWH(25, 47, 200, 100));
      expect(layout.layoutSize, const Size(100, 50));
      expect(layout.paintScale, 2);
    });

    test('fixed screen size follows world center without scaling size', () {
      const element = CanvasWidgetElement(
        id: 'w',
        worldRect: Rect.fromLTWH(10, 20, 100, 50),
        widgetType: 't',
        scaleMode: CanvasWidgetScaleMode.fixedScreenSize,
      );
      const transform = CanvasTransform(scale: 2, offset: Offset(5, 7));

      final layout = CanvasWidgetLayout.resolve(element, transform);

      expect(layout.screenRect, const Rect.fromLTWH(75, 72, 100, 50));
      expect(layout.layoutSize, const Size(100, 50));
      expect(layout.paintScale, 1);
    });

    test('min and max screen size constrain proportional scale', () {
      const minElement = CanvasWidgetElement(
        id: 'min',
        worldRect: Rect.fromLTWH(0, 0, 100, 50),
        widgetType: 't',
        minScreenSize: Size(80, 80),
      );
      const maxElement = CanvasWidgetElement(
        id: 'max',
        worldRect: Rect.fromLTWH(0, 0, 100, 50),
        widgetType: 't',
        maxScreenSize: Size(120, 120),
      );

      final minLayout = CanvasWidgetLayout.resolve(
        minElement,
        const CanvasTransform(scale: 0.2),
      );
      final maxLayout = CanvasWidgetLayout.resolve(
        maxElement,
        const CanvasTransform(scale: 4),
      );

      expect(minLayout.screenRect.size, const Size(160, 80));
      expect(minLayout.paintScale, 1.6);
      expect(minLayout.detail, CanvasWidgetRenderDetail.thumbnail);
      expect(maxLayout.screenRect.size, const Size(120, 60));
      expect(maxLayout.paintScale, 1.2);
      expect(maxLayout.detail, CanvasWidgetRenderDetail.thumbnail);
    });

    test('uses four render detail levels by screen size', () {
      const element = CanvasWidgetElement(
        id: 'w',
        worldRect: Rect.fromLTWH(0, 0, 100, 60),
        widgetType: 't',
      );

      expect(
        CanvasWidgetLayout.resolve(
          element,
          const CanvasTransform(scale: 0.1),
        ).detail,
        CanvasWidgetRenderDetail.color,
      );
      expect(
        CanvasWidgetLayout.resolve(
          element,
          const CanvasTransform(scale: 0.4),
        ).detail,
        CanvasWidgetRenderDetail.colorWithText,
      );
      expect(
        CanvasWidgetLayout.resolve(
          element,
          const CanvasTransform(scale: 1),
        ).detail,
        CanvasWidgetRenderDetail.thumbnail,
      );
      expect(
        CanvasWidgetLayout.resolve(
          element,
          const CanvasTransform(scale: 2),
        ).detail,
        CanvasWidgetRenderDetail.thumbnail,
      );
      expect(
        CanvasWidgetLayout.resolve(
          element,
          const CanvasTransform(scale: 3),
        ).detail,
        CanvasWidgetRenderDetail.full,
      );
    });
  });

  // ============================================================
  // CanvasWidgetScaleMode 枚举测试
  // ============================================================
  group('CanvasWidgetScaleMode', () {
    test('has all three modes', () {
      expect(CanvasWidgetScaleMode.values.length, 3);
      expect(
        CanvasWidgetScaleMode.values,
        containsAll([
          CanvasWidgetScaleMode.layoutScale,
          CanvasWidgetScaleMode.paintScale,
          CanvasWidgetScaleMode.fixedScreenSize,
        ]),
      );
    });
  });
}

/// Mock builder for testing registry
class _MockBuilder extends WidgetElementBuilder {
  const _MockBuilder();

  @override
  Widget build(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    return const SizedBox.shrink();
  }
}
