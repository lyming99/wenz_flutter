/// 可撤销的操作命令。
///
/// 所有具体的操作（添加、删除、移动等）都实现此接口。
/// 通过构造函数持有对 ElementManager 的引用，execute / undo 不再接收 state 参数。
abstract class CanvasCommand {
  /// 执行命令。
  void execute();

  /// 撤销命令。
  void undo();

  /// 命令描述（用于调试或 UI 展示）。
  String get description;
}
