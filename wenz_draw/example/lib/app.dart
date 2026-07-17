import 'package:flutter/material.dart';

import 'pages/canvas_demo_page.dart';
import 'pages/minimal_canvas_page.dart';

class WenzDrawExampleApp extends StatefulWidget {
  const WenzDrawExampleApp({super.key});

  @override
  State<WenzDrawExampleApp> createState() => _WenzDrawExampleAppState();
}

class _WenzDrawExampleAppState extends State<WenzDrawExampleApp> {
  bool _showMinimal = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'wenz_draw',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: _showMinimal
          ? MinimalCanvasPage(
              key: const ValueKey('minimal'),
              onExit: () => setState(() => _showMinimal = false),
            )
          : CanvasDemoPage(
              key: const ValueKey('demo'),
              onShowMinimal: () => setState(() => _showMinimal = true),
            ),
    );
  }
}
