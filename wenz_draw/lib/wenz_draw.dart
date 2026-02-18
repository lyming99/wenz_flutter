
import 'wenz_draw_platform_interface.dart';

class WenzDraw {
  Future<String?> getPlatformVersion() {
    return WenzDrawPlatform.instance.getPlatformVersion();
  }
}
