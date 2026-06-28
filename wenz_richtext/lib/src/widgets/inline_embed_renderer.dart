import 'package:flutter/widgets.dart';

import '../core/model/inline_node.dart';
import '../core/position/document_position.dart';

/// Callback invoked when a mention inline embed is activated.
typedef WenzMentionTapCallback = void Function(WenzMentionTapDetails details);

/// Stable payload for mention activation events.
///
/// The event exposes the original [InlineEmbed] and its raw [data], while also
/// carrying the document [position] that identifies the logical inline slot.
/// [selection] is the editor selection at dispatch time, useful when callers
/// need to distinguish a simple activation from selection-oriented gestures.
class WenzMentionTapDetails {
  const WenzMentionTapDetails({
    required this.embed,
    required this.position,
    this.selection,
  });

  /// Original mention embed from the document model.
  final InlineEmbed embed;

  /// Logical position of the mention embed within the document.
  final DocumentPosition position;

  /// Editor selection at dispatch time, when available.
  final DocumentSelection? selection;

  /// Original mention payload. At minimum, mention integrations should expect
  /// `id` and `label` keys, while preserving any business-specific fields.
  Map<String, Object?> get data => embed.data;

  /// Mention id normalized to a string when present.
  String? get id => data['id']?.toString();

  /// Mention label normalized to a string when present.
  String? get label => data['label']?.toString();

  String get blockId => position.blockId;
  int get blockIndex => position.blockIndex;
  PositionPath get path => position.path;
  int get offset => position.offset;
}

/// Makes the editor's mention activation callback available to inline embed
/// renderers.
///
/// Built-in mention rendering uses this scope as the callback source for
/// editor-level activation. Custom [InlineEmbedRenderer] implementations can
/// look up the handler and call [notifyMentionTap] to reuse the same public
/// callback payload instead of inventing a parallel API.
class WenzMentionTapHandler extends InheritedWidget {
  const WenzMentionTapHandler({
    super.key,
    required this.onMentionTap,
    required this.selection,
    required super.child,
  });

  final WenzMentionTapCallback? onMentionTap;
  final DocumentSelection? selection;

  static WenzMentionTapHandler? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WenzMentionTapHandler>();
  }

  void notifyMentionTap(InlineEmbed embed, DocumentPosition position) {
    final callback = onMentionTap;
    if (callback == null) {
      return;
    }
    callback(
      WenzMentionTapDetails(
        embed: embed,
        position: position,
        selection: selection,
      ),
    );
  }

  @override
  bool updateShouldNotify(covariant WenzMentionTapHandler oldWidget) {
    return oldWidget.onMentionTap != onMentionTap ||
        oldWidget.selection != selection;
  }
}

/// Builds an inline span for an [InlineEmbed].
///
/// The editor still treats every embed as one logical character for selection
/// and caret movement. Custom renderers should therefore return compact spans;
/// use a block renderer when an embed needs a large interactive widget.
///
/// Interaction boundary: built-in mention embeds are rendered by the editor as
/// compact `@label` text and participate in the editor's normal tap, drag, and
/// selection handling. When a custom renderer returns a non-null span for a
/// mention, that renderer owns any recognizers it attaches; return `null` to
/// keep the built-in mention behaviour and future editor-level mention events.
///
/// [textStyle] is the effective inline style after the editor applies its body
/// baseline and the embed's own [InlineEmbed.attributes]. Reuse it (or merge
/// from it) so custom embeds keep line height, color, and selection geometry in
/// sync with surrounding text.
typedef InlineEmbedSpanBuilder = InlineSpan? Function(
  BuildContext context,
  InlineEmbed embed,
  TextStyle textStyle,
);

/// Optional extension point for formula / mention / emoji / custom inline embeds.
abstract class InlineEmbedRenderer {
  const InlineEmbedRenderer();

  /// Returns an [InlineSpan] for [embed], or `null` to use the built-in fallback.
  InlineSpan? buildTextSpan(
    BuildContext context,
    InlineEmbed embed,
    TextStyle textStyle,
  );
}

/// Convenience adapter for function-based inline embed rendering.
class InlineEmbedRendererCallback extends InlineEmbedRenderer {
  const InlineEmbedRendererCallback(this.builder);

  final InlineEmbedSpanBuilder builder;

  @override
  InlineSpan? buildTextSpan(
    BuildContext context,
    InlineEmbed embed,
    TextStyle textStyle,
  ) {
    return builder(context, embed, textStyle);
  }
}

/// Ordered registry for inline embed span builders keyed by
/// [InlineEmbed.embedType].
///
/// This is the plugin-friendly variant of [InlineEmbedRendererCallback]: a host
/// can pass one registry to [WenzRichTextEditor.inlineEmbedRenderer] and let
/// multiple plugins contribute compact renderers without wrapping each other.
class InlineEmbedRendererRegistry extends InlineEmbedRenderer {
  InlineEmbedRendererRegistry({
    Map<String, InlineEmbedSpanBuilder> builders =
        const <String, InlineEmbedSpanBuilder>{},
    this.fallback,
  }) {
    _builders.addAll(builders);
  }

  final Map<String, InlineEmbedSpanBuilder> _builders =
      <String, InlineEmbedSpanBuilder>{};

  /// Optional renderer used when no builder is registered for the embed type.
  final InlineEmbedRenderer? fallback;

  /// Registered embed types in insertion order.
  Iterable<String> get embedTypes => _builders.keys;

  /// Registers [builder] for [embedType], replacing any previous builder.
  InlineEmbedSpanBuilder? register(
    String embedType,
    InlineEmbedSpanBuilder builder,
  ) {
    final previous = _builders[embedType];
    _builders[embedType] = builder;
    return previous;
  }

  /// Removes the builder for [embedType], if any.
  void unregister(String embedType) {
    _builders.remove(embedType);
  }

  /// Whether a builder is registered for [embedType].
  bool has(String embedType) => _builders.containsKey(embedType);

  @override
  InlineSpan? buildTextSpan(
    BuildContext context,
    InlineEmbed embed,
    TextStyle textStyle,
  ) {
    final builder = _builders[embed.embedType];
    if (builder != null) {
      return builder(context, embed, textStyle);
    }
    return fallback?.buildTextSpan(context, embed, textStyle);
  }
}
