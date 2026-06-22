import 'package:flutter/widgets.dart';

import '../core/model/block_node.dart';

/// Resolves a media block ([ImageBlockNode], [VideoBlockNode], or
/// [FileBlockNode]) into a display widget.
///
/// Inject an instance via `WenzRichTextEditor.mediaResolver` (and, for
/// convenience, `WenzRichTextController.mediaResolver`) to take over how media
/// blocks render. The default image/video/file renderers first ask the
/// resolver; when it returns `null` (or when no resolver is injected) they
/// fall back to the built-in placeholder.
///
/// Returning a widget (rather than an `ImageProvider`/URL) keeps the resolver
/// fully general: the business layer assembles its own `Image`, a video
/// player, a download chip, or any custom widget, using whatever source it
/// owns (network, local file, memory bytes, signed URL, …). The package never
/// needs to depend on `video_player`/`image`/etc. — that stays a business
/// concern.
///
/// ```dart
/// class NetworkImageResolver implements MediaResolver {
///   @override
///   Widget? resolve(BuildContext context, BlockNode block) {
///     if (block is! ImageBlockNode) return null;
///     final url = block.file.isNotEmpty ? block.file : block.assetId;
///     if (!url.startsWith('http')) return null; // let the placeholder show
///     return Image.network(
///       url,
///       fit: BoxFit.contain,
///       errorBuilder: (_, __, ___) => const Text('image load failed'),
///     );
///   }
/// }
/// ```
///
/// Throwing from [resolve] is tolerated: the editor catches it and falls back
/// to the placeholder, so a faulty resolver never crashes the editor (see
/// `docs/schema_and_commands.md` §Error handling).
abstract class MediaResolver {
  /// Builds the widget for [block], or `null` to let the editor fall back to
  /// its built-in placeholder for that block.
  ///
  /// [context] is the build context the block is being painted in (use it for
  /// `MediaQuery`/`Theme`/`DefaultTextStyle`). The block is guaranteed to be
  /// an [ImageBlockNode], [VideoBlockNode], or [FileBlockNode] — the only
  /// block types whose default renderers consult a resolver.
  Widget? resolve(BuildContext context, BlockNode block);
}
