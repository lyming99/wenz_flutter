import 'package:flutter/material.dart';

import '../core/model/comment_model.dart';
import '../core/position/document_position.dart';

typedef CommentThreadCallback = void Function(CommentThread thread);
typedef CommentAnchorSelectionCallback = void Function(
  CommentThread thread,
  DocumentSelection selection,
);

class WenzCommentSidebar extends StatelessWidget {
  const WenzCommentSidebar({
    super.key,
    required this.threads,
    this.activeThreadId,
    this.showResolved = true,
    this.width = 320,
    this.onSelectThread,
    this.onRevealAnchor,
    this.onResolveThread,
    this.onReopenThread,
    this.emptyBuilder,
  });

  final List<CommentThread> threads;
  final String? activeThreadId;
  final bool showResolved;
  final double width;
  final CommentThreadCallback? onSelectThread;
  final CommentAnchorSelectionCallback? onRevealAnchor;
  final CommentThreadCallback? onResolveThread;
  final CommentThreadCallback? onReopenThread;
  final WidgetBuilder? emptyBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleThreads = showResolved
        ? threads
        : threads.where((thread) => thread.isOpen).toList();
    return SizedBox(
      width: width,
      child: Material(
        key: const ValueKey<String>('wenz-comment-sidebar-surface'),
        color: theme.colorScheme.surface,
        elevation: 1,
        shadowColor: theme.colorScheme.shadow.withAlpha(32),
        surfaceTintColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _CommentSidebarHeader(
              openCount: threads.where((thread) => thread.isOpen).length,
              totalCount: threads.length,
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            if (visibleThreads.isEmpty)
              Expanded(
                child: emptyBuilder?.call(context) ?? const _EmptyComments(),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: visibleThreads.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final thread = visibleThreads[index];
                    return _CommentThreadCard(
                      thread: thread,
                      isActive: thread.id == activeThreadId,
                      onTap: () => _selectAndReveal(thread),
                      onReveal: onRevealAnchor == null
                          ? null
                          : () =>
                              onRevealAnchor!(thread, thread.anchor.selection),
                      onResolve: thread.isOpen && onResolveThread != null
                          ? () => onResolveThread!(thread)
                          : null,
                      onReopen: thread.isResolved && onReopenThread != null
                          ? () => onReopenThread!(thread)
                          : null,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _selectAndReveal(CommentThread thread) {
    onSelectThread?.call(thread);
    onRevealAnchor?.call(thread, thread.anchor.selection);
  }
}

class _CommentSidebarHeader extends StatelessWidget {
  const _CommentSidebarHeader(
      {required this.openCount, required this.totalCount});

  final int openCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.mode_comment_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Comments',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            '$openCount open / $totalCount total',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentThreadCard extends StatelessWidget {
  const _CommentThreadCard({
    required this.thread,
    required this.isActive,
    required this.onTap,
    this.onReveal,
    this.onResolve,
    this.onReopen,
  });

  final CommentThread thread;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onReveal;
  final VoidCallback? onResolve;
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final firstMessage = thread.firstMessage;
    final lastMessage = thread.lastMessage;
    return Card(
      key: ValueKey<String>('wenz-comment-thread-${thread.id}'),
      color: isActive
          ? colorScheme.primaryContainer.withAlpha(
              theme.brightness == Brightness.dark ? 72 : 48,
            )
          : colorScheme.surfaceContainerLow,
      elevation: isActive ? 2 : 0,
      shadowColor: colorScheme.shadow.withAlpha(32),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isActive ? colorScheme.primary : colorScheme.outlineVariant,
          width: isActive ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _StatusChip(status: thread.status),
                  const Spacer(),
                  if (onReveal != null)
                    IconButton(
                      key: ValueKey<String>('wenz-comment-reveal-${thread.id}'),
                      tooltip: '在文档中显示',
                      icon: const Icon(Icons.my_location, size: 18),
                      onPressed: onReveal,
                    ),
                  if (onResolve != null)
                    IconButton(
                      key:
                          ValueKey<String>('wenz-comment-resolve-${thread.id}'),
                      tooltip: '解决评论',
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      onPressed: onResolve,
                    ),
                  if (onReopen != null)
                    IconButton(
                      key: ValueKey<String>('wenz-comment-reopen-${thread.id}'),
                      tooltip: '重新打开评论',
                      icon: const Icon(Icons.undo, size: 18),
                      onPressed: onReopen,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                firstMessage?.authorName.isNotEmpty == true
                    ? firstMessage!.authorName
                    : 'Unknown author',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                firstMessage?.text.isNotEmpty == true
                    ? firstMessage!.text
                    : 'No comment text',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${thread.messages.length} message${thread.messages.length == 1 ? '' : 's'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (lastMessage != null) ...<Widget>[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          _formatTimestamp(lastMessage.createdAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final CommentThreadStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isResolved = status == CommentThreadStatus.resolved;
    return Chip(
      label: Text(isResolved ? 'Resolved' : 'Open'),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: isResolved
          ? colorScheme.secondaryContainer
          : colorScheme.primaryContainer,
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        color: isResolved
            ? colorScheme.onSecondaryContainer
            : colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EmptyComments extends StatelessWidget {
  const _EmptyComments();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        'No comments',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
