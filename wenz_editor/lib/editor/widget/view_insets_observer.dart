import 'dart:ui';

import 'package:flutter/material.dart';

typedef ViewInsetsBuilder = Widget Function(
    BuildContext context, EdgeInsets viewInsets);

class ViewInsetsObserver extends StatefulWidget {
  final ViewInsetsBuilder builder;
  final bool Function(EdgeInsets oldInsets, EdgeInsets newInsets)?
      shouldRebuild;

  const ViewInsetsObserver({
    super.key,
    required this.builder,
    this.shouldRebuild,
  });

  @override
  State<ViewInsetsObserver> createState() => _ViewInsetsObserverState();
}

class _ViewInsetsObserverState extends State<ViewInsetsObserver>
    with WidgetsBindingObserver {
  EdgeInsets? _viewInsets;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewInsets = MediaQuery.of(context).viewInsets;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final newInsets = MediaQuery.of(context).viewInsets;
    if (widget.shouldRebuild?.call(_viewInsets ?? newInsets, newInsets) ??
        true) {
      setState(() {
        _viewInsets = newInsets;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _viewInsets ?? MediaQuery.of(context).viewInsets);
  }
}
