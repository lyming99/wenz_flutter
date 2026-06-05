import 'package:flutter/animation.dart';

/// 惯性滚动控制器。
///
/// 使用 Ticker 驱动的 AnimationController 实现减速动画。
/// 需要由 Widget 层通过 SingleTickerProviderStateMixin 提供 TickerProvider。
class InertiaScrollController {
  final TickerProvider vsync;

  AnimationController? _controller;
  Offset _velocity = Offset.zero;

  /// 摩擦系数（0~1），值越小减速越快
  final double friction;

  /// 最小速度阈值，低于此值停止
  final double minVelocity;

  InertiaScrollController({
    required this.vsync,
    this.friction = 0.95,
    this.minVelocity = 50.0,
  });

  /// 是否正在惯性滚动
  bool get isActive => _controller?.isAnimating ?? false;

  /// 启动惯性滚动。
  ///
  /// [velocity] 为初始速度（像素/秒）。
  /// [onUpdate] 每帧回调，参数为当前帧的位移量。
  void startFling(Offset velocity, void Function(Offset delta) onUpdate) {
    if (velocity.distanceSquared < minVelocity * minVelocity) return;

    stopFling();
    _velocity = velocity;

    _controller = AnimationController(
      vsync: vsync,
      duration: const Duration(seconds: 5), // 最大持续时间
    )..addListener(() {
        if (_velocity.distanceSquared < minVelocity * minVelocity) {
          stopFling();
          return;
        }

        // 计算本帧位移（假设 60fps，每帧约 16.67ms）
        final double dt = 1 / 60;
        final Offset delta = _velocity * dt;
        onUpdate(delta);

        // 衰减速度
        _velocity = _velocity * friction;
      });

    _controller!.forward();
  }

  /// 停止惯性滚动。
  void stopFling() {
    _controller?.stop();
    _controller?.dispose();
    _controller = null;
    _velocity = Offset.zero;
  }

  /// 释放资源。
  void dispose() {
    stopFling();
  }
}
