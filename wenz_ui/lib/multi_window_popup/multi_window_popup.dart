import 'package:flutter/material.dart';
import 'multi_window_popup_controller.dart';

class MultiWindowPopup extends StatefulWidget {
  final Widget child;
  final MultiWindowPopupController? controller;

  const MultiWindowPopup({
    super.key,
    required this.child,
    this.controller,
  });

  static MultiWindowPopupController of(BuildContext context) {
    final _MultiWindowPopupState? state =
        context.findAncestorStateOfType<_MultiWindowPopupState>();
    if (state == null) {
      throw FlutterError(
          'MultiWindowPopup.of() called with a context that does not contain a MultiWindowPopup.');
    }
    return state._controller;
  }

  @override
  State<MultiWindowPopup> createState() => _MultiWindowPopupState();
}

class _MultiWindowPopupState extends State<MultiWindowPopup> {
  late MultiWindowPopupController _controller;
  Size? _screenSize;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? MultiWindowPopupController();
    _controller.addListener(_handleChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.of(context).size;
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleChange() {
    setState(() {});
  }

  void _handleDrag(String id, DragUpdateDetails details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Size screenSize = box.size;
    final window = _controller.windows.firstWhere((w) => w.id == id);
    final newPosition = window.position + details.delta;
    _controller.updateWindowPosition(id, newPosition, screenSize);
  }

  void _handleResize(
      String id, DragUpdateDetails details, ResizeDirection direction) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Size screenSize = box.size;
    _controller.resizeWindow(id, details.delta, direction, screenSize);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              widget.child,
              if (_controller.windows.any((w) => w.isVisible))
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _controller.hideAll,
                    child: Stack(
                      children: [
                        for (final window
                            in _controller.windows.where((w) => w.isVisible))
                          Positioned(
                            left: window.position.dx,
                            top: window.position.dy,
                            child: Material(
                              color: Colors.transparent,
                              child: GestureDetector(
                                onTap: () =>
                                    _controller.bringToFront(window.id),
                                child: buildPopupWindowContent(window, context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        });
  }

  Widget buildPopupWindowContent(PopupWindow window, BuildContext context) {
    return Stack(
      children: [
        // Main window content
        SizedBox(
          width: window.width,
          height: window.height,
          child: Card(
            child: Column(
              children: [
                // 标题栏
                GestureDetector(
                  onPanUpdate: (details) => _handleDrag(window.id, details),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _controller.activeWindowId == window.id
                          ? Theme.of(context).colorScheme.surfaceContainerHigh
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh
                              .withAlpha(150),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            window.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (window.onOpen != null)
                          IconButton(
                            icon: const Icon(Icons.open_in_new, size: 18),
                            onPressed: window.onOpen,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: '打开',
                          ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => _controller.hideWindow(window.id),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: '关闭',
                        ),
                      ],
                    ),
                  ),
                ),
                // 内容区域
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(bottom: Radius.circular(8)),
                    child: window.child,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Resize handles
        // Left edge resize handle
        Positioned(
          left: 0,
          top: 8,
          // Start below the rounded corner
          bottom: 8,
          // End above the rounded corner
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              onPanUpdate: (details) =>
                  _handleResize(window.id, details, ResizeDirection.left),
              child: Container(
                width: 8,
                color: Colors.transparent,
              ),
            ),
          ),
        ),

        // Right edge resize handle
        Positioned(
          right: 0,
          top: 8,
          bottom: 8,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              onPanUpdate: (details) =>
                  _handleResize(window.id, details, ResizeDirection.right),
              child: Container(
                width: 8,
                color: Colors.transparent,
              ),
            ),
          ),
        ),

        // Top edge resize handle
        Positioned(
          top: 0,
          left: 8,
          right: 8,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: GestureDetector(
              onPanUpdate: (details) =>
                  _handleResize(window.id, details, ResizeDirection.top),
              child: Container(
                height: 8,
                color: Colors.transparent,
              ),
            ),
          ),
        ),

        // Bottom edge resize handle
        Positioned(
          bottom: 0,
          left: 8,
          right: 8,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: GestureDetector(
              onPanUpdate: (details) =>
                  _handleResize(window.id, details, ResizeDirection.bottom),
              child: Container(
                height: 8,
                color: Colors.transparent,
              ),
            ),
          ),
        ),

        // Top-left corner resize handle
        Positioned(
          left: 0,
          top: 0,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            child: GestureDetector(
              onPanUpdate: (details) =>
                  _handleResize(window.id, details, ResizeDirection.topLeft),
              child: Container(
                width: 16,
                height: 16,
                color: Colors.transparent,
              ),
            ),
          ),
        ),

        // Top-right corner resize handle
        Positioned(
          right: 0,
          top: 0,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpRightDownLeft,
            child: GestureDetector(
              onPanUpdate: (details) =>
                  _handleResize(window.id, details, ResizeDirection.topRight),
              child: Container(
                width: 16,
                height: 16,
                color: Colors.transparent,
              ),
            ),
          ),
        ),

        // Bottom-left corner resize handle
        Positioned(
          left: 0,
          bottom: 0,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpRightDownLeft,
            child: GestureDetector(
              onPanUpdate: (details) =>
                  _handleResize(window.id, details, ResizeDirection.bottomLeft),
              child: Container(
                width: 16,
                height: 16,
                color: Colors.transparent,
              ),
            ),
          ),
        ),

        // Bottom-right corner resize handle
        Positioned(
          right: 0,
          bottom: 0,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            child: GestureDetector(
              onPanUpdate: (details) => _handleResize(
                  window.id, details, ResizeDirection.bottomRight),
              child: Container(
                width: 16,
                height: 16,
                color: Colors.transparent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

extension MultiWindowPopupControllerExtension on MultiWindowPopupController {
  void registerWindowWithContext(
    BuildContext context, {
    required String id,
    required String title,
    required Widget child,
    double width = 800,
    double height = 600,
    VoidCallback? onOpen,
  }) {
    final screenSize = MediaQuery.of(context).size;
    registerWindow(
      id: id,
      title: title,
      child: child,
      width: width,
      height: height,
      screenSize: screenSize,
      onOpen: onOpen,
    );
  }
}
