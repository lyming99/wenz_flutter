import 'package:flutter/widgets.dart';

import '../core/model/inline_node.dart';

/// Builds an inline span for an [InlineEmbed].
///
/// The editor still treats every embed as one logical character for selection
/// and caret movement. Custom renderers should therefore return compact spans;
/// use a block renderer when an embed needs a large interactive widget.
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
