import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

/// Page for managing AI service configurations (OpenAI / DeepSeek).
///
/// Displays a list of all stored configs and allows creating, editing, deleting,
/// and testing connections.
class AIConfigPage extends StatefulWidget {
  const AIConfigPage({super.key, required this.configManager});

  /// The [AIConfigManager] that owns the persisted config list.
  final AIConfigManager configManager;

  @override
  State<AIConfigPage> createState() => _AIConfigPageState();
}

class _AIConfigPageState extends State<AIConfigPage> {
  AIConfigManager get _manager => widget.configManager;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onChanged);
  }

  @override
  void dispose() {
    _manager.removeListener(_onChanged);
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
    final configs = _manager.configs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 配置管理'),
        centerTitle: true,
      ),
      body: configs.isEmpty
          ? Center(
              child: Text(
                '暂无 AI 配置，点击右下角按钮创建',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: configs.length,
              itemBuilder: (context, index) => _buildConfigTile(configs[index]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: '新建配置',
        child: const Icon(Icons.add),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Config tile
  // ---------------------------------------------------------------------------

  Widget _buildConfigTile(AIConfig config) {
    final theme = Theme.of(context);
    final isOpenAI = config is OpenAIConfig;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(
          isOpenAI ? Icons.auto_awesome : Icons.smart_toy_outlined,
          color: isOpenAI ? Colors.teal : Colors.deepPurple,
        ),
        title: Text(config.name),
        subtitle: Text(
          '${isOpenAI ? 'OpenAI' : 'DeepSeek'}  ·  ${config.model}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '编辑',
              onPressed: () => _openEditor(existing: config),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              tooltip: '删除',
              onPressed: () => _confirmDelete(config),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  Future<void> _confirmDelete(AIConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除配置'),
        content: Text('确定要删除「${config.name}」吗？此操作不可撤销。'),
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
      await _manager.deleteConfig(config.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Editor dialog
  // ---------------------------------------------------------------------------

  Future<void> _openEditor({AIConfig? existing}) async {
    final result = await showDialog<AIConfig>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConfigEditorDialog(existing: existing),
    );
    if (result == null) return;

    if (existing != null) {
      await _manager.updateConfig(result);
    } else {
      await _manager.addConfig(result);
    }
  }
}

// =============================================================================
// Editor dialog
// =============================================================================

class _ConfigEditorDialog extends StatefulWidget {
  const _ConfigEditorDialog({required this.existing});

  final AIConfig? existing;

  @override
  State<_ConfigEditorDialog> createState() => _ConfigEditorDialogState();
}

class _ConfigEditorDialogState extends State<_ConfigEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _orgIdCtrl;
  late final TextEditingController _maxTokensCtrl;

  AIProvider _provider = AIProvider.openai;
  ThinkingDepth _thinkingDepth = ThinkingDepth.medium;
  DeepSeekThinkingMode _thinkingMode = DeepSeekThinkingMode.disabled;
  bool _testing = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _apiKeyCtrl = TextEditingController(text: existing?.apiKey ?? '');
    _modelCtrl = TextEditingController(
      text: existing?.model ??
          (existing is DeepSeekConfig ? 'deepseek-chat' : 'gpt-4o'),
    );
    _baseUrlCtrl = TextEditingController(text: existing?.baseUrl ?? '');
    _provider = existing?.provider ?? AIProvider.openai;

    if (existing is OpenAIConfig) {
      _thinkingDepth = existing.thinkingDepth;
      _orgIdCtrl = TextEditingController(text: existing.organizationId ?? '');
      _thinkingMode = DeepSeekThinkingMode.disabled;
      _maxTokensCtrl = TextEditingController();
    } else if (existing is DeepSeekConfig) {
      _thinkingMode = existing.thinkingMode;
      _maxTokensCtrl = TextEditingController(
        text: existing.maxTokens?.toString() ?? '',
      );
      _thinkingDepth = ThinkingDepth.medium;
      _orgIdCtrl = TextEditingController();
    } else {
      _orgIdCtrl = TextEditingController();
      _maxTokensCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _baseUrlCtrl.dispose();
    _orgIdCtrl.dispose();
    _maxTokensCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Provider change
  // ---------------------------------------------------------------------------

  void _onProviderChanged(AIProvider? value) {
    if (value == null || value == _provider) return;
    setState(() {
      _provider = value;
      // Reset model to sensible default for the chosen provider.
      if (!_isEditing) {
        _modelCtrl.text = value == AIProvider.deepseek ? 'deepseek-chat' : 'gpt-4o';
      }
      // Clear provider-specific defaults when toggling.
      if (value == AIProvider.deepseek && _baseUrlCtrl.text.isEmpty) {
        _baseUrlCtrl.text = 'https://api.deepseek.com/v1';
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Test connection
  // ---------------------------------------------------------------------------

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _testing = true);
    try {
      final config = _buildConfig();
      final service = AIServiceFactory.create(_provider);
      await service.validateConfig(config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('连接测试成功 ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_buildConfig());
  }

  AIConfig _buildConfig() {
    final now = DateTime.now();

    if (_provider == AIProvider.openai) {
      return OpenAIConfig(
        id: widget.existing?.id ?? _uuid.v4(),
        name: _nameCtrl.text.trim(),
        apiKey: _apiKeyCtrl.text.trim(),
        baseUrl: _baseUrlCtrl.text.trim().isEmpty
            ? null
            : _baseUrlCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
        thinkingDepth: _thinkingDepth,
        organizationId: _orgIdCtrl.text.trim().isEmpty
            ? null
            : _orgIdCtrl.text.trim(),
      );
    } else {
      final maxTokens = int.tryParse(_maxTokensCtrl.text.trim());
      return DeepSeekConfig(
        id: widget.existing?.id ?? _uuid.v4(),
        name: _nameCtrl.text.trim(),
        apiKey: _apiKeyCtrl.text.trim(),
        baseUrl: _baseUrlCtrl.text.trim().isEmpty
            ? null
            : _baseUrlCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
        thinkingMode: _thinkingMode,
        maxTokens: maxTokens,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isOpenAI = _provider == AIProvider.openai;

    return AlertDialog(
      title: Text(_isEditing ? '编辑 AI 配置' : '新建 AI 配置'),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Name ---
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '配置名称',
                  hintText: '例如：我的 OpenAI 账号',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '名称不能为空' : null,
              ),
              const SizedBox(height: 12),

              // --- Provider ---
              DropdownButtonFormField<AIProvider>(
                initialValue: _provider,
                decoration: const InputDecoration(labelText: '提供商'),
                items: const [
                  DropdownMenuItem(
                    value: AIProvider.openai,
                    child: Text('OpenAI'),
                  ),
                  DropdownMenuItem(
                    value: AIProvider.deepseek,
                    child: Text('DeepSeek'),
                  ),
                ],
                onChanged: _onProviderChanged,
              ),
              const SizedBox(height: 12),

              // --- API Key ---
              TextFormField(
                controller: _apiKeyCtrl,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                ),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'API Key 不能为空' : null,
              ),
              const SizedBox(height: 12),

              // --- Model ---
              TextFormField(
                controller: _modelCtrl,
                decoration: const InputDecoration(
                  labelText: '模型名称',
                  hintText: 'gpt-4o / deepseek-chat',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '模型名称不能为空' : null,
              ),
              const SizedBox(height: 12),

              // --- Base URL ---
              TextFormField(
                controller: _baseUrlCtrl,
                decoration: InputDecoration(
                  labelText: '自定义 Base URL（可选）',
                  hintText: isOpenAI
                      ? 'https://api.openai.com/v1'
                      : 'https://api.deepseek.com/v1',
                ),
              ),
              const SizedBox(height: 12),

              // --- OpenAI: thinking depth ---
              if (isOpenAI) ...[
                DropdownButtonFormField<ThinkingDepth>(
                  initialValue: _thinkingDepth,
                  decoration: const InputDecoration(
                    labelText: '思考深度',
                    helperText: '控制 o 系列模型的推理深度 (reasoning_effort)',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ThinkingDepth.low,
                      child: Text('低 (low)'),
                    ),
                    DropdownMenuItem(
                      value: ThinkingDepth.medium,
                      child: Text('中 (medium)'),
                    ),
                    DropdownMenuItem(
                      value: ThinkingDepth.high,
                      child: Text('高 (high)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _thinkingDepth = v);
                  },
                ),
                const SizedBox(height: 12),

                // --- OpenAI: organization ID ---
                TextFormField(
                  controller: _orgIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Organization ID（可选）',
                    hintText: 'org-...',
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // --- DeepSeek: thinking mode ---
              if (!isOpenAI) ...[
                SwitchListTile(
                  title: const Text('深度思考模式'),
                  subtitle: const Text('启用 DeepSeek-R1 的深度思考能力'),
                  value: _thinkingMode == DeepSeekThinkingMode.enabled,
                  onChanged: (v) {
                    setState(() {
                      _thinkingMode = v
                          ? DeepSeekThinkingMode.enabled
                          : DeepSeekThinkingMode.disabled;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),

                // --- DeepSeek: max tokens ---
                TextFormField(
                  controller: _maxTokensCtrl,
                  decoration: const InputDecoration(
                    labelText: '最大 Token 数（可选）',
                    hintText: '例如：4096',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
              ],

              // --- Test connection ---
              OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_find),
                label: Text(_testing ? '测试中…' : '测试连接'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
