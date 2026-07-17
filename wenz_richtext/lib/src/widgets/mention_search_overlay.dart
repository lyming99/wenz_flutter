import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'inline_embed_renderer.dart';

const ValueKey<String> wenzMentionSearchOverlayKey =
    ValueKey<String>('wenz-mention-search-overlay');

const double _kMentionSurfaceRadius = 10.0;
const double _kMentionSurfaceElevation = 3.0;
const int _kMentionSurfaceShadowAlpha = 30;
const int _kMentionSurfaceBorderAlphaLight = 112;
const int _kMentionSurfaceBorderAlphaDark = 96;
const EdgeInsets _kMentionListPadding = EdgeInsets.all(4);
const EdgeInsets _kMentionItemOuterPadding = EdgeInsets.symmetric(vertical: 1);
const EdgeInsets _kMentionItemPadding = EdgeInsets.symmetric(horizontal: 10);
const double _kMentionItemRadius = 8.0;
const int _kMentionItemHoverAlpha = 13;
const int _kMentionItemPressedAlpha = 34;
const int _kMentionSelectedAlphaLight = 22;
const int _kMentionSelectedAlphaDark = 34;

int _mentionSurfaceBorderAlpha(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kMentionSurfaceBorderAlphaDark
      : _kMentionSurfaceBorderAlphaLight;
}

int _mentionSelectedAlpha(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kMentionSelectedAlphaDark
      : _kMentionSelectedAlphaLight;
}

class WenzMentionSearchOverlay extends StatelessWidget {
  const WenzMentionSearchOverlay({
    super.key,
    required this.anchorRect,
    required this.containerSize,
    required this.candidates,
    required this.highlightedIndex,
    required this.loading,
    required this.error,
    required this.onCandidateSelected,
    required this.onHighlightChanged,
    this.tapRegionGroupId,
    this.minWidth = 240,
    this.maxWidth = 340,
    this.maxHeight = 280,
    this.gap = 6,
  });

  final Rect anchorRect;
  final Size containerSize;
  final List<WenzMentionCandidate> candidates;
  final int highlightedIndex;
  final bool loading;
  final Object? error;
  final ValueChanged<WenzMentionCandidate> onCandidateSelected;
  final ValueChanged<int> onHighlightChanged;
  final Object? tapRegionGroupId;
  final double minWidth;
  final double maxWidth;
  final double maxHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final width = math.min(
      maxWidth,
      math.max(minWidth, containerSize.width - gap * 2),
    );
    final maxLeft = math.max(0.0, containerSize.width - width - gap);
    final minLeft = maxLeft >= gap ? gap : 0.0;
    final left = anchorRect.left.clamp(minLeft, maxLeft).toDouble();
    final roomBelow = containerSize.height - anchorRect.bottom - gap;
    final roomAbove = anchorRect.top - gap;
    final openAbove = roomBelow < 120 && roomAbove > roomBelow;
    final maxSurfaceHeight = math.max(
      72.0,
      math.min(maxHeight, openAbove ? roomAbove : roomBelow),
    );

    return Positioned(
      left: left,
      top: openAbove ? null : anchorRect.bottom + gap,
      bottom: openAbove ? containerSize.height - anchorRect.top + gap : null,
      child: TapRegion(
        groupId: tapRegionGroupId,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth,
            maxWidth: width,
            maxHeight: maxSurfaceHeight,
          ),
          child: _MentionSearchSurface(
            candidates: candidates,
            highlightedIndex: highlightedIndex,
            loading: loading,
            error: error,
            onCandidateSelected: onCandidateSelected,
            onHighlightChanged: onHighlightChanged,
          ),
        ),
      ),
    );
  }
}

class _MentionSearchSurface extends StatelessWidget {
  const _MentionSearchSurface({
    required this.candidates,
    required this.highlightedIndex,
    required this.loading,
    required this.error,
    required this.onCandidateSelected,
    required this.onHighlightChanged,
  });

