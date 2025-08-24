import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool get isMobile {
  if (kIsWeb) return false;
  return [
    TargetPlatform.iOS,
    TargetPlatform.android,
  ].contains(defaultTargetPlatform);
}

Future<dynamic> showMobileDialog({
  required BuildContext context,
  required WidgetBuilder builder,
  bool autoPosition = true,
  Duration? transitionDuration,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  String? barrierLabel,
  Color? barrierColor = const Color(0x8A000000),
  bool barrierDismissible = false,
}) async {
  return showDialog(
    context: context,
    builder: autoPosition
        ? (context) {
            return builder.call(context);
          }
        : builder,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    barrierLabel: barrierLabel,
    barrierColor: barrierColor,
    barrierDismissible: barrierDismissible,
  );
}
