import 'package:flutter/material.dart';

import '../model/wenz_chat_message.dart';
import '../theme/wenz_chat_theme.dart';

/// Position of a message inside a consecutive same-author group.
enum WenzChatGroupPosition { single, first, middle, last }

/// The package's dependency-free default message renderer.
class WenzChatBubble extends StatelessWidget {
  const WenzChatBubble({
    required this.message,
    required this.isOutgoing,
    required this.groupPosition,
    required this.theme,
    this.avatar,
    this.showTimestamp = true,
    this.selectableText = false,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final WenzChatMessage message;
  final bool isOutgoing;
  final WenzChatGroupPosition groupPosition;
  final WenzChatThemeData theme;
  final Widget? avatar;
  final bool showTimestamp;
  final bool selectableText;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (message.kind == WenzChatMessageKind.system) {
      return _buildSystemMessage();
    }

    final bubble = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isOutgoing
              ? theme.outgoingBubbleColor
              : theme.incomingBubbleColor,
          borderRadius: _borderRadius(),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.horizontalPadding,
            vertical: theme.verticalPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!isOutgoing &&
                  message.authorName != null &&
                  (groupPosition == WenzChatGroupPosition.first ||
                      groupPosition == WenzChatGroupPosition.single)) ...[
                Text(message.authorName!, style: theme.authorTextStyle),
                const SizedBox(height: 2),
              ],
              if (selectableText)
                SelectableText(
                  message.text,
                  style: isOutgoing
                      ? theme.outgoingTextStyle
                      : theme.incomingTextStyle,
                )
              else
                Text(
                  message.text,
                  style: isOutgoing
                      ? theme.outgoingTextStyle
                      : theme.incomingTextStyle,
                ),
              if (showTimestamp) ...[
                const SizedBox(height: 3),
                _MessageMeta(
                  message: message,
                  isOutgoing: isOutgoing,
                  theme: theme,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: _semanticLabel(),
      button: onTap != null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxBubbleWidth =
              constraints.maxWidth * theme.maxBubbleWidthFactor;
          final constrainedBubble = ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: bubble,
          );
          final children = <Widget>[
            if (!isOutgoing) ...[
              _AvatarSpace(theme: theme, avatar: avatar),
              SizedBox(width: theme.avatarGap),
            ],
            Flexible(child: constrainedBubble),
            if (isOutgoing && avatar != null) ...[
              SizedBox(width: theme.avatarGap),
              _AvatarSpace(theme: theme, avatar: avatar),
            ],
          ];
          return Row(
            mainAxisAlignment: isOutgoing
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: children,
          );
        },
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Semantics(
      label: message.text,
      child: Align(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.systemBubbleColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(message.text, style: theme.systemTextStyle),
          ),
        ),
      ),
    );
  }

  String _semanticLabel() {
    final sender = isOutgoing
        ? 'You'
        : (message.authorName ?? message.authorId);
    return '$sender, ${message.text}, ${_formatTime(message.sentAt)}';
  }

  BorderRadius _borderRadius() {
    final radius = Radius.circular(theme.bubbleRadius);
    final grouped = Radius.circular(theme.groupedCornerRadius);
    final joinsPrevious =
        groupPosition == WenzChatGroupPosition.middle ||
        groupPosition == WenzChatGroupPosition.last;
    final joinsNext =
        groupPosition == WenzChatGroupPosition.first ||
        groupPosition == WenzChatGroupPosition.middle;
    if (isOutgoing) {
      return BorderRadius.only(
        topLeft: radius,
        bottomLeft: radius,
        topRight: joinsPrevious ? grouped : radius,
        bottomRight: joinsNext ? grouped : radius,
      );
    }
    return BorderRadius.only(
      topLeft: joinsPrevious ? grouped : radius,
      bottomLeft: joinsNext ? grouped : radius,
      topRight: radius,
      bottomRight: radius,
    );
  }
}

class _AvatarSpace extends StatelessWidget {
  const _AvatarSpace({required this.theme, required this.avatar});

  final WenzChatThemeData theme;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final diameter = theme.avatarRadius * 2;
    return SizedBox(width: diameter, height: diameter, child: avatar);
  }
}

class _MessageMeta extends StatelessWidget {
  const _MessageMeta({
    required this.message,
    required this.isOutgoing,
    required this.theme,
  });

  final WenzChatMessage message;
  final bool isOutgoing;
  final WenzChatThemeData theme;

  @override
  Widget build(BuildContext context) {
    final baseColor = isOutgoing
        ? theme.outgoingTextStyle.color?.withValues(alpha: 0.72)
        : theme.timestampTextStyle.color;
    final style = theme.timestampTextStyle.copyWith(color: baseColor);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text(_formatTime(message.sentAt), style: style),
        if (isOutgoing) ...[
          const SizedBox(width: 4),
          Icon(
            _statusIcon(message.status),
            size: 12,
            color: message.status == WenzChatMessageStatus.failed
                ? theme.failedColor
                : baseColor,
          ),
        ],
      ],
    );
  }
}

IconData _statusIcon(WenzChatMessageStatus status) {
  return switch (status) {
    WenzChatMessageStatus.sending => Icons.schedule,
    WenzChatMessageStatus.sent => Icons.check,
    WenzChatMessageStatus.delivered => Icons.done_all,
    WenzChatMessageStatus.read => Icons.done_all,
    WenzChatMessageStatus.failed => Icons.error_outline,
  };
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
