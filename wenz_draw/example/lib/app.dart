import 'package:flutter/material.dart';

import 'pages/canvas_demo_page.dart';

class WenzDrawExampleApp extends StatelessWidget {
  const WenzDrawExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'wenz_draw',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const CanvasDemoPage(),
    );
  }
}
