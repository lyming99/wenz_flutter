import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'wenz_draw_method_channel.dart';

abstract class WenzDrawPlatform extends PlatformInterface {
  /// Constructs a WenzDrawPlatform.
  WenzDrawPlatform() : super(token: _token);

  static final Object _token = Object();

  static WenzDrawPlatform _instance = MethodChannelWenzDraw();

  /// The default instance of [WenzDrawPlatform] to use.
  ///
  /// Defaults to [MethodChannelWenzDraw].
  static WenzDrawPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WenzDrawPlatform] when
  /// they register themselves.
  static set instance(WenzDrawPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
