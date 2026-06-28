import 'package:flutter/material.dart';

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
    final inputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );
    return AlertDialog(
      key: const ValueKey<String>('wenz-link-edit-dialog'),
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      title: const Text('Link URL'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'https://example.com',
          labelText: 'URL',
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
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => _apply(context),
          child: const Text('Apply'),
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
  return showDialog<String>(
    context: context,
    builder: (context) => WenzLinkEditDialog(
      initialUrl: initialUrl,
      canRemove: canRemove,
    ),
  );
}
