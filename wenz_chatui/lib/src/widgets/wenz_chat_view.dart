import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controller/wenz_chat_controller.dart';
import '../model/wenz_chat_message.dart';
import '../theme/wenz_chat_theme.dart';
import 'wenz_chat_bubble.dart';

/// Controls what happens when a new message arrives while the view is at the
/// bottom of the timeline.
enum WenzChatAutoScrollBehavior { disabled, jump, animate }

/// Immutable details calculated for a rendered message.
@immutable
class WenzChatItemContext {
  const WenzChatItemContext({
    required this.index,
    required this.isOutgoing,
    required this.groupPosition,
    required this.isFirstMessageOfDay,
    required this.showAvatar,
    required this.showTimestamp,
  });

  /// Chronological index, where zero is the oldest message.
  final int index;
  final bool isOutgoing;
  final WenzChatGroupPosition groupPosition;
  final bool isFirstMessageOfDay;
  final bool showAvatar;
  final bool showTimestamp;
}

typedef WenzChatMessageBuilder =
    Widget Function(
      BuildContext context,
      WenzChatMessage message,
      WenzChatItemContext itemContext,
    );

typedef WenzChatAvatarBuilder =
    Widget Function(BuildContext context, WenzChatMessage message);

typedef WenzChatDateSeparatorBuilder =
    Widget Function(BuildContext context, DateTime date);

typedef WenzChatMessageCallback = void Function(WenzChatMessage message);
typedef WenzChatLoadOlderCallback = Future<void> Function();
typedef WenzChatLoadErrorCallback =
    void Function(Object error, StackTrace stackTrace);

/// A virtualized, reversed chat timeline optimized for large histories and
/// streaming updates.
///
/// Messages in [controller] are chronological. Internally the sliver is
/// reversed so scroll offset zero remains the conversation bottom and
/// prepending history does not disturb the visible anchor.
class WenzChatView extends StatefulWidget {
  const WenzChatView({
    required this.controller,
    required this.currentUserId,
    this.scrollController,
    this.messageBuilder,
    this.avatarBuilder,
    this.dateSeparatorBuilder,
    this.emptyBuilder,
    this.loadingOlderBuilder,
    this.newMessagesIndicatorBuilder,
    this.onLoadOlder,
    this.onLoadOlderError,
    this.onMessageTap,
    this.onMessageLongPress,
    this.theme,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 12),
    this.cacheExtent = 600,
    this.loadOlderThreshold = 240,
    this.bottomThreshold = 72,
    this.groupingInterval = const Duration(minutes: 5),
    this.autoScrollBehavior = WenzChatAutoScrollBehavior.animate,
    this.autoScrollDuration = const Duration(milliseconds: 180),
    this.autoScrollCurve = Curves.easeOutCubic,
    this.showOutgoingAvatar = false,
    this.selectableText = false,
    this.addAutomaticKeepAlives = false,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    this.physics,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    super.key,
  }) : assert(currentUserId != ''),
       assert(cacheExtent >= 0),
       assert(loadOlderThreshold >= 0),
       assert(bottomThreshold >= 0);

  final WenzChatController controller;
  final String currentUserId;
  final ScrollController? scrollController;
  final WenzChatMessageBuilder? messageBuilder;
  final WenzChatAvatarBuilder? avatarBuilder;
  final WenzChatDateSeparatorBuilder? dateSeparatorBuilder;
  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? loadingOlderBuilder;

  /// Builds the floating indicator shown when messages arrive away from the
  /// bottom. The integer is the number of newly appended messages.
  final Widget Function(BuildContext context, int count)?
  newMessagesIndicatorBuilder;

  final WenzChatLoadOlderCallback? onLoadOlder;
  final WenzChatLoadErrorCallback? onLoadOlderError;
  final WenzChatMessageCallback? onMessageTap;
  final WenzChatMessageCallback? onMessageLongPress;
  final WenzChatThemeData? theme;
  final EdgeInsetsGeometry padding;
  final double cacheExtent;
  final double loadOlderThreshold;
  final double bottomThreshold;
  final Duration groupingInterval;
  final WenzChatAutoScrollBehavior autoScrollBehavior;
  final Duration autoScrollDuration;
  final Curve autoScrollCurve;
  final bool showOutgoingAvatar;
  final bool selectableText;
  final bool addAutomaticKeepAlives;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final ScrollPhysics? physics;
  final Clip clipBehavior;
  final String? restorationId;

  @override
  State<WenzChatView> createState() => WenzChatViewState();
}