  final List<WenzMentionCandidate> candidates;
  final int highlightedIndex;
  final bool loading;
  final Object? error;
  final ValueChanged<WenzMentionCandidate> onCandidateSelected;
  final ValueChanged<int> onHighlightChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      key: wenzMentionSearchOverlayKey,
      color: colorScheme.surfaceContainerLow,
      elevation: _kMentionSurfaceElevation,
      shadowColor: colorScheme.shadow.withAlpha(_kMentionSurfaceShadowAlpha),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kMentionSurfaceRadius),
        side: BorderSide(
          color: colorScheme.outlineVariant.withAlpha(
            _mentionSurfaceBorderAlpha(theme),
          ),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (loading) {
      return const _MentionStatusRow.loading();
    }
    if (error != null) {
      return const _MentionStatusRow.error();
    }
    if (candidates.isEmpty) {
      return const _MentionStatusRow.empty();
    }
    return ListView.builder(
      padding: _kMentionListPadding,
      shrinkWrap: true,
      itemCount: candidates.length,
      itemBuilder: (context, index) {
        final candidate = candidates[index];
        return _MentionCandidateTile(
          key: ValueKey<String>('wenz-mention-candidate-${candidate.id}'),
          candidate: candidate,
          selected: index == highlightedIndex,
          onHover: () => onHighlightChanged(index),
          onTap: () => onCandidateSelected(candidate),
        );
      },
    );
  }
}

class _MentionStatusRow extends StatelessWidget {
  const _MentionStatusRow.loading()
      : label = '搜索中...',
        loading = true;

  const _MentionStatusRow.empty()
      : label = '没有匹配的提及',
        loading = false;

  const _MentionStatusRow.error()
      : label = '提及搜索失败',
        loading = false;

  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(width: 14),
          if (loading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          else
            Icon(Icons.person_search, size: 18, color: color),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _MentionCandidateTile extends StatelessWidget {
  const _MentionCandidateTile({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });

  final WenzMentionCandidate candidate;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background = selected
        ? colorScheme.primary.withAlpha(_mentionSelectedAlpha(theme))
        : Colors.transparent;
    return Padding(
      padding: _kMentionItemOuterPadding,
      child: InkWell(
        onTap: onTap,
        onHover: (hovered) {
          if (hovered) {
            onHover();
          }
        },
        borderRadius: BorderRadius.circular(_kMentionItemRadius),
        hoverColor: colorScheme.onSurface.withAlpha(_kMentionItemHoverAlpha),
        highlightColor:
            colorScheme.primary.withAlpha(_kMentionItemPressedAlpha),
        splashColor: colorScheme.primary.withAlpha(_kMentionItemPressedAlpha),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(_kMentionItemRadius),
          ),
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: _kMentionItemPadding,
              child: Row(
                children: <Widget>[
                  _MentionAvatar(candidate: candidate, selected: selected),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          candidate.label.isEmpty
                              ? candidate.id
                              : candidate.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (candidate.description != null &&
                            candidate.description!.trim().isNotEmpty)
                          ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              candidate.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MentionAvatar extends StatelessWidget {
  const _MentionAvatar({required this.candidate, required this.selected});

  final WenzMentionCandidate candidate;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final avatarUrl = candidate.avatarUrl?.trim();
    final label = candidate.label.trim().isNotEmpty
        ? candidate.label.trim()
        : candidate.id.trim();
    final initial =
        label.isEmpty ? '@' : label.substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 16,
      backgroundColor: selected
          ? colorScheme.primary
          : colorScheme.primaryContainer.withAlpha(180),
      foregroundColor:
          selected ? colorScheme.onPrimary : colorScheme.onPrimaryContainer,
      backgroundImage: avatarUrl == null || avatarUrl.isEmpty
          ? null
          : NetworkImage(avatarUrl),
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Text(
              initial,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}
