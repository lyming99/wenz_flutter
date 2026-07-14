import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_border/window_border.dart';
import 'package:window_border/window_border_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('window_border');
  late MethodChannelWindowBorder platform;
  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    platform = MethodChannelWindowBorder(channel: channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
      calls.add(methodCall);
      return switch (methodCall.method) {
        'isMaximized' => true,
        'getState' => 'maximized',
        _ => null,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize serializes native style arguments', () async {
    await platform.initialize(
      const WindowBorderStyle(
        borderWidth: 2,
        borderColor: 0xFFAABBCC,
        backgroundColor: 0xFF010203,
        cornerRadius: 12,
        shadowEnabled: false,
        resizeBorderWidth: 12,
        resizable: false,
      ),
    );

    expect(calls.single.method, 'initialize');
    expect(calls.single.arguments, <String, Object>{
      'borderWidth': 2.0,
      'borderColor': 0xFFAABBCC,
      'backgroundColor': 0xFF010203,
      'cornerRadius': 12.0,
      'shadowEnabled': false,
      'resizeBorderWidth': 12.0,
      'resizable': false,
      'enabled': true,
    });
  });

  test('default colors are supplied by the native implementation', () {
    final arguments = const WindowBorderStyle().toMap();

    expect(arguments, isNot(contains('borderColor')));
    expect(arguments, isNot(contains('backgroundColor')));
  });

  test('window commands use the expected channel methods', () async {
    await platform.startDragging();
    await platform.startResizing(WindowResizeEdge.bottomRight);
    await platform.minimize();
    await platform.toggleMaximize();
    await platform.restore();

    expect(calls.map((call) => call.method), <String>[
      'startDragging',
      'startResizing',
      'minimize',
      'toggleMaximize',
      'restore',
    ]);
    expect(calls[1].arguments, 'bottomRight');
  });

  test('native state values are decoded', () async {
    expect(await platform.isMaximized(), isTrue);
    expect(await platform.getState(), WindowState.maximized);
  });
}
