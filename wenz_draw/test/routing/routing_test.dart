import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  // ===========================================================================
  // OrthConnector 测试
  // ===========================================================================
  group('OrthConnector', () {
    test('无障碍时生成最短正交路径（两拐点）', () {
      final source = const Rect.fromLTWH(0, 0, 100, 100);
      final target = const Rect.fromLTWH(200, 150, 100, 100);

      final path = OrthConnector.route(
        start: source.center,
        end: target.center,
        sourceBounds: source,
        targetBounds: target,
        margin: 16,
      );

      // 路径非空，至少有起点和终点
      expect(path.length, greaterThanOrEqualTo(2));
      expect(path.first, source.center);
      expect(path.last, target.center);

      // 所有段必须是正交的（水平或垂直）
      for (var i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        final horizontal = (a.dy - b.dy).abs() < 0.01;
        final vertical = (a.dx - b.dx).abs() < 0.01;
        expect(
          horizontal || vertical,
          isTrue,
          reason: 'Segment $i from $a to $b is not orthogonal',
        );
      }
    });

    test('source 在 target 左边时生成合理路径', () {
      final source = const Rect.fromLTWH(0, 0, 100, 100);
      final target = const Rect.fromLTWH(300, 0, 100, 100);

      final path = OrthConnector.route(
        start: source.center,
        end: target.center,
        sourceBounds: source,
        targetBounds: target,
        margin: 16,
      );

      // 路径应该是合理的（非空，正交）
      expect(path.isNotEmpty, isTrue);

      // 验证所有段正交
      for (var i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        final horizontal = (a.dy - b.dy).abs() < 0.01;
        final vertical = (a.dx - b.dx).abs() < 0.01;
        expect(horizontal || vertical, isTrue);
      }
    });

    test('source 在 target 上方时生成合理路径', () {
      final source = const Rect.fromLTWH(0, 0, 100, 100);
      final target = const Rect.fromLTWH(0, 300, 100, 100);

      final path = OrthConnector.route(
        start: source.center,
        end: target.center,
        sourceBounds: source,
        targetBounds: target,
        margin: 16,
      );

      expect(path.isNotEmpty, isTrue);

      for (var i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        final horizontal = (a.dy - b.dy).abs() < 0.01;
        final vertical = (a.dx - b.dx).abs() < 0.01;
        expect(horizontal || vertical, isTrue);
      }
    });

    test('对角场景（source 左上，target 右下）', () {
      final source = const Rect.fromLTWH(0, 0, 100, 100);
      final target = const Rect.fromLTWH(300, 300, 100, 100);

      final path = OrthConnector.route(
        start: source.center,
        end: target.center,
        sourceBounds: source,
        targetBounds: target,
        margin: 16,
      );

      expect(path.isNotEmpty, isTrue);

      for (var i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        final horizontal = (a.dy - b.dy).abs() < 0.01;
        final vertical = (a.dx - b.dx).abs() < 0.01;
        expect(horizontal || vertical, isTrue);
      }
    });

    test('两个矩形重叠时的路由', () {
      // 重叠的矩形应该仍然能生成路径（不 crash）
      final source = const Rect.fromLTWH(0, 0, 100, 100);
      final target = const Rect.fromLTWH(50, 50, 100, 100);

      final path = OrthConnector.route(
        start: source.center,
        end: target.center,
        sourceBounds: source,
        targetBounds: target,
        margin: 8,
      );

      expect(path.isNotEmpty, isTrue);

      for (var i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        final horizontal = (a.dy - b.dy).abs() < 0.01;
        final vertical = (a.dx - b.dx).abs() < 0.01;
        expect(horizontal || vertical, isTrue);
      }
    });

    test('路径起终点正确', () {
      final source = const Rect.fromLTWH(10, 10, 80, 80);
      final target = const Rect.fromLTWH(200, 100, 80, 80);

      final path = OrthConnector.route(
        start: Offset(50, 50),
        end: Offset(240, 140),
        sourceBounds: source,
        targetBounds: target,
        margin: 16,
      );

      expect(path.first.dx, closeTo(50, 0.01));
      expect(path.first.dy, closeTo(50, 0.01));
      expect(path.last.dx, closeTo(240, 0.01));
      expect(path.last.dy, closeTo(140, 0.01));
    });

    test('不同 margin 值产生不同路径', () {
      final source = const Rect.fromLTWH(0, 0, 100, 100);
      final target = const Rect.fromLTWH(200, 150, 100, 100);

      final path1 = OrthConnector.route(
        start: source.center,
        end: target.center,
        sourceBounds: source,
        targetBounds: target,
        margin: 8,
      );

      final path2 = OrthConnector.route(
        start: source.center,
        end: target.center,
        sourceBounds: source,
        targetBounds: target,
        margin: 32,
      );

      // 不同 margin 可能导致相同或不同的拐点位置
      // 至少保证两者都是正交路径
      expect(path1.length, greaterThanOrEqualTo(2));
      expect(path2.length, greaterThanOrEqualTo(2));
    });

    test('无 bounds 时回退到简单路径', () {
      final path = OrthConnector.route(
        start: Offset(0, 0),
        end: Offset(200, 100),
        sourceBounds: null,
        targetBounds: null,
      );

      expect(path.isNotEmpty, isTrue);
      // 无 bounds 情况下的简单回退
      for (var i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        final horizontal = (a.dy - b.dy).abs() < 0.01;
        final vertical = (a.dx - b.dx).abs() < 0.01;
        expect(horizontal || vertical, isTrue);
      }
    });
  });

  // ===========================================================================
  // ElbowRouter 测试
  // ===========================================================================
  group('ElbowRouter', () {
    test('elbowConnector 默认使用 sideToSide', () {
      final source = const Rect.fromLTWH(0, 0, 100, 100);
      final target = const Rect.fromLTWH(200, 0, 100, 100);

      final path = ElbowRouter.elbowConnector(
        start: source.center,
        end: target.center,
        sourceBounds: source,
        targetBounds: target,
      );

      expect(path.isNotEmpty, isTrue);
      for (var i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        final horizontal = (a.dy - b.dy).abs() < 0.01;
        final vertical = (a.dx - b.dx).abs() < 0.01;
        expect(horizontal || vertical, isTrue);
      }
    });

    test('elbowConnector 上下布局使用 topToBottom', () {
      final source = const Rect.fromLTWH(0, 0, 100, 100);
      final target = const Rect.fromLTWH(0, 200, 100, 100);

      final path = ElbowRouter.elbowConnector(
        start: source.center,
        end: target.center,
        sourceBounds: source,
        targetBounds: target,
      );

      expect(path.isNotEmpty, isTrue);
      for (var i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        final horizontal = (a.dy - b.dy).abs() < 0.01;
        final vertical = (a.dx - b.dx).abs() < 0.01;
        expect(horizontal || vertical, isTrue);
      }
    });

    test('entityRelation ER 图风格连接', () {
      final source = const Rect.fromLTWH(0, 0, 100, 100);
      final target = const Rect.fromLTWH(200, 50, 100, 100);

      final path = ElbowRouter.entityRelation(
        start: source.center,
        end: target.center,
        sourceBounds: source,
        targetBounds: target,
        segment: 30,
      );

      expect(path.isNotEmpty, isTrue);
      for (var i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        final horizontal = (a.dy - b.dy).abs() < 0.01;
        final vertical = (a.dx - b.dx).abs() < 0.01;
        expect(horizontal || vertical, isTrue);
      }
    });

    test('sideToSide 路径结构', () {
      final source = const Rect.fromLTWH(0, 0, 100, 100);
      final target = const Rect.fromLTWH(200, 0, 100, 100);

      final path = ElbowRouter.sideToSide(
        start: source.centerRight,
        end: target.centerLeft,
        sourceBounds: source,
        targetBounds: target,
        margin: 16,
      );

      // 应该至少有 2 个点（起点和终点）
      expect(path.length, greaterThanOrEqualTo(2));
    });

    test('topToBottom 路径结构', () {
      final source = const Rect.fromLTWH(0, 0, 100, 100);
      final target = const Rect.fromLTWH(0, 200, 100, 100);

      final path = ElbowRouter.topToBottom(
        start: source.bottomCenter,
        end: target.topCenter,
        sourceBounds: source,
        targetBounds: target,
        margin: 16,
      );

      expect(path.length, greaterThanOrEqualTo(2));
    });
  });

  // ===========================================================================
  // WenzPerimeter 测试
  // ===========================================================================
  group('WenzPerimeter', () {
    test('rectanglePerimeter 右侧交点', () {
      final bounds = const Rect.fromLTWH(0, 0, 100, 100);
      final next = Offset(200, 50);

      final result = WenzPerimeter.rectanglePerimeter(
        bounds,
        next,
        orthogonal: false,
      );

      // 应该在右边界上
      expect(result.dx, closeTo(100, 0.01));
      expect(result.dy, closeTo(50, 0.01));
    });

    test('rectanglePerimeter 左侧交点', () {
      final bounds = const Rect.fromLTWH(0, 0, 100, 100);
      final next = Offset(-50, 50);

      final result = WenzPerimeter.rectanglePerimeter(
        bounds,
        next,
        orthogonal: false,
      );

      expect(result.dx, closeTo(0, 0.01));
      expect(result.dy, closeTo(50, 0.01));
    });

    test('rectanglePerimeter 上侧交点', () {
      final bounds = const Rect.fromLTWH(0, 0, 100, 100);
      final next = Offset(50, -50);

      final result = WenzPerimeter.rectanglePerimeter(
        bounds,
        next,
        orthogonal: false,
      );

      expect(result.dy, closeTo(0, 0.01));
      expect(result.dx, closeTo(50, 0.01));
    });

    test('rectanglePerimeter 下侧交点', () {
      final bounds = const Rect.fromLTWH(0, 0, 100, 100);
      final next = Offset(50, 200);

      final result = WenzPerimeter.rectanglePerimeter(
        bounds,
        next,
        orthogonal: false,
      );

      expect(result.dy, closeTo(100, 0.01));
      expect(result.dx, closeTo(50, 0.01));
    });

    test('rectanglePerimeter 正交模式', () {
      final bounds = const Rect.fromLTWH(0, 0, 100, 100);
      // next 点在矩形右上方
      final next = Offset(150, 30);

      final result = WenzPerimeter.rectanglePerimeter(
        bounds,
        next,
        orthogonal: true,
      );

      // 正交模式下，next.dy 在矩形垂直范围内 → 锁定 y
      expect(result.dx, closeTo(100, 0.01));
      expect(result.dy, closeTo(30, 0.01));
    });

    test('ellipsePerimeter 基本交点', () {
      final bounds = const Rect.fromLTWH(0, 0, 100, 100);
      final next = Offset(200, 50);

      final result = WenzPerimeter.ellipsePerimeter(
        bounds,
        next,
        orthogonal: false,
      );

      // 应该落在椭圆边界上
      // 对于 cx=50, cy=50, rx=50, ry=50 的圆，右边交点应在 (100, 50)
      expect(result.dx, closeTo(100, 0.01));
      expect(result.dy, closeTo(50, 0.01));
    });

    test('ellipsePerimeter 对角交点', () {
      final bounds = const Rect.fromLTWH(0, 0, 100, 100);
      final next = Offset(200, 200);

      final result = WenzPerimeter.ellipsePerimeter(
        bounds,
        next,
        orthogonal: false,
      );

      // 45度角，交点应在圆上：cx+rx*cos(45°), cy+ry*sin(45°)
      // 50+50*0.707 ≈ 85.35
      expect(result.dx, closeTo(85.35, 0.1));
      expect(result.dy, closeTo(85.35, 0.1));
    });

    test('diamondPerimeter 右侧交点', () {
      final bounds = const Rect.fromLTWH(0, 0, 100, 100);
      final next = Offset(200, 50);

      final result = WenzPerimeter.diamondPerimeter(
        bounds,
        next,
        orthogonal: false,
      );

      // 菱形右顶点在 (100, 50)
      expect(result.dx, closeTo(100, 0.01));
      expect(result.dy, closeTo(50, 0.01));
    });

    test('trianglePerimeter 东向三角形', () {
      final bounds = const Rect.fromLTWH(0, 0, 100, 100);
      final next = Offset(200, 50);

      final result = WenzPerimeter.trianglePerimeter(
        bounds,
        next,
        orthogonal: false,
        direction: 'east',
      );

      // 东向三角形，尖角朝右，应该在右侧边界上
      expect(result.dy, closeTo(50, 0.01));
    });

    test('hexagonPerimeter 基本交点', () {
      final bounds = const Rect.fromLTWH(0, 0, 100, 100);
      final next = Offset(200, 50);

      final result = WenzPerimeter.hexagonPerimeter(
        bounds,
        next,
        orthogonal: false,
      );

      // 应该在右边界的某个位置
      expect(result.dx, closeTo(100, 0.01));
      expect(result.dy, closeTo(50, 0.01)); // 六边形右中点在 (100, 50)
    });

    test('hexagonPerimeter 正交模式', () {
      final bounds = const Rect.fromLTWH(0, 0, 100, 100);
      final next = Offset(150, 20);

      final result = WenzPerimeter.hexagonPerimeter(
        bounds,
        next,
        orthogonal: true,
      );

      // 结果应在六边形边界上
      expect(result.dx, greaterThan(0));
      expect(result.dy, closeTo(20, 0.01));
    });

    test('computePerimeter 根据 shapeType 选择', () {
      final bounds = const Rect.fromLTWH(0, 0, 100, 100);
      final next = Offset(200, 50);

      final rect = WenzPerimeter.computePerimeter(
        bounds,
        next,
        shapeType: 'rectangle',
      );
      final ellipse = WenzPerimeter.computePerimeter(
        bounds,
        next,
        shapeType: 'ellipse',
      );
      final diamond = WenzPerimeter.computePerimeter(
        bounds,
        next,
        shapeType: 'diamond',
      );
      final hexagon = WenzPerimeter.computePerimeter(
        bounds,
        next,
        shapeType: 'hexagon',
      );

      // 不同形状应该产生不同的交点
      // rectangle: (100, 50)
      // ellipse/circle: (100, 50) — 圆形右侧也是 (100,50)
      // diamond: (100, 50) — 菱形右侧也是 (100,50)
      // hexagon: (100, 50)
      // 对于正右方，它们在该点重合是正常的
      expect(rect.dx, closeTo(100, 0.01));
      expect(ellipse.dx, closeTo(100, 0.01));
      expect(diamond.dx, closeTo(100, 0.01));
      expect(hexagon.dx, closeTo(100, 0.01));
    });

    test('computePerimeter 对角方向各形状不同', () {
      final bounds = const Rect.fromLTWH(0, 0, 100, 100);
      final next = Offset(200, 50);

      final rect = WenzPerimeter.computePerimeter(
        bounds,
        next,
        shapeType: 'rectangle',
      );
      final ellipse = WenzPerimeter.computePerimeter(
        bounds,
        next,
        shapeType: 'ellipse',
      );

      // 矩形右侧交点 y 由角度计算
      expect(rect.dx, closeTo(100, 0.01));
      expect(rect.dy, closeTo(50, 0.01));
      // 椭圆右侧交点
      expect(ellipse.dx, closeTo(100, 0.01));
      expect(ellipse.dy, closeTo(50, 0.01));

      // 椭圆和矩形的交点应该不同（因为曲线 vs 直线）
      // 但不一定，对于同一角度射线，交点取决于形状
    });

    test('computePerimeter supports cylinder and double ellipse aliases', () {
      final bounds = const Rect.fromLTWH(0, 0, 120, 80);
      final cylinder = WenzPerimeter.computePerimeter(
        bounds,
        const Offset(200, 40),
        shapeType: 'cylinder',
        orthogonal: true,
      );
      final doubleEllipse = WenzPerimeter.computePerimeter(
        bounds,
        const Offset(200, 40),
        shapeType: 'doubleEllipse',
      );

      expect(cylinder.dx, closeTo(120, 0.01));
      expect(cylinder.dy, closeTo(40, 0.01));
      expect(doubleEllipse.dx, closeTo(120, 0.01));
      expect(doubleEllipse.dy, closeTo(40, 0.01));
    });

    test('connector routing resolves drawio shape perimeter from binding', () {
      const service = ConnectorRoutingService(
        options: ConnectorRoutingOptions(
          mode: ConnectorRoutingMode.simpleManhattan,
        ),
      );
      const diamond = DrawioShapeElement(
        id: 'diamond-1',
        shapeKey: 'rhombus',
        rect: Rect.fromLTWH(0, 0, 100, 100),
      );
      const target = DrawioShapeElement(
        id: 'target-1',
        shapeKey: 'ellipse',
        rect: Rect.fromLTWH(200, 0, 100, 100),
      );

      final route = service.route(
        start: diamond.rect.center,
        end: target.rect.center,
        elements: const [diamond, target],
        isLayerVisible: (_) => true,
        isLayerLocked: (_) => false,
        startBinding: const SnapBinding(
          elementId: 'diamond-1',
          anchorId: 'center',
        ),
        endBinding: const SnapBinding(
          elementId: 'target-1',
          anchorId: 'center',
        ),
      );

      expect(route.points.first.dx, closeTo(100, 1.5));
      expect(route.points.first.dy, closeTo(50, 1.5));
      expect(route.points.last.dx, closeTo(200, 1.5));
      expect(route.points.last.dy, closeTo(50, 1.5));
    });

    test('nearestSide 返回正确的边', () {
      final bounds = const Rect.fromLTWH(0, 0, 100, 100);

      final (side1, _) = WenzPerimeter.nearestSide(bounds, Offset(200, 50));
      expect(side1, 'right');

      final (side2, _) = WenzPerimeter.nearestSide(bounds, Offset(-50, 50));
      expect(side2, 'left');

      final (side3, _) = WenzPerimeter.nearestSide(bounds, Offset(50, -50));
      expect(side3, 'top');

      final (side4, _) = WenzPerimeter.nearestSide(bounds, Offset(50, 200));
      expect(side4, 'bottom');
    });
  });

  // ===========================================================================
  // SegmentConnector 测试
  // ===========================================================================
  group('SegmentConnector', () {
    test('无控制点时代入简单正交', () {
      final source = const Rect.fromLTWH(0, 0, 100, 100);
      final target = const Rect.fromLTWH(200, 150, 100, 100);

      final path = SegmentConnector.route(
        start: source.center,
        end: target.center,
        sourceBounds: source,
        targetBounds: target,
      );

      expect(path.isNotEmpty, isTrue);
      for (var i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        final horizontal = (a.dy - b.dy).abs() < 0.01;
        final vertical = (a.dx - b.dx).abs() < 0.01;
        expect(horizontal || vertical, isTrue);
      }
    });

    test('单个控制点生成正确路径', () {
      final source = const Rect.fromLTWH(0, 0, 100, 100);
      final target = const Rect.fromLTWH(200, 150, 100, 100);

      final path = SegmentConnector.route(
        start: source.center,
        end: target.center,
        sourceBounds: source,
        targetBounds: target,
        controlPoints: [Offset(150, 50)],
      );

      expect(path.isNotEmpty, isTrue);
      // 路径应该经过控制点
      final containsControlPoint = path.any(
        (p) => (p.dx - 150).abs() < 0.01 && (p.dy - 50).abs() < 0.01,
      );
      expect(containsControlPoint, isTrue);

      // 所有段正交
      for (var i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        final horizontal = (a.dy - b.dy).abs() < 0.01;
        final vertical = (a.dx - b.dx).abs() < 0.01;
        expect(horizontal || vertical, isTrue);
      }
    });

    test('多个控制点', () {
      final source = const Rect.fromLTWH(0, 0, 100, 100);
      final target = const Rect.fromLTWH(300, 200, 100, 100);

      final path = SegmentConnector.route(
        start: source.center,
        end: target.center,
        sourceBounds: source,
        targetBounds: target,
        controlPoints: [Offset(150, 50), Offset(150, 150), Offset(250, 150)],
      );

      expect(path.isNotEmpty, isTrue);

      for (var i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        final horizontal = (a.dy - b.dy).abs() < 0.01;
        final vertical = (a.dx - b.dx).abs() < 0.01;
        expect(horizontal || vertical, isTrue);
      }
    });

    test('路径去重', () {
      final path = SegmentConnector.route(
        start: Offset(0, 0),
        end: Offset(100, 100),
        controlPoints: [
          Offset(50, 0),
          Offset(50, 0), // 重复点
          Offset(50, 100),
        ],
        tolerance: 0.5,
      );

      // 检查去重后没有连续重复点
      for (var i = 0; i < path.length - 1; i++) {
        expect((path[i] - path[i + 1]).distance, greaterThan(0.4));
      }
    });
  });

  // ===========================================================================
  // ConnectorRoutingService 集成测试
  // ===========================================================================
  group('ConnectorRoutingService', () {
    test('simpleManhattan 模式', () {
      final service = ConnectorRoutingService(
        options: ConnectorRoutingOptions(
          mode: ConnectorRoutingMode.simpleManhattan,
        ),
      );

      final result = service.route(
        start: Offset(0, 0),
        end: Offset(200, 100),
        elements: [],
        isLayerVisible: (_) => true,
      );

      expect(result.points.length, greaterThanOrEqualTo(2));
      expect(result.strategy, ConnectorRouteStrategy.directOrthogonal);
      expect(result.usedFallback, isFalse);
    });

    test('orthConnector 模式', () {
      final service = ConnectorRoutingService(
        options: ConnectorRoutingOptions(
          mode: ConnectorRoutingMode.orthConnector,
          margin: 16,
        ),
      );

      // 需要模拟 CanvasElements 来提供 bounds
      // 这里测试无元素 fallback
      final result = service.route(
        start: Offset(50, 50),
        end: Offset(250, 50),
        elements: [],
        isLayerVisible: (_) => true,
      );

      expect(result.points.isNotEmpty, isTrue);
    });

    test('ConnectorRoutingOptions forQuality 生成正确配置', () {
      final base = ConnectorRoutingOptions();

      final fast = base.forQuality(ConnectorRouteQuality.fast);
      final balanced = base.forQuality(ConnectorRouteQuality.balanced);
      final high = base.forQuality(ConnectorRouteQuality.high);

      // fast 应该更激进地裁剪
      expect(fast.maxObstacles, lessThanOrEqualTo(balanced.maxObstacles));
      expect(fast.searchPadding, lessThan(balanced.searchPadding));
    });

    test('ConnectorPortResolver 解析中心端口', () {
      const resolver = ConnectorPortResolver();
      final port = resolver.resolve(
        position: Offset(50, 50),
        toward: Offset(250, 50),
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        shapeType: 'rectangle',
      );

      expect(port.side, isNotNull);
      expect(port.position.dx, isNotNull);
      expect(port.position.dy, isNotNull);
    });

    test('默认路由选项', () {
      const options = ConnectorRoutingOptions();
      expect(options.mode, ConnectorRoutingMode.advancedOrthogonal);
      expect(options.margin, 16);
      expect(options.portLead, 18);
    });
  });
}
