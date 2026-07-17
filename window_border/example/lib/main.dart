import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_border/window_border.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WindowBorderExample());
}

class WindowBorderExample extends StatefulWidget {
  const WindowBorderExample({super.key});

  @override
  State<WindowBorderExample> createState() => _WindowBorderExampleState();
}

class _WindowBorderExampleState extends State<WindowBorderExample> {
  final WindowBorder _window = WindowBorder.instance;
  StreamSubscription<WindowState>? _stateSubscription;
  WindowState _windowState = WindowState.unknown;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stateSubscription = _window.stateChanges.listen((state) {
      if (mounted) setState(() => _windowState = state);
    });
    unawaited(_initializeWindow());
  }

  Future<void> _initializeWindow() async {
    try {
      await _window.initialize(
        style: const WindowBorderStyle(
          borderWidth: 2,
          cornerRadius: 14,
          shadowEnabled: true,
          resizeBorderWidth: 8,
        ),
      );
      final state = await _window.getState();
      if (mounted) setState(() => _windowState = state);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF9AA0A6),
        scaffoldBackgroundColor: const Color(0xFF000000),
      ),
      home: Scaffold(
        body: Column(
          children: <Widget>[
            _TitleBar(window: _window, state: _windowState),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Card(
                    color: const Color(0xFF202124),
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Native frameless window',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          Text('Window state: ${_windowState.name}'),
                          const SizedBox(height: 8),
                          const Text(
                            'Drag the custom title area, double-click it to '
                            'maximize, or resize from any window edge.',
                          ),
                          if (_error case final error?) ...<Widget>[
                            const SizedBox(height: 16),
                            Text(
                              error,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.window, required this.state});

  final WindowBorder window;
  final WindowState state;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF202124),
      child: SizedBox(
        height: 44,
        child: Row(
          children: <Widget>[
            const Expanded(
              child: WindowDragArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.crop_square, size: 18),
                      SizedBox(width: 9),
                      Text('window_border example'),
                    ],
                  ),
                ),
              ),
            ),
            _WindowButton(
              tooltip: 'Minimize',
              icon: Icons.remove,
              onPressed: window.minimize,
            ),
            _WindowButton(
              tooltip: state == WindowState.maximized ? 'Restore' : 'Maximize',
              icon: state == WindowState.maximized
                  ? Icons.filter_none
                  : Icons.crop_square,
              onPressed: window.toggleMaximize,
            ),
            _WindowButton(
              tooltip: 'Close',
              icon: Icons.close,
              isClose: true,
              onPressed: window.close,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;
  final bool isClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 44,
      child: IconButton(
        tooltip: tooltip,
        hoverColor: isClose ? const Color(0xFFC42B1C) : Colors.white12,
        icon: Icon(icon, size: 17),
        onPressed: () => unawaited(onPressed()),
      ),
    );
  }
}
