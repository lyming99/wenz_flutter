import 'package:url_launcher/url_launcher.dart';
import 'package:wenz_draw/wenz_draw_mindmap.dart';

/// [MindmapLinkOpener] backed by the `url_launcher` plugin. Provided here in
/// the example app (not the SDK) because the SDK deliberately avoids depending
/// on platform plugins. A real app wires up its own implementation — this is
/// the reference one.
class UrlLauncherLinkOpener implements MindmapLinkOpener {
  const UrlLauncherLinkOpener();

  @override
  Future<bool> open(Uri uri) {
    return launchUrl(uri);
  }
}
