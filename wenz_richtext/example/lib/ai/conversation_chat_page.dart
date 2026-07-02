import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

/// Chat page for a single AI conversation.
///
/// Displays the message history as chat bubbles, renders status indicators
/// during streaming, and provides a text input bar at the bottom.
class ConversationChatPage extends StatefulWidget {
  const ConversationChatPage({
    super.key,
    required this.conversationManager,
    required this.configManager,
    required this.conversationId,
  });

  final ConversationManager conversationManager;
  final AIConfigManager configManager;
  final String conversationId;

  @override
  State<ConversationChatPage> createState() => _ConversationChatPageState();
}

class _ConversationChatPageState extends State<ConversationChatPage> {
  ConversationManager get _manager => widget.conversationManager;
  String get _convId => widget.conversationId;

  final _scrollController = ScrollController();
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();

  /// Locally accumulated streaming content for the in-progress assistant
  /// message, displayed in real-time between manager notifications.
  String _streamingContent = '';

  /// Whether a message is currently being sent.
  bool _isSending = false;

  StreamSubscription<String>? _streamSub;

  Conversation? get _conversation => _manager.getConversation(_convId);

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onConversationChanged);
    // Scroll to bottom after initial layout.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _manager.removeListener(_onConversationChanged);
    _scrollController.dispose();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------

  void _onConversationChanged() {
    if (!mounted) return;

    final conv = _conversation;
    if (conv == null) return;

    // When streaming completes or errors, clear local streaming state.
    if (conv.status == ConversationStatus.idle ||
        conv.status == ConversationStatus.error) {
      _streamingContent = '';
      _isSending = false;
    }

    setState(() {});
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Send message
  // ---------------------------------------------------------------------------

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    _textCtrl.clear();
    setState(() {
      _isSending = true;
      _streamingContent = '';
    });

    // Scroll to bottom after user message is added.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final stream = _manager.sendMessage(_convId, text);
      _streamSub = stream.listen(
        (token) {
          _streamingContent += token;
          if (mounted) {
            setState(() {});
            _scrollToBottom();
          }
        },
        onError: (e) {
          _isSending = false;
          if (mounted) setState(() {});
        },
        onDone: () {
          _streamSub = null;
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final conv = _conversation;

    return Scaffold(
      appBar: AppBar(
        title: Text(conv?.title ?? '对话'),
        centerTitle: true,
      ),
      body: conv == null
          ? const Center(child: Text('对话不存在'))
          : Column(
              children: [
                // --- Messages ---
                Expanded(
                  child: GestureDetector(
                    onTap: () => _focusNode.unfocus(),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: conv.messages.length +
                          (_isSending && _streamingContent.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Last item may be the streaming placeholder.
                        if (_isSending &&
                            _streamingContent.isNotEmpty &&
                            index == conv.messages.length) {
                          return _buildStreamingBubble(_streamingContent);
                        }
                        return _buildMessageBubble(
                          conv.messages[index],
                          isLastAssistant:
                              index == conv.messages.length - 1 &&
                              conv.messages[index].role ==
                                  MessageRole.assistant,
                          convStatus: conv.status,
                        );
                      },
                    ),
                  ),
                ),

                // --- Status bar ---
                _buildStatusBar(conv.status),

                // --- Input bar ---
                _buildInputBar(),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status bar
  // ---------------------------------------------------------------------------

  Widget _buildStatusBar(ConversationStatus status) {
    if (status == ConversationStatus.idle) return const SizedBox.shrink();

    final Color bgColor;
    final IconData icon;
    final String text;
    final bool showLoading;

    switch (status) {
      case ConversationStatus.thinking:
        bgColor = Colors.orange.shade50;
        icon = Icons.psychology_outlined;
        text = '思考中…';
        showLoading = true;
      case ConversationStatus.replying:
        bgColor = Colors.blue.shade50;
        icon = Icons.chat_outlined;
        text = '回复中…';
        showLoading = false;
      case ConversationStatus.error:
        bgColor = Colors.red.shade50;
        icon = Icons.error_outline;
        text = '出错啦';
        showLoading = false;
      case ConversationStatus.idle:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: bgColor,
      child: Row(
        children: [
          if (showLoading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          if (status == ConversationStatus.error)
            TextButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重试', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Input bar
  // ---------------------------------------------------------------------------

  Widget _buildInputBar() {
    final conv = _conversation;
    final disabled =
        _isSending || (conv != null && conv.status != ConversationStatus.idle);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                focusNode: _focusNode,
                enabled: !disabled,
                decoration: const InputDecoration(
                  hintText: '输入消息…',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: disabled ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Message bubbles
  // ---------------------------------------------------------------------------

  Widget _buildMessageBubble(
    ChatMessage message, {
    required bool isLastAssistant,
    required ConversationStatus convStatus,
  }) {
    final isUser = message.role == MessageRole.user;
    final isError = message.error != null && message.error!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) const SizedBox(width: 4),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isError
                    ? Colors.red.shade100
                    : isUser
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Error indicator.
                  if (isError) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 14, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '错误',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Message content.
                  SelectableText(
                    message.content,
                    style: TextStyle(
                      color: isUser
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  // Replying tag on last assistant message.
                  if (isLastAssistant &&
                      !isError &&
                      convStatus == ConversationStatus.replying &&
                      message.content.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '回复中…',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  // Error detail.
                  if (isError) ...[
                    const SizedBox(height: 4),
                    Text(
                      message.error!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// Renders the in-progress streaming bubble before the manager finalizes
  /// the assistant message.
  Widget _buildStreamingBubble(String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 4),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    content,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '回复中…',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Retry
  // ---------------------------------------------------------------------------

  void _retry() {
    final conv = _conversation;
    if (conv == null || conv.messages.isEmpty) return;

    // Re-send the last user message.
    final lastUserMsg = conv.messages
        .where((m) => m.role == MessageRole.user)
        .toList();
    if (lastUserMsg.isEmpty) return;
    final lastContent = lastUserMsg.last.content;

    _textCtrl.text = lastContent;
    _sendMessage();
  }
}
