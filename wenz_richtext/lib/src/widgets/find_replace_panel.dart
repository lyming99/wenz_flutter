import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/find_replace_controller.dart';

class WenzFindReplacePanel extends StatefulWidget {
  const WenzFindReplacePanel({
    super.key,
    required this.controller,
    this.showReplace = true,
    this.replaceExpanded = true,
    this.queryFocusNode,
    this.replacementFocusNode,
    this.onReplaceExpandedChanged,
    this.onClose,
  });

  final WenzFindReplaceController controller;
  final bool showReplace;
  final bool replaceExpanded;
  final FocusNode? queryFocusNode;
  final FocusNode? replacementFocusNode;
  final ValueChanged<bool>? onReplaceExpandedChanged;
  final VoidCallback? onClose;

  @override
  State<WenzFindReplacePanel> createState() => _WenzFindReplacePanelState();
}

class _WenzFindReplacePanelState extends State<WenzFindReplacePanel> {
  late final TextEditingController _queryController;
  late final TextEditingController _replacementController;
  late bool _replaceExpanded;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.controller.query);
    _replacementController = TextEditingController(
      text: widget.controller.replacement,
    );
    _replaceExpanded = widget.showReplace && widget.replaceExpanded;
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
    if (oldWidget.replaceExpanded != widget.replaceExpanded ||
        oldWidget.showReplace != widget.showReplace) {
      _replaceExpanded = widget.showReplace && widget.replaceExpanded;
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
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.enter): controller.next,
          const SingleActivator(
            LogicalKeyboardKey.enter,
            shift: true,
          ): controller.previous,
          if (widget.onClose != null)
            const SingleActivator(LogicalKeyboardKey.escape): widget.onClose!,
        },
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: LayoutBuilder(
            builder: (context, constraints) => _buildBody(
              theme,
              controller,
              current,
              total,
              constraints.maxWidth,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    WenzFindReplaceController controller,
    int current,
    int total,
    double maxWidth,
  ) {
    if (maxWidth < 400) {
      return _buildNarrowBody(theme, controller, current, total);
    }
    final trailingButtonCount = widget.onClose == null ? 4 : 5;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (widget.showReplace)
              _replaceToggleButton()
            else
              const SizedBox(width: _buttonExtent),
            const SizedBox(width: 4),
            Expanded(child: _queryField(controller)),
            SizedBox(
              width: 48,
              child: Text(
                '$current/$total',
                textAlign: TextAlign.center,
                maxLines: 1,
                style: theme.textTheme.labelSmall,
              ),
            ),
            _previousButton(controller, total),
            _nextButton(controller, total),
            _caseSensitiveButton(theme, controller),
            _wholeWordButton(theme, controller),
            if (widget.onClose != null)
              _compactIconButton(
                key: const ValueKey<String>('wenz-find-close'),
                tooltip: '关闭',
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
          ],
        ),
        if (widget.showReplace && _replaceExpanded) ...<Widget>[
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              const SizedBox(width: _buttonExtent + 4),
              Expanded(child: _replacementField(controller)),
              const SizedBox(width: 48),
              _replaceCurrentButton(controller, total),
              _replaceAllButton(controller, total),
              SizedBox(
                width: (trailingButtonCount - 2) * _buttonExtent,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNarrowBody(
    ThemeData theme,
    WenzFindReplaceController controller,
    int current,
    int total,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (widget.showReplace)
              _replaceToggleButton()
            else
              const SizedBox(width: _buttonExtent),
            const SizedBox(width: 4),
            Expanded(child: _queryField(controller)),
            if (widget.onClose != null)
              _compactIconButton(
                key: const ValueKey<String>('wenz-find-close'),
                tooltip: '关闭',
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            SizedBox(
              width: 48,
              child: Text(
                '$current/$total',
                textAlign: TextAlign.center,
                maxLines: 1,
                style: theme.textTheme.labelSmall,
              ),
            ),
            _previousButton(controller, total),
            _nextButton(controller, total),
            _caseSensitiveButton(theme, controller),
            _wholeWordButton(theme, controller),
          ],
        ),
        if (widget.showReplace && _replaceExpanded) ...<Widget>[
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              const SizedBox(width: _buttonExtent + 4),
              Expanded(child: _replacementField(controller)),
              _replaceCurrentButton(controller, total),
              _replaceAllButton(controller, total),
            ],
          ),
        ],
      ],
    );
  }

  Widget _replaceToggleButton() {
    return _compactIconButton(
      key: const ValueKey<String>('wenz-find-toggle-replace'),
      tooltip: _replaceExpanded ? '收起替换' : '展开替换',
      icon: AnimatedRotation(
        turns: _replaceExpanded ? 0.25 : 0,
        duration: const Duration(milliseconds: 120),
        child: const Icon(Icons.chevron_right),
      ),
      onPressed: () {
        setState(() {
          _replaceExpanded = !_replaceExpanded;
        });
        widget.onReplaceExpandedChanged?.call(_replaceExpanded);
      },
    );
  }

  Widget _queryField(WenzFindReplaceController controller) {
    return TextField(
      key: const ValueKey<String>('wenz-find-query'),
      controller: _queryController,
      focusNode: widget.queryFocusNode,
      autofocus: true,
      decoration: _fieldDecoration('查找'),
      onChanged: controller.setQuery,
    );
  }

  Widget _replacementField(WenzFindReplaceController controller) {
    return TextField(
      key: const ValueKey<String>('wenz-find-replacement'),
      controller: _replacementController,
      focusNode: widget.replacementFocusNode,
      decoration: _fieldDecoration('替换'),
      onChanged: controller.setReplacement,
    );
  }

  Widget _previousButton(WenzFindReplaceController controller, int total) {
    return _compactIconButton(
      key: const ValueKey<String>('wenz-find-previous'),
      tooltip: '上一个匹配项',
      icon: const Icon(Icons.keyboard_arrow_up),
      onPressed: total == 0 ? null : controller.previous,
    );
  }

  Widget _nextButton(WenzFindReplaceController controller, int total) {
    return _compactIconButton(
      key: const ValueKey<String>('wenz-find-next'),
      tooltip: '下一个匹配项',
      icon: const Icon(Icons.keyboard_arrow_down),
      onPressed: total == 0 ? null : controller.next,
    );
  }

  Widget _caseSensitiveButton(
    ThemeData theme,
    WenzFindReplaceController controller,
  ) {
    return _compactIconButton(
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
    );
  }

  Widget _wholeWordButton(
    ThemeData theme,
    WenzFindReplaceController controller,
  ) {
    return _compactIconButton(
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
    );
  }

  Widget _replaceCurrentButton(
    WenzFindReplaceController controller,
    int total,
  ) {
    return _compactIconButton(
      key: const ValueKey<String>('wenz-find-replace-current'),
      tooltip: '替换当前匹配项',
      icon: const Icon(Icons.swap_horiz),
      onPressed: total == 0 ? null : controller.replaceCurrent,
    );
  }

  Widget _replaceAllButton(
    WenzFindReplaceController controller,
    int total,
  ) {
    return _compactIconButton(
      key: const ValueKey<String>('wenz-find-replace-all'),
      tooltip: '全部替换',
      icon: const Icon(Icons.done_all),
      onPressed: total == 0 ? null : controller.replaceAll,
    );
  }
}

const double _buttonExtent = 32;

InputDecoration _fieldDecoration(String hintText) {
  return InputDecoration(
    isDense: true,
    border: const OutlineInputBorder(),
    hintText: hintText,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  );
}

Widget _compactIconButton({
  Key? key,
  required String tooltip,
  required Widget icon,
  required VoidCallback? onPressed,
  Widget? selectedIcon,
  bool? isSelected,
  ButtonStyle? style,
}) {
  return IconButton(
    key: key,
    tooltip: tooltip,
    icon: icon,
    selectedIcon: selectedIcon,
    isSelected: isSelected,
    style: style,
    constraints: const BoxConstraints.tightFor(
      width: _buttonExtent,
      height: _buttonExtent,
    ),
    padding: const EdgeInsets.all(6),
    iconSize: 20,
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
  );
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
