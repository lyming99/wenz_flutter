import 'package:flutter/material.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'ai_config_page.dart';
import 'conversation_chat_page.dart';

/// Page that lists all AI conversations.
///
/// Provides create / delete operations and navigates to
/// [ConversationChatPage] on tap.
class ConversationListPage extends StatefulWidget {
  const ConversationListPage({
    super.key,
    required this.conversationManager,
    required this.configManager,
  });

  final ConversationManager conversationManager;
  final AIConfigManager configManager;

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  ConversationManager get _convManager => widget.conversationManager;
  AIConfigManager get _configManager => widget.configManager;

  @override
  void initState() {
    super.initState();
    _convManager.addListener(_onChanged);
  }

  @override
  void dispose() {
    _convManager.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final conversations = _convManager.conversations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 对话'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'AI 配置',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AIConfigPage(configManager: _configManager),
                ),
              );
            },
          ),
        ],
      ),
      body: conversations.isEmpty
          ? Center(
              child: Text(
                '暂无对话，点击右下角按钮新建',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                return _buildConversationTile(conversations[index]);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createConversation,
        tooltip: '新建对话',
        child: const Icon(Icons.add),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Conversation tile
  // ---------------------------------------------------------------------------

  Widget _buildConversationTile(Conversation conv) {
    final theme = Theme.of(context);
    final messageCount = conv.messages.length;
    final lastUpdated = _formatTime(conv.updatedAt);

    // Resolve provider name for subtitle.
    final config = _configManager.getConfig(conv.aiConfigId);
    final providerLabel =
        config != null ? (config is OpenAIConfig ? 'OpenAI' : 'DeepSeek') : '—';

    return Dismissible(
      key: Key(conv.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(conv),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.chat_bubble_outline,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          conv.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$providerLabel  ·  $messageCount 条消息  ·  $lastUpdated',
          style: theme.textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openChat(conv),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<bool> _confirmDelete(Conversation conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定要删除「${conv.title}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _convManager.deleteConversation(conv.id);
    }
    return false;
  }

  void _openChat(Conversation conv) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationChatPage(
          conversationManager: _convManager,
          configManager: _configManager,
          conversationId: conv.id,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Create conversation dialog
  // ---------------------------------------------------------------------------

  Future<void> _createConversation() async {
    final configs = _configManager.configs;
    if (configs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先创建至少一个 AI 配置')),
        );
      }
      return;
    }

    final titleCtrl = TextEditingController();
    final systemPromptCtrl = TextEditingController();
    String? selectedConfigId = configs.first.id;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('新建对话'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: '对话标题',
                        hintText: '例如：代码审查助手',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedConfigId,
                      decoration: const InputDecoration(labelText: 'AI 配置'),
                      items: configs.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            '${c.name} (${c is OpenAIConfig ? 'OpenAI' : 'DeepSeek'} · ${c.model})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedConfigId = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: systemPromptCtrl,
                      decoration: const InputDecoration(
                        labelText: 'System Prompt（可选）',
                        hintText: '设定 AI 的角色和行为',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) return;
                    Navigator.of(ctx).pop({
                      'title': titleCtrl.text.trim(),
                      'configId': selectedConfigId!,
                      'systemPrompt': systemPromptCtrl.text.trim(),
                    });
                  },
                  child: const Text('创建'),
                ),
              ],
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    systemPromptCtrl.dispose();

    if (result == null) return;

    await _convManager.createConversation(
      title: result['title']!,
      aiConfigId: result['configId']!,
      systemPrompt:
          result['systemPrompt']!.isEmpty ? null : result['systemPrompt'],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${dt.month}/${dt.day}';
  }
}
