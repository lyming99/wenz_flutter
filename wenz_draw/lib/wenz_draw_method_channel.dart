import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'wenz_draw_platform_interface.dart';

/// An implementation of [WenzDrawPlatform] that uses method channels.
class MethodChannelWenzDraw extends WenzDrawPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('wenz_draw');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
