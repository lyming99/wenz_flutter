import 'package:flutter/material.dart';

import '../core/position/document_position.dart';

/// Resolved description of the inline link run a pointer is hovering, shared
/// between the document gesture surface (which probes for links) and the
/// [WenzLinkHoverOverlay] (which presents Edit / Open actions for that run).
///
/// `globalRect` is the bounding [Rect] of the contiguous same-`url` run in
/// **global** coordinates; the overlay host converts it to its own coordinate
/// space to anchor the popup above the link. `position` is a [DocumentPosition]
/// on the link's block at the run start, so the host can rebuild a
/// [DocumentSelection] over [range] or report the run's location via
/// [WenzRichTextEditor.onOpenLink]. Records compare structurally, so hovering
/// across a single run yields a stable value (no rebuild churn).
typedef WenzLinkHoverInfo = ({
  String url,
  TextRange range,
  Rect globalRect,
  DocumentPosition position,
});

// Surface chrome mirrors the slash menu (slash_menu_overlay.dart) so the link
// popup reads as the same surface family: radius, elevation, shadow, border,
// and the surface colour token.
const double _kLinkHoverSurfaceRadius = 10.0;
const double _kLinkHoverSurfaceElevation = 3.0;
const int _kLinkHoverShadowAlpha = 30;
const int _kLinkHoverBorderAlphaLight = 112;
const int _kLinkHoverBorderAlphaDark = 96;
const double _kLinkHoverGap = 6.0;
const double _kLinkHoverMaxUrlWidth = 220.0;
const double _kLinkHoverFallbackHeight = 44.0;
const double _kLinkHoverActionRadius = 8.0;
const EdgeInsets _kLinkHoverPadding = EdgeInsets.symmetric(
  horizontal: 6,
  vertical: 4,
);
const EdgeInsets _kLinkHoverActionPadding = EdgeInsets.symmetric(
  horizontal: 10,
  vertical: 6,
);
// Hover wash for action chips, matching the slash-menu item hover alpha.
const int _kLinkHoverActionHoverAlpha = 13;

int _linkHoverBorderAlpha(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kLinkHoverBorderAlphaDark
      : _kLinkHoverBorderAlphaLight;
}

/// Mouse/pen popup shown above a hovered inline link with "Edit" and "Open"
/// actions.
///
/// The editor mounts this overlay inside the editor [Stack] only while a pointer
/// hovers a link, so it is inherently a desktop affordance (touch has no hover).
/// It anchors itself above [linkRect] — in the coordinate space of that [Stack]
/// — with [gap], flipping below the link when there is no room above, and clamps
/// horizontally to [containerWidth]. Positioning follows the
/// `TableFloatingToolbarOverlay` measure-then-place pattern: the surface
/// measures itself after layout (via a post-frame callback) and repositions so
/// its horizontal centring and vertical flip are exact.
///
/// Read-only surfaces hide the "Edit" action. When [onOpen] is `null` (the host
/// supplied no [WenzRichTextEditor.onOpenLink]) the "Open" action renders
/// disabled. [onHoverEnter] / [onHoverExit] let the host keep the popup alive
/// while the pointer travels from the link text onto the popup itself.
class WenzLinkHoverOverlay extends StatefulWidget {
  const WenzLinkHoverOverlay({
    super.key,
    required this.linkRect,
    required this.containerWidth,
    required this.url,
    required this.readOnly,
    required this.onEdit,
    required this.onOpen,
    required this.onHoverEnter,
    required this.onHoverExit,
    this.gap = _kLinkHoverGap,
  });

  /// Bounding rect of the hovered link run, in the coordinate space of the
  /// [Stack] this overlay is placed in.
  final Rect linkRect;

  /// Width of the containing [Stack], used to keep the popup on-screen
  /// horizontally.
  final double containerWidth;

  /// The link's URL. Shown truncated (when non-empty) and passed back to
  /// [onOpen].
  final String url;

  /// When `true` the "Edit" action is hidden — read-only surfaces cannot mutate
  /// the document.
  final bool readOnly;

  /// Invoked when the user picks "Edit". The host selects the link run and
  /// opens the library link-edit dialog. Only reachable when [readOnly] is
  /// false.
  final VoidCallback onEdit;

  /// Invoked when the user picks "Open". When `null`, "Open" renders disabled.
  final VoidCallback? onOpen;

  /// Invoked when the pointer enters the popup. The host cancels its pending
  /// hide so the user can travel from the link text onto the popup.
  final VoidCallback onHoverEnter;

