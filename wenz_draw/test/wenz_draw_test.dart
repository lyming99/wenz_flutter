import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';
import 'package:wenz_draw/wenz_draw_platform_interface.dart';
import 'package:wenz_draw/wenz_draw_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockWenzDrawPlatform
    with MockPlatformInterfaceMixin
    implements WenzDrawPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final WenzDrawPlatform initialPlatform = WenzDrawPlatform.instance;

  test('$MethodChannelWenzDraw is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWenzDraw>());
  });

  test('getPlatformVersion', () async {
    WenzDraw wenzDrawPlugin = WenzDraw();
    MockWenzDrawPlatform fakePlatform = MockWenzDrawPlatform();
    WenzDrawPlatform.instance = fakePlatform;

    expect(await wenzDrawPlugin.getPlatformVersion(), '42');
  });
}
