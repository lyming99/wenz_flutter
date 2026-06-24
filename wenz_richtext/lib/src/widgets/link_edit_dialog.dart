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
    return AlertDialog(
      title: const Text('Link URL'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'https://example.com',
          labelText: 'URL',
        ),
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _apply(context),
      ),
      actions: <Widget>[
        if (widget.canRemove)
          TextButton(
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
