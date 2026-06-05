import '../canvas_command.dart';

/// 批量命令（组合模式）。
///
/// 将多个命令组合为一个原子操作，支持一次性执行/撤销。
/// undo 时按反序撤销所有子命令。
class BatchCommand implements CanvasCommand {
  final List<CanvasCommand> _commands;
  final String _description;

  BatchCommand(List<CanvasCommand> commands, {String? description})
      : _commands = List.unmodifiable(commands),
        _description = description ?? '批量操作 (${commands.length} 个)';

  /// 子命令列表（不可变）。
  List<CanvasCommand> get commands => _commands;

  @override
  void execute() {
    for (final command in _commands) {
      command.execute();
    }
  }

  @override
  void undo() {
    for (final command in _commands.reversed) {
      command.undo();
    }
  }

  @override
  String get description => _description;
}
