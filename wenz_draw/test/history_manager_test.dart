import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

/// Simple mock command that tracks execute/undo call counts.
class _TestCommand extends CanvasCommand {
  int executeCount = 0;
  int undoCount = 0;

  @override
  void execute() {
    executeCount++;
  }

  @override
  void undo() {
    undoCount++;
  }

  @override
  String get description => 'test';
}

void main() {
  group('HistoryManager', () {
    late HistoryManager manager;

    setUp(() {
      manager = HistoryManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('initial state has empty stacks', () {
      expect(manager.canUndo, isFalse);
      expect(manager.canRedo, isFalse);
      expect(manager.undoCount, 0);
      expect(manager.redoCount, 0);
    });

    test('execute adds command to undo stack', () {
      final cmd = _TestCommand();
      manager.execute(cmd);

      expect(manager.canUndo, isTrue);
      expect(manager.canRedo, isFalse);
      expect(manager.undoCount, 1);
      expect(cmd.executeCount, 1);
    });

    test('execute calls command.execute()', () {
      final cmd = _TestCommand();
      manager.execute(cmd);
      expect(cmd.executeCount, 1);

      manager.execute(cmd);
      expect(cmd.executeCount, 2);
    });

    test('undo pops from undo stack and pushes to redo stack', () {
      final cmd1 = _TestCommand();
      final cmd2 = _TestCommand();
      manager.execute(cmd1);
      manager.execute(cmd2);

      expect(manager.undoCount, 2);
      expect(manager.redoCount, 0);

      manager.undo();

      expect(manager.undoCount, 1);
      expect(manager.redoCount, 1);
      expect(manager.canUndo, isTrue);
      expect(manager.canRedo, isTrue);
      expect(cmd2.undoCount, 1);
    });

    test('redo pops from redo stack and pushes to undo stack', () {
      final cmd = _TestCommand();
      manager.execute(cmd);
      manager.undo();

      expect(manager.undoCount, 0);
      expect(manager.redoCount, 1);

      manager.redo();

      expect(manager.undoCount, 1);
      expect(manager.redoCount, 0);
      expect(cmd.executeCount, 2); // execute on first call + redo
    });

    test('undo does nothing when undo stack is empty', () {
      manager.undo();
      expect(manager.undoCount, 0);
      expect(manager.redoCount, 0);
    });

    test('redo does nothing when redo stack is empty', () {
      manager.redo();
      expect(manager.undoCount, 0);
      expect(manager.redoCount, 0);
    });

    test('execute clears redo stack', () {
      final cmd1 = _TestCommand();
      final cmd2 = _TestCommand();
      manager.execute(cmd1);
      manager.undo();

      expect(manager.redoCount, 1);

      manager.execute(cmd2);

      expect(manager.redoCount, 0);
      expect(manager.undoCount, 1);
    });

    test('clear empties both stacks', () {
      manager.execute(_TestCommand());
      manager.execute(_TestCommand());
      manager.undo();

      expect(manager.undoCount, 1);
      expect(manager.redoCount, 1);

      manager.clear();

      expect(manager.undoCount, 0);
      expect(manager.redoCount, 0);
      expect(manager.canUndo, isFalse);
      expect(manager.canRedo, isFalse);
    });

    test('maxHistory discards oldest commands', () {
      manager = HistoryManager(maxHistory: 3);

      final cmd1 = _TestCommand();
      final cmd2 = _TestCommand();
      final cmd3 = _TestCommand();
      final cmd4 = _TestCommand();

      manager.execute(cmd1);
      manager.execute(cmd2);
      manager.execute(cmd3);
      manager.execute(cmd4);

      // Should only keep the last 3 commands
      expect(manager.undoCount, 3);

      // Undo all 3 - should get cmd4, cmd3, cmd2 (cmd1 was discarded)
      manager.undo();
      manager.undo();
      manager.undo();

      expect(manager.canUndo, isFalse);
      expect(manager.redoCount, 3);
    });

    test('multiple undo/redo cycles work correctly', () {
      final cmd1 = _TestCommand();
      final cmd2 = _TestCommand();
      final cmd3 = _TestCommand();

      manager.execute(cmd1);
      manager.execute(cmd2);
      manager.execute(cmd3);

      // Undo twice
      manager.undo();
      manager.undo();
      expect(manager.undoCount, 1);
      expect(manager.redoCount, 2);

      // Redo once
      manager.redo();
      expect(manager.undoCount, 2);
      expect(manager.redoCount, 1);

      // Undo all
      manager.undo();
      manager.undo();
      expect(manager.undoCount, 0);
      expect(manager.redoCount, 3);
    });

    test('notifyListeners is called on execute', () {
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      manager.execute(_TestCommand());
      expect(notifyCount, 1);

      manager.execute(_TestCommand());
      expect(notifyCount, 2);
    });

    test('notifyListeners is called on undo and redo', () {
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      manager.execute(_TestCommand());
      expect(notifyCount, 1);

      manager.undo();
      expect(notifyCount, 2);

      manager.redo();
      expect(notifyCount, 3);
    });

    test('notifyListeners is called on clear', () {
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      manager.execute(_TestCommand());
      // notifyCount = 1 from execute

      manager.clear();
      expect(notifyCount, 2);
    });

    test('default maxHistory is 100', () {
      manager = HistoryManager();
      expect(manager.maxHistory, 100);
    });
  });
}
