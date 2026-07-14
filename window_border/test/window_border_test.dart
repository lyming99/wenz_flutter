import 'package:flutter_test/flutter_test.dart';
import 'package:window_border/window_border.dart';
import 'package:window_border/window_border_method_channel.dart';
import 'package:window_border/window_border_platform_interface.dart';

class FakeWindowBorderPlatform extends WindowBorderPlatform {
  WindowBorderStyle? initializedStyle;
  bool? initializedEnabled;

  @override
  Future<void> initialize(
    WindowBorderStyle style, {
    bool enabled = true,
  }) async {
    initializedStyle = style;
    initializedEnabled = enabled;
  }

  @override
  Future<WindowState> getState() async => WindowState.maximized;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final WindowBorderPlatform initialPlatform = WindowBorderPlatform.instance;

  tearDown(() => WindowBorderPlatform.instance = initialPlatform);

  test('$MethodChannelWindowBorder is the default instance', () {
    expect(initialPlatform, isA<MethodChannelWindowBorder>());
  });

  test('WindowBorder is a singleton facade', () {
    expect(WindowBorder(), same(WindowBorder.instance));
  });

  test('initialize and getState delegate to the platform', () async {
    final fakePlatform = FakeWindowBorderPlatform();
    WindowBorderPlatform.instance = fakePlatform;
    const style = WindowBorderStyle(
      borderWidth: 2,
      borderColor: 0xFF112233,
      backgroundColor: 0xFF010203,
      cornerRadius: 12,
      shadowEnabled: false,
      resizeBorderWidth: 10,
      resizable: false,
    );

    await WindowBorder.instance.initialize(style: style, enabled: false);

    expect(fakePlatform.initializedStyle, same(style));
    expect(fakePlatform.initializedEnabled, isFalse);
    expect(await WindowBorder.instance.getState(), WindowState.maximized);
  });
}
