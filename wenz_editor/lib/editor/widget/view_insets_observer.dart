import 'dart:ui';

import 'package:flutter/material.dart';

typedef ViewInsetsBuilder = Widget Function(BuildContext context, ViewPadding viewInsets);

class ViewInsetsObserver extends StatefulWidget {
  final ViewInsetsBuilder builder;
  final bool Function(ViewPadding oldInsets, ViewPadding newInsets)? shouldRebuild;

  const ViewInsetsObserver({
    super.key,
    required this.builder,
    this.shouldRebuild,
  });

  @override
  State<ViewInsetsObserver> createState() => _ViewInsetsObserverState();
}

class _ViewInsetsObserverState extends State<ViewInsetsObserver> with WidgetsBindingObserver {
  ViewPadding? _viewInsets;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewInsets = View.of(context).viewInsets;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final newInsets = View.of(context).viewInsets;
    if (widget.shouldRebuild?.call(_viewInsets ?? newInsets, newInsets) ?? true) {
      setState(() {
        _viewInsets = newInsets;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _viewInsets ?? View.of(context).viewInsets);
  }
}
