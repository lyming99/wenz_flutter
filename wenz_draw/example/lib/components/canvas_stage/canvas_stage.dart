import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

import '../../mindmap/mindmap_connection_layer.dart';
import '../../theme/ui_colors.dart';
import '../common/floating_pill.dart';

class CanvasStage extends StatelessWidget {
  const CanvasStage({
    required this.canvasController,
    required this.viewController,
  });

  final CanvasController canvasController;
  final InfiniteCanvasController viewController;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: UiColors.canvasBackground,
      child: MindmapDragOverlay(
        canvasController: canvasController,
        viewController: viewController,
        child: Stack(
          children: [
            InfiniteCanvasWidget(
              controller: viewController,
              config: const InfiniteCanvasConfig(
                gridType: GridType.lines,
                backgroundColor: UiColors.canvasBackground,
                gridColor: Color(0x1F5F748B),
                majorGridColor: Color(0x2B5F748B),
                gridBaseSize: 20,
              ),
            ),
            // 思维导图连线层：绘制在节点元素之上，跟随视图变换。
            Positioned.fill(
              child: MindmapConnectionLayer(
                canvasController: canvasController,
                viewController: viewController,
              ),
            ),
            Positioned(
              left: 18,
              top: 14,
              child: AnimatedBuilder(
                animation: Listenable.merge([canvasController, viewController]),
                builder: (context, _) {
                  return FloatingPill(
                    child: Text(
                      '${canvasController.currentTool?.name ?? 'Select'}  '
                      '${canvasController.selectedIds.length} 个对象  '
                      '${canvasController.elements.length} 个元素',
                      style: const TextStyle(
                        color: Color(0xFF405164),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 18,
              bottom: 18,
              child: ZoomPill(viewController: viewController),
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: UiColors.panel.withValues(alpha: 0.9),
                  border: Border.all(color: UiColors.line),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1418232E),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: MinimapWidget(controller: viewController),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
