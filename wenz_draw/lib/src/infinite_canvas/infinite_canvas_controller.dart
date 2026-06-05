import 'dart:async';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';

import '../canvas/canvas_controller.dart';
import 'canvas_transform.dart';

/// 无限画布视图变换控制器。
///
/// 管理画布的平移、缩放等视图变换，以及惯性滚动。
/// 通过 [transform] 暴露当前变换状态，通过 [addListener] 通知变更。
class InfiniteCanvasController extends ChangeNotifier {
  // ─── 子控制器 ─────────────────────────────────────────────

  /// 核心画布控制器（元素/工具/历史等）
  final CanvasController canvasController;

  // ─── 变换状态 ───────────────────────────────────────────

  CanvasTransform _transform = CanvasTransform.identity;

  /// 当前视图变换。
  CanvasTransform get transform => _transform;

  /// 视口尺寸，由 Widget 层注入。
  Size? _viewportSize;

  /// 当前视口尺寸。
  Size? get viewportSize => _viewportSize;

  // ─── 缩放常量 ───────────────────────────────────────────

  /// 最小缩放比例
  /// 缩放限制
  static const double minScale = CanvasTransform.minScale;
  static const double maxScale = CanvasTransform.maxScale;

  // ─── 惯性滚动 ───────────────────────────────────────────

  /// 惯性衰减系数
  static const double _flingDeceleration = 0.95;

  Timer? _flingTimer;
  Offset _flingVelocity = Offset.zero;

  // ─── 构造函数 ─────────────────────────────────────────────

  InfiniteCanvasController({
    CanvasController? canvasController,
    CanvasTransform initialTransform = CanvasTransform.identity,
  })  : canvasController = canvasController ?? CanvasController(),
        _transform = initialTransform;

  // ─── 视口注入 ─────────────────────────────────────────────

  /// 由 Widget 层调用，注入当前视口尺寸。
  void updateViewportSize(Size size) {
    if (_viewportSize != size) {
      _viewportSize = size;
      notifyListeners();
    }
  }

  // ─── 直接设置变换（用于双指缩放等需要精确控制的场景） ────────────

  /// 直接设置变换。
  void setTransform(CanvasTransform newTransform) {
    _transform = newTransform;
    notifyListeners();
  }

  // ─── 变换操作 ─────────────────────────────────────────────

  /// 平移画布（增量）。
  void pan(Offset delta) {
    if (delta == Offset.zero) return;
    _transform = _transform.pan(delta);
    notifyListeners();
  }

  /// 缩放到指定比例，以 [focalPoint]（屏幕坐标）为焦点。
  void zoomTo(double newScale, {Offset? focalPoint}) {
    final focal = focalPoint ??
        (_viewportSize != null
            ? Offset(_viewportSize!.width / 2, _viewportSize!.height / 2)
            : Offset.zero);
    _transform = _transform.zoomTo(newScale, focal);
    notifyListeners();
  }

  /// 放大一步。
  void zoomIn({Offset? focalPoint}) {
    final focal = focalPoint ??
        (_viewportSize != null
            ? Offset(_viewportSize!.width / 2, _viewportSize!.height / 2)
            : Offset.zero);
    _transform = _transform.zoomIn(focalPoint: focal);
    notifyListeners();
  }

  /// 缩小一步。
  void zoomOut({Offset? focalPoint}) {
    final focal = focalPoint ??
        (_viewportSize != null
            ? Offset(_viewportSize!.width / 2, _viewportSize!.height / 2)
            : Offset.zero);
    _transform = _transform.zoomOut(focalPoint: focal);
    notifyListeners();
  }

  /// 按比例缩放（相对于当前 scale）。
  void zoomBy(double factor, {Offset? focalPoint}) {
    final focal = focalPoint ??
        (_viewportSize != null
            ? Offset(_viewportSize!.width / 2, _viewportSize!.height / 2)
            : Offset.zero);
    _transform = _transform.zoomBy(factor, focal);
    notifyListeners();
  }

  /// 重置视图为初始状态。
  void resetView() {
    cancelFling();
    _transform = CanvasTransform.identity;
    notifyListeners();
  }

  /// 缩放至指定内容区域刚好适配视口。
  void zoomToFit(Rect contentBounds, {double padding = 0.1}) {
    if (_viewportSize == null) return;
    cancelFling();
    _transform = _transform.zoomToFit(
      contentBounds,
      _viewportSize!,
      padding: padding,
    );
    notifyListeners();
  }

  // ─── 坐标转换代理 ─────────────────────────────────────────

  /// 屏幕坐标 → 世界坐标
  Offset screenToWorld(Offset screenPoint) {
    return _transform.screenToWorld(screenPoint);
  }

  /// 世界坐标 → 屏幕坐标
  Offset worldToScreen(Offset worldPoint) {
    return _transform.worldToScreen(worldPoint);
  }

  /// 当前视口在世界坐标系中的可见矩形。
  Rect get visibleWorldRect {
    if (_viewportSize == null) return Rect.zero;
    return _transform.visibleWorldRect(_viewportSize!);
  }

  // ─── 惯性滚动 ───────────────────────────────────────────

  /// 启动惯性滚动。
  ///
  /// [velocity] 为初始速度（像素/帧）。
  void startFling(Offset velocity) {
    if (velocity == Offset.zero) return;

    cancelFling();
    _flingVelocity = velocity;

    // 使用 Timer.periodic 模拟惯性衰减（约 16ms ≈ 60fps）
    _flingTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _flingVelocity = _flingVelocity * _flingDeceleration;

      // 速度足够小时停止
      if (_flingVelocity.distanceSquared < 1.0) {
        cancelFling();
        return;
      }

      _transform = _transform.pan(_flingVelocity);
      notifyListeners();
    });
  }

  /// 取消惯性滚动。
  void cancelFling() {
    _flingTimer?.cancel();
    _flingTimer = null;
    _flingVelocity = Offset.zero;
  }

  /// 是否正在惯性滚动中。
  bool get isFlinging => _flingTimer != null;

  // ─── 生命周期 ─────────────────────────────────────────────

  @override
  void dispose() {
    cancelFling();
    super.dispose();
  }
}
