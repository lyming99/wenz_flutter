import 'package:flutter/material.dart';

import 'editor_tokens.dart';

const double _kLinkEditDialogRadius = 10.0;
const double _kLinkEditDialogElevation = 3.0;
const int _kLinkEditDialogShadowAlpha = 30;
const int _kLinkEditDialogBorderAlphaLight = 112;
const int _kLinkEditDialogBorderAlphaDark = 96;

int _linkEditDialogBorderAlpha(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kLinkEditDialogBorderAlphaDark
      : _kLinkEditDialogBorderAlphaLight;
}

class WenzLinkEditDialog extends StatefulWidget {
  const WenzLinkEditDialog({
    super.key,
    this.initialUrl = '',
    this.canRemove = false,
  });

  final String initialUrl;
  final bool canRemove;

  @override
  State<WenzLinkEditDialog> createState() => _WenzLinkEditDialogState();
}

class _WenzLinkEditDialogState extends State<WenzLinkEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final outlineColor = colorScheme.outlineVariant.withAlpha(
      _linkEditDialogBorderAlpha(theme),
    );
    final inputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: outlineColor),
    );
    return AlertDialog(
      key: const ValueKey<String>('wenz-link-edit-dialog'),
      backgroundColor: colorScheme.surfaceContainerLow,
      elevation: _kLinkEditDialogElevation,
      shadowColor: colorScheme.shadow.withAlpha(_kLinkEditDialogShadowAlpha),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: outlineColor),
        borderRadius: BorderRadius.circular(_kLinkEditDialogRadius),
      ),
      title: const Text('链接地址'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'https://example.com',
          labelText: '链接地址',
          border: inputBorder,
          enabledBorder: inputBorder,
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _apply(context),
      ),
      actions: <Widget>[
        if (widget.canRemove)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('移除'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => _apply(context),
          child: const Text('应用'),
        ),
      ],
    );
  }

  void _apply(BuildContext context) {
    Navigator.of(context).pop(_controller.text.trim());
  }
}

Future<String?> showWenzLinkEditDialog({
  required BuildContext context,
  String initialUrl = '',
  bool canRemove = false,
}) {
  // Mobile surfaces use a modal bottom sheet (full-width, sits above the soft
  // keyboard) instead of a centered AlertDialog that would be cramped and
  // occluded on a phone. Desktop keeps the original centered dialog unchanged.
  if (EditorTokens.resolve(context).isMobile) {
    final theme = Theme.of(context);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_kLinkEditDialogRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) => _WenzLinkEditSheet(
        initialUrl: initialUrl,
        canRemove: canRemove,
      ),
    );
  }
  return showDialog<String>(
    context: context,
    builder: (context) => WenzLinkEditDialog(
      initialUrl: initialUrl,
      canRemove: canRemove,
    ),
  );
}

/// Mobile link-edit form rendered inside a [showModalBottomSheet]. Owns the
/// same text controller + result semantics as [WenzLinkEditDialog] (pop `null`
/// cancel, `''` remove, trimmed url apply), but laid out as a bottom sheet that
/// clears the soft keyboard and the gesture bar.
class _WenzLinkEditSheet extends StatefulWidget {
  const _WenzLinkEditSheet({this.initialUrl = '', this.canRemove = false});

  final String initialUrl;
  final bool canRemove;

  @override
  State<_WenzLinkEditSheet> createState() => _WenzLinkEditSheetState();
}

class _WenzLinkEditSheetState extends State<_WenzLinkEditSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final outlineColor = colorScheme.outlineVariant.withAlpha(
      _linkEditDialogBorderAlpha(theme),
    );
    final inputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: outlineColor),
    );
    return Padding(
      // isScrollControlled lets the sheet grow with the keyboard; this padding
      // keeps the field + actions above the IME so they stay tappable.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                    ),
                    child: const SizedBox(width: 32, height: 4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('链接地址', style: theme.textTheme.titleMedium),
              ),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'https://example.com',
                  labelText: '链接地址',
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: colorScheme.primary, width: 1.5),
                  ),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _apply(),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (widget.canRemove)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.error,
                      ),
                      onPressed: _remove,
                      child: const Text('移除'),
                    ),
                  TextButton(
                    onPressed: _cancel,
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: _apply,
                    child: const Text('应用'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _apply() => Navigator.of(context).pop(_controller.text.trim());

  void _remove() => Navigator.of(context).pop('');

  void _cancel() => Navigator.of(context).pop(null);
}
