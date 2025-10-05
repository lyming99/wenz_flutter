import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformUtils {
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static bool get isDesktop {
    if (kIsWeb) return true;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  static bool get isWindows {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }
  static bool get isMacOS {
    if (kIsWeb) return false;
    return Platform.isMacOS;
  }
  static bool get isLinux {
    if (kIsWeb) return false;
    return Platform.isLinux;
  }
}
