import 'package:flutter/material.dart';

import '../controller/find_replace_controller.dart';

class WenzFindReplacePanel extends StatefulWidget {
  const WenzFindReplacePanel({
    super.key,
    required this.controller,
    this.showReplace = true,
    this.onClose,
  });

  final WenzFindReplaceController controller;
  final bool showReplace;
  final VoidCallback? onClose;

  @override
  State<WenzFindReplacePanel> createState() => _WenzFindReplacePanelState();
}

class _WenzFindReplacePanelState extends State<WenzFindReplacePanel> {
  late final TextEditingController _queryController;
  late final TextEditingController _replacementController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.controller.query);
    _replacementController = TextEditingController(
      text: widget.controller.replacement,
    );
    widget.controller.addListener(_syncFromController);
  }

  @override
  void didUpdateWidget(covariant WenzFindReplacePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromController);
      widget.controller.addListener(_syncFromController);
      _syncFromController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    _queryController.dispose();
    _replacementController.dispose();
    super.dispose();
  }

  void _syncFromController() {
    _syncText(_queryController, widget.controller.query);
    _syncText(_replacementController, widget.controller.replacement);
    if (mounted) {
      setState(() {});
    }
  }

  void _syncText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final current =
        controller.currentIndex >= 0 ? controller.currentIndex + 1 : 0;
    final total = controller.matches.length;
    final colorScheme = theme.colorScheme;
    return Material(
      key: const ValueKey<String>('wenz-find-replace-panel-surface'),
      color: colorScheme.surface,
      elevation: 2,
      shadowColor: colorScheme.shadow.withAlpha(40),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 220,
              child: TextField(
                key: const ValueKey<String>('wenz-find-query'),
                controller: _queryController,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: controller.setQuery,
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '$current/$total',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium,
              ),
            ),
            IconButton(
              key: const ValueKey<String>('wenz-find-previous'),
              tooltip: '上一个匹配项',
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: total == 0 ? null : controller.previous,
            ),
            IconButton(
              key: const ValueKey<String>('wenz-find-next'),
              tooltip: '下一个匹配项',
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: total == 0 ? null : controller.next,
            ),
            IconButton(
              key: const ValueKey<String>('wenz-find-case-sensitive'),
              tooltip: '区分大小写',
              isSelected: controller.options.caseSensitive,
              style: _findPanelToggleStyle(theme),
              selectedIcon: const Icon(Icons.text_fields),
              icon: const Icon(Icons.text_fields_outlined),
              onPressed: () {
                controller.setOptions(
                  caseSensitive: !controller.options.caseSensitive,
                );
              },
            ),
            IconButton(
              key: const ValueKey<String>('wenz-find-whole-word'),
              tooltip: '全字匹配',
              isSelected: controller.options.wholeWord,
              style: _findPanelToggleStyle(theme),
              selectedIcon: const Icon(Icons.short_text),
              icon: const Icon(Icons.subject),
              onPressed: () {
                controller.setOptions(
                  wholeWord: !controller.options.wholeWord,
                );
              },
            ),
            if (widget.showReplace) ...<Widget>[
              SizedBox(
                width: 220,
                child: TextField(
                  key: const ValueKey<String>('wenz-find-replacement'),
                  controller: _replacementController,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.find_replace),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: controller.setReplacement,
                ),
              ),
              IconButton(
                key: const ValueKey<String>('wenz-find-replace-current'),
                tooltip: '替换当前匹配项',
                icon: const Icon(Icons.swap_horiz),
                onPressed: total == 0 ? null : controller.replaceCurrent,
              ),
              IconButton(
                key: const ValueKey<String>('wenz-find-replace-all'),
                tooltip: '全部替换',
                icon: const Icon(Icons.done_all),
                onPressed: total == 0 ? null : controller.replaceAll,
              ),
            ],
            if (widget.onClose != null)
              IconButton(
                key: const ValueKey<String>('wenz-find-close'),
                tooltip: '关闭',
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
          ],
        ),
      ),
    );
  }
}

ButtonStyle _findPanelToggleStyle(ThemeData theme) {
  final colorScheme = theme.colorScheme;
  return IconButton.styleFrom(
    foregroundColor: colorScheme.onSurfaceVariant,
    backgroundColor: Colors.transparent,
    disabledForegroundColor: colorScheme.onSurface.withAlpha(96),
  ).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return colorScheme.onSurface.withAlpha(96);
      }
      if (states.contains(WidgetState.selected)) {
        return colorScheme.onPrimaryContainer;
      }
      return colorScheme.onSurfaceVariant;
    }),
    backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return colorScheme.primaryContainer;
      }
      return Colors.transparent;
    }),
  );
}