  /// Invoked when the pointer leaves the popup. The host schedules a hide.
  final VoidCallback onHoverExit;

  /// Gap between the popup edge and the link rect.
  final double gap;

  @override
  State<WenzLinkHoverOverlay> createState() => _WenzLinkHoverOverlayState();
}

class _WenzLinkHoverOverlayState extends State<WenzLinkHoverOverlay> {
  final GlobalKey _surfaceKey = GlobalKey();
  Size? _size;
  bool _measureScheduled = false;

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final width = _size?.width ?? 0.0;
    final height = _size?.height ?? _kLinkHoverFallbackHeight;

    // Centre on the link and clamp into the container so long URLs near an edge
    // do not overflow the editor. `clamp` returns `num`, so convert for
    // [Positioned] (matching the formula/table anchor pattern).
    final maxLeft =
        (widget.containerWidth - width).clamp(0.0, double.infinity);
    final left = (widget.linkRect.center.dx - width / 2)
        .clamp(0.0, maxLeft)
        .toDouble();
    // Prefer above the link; flip below when there is no room above the top of
    // the stack (e.g. a link on the first visible line).
    final aboveTop = widget.linkRect.top - widget.gap - height;
    final top = aboveTop >= 0
        ? aboveTop
        : widget.linkRect.bottom + widget.gap;

    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        onEnter: (_) => widget.onHoverEnter(),
        onExit: (_) => widget.onHoverExit(),
        child: _buildSurface(theme, colorScheme),
      ),
    );
  }

  Widget _buildSurface(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final showUrl = widget.url.isNotEmpty;
    final actions = <Widget>[
      if (!widget.readOnly)
        _LinkHoverAction(
          label: 'Edit',
          onTap: widget.onEdit,
          foreground: colorScheme.onSurface,
        ),
      _LinkHoverAction(
        label: 'Open',
        onTap: widget.onOpen,
        foreground: colorScheme.primary,
        disabledForeground: colorScheme.onSurfaceVariant,
      ),
    ];
    return Material(
      key: _surfaceKey,
      color: colorScheme.surfaceContainerLow,
      elevation: _kLinkHoverSurfaceElevation,
      shadowColor: colorScheme.shadow.withAlpha(_kLinkHoverShadowAlpha),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: colorScheme.outlineVariant.withAlpha(
            _linkHoverBorderAlpha(theme),
          ),
        ),
        borderRadius: BorderRadius.circular(_kLinkHoverSurfaceRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: _kLinkHoverPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showUrl)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _kLinkHoverMaxUrlWidth,
                ),
                child: Text(
                  widget.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (showUrl) const SizedBox(width: 6),
            for (var index = 0; index < actions.length; index++) ...[
              if (index > 0) const SizedBox(width: 4),
              actions[index],
            ],
          ],
        ),
      ),
    );
  }

  /// Measures the surface after layout so the centring / flip computed in
  /// [build] is exact on the next frame. Mirrors the table floating toolbar's
  /// post-frame size sync.
  void _scheduleMeasure() {
    if (_measureScheduled) {
      return;
    }
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) {
        return;
      }
      final render = _surfaceKey.currentContext?.findRenderObject();
      if (render is! RenderBox || !render.hasSize) {
        return;
      }
      final next = render.size;
      final current = _size;
      if (current != null &&
          (current.width - next.width).abs() < 0.5 &&
          (current.height - next.height).abs() < 0.5) {
        return;
      }
      setState(() {
        _size = next;
      });
    });
  }
}

/// A single tappable label inside the link hover popup. Disabled (greyed,
/// non-interactive) when [onTap] is `null`.
class _LinkHoverAction extends StatelessWidget {
  const _LinkHoverAction({
    required this.label,
    required this.onTap,
    required this.foreground,
    this.disabledForeground,
  });

  final String label;
  final VoidCallback? onTap;
  final Color foreground;

  /// Colour used when disabled. Defaults to a muted variant of [foreground].
  final Color? disabledForeground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = onTap != null;
    final disabled = disabledForeground ?? colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_kLinkHoverActionRadius),
      hoverColor: colorScheme.onSurface.withAlpha(_kLinkHoverActionHoverAlpha),
      child: Padding(
        padding: _kLinkHoverActionPadding,
        child: Text(
          label,
          style: (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
            color: enabled ? foreground : disabled.withAlpha(102),
          ),
        ),
      ),
    );
  }
}
