import 'package:flutter/widgets.dart';

import '../core/model/inline_node.dart';

/// Builds a text span for an [InlineEmbed].
///
/// The editor still treats every embed as one logical character for selection
/// and caret movement. Custom renderers should therefore return compact
/// [TextSpan]s; use a block renderer when an embed needs a large interactive
/// widget.
typedef InlineEmbedSpanBuilder = TextSpan? Function(
  BuildContext context,
  InlineEmbed embed,
  TextStyle textStyle,
);

/// Optional extension point for formula / mention / custom inline embeds.
abstract class InlineEmbedRenderer {
  const InlineEmbedRenderer();

  /// Returns a [TextSpan] for [embed], or `null` to use the built-in fallback.
  TextSpan? buildTextSpan(
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
  TextSpan? buildTextSpan(
    BuildContext context,
    InlineEmbed embed,
    TextStyle textStyle,
  ) {
    return builder(context, embed, textStyle);
  }
}
