import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:wenz_ui/scroll/two_direction_scrollable.dart';

/// 支持缩放的双向滚动视图
/// 在TwoDirectionScrollable基础上添加了缩放功能
class ZoomableScrollable extends StatefulWidget {
  /// 垂直方向滚动控制器
  final ScrollController verticalController;

  /// 水平方向滚动控制器
  final ScrollController horizontalController;

  /// 内容构建器
  final ContentBuilder contentBuilder;

  /// 布局回调
  final OnContentLayout onLayout;

  /// 滚动更新回调
  final VoidCallback? onScrollUpdate;

  /// 最小缩放比例
  final double minScale;

  /// 最大缩放比例
  final double maxScale;

  /// 初始缩放比例
  final double initialScale;

  /// 是否显示缩放控制按钮
  final bool showZoomControls;

  /// 缩放变化回调
  final void Function(double scale)? onScaleChanged;

  const ZoomableScrollable({
    super.key,
    required this.verticalController,
    required this.horizontalController,
    required this.contentBuilder,
    required this.onLayout,
    this.onScrollUpdate,
    this.minScale = 0.2,
    this.maxScale = 3.0,
    this.initialScale = 1.0,
    this.showZoomControls = true,
    this.onScaleChanged,
  });

  @override
  State<ZoomableScrollable> createState() =>
      _ZoomableScrollableState();
}

class _ZoomableScrollableState
    extends State<ZoomableScrollable> {
  /// 当前缩放比例
  late double _scale;

  /// 平移偏移量
  Offset _startFocalOffset = Offset.zero;
  Offset _endFocalOffset = Offset.zero;
  Offset _startScrollOffset = Offset.zero;
  double _startScale = 1.0;
  double _endScale = 1.0;
  Offset startHorizontalScrollExtent = Offset.zero;
  Offset startVerticalScrollExtent = Offset.zero;

  @override
  void initState() {
    super.initState();
    _scale = widget.initialScale;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildZoomableContent(),
        if (widget.showZoomControls) _buildZoomControls(),
      ],
    );
  }

  /// 构建可缩放的内容
  Widget _buildZoomableContent() {
    return GestureDetector(
      // 添加缩放手势
      onScaleStart: (details) {
        _startScale = _scale;
        _startFocalOffset = details.focalPoint;
        _startScrollOffset = Offset(
          widget.verticalController.offset,
          widget.horizontalController.offset,
        );
        startHorizontalScrollExtent = Offset(
            widget.horizontalController.position.minScrollExtent,
            widget.horizontalController.position.maxScrollExtent);
        startVerticalScrollExtent = Offset(
            widget.verticalController.position.minScrollExtent,
            widget.verticalController.position.maxScrollExtent);
      },
      onScaleUpdate: (details) {
        setState(() {
          // 更新缩放比例
          if (details.scale != 1.0) {
            _scale = (_startScale * details.scale).clamp(
              widget.minScale,
              widget.maxScale,
            );
            if (widget.onScaleChanged != null) {
              widget.onScaleChanged!(_scale);
            }
          }

          // 更新平移偏移量
          if (details.pointerCount > 0) {
            _endFocalOffset += details.focalPoint;
          }
          _endScale = _scale;
          calculateZoomScrollPosition();
        });
      },
      onScaleEnd: (details) {
        _endScale = _startScale = _scale;
      },
      child: TwoDirectionScrollable(
        verticalController: widget.verticalController,
        horizontalController: widget.horizontalController,
        onScrollUpdate: widget.onScrollUpdate,
        contentBuilder: (context, xOffset, yOffset) {
          return widget.contentBuilder(context, xOffset, yOffset);
        },
        onLayout: (
          Size size,
          ViewportOffset xOffset,
          ViewportOffset yOffset,
        ) {
          widget.onLayout.call(size, xOffset, yOffset);
        },
      ),
    );
  }

  void calculateZoomScrollPosition() {
    var focalDelta = _endFocalOffset - _startFocalOffset;
    var endScrollOffset =
        _startScrollOffset / _startScale + focalDelta * _endScale;
    var endHorizontalScrollExtent =
        startHorizontalScrollExtent / _startScale * _endScale;
    var endVerticalScrollExtent =
        startVerticalScrollExtent / _startScale * _endScale;
    widget.horizontalController.position.applyContentDimensions(
        endHorizontalScrollExtent.dx, endHorizontalScrollExtent.dy);
    widget.verticalController.position.applyContentDimensions(
        endVerticalScrollExtent.dx, endVerticalScrollExtent.dy);
    widget.horizontalController.jumpTo(endScrollOffset.dx);
    widget.verticalController.jumpTo(endScrollOffset.dy);
    widget.onScaleChanged?.call(_scale);
  }

  /// 构建缩放控制按钮
  Widget _buildZoomControls() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '缩放: ${(_scale * 100).toInt()}%',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 8),
              // 缩放滑块
              Container(
                height: 100,
                width: 40,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Slider(
                    value: _scale,
                    min: widget.minScale,
                    max: widget.maxScale,
                    divisions: 28,
                    onChanged: (value) {
                      setState(() {
                        _scale = value;
                        if (widget.onScaleChanged != null) {
                          widget.onScaleChanged!(_scale);
                        }
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: 8),
              FloatingActionButton(
                mini: true,
                heroTag: "zoom_in",
                onPressed: _zoomIn,
                tooltip: '放大',
                child: Icon(Icons.add),
              ),
              SizedBox(height: 4),
              FloatingActionButton(
                mini: true,
                heroTag: "zoom_reset",
                onPressed: _resetZoom,
                tooltip: '重置缩放',
                child: Icon(Icons.refresh),
              ),
              SizedBox(height: 4),
              FloatingActionButton(
                mini: true,
                heroTag: "zoom_out",
                onPressed: _zoomOut,
                tooltip: '缩小',
                child: Icon(Icons.remove),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 放大
  void _zoomIn() {
    setState(() {
      _scale = (_scale * 1.2).clamp(widget.minScale, widget.maxScale);
      widget.onScaleChanged?.call(_scale);
    });
  }

  /// 缩小
  void _zoomOut() {
    setState(() {
      _scale = (_scale / 1.2).clamp(widget.minScale, widget.maxScale);
      widget.onScaleChanged?.call(_scale);
    });
  }

  /// 重置缩放
  void _resetZoom() {
    setState(() {
      _scale = widget.initialScale;
      widget.onScaleChanged?.call(_scale);
    });
  }
}
