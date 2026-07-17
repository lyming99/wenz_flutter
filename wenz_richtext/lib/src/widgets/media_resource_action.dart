import '../core/model/block_node.dart';

/// Host-owned actions that can be exposed for image and video resources.
///
/// The rich-text package only dispatches the intent. Resolving an asset to a
/// local file and interacting with the operating system or clipboard remains
/// the host application's responsibility.
enum MediaResourceAction {
  /// Reveals the resource in the platform file manager.
  openPath,

  /// Copies the resolved local resource path as text.
  copyPath,

  /// Copies the resolved image bytes to an image-capable clipboard.
  ///
  /// This action is only meaningful for [MediaResourceType.image].
  copyImage,
}

/// The kind of media resource targeted by a [MediaResourceActionIntent].
enum MediaResourceType {
  image,
  video,
}

/// Describes a media-resource action requested by an editor block.
///
/// [block] is included so hosts can resolve every source representation owned
/// by the media node, including a local path, a file URI, or an asset id.
class MediaResourceActionIntent {
  const MediaResourceActionIntent({
    required this.action,
    required this.blockIndex,
    required this.mediaType,
    required this.block,
  })  : assert(blockIndex >= 0),
        assert(
          (mediaType == MediaResourceType.image && block is ImageBlockNode) ||
              (mediaType == MediaResourceType.video && block is VideoBlockNode),
          'mediaType must match the supplied image or video block.',
        ),
        assert(
          action != MediaResourceAction.copyImage ||
              mediaType == MediaResourceType.image,
          'copyImage is only supported for image resources.',
        );

  final MediaResourceAction action;
  final int blockIndex;
  final MediaResourceType mediaType;
  final BlockNode block;
}

/// Handles a media-resource action on behalf of the editor.
///
/// Implementations may perform asynchronous asset resolution, file-manager,
/// or clipboard work. The editor does not await the result before dismissing
/// its menu.
typedef MediaResourceActionHandler = Future<void> Function(
  MediaResourceActionIntent intent,
);