/// State methods are public so a host can expose explicit scroll actions.
class WenzChatViewState extends State<WenzChatView> {
  late ScrollController _scrollController;
  bool _ownsScrollController = false;
  bool _isLoadingOlder = false;
  bool _scrollScheduled = false;
  int _unreadCount = 0;
  int _lastHandledMutation = 0;

  ScrollController get scrollController => _scrollController;
  bool get isLoadingOlder => _isLoadingOlder;
  int get unreadCount => _unreadCount;

  bool get isNearBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels <= widget.bottomThreshold;
  }

  @override
  void initState() {
    super.initState();
    _adoptScrollController(widget.scrollController);
    widget.controller.structureListenable.addListener(_handleStructureChange);
    _lastHandledMutation = widget.controller.lastMutation?.sequence ?? 0;
  }

  @override
  void didUpdateWidget(WenzChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.structureListenable.removeListener(
        _handleStructureChange,
      );
      widget.controller.structureListenable.addListener(_handleStructureChange);
      _lastHandledMutation = widget.controller.lastMutation?.sequence ?? 0;
      _unreadCount = 0;
    }
    if (oldWidget.scrollController != widget.scrollController) {
      if (_ownsScrollController) _scrollController.dispose();
      _adoptScrollController(widget.scrollController);
    }
  }

  void _adoptScrollController(ScrollController? supplied) {
    _ownsScrollController = supplied == null;
    _scrollController = supplied ?? ScrollController();
  }

  void _handleStructureChange() {
    if (!mounted) return;
    final mutation = widget.controller.lastMutation;
    if (mutation == null || mutation.sequence == _lastHandledMutation) return;
    _lastHandledMutation = mutation.sequence;

    final shouldFollow = isNearBottom;
    setState(() {
      if (mutation.type == WenzChatMutationType.append) {
        if (!shouldFollow) {
          _unreadCount += mutation.messageIds.length;
        }
      } else if (mutation.type == WenzChatMutationType.clear ||
          mutation.type == WenzChatMutationType.replaceAll) {
        _unreadCount = 0;
      }
    });

    if (mutation.type == WenzChatMutationType.append && shouldFollow) {
      _scheduleScrollToBottom();
    }
  }

  /// Moves to the newest message and clears the unread indicator.
  Future<void> scrollToBottom({bool animated = true}) async {
    if (_unreadCount != 0 && mounted) {
      setState(() => _unreadCount = 0);
    }
    if (!_scrollController.hasClients) return;
    if (animated) {
      await _scrollController.animateTo(
        0,
        duration: widget.autoScrollDuration,
        curve: widget.autoScrollCurve,
      );
    } else {
      _scrollController.jumpTo(0);
    }
  }

  void _scheduleScrollToBottom() {
    if (widget.autoScrollBehavior == WenzChatAutoScrollBehavior.disabled ||
        _scrollScheduled) {
      return;
    }
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      unawaited(
        scrollToBottom(
          animated:
              widget.autoScrollBehavior == WenzChatAutoScrollBehavior.animate,
        ),
      );
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      if (notification.metrics.pixels <= widget.bottomThreshold &&
          _unreadCount != 0) {
        setState(() => _unreadCount = 0);
      }
      final distanceToOldest =
          notification.metrics.maxScrollExtent - notification.metrics.pixels;
      if (distanceToOldest <= widget.loadOlderThreshold) {
        unawaited(_loadOlder());
      }
    }
    return false;
  }

  Future<void> _loadOlder() async {
    final callback = widget.onLoadOlder;
    if (callback == null || _isLoadingOlder) return;
    setState(() => _isLoadingOlder = true);
    try {
      await callback();
    } catch (error, stackTrace) {
      final errorCallback = widget.onLoadOlderError;
      if (errorCallback != null) {
        errorCallback(error, stackTrace);
      } else {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'wenz_chatui',
            context: ErrorDescription('while loading older chat messages'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingOlder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? WenzChatTheme.of(context);
    if (widget.controller.isEmpty) {
      return ColoredBox(
        color: theme.backgroundColor,
        child:
            widget.emptyBuilder?.call(context) ??
            const Center(child: Text('No messages')),
      );
    }

    return ColoredBox(
      color: theme.backgroundColor,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: CustomScrollView(
                controller: _scrollController,
                reverse: true,
                cacheExtent: widget.cacheExtent,
                keyboardDismissBehavior: widget.keyboardDismissBehavior,
                physics: widget.physics,
                clipBehavior: widget.clipBehavior,
                restorationId: widget.restorationId,
                semanticChildCount: widget.controller.length,
                slivers: <Widget>[
                  SliverPadding(
                    padding: widget.padding,
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, builderIndex) =>
                            _buildItem(context, builderIndex, theme),
                        childCount:
                            widget.controller.length +
                            (_isLoadingOlder ? 1 : 0),
                        addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
                        addRepaintBoundaries: true,
                        addSemanticIndexes: true,
                        semanticIndexCallback: (child, localIndex) {
                          if (localIndex >= widget.controller.length) {
                            return null;
                          }
                          return widget.controller.length - localIndex - 1;
                        },
                        findChildIndexCallback: _findChildIndex,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_unreadCount > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(child: _buildUnreadIndicator(context)),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    int builderIndex,
    WenzChatThemeData theme,
  ) {
    final messageCount = widget.controller.length;
    if (builderIndex == messageCount) {
      return KeyedSubtree(
        key: const ValueKey<_LoadingOlderKey>(_LoadingOlderKey()),
        child:
            widget.loadingOlderBuilder?.call(context) ??
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
      );
    }

    final chronologicalIndex = messageCount - builderIndex - 1;
    final message = widget.controller.messageAt(chronologicalIndex);
    return _WenzChatMessageCell(
      key: ValueKey<String>(message.id),
      messageId: message.id,
      messageListenable: widget.controller.messageListenableAt(
        chronologicalIndex,
      ),
      controller: widget.controller,
      currentUserId: widget.currentUserId,
      groupingInterval: widget.groupingInterval,
      theme: theme,
      messageBuilder: widget.messageBuilder,
      avatarBuilder: widget.avatarBuilder,
      dateSeparatorBuilder: widget.dateSeparatorBuilder,
      onMessageTap: widget.onMessageTap,
      onMessageLongPress: widget.onMessageLongPress,
      showOutgoingAvatar: widget.showOutgoingAvatar,
      selectableText: widget.selectableText,
    );
  }

  int? _findChildIndex(Key key) {
    if (key == const ValueKey<_LoadingOlderKey>(_LoadingOlderKey())) {
      return _isLoadingOlder ? widget.controller.length : null;
    }
    if (key is! ValueKey<String>) return null;
    final chronologicalIndex = widget.controller.indexOf(key.value);
    if (chronologicalIndex < 0) return null;
    return widget.controller.length - chronologicalIndex - 1;
  }

  Widget _buildUnreadIndicator(BuildContext context) {
    final custom = widget.newMessagesIndicatorBuilder;
    if (custom != null) {
      return GestureDetector(
        onTap: scrollToBottom,
        child: custom(context, _unreadCount),
      );
    }
    return FilledButton.tonalIcon(
      onPressed: scrollToBottom,
      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
      label: Text('$_unreadCount new'),
    );
  }

  @override
  void dispose() {
    widget.controller.structureListenable.removeListener(
      _handleStructureChange,
    );
    if (_ownsScrollController) _scrollController.dispose();
    super.dispose();
  }
}

class _WenzChatMessageCell extends StatelessWidget {
  const _WenzChatMessageCell({
    required this.messageId,
    required this.messageListenable,
    required this.controller,
    required this.currentUserId,
    required this.groupingInterval,
    required this.theme,
    required this.messageBuilder,
    required this.avatarBuilder,
    required this.dateSeparatorBuilder,
    required this.onMessageTap,
    required this.onMessageLongPress,
    required this.showOutgoingAvatar,
    required this.selectableText,
    super.key,
  });

  final String messageId;
  final ValueListenable<WenzChatMessage> messageListenable;
  final WenzChatController controller;
  final String currentUserId;
  final Duration groupingInterval;
  final WenzChatThemeData theme;
  final WenzChatMessageBuilder? messageBuilder;
  final WenzChatAvatarBuilder? avatarBuilder;
  final WenzChatDateSeparatorBuilder? dateSeparatorBuilder;
  final WenzChatMessageCallback? onMessageTap;
  final WenzChatMessageCallback? onMessageLongPress;
  final bool showOutgoingAvatar;
  final bool selectableText;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WenzChatMessage>(
      valueListenable: messageListenable,
      builder: (context, message, _) {
        final index = controller.indexOf(messageId);
        if (index < 0) return const SizedBox.shrink();
        final previous = index > 0 ? controller.messageAt(index - 1) : null;
        final next = index + 1 < controller.length
            ? controller.messageAt(index + 1)
            : null;
        final sameAsPrevious = _isGrouped(previous, message);
        final sameAsNext = _isGrouped(message, next);
        final groupPosition = _groupPosition(sameAsPrevious, sameAsNext);
        final isFirstMessageOfDay =
            previous == null ||
            !_isSameLocalDay(previous.sentAt, message.sentAt);
        final isOutgoing = message.authorId == currentUserId;
        final groupEnds = !sameAsNext;
        final showAvatar = groupEnds && (!isOutgoing || showOutgoingAvatar);
        final itemContext = WenzChatItemContext(
          index: index,
          isOutgoing: isOutgoing,
          groupPosition: groupPosition,
          isFirstMessageOfDay: isFirstMessageOfDay,
          showAvatar: showAvatar,
          showTimestamp: groupEnds,
        );

        final customBuilder = messageBuilder;
        final content = customBuilder != null
            ? _withMessageGestures(
                customBuilder(context, message, itemContext),
                message,
              )
            : WenzChatBubble(
                message: message,
                isOutgoing: isOutgoing,
                groupPosition: groupPosition,
                theme: theme,
                avatar: showAvatar ? _buildAvatar(context, message) : null,
                showTimestamp: groupEnds,
                selectableText: selectableText,
                onTap: onMessageTap == null
                    ? null
                    : () => onMessageTap!(message),
                onLongPress: onMessageLongPress == null
                    ? null
                    : () => onMessageLongPress!(message),
              );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (isFirstMessageOfDay)
              dateSeparatorBuilder?.call(context, message.sentAt) ??
                  _DefaultDateSeparator(date: message.sentAt, theme: theme),
            SizedBox(
              height: sameAsPrevious
                  ? theme.messageSpacing
                  : theme.groupSpacing,
            ),
            content,
          ],
        );
      },
    );
  }

  bool _isGrouped(WenzChatMessage? older, WenzChatMessage? newer) {
    if (older == null || newer == null) return false;
    if (older.kind == WenzChatMessageKind.system ||
        newer.kind == WenzChatMessageKind.system ||
        older.authorId != newer.authorId) {
      return false;
    }
    final delta = newer.sentAt.difference(older.sentAt).abs();
    return delta <= groupingInterval &&
        _isSameLocalDay(older.sentAt, newer.sentAt);
  }

  Widget _buildAvatar(BuildContext context, WenzChatMessage message) {
    final customBuilder = avatarBuilder;
    if (customBuilder != null) return customBuilder(context, message);
    final name = (message.authorName ?? message.authorId).trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return CircleAvatar(
      radius: theme.avatarRadius,
      backgroundColor: theme.avatarBackgroundColor,
      foregroundColor: theme.avatarForegroundColor,
      child: Text(initial),
    );
  }

  Widget _withMessageGestures(Widget child, WenzChatMessage message) {
    if (onMessageTap == null && onMessageLongPress == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onMessageTap == null ? null : () => onMessageTap!(message),
      onLongPress: onMessageLongPress == null
          ? null
          : () => onMessageLongPress!(message),
      child: child,
    );
  }
}

class _LoadingOlderKey {
  const _LoadingOlderKey();
}

class _DefaultDateSeparator extends StatelessWidget {
  const _DefaultDateSeparator({required this.date, required this.theme});

  final DateTime date;
  final WenzChatThemeData theme;

  @override
  Widget build(BuildContext context) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final difference = today.difference(day).inDays;
    final label = switch (difference) {
      0 => 'Today',
      1 => 'Yesterday',
      _ =>
        '${local.year}-${local.month.toString().padLeft(2, '0')}-'
            '${local.day.toString().padLeft(2, '0')}',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(child: Text(label, style: theme.dateSeparatorTextStyle)),
    );
  }
}

WenzChatGroupPosition _groupPosition(bool hasPrevious, bool hasNext) {
  if (hasPrevious && hasNext) return WenzChatGroupPosition.middle;
  if (hasPrevious) return WenzChatGroupPosition.last;
  if (hasNext) return WenzChatGroupPosition.first;
  return WenzChatGroupPosition.single;
}

bool _isSameLocalDay(DateTime first, DateTime second) {
  final a = first.toLocal();
  final b = second.toLocal();
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
