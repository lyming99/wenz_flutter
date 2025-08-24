import '../byte_input_stream.dart';

abstract class AbstractStreamDecoder<T> {
  late ByteArrayInputStream stream;
  late bool _leaveOpen;

  AbstractStreamDecoder(ByteArrayInputStream input, {bool leaveOpen = false}) {
    stream = input;
    _leaveOpen = leaveOpen;
  }

  bool get disposed => stream.isClosed();

  bool get hasContent => stream.available() > 0;

  T read();

  void dispose() {
    _dispose(disposing: true);
  }

  void _dispose({bool disposing = true}) {
    if (!disposed) {
      if (disposing && !_leaveOpen) {
        stream.close();
      }
    }
  }

  void checkDisposed() {
    if (disposed) {
      throw Exception('${runtimeType.toString()} is disposed');
    }
  }
}
