import 'dart:collection';

class QueueStack<T> {
  Queue<T> queue = Queue();

  bool get isNotEmpty => queue.isNotEmpty;

  void push(T t) {
    queue.addLast(t);
  }

  T pop() {
    return queue.removeLast();
  }

  T peek() {
    return queue.last;
  }

  void clear() {
    queue.clear();
  }
}
