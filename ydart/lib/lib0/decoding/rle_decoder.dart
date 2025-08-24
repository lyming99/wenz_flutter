import 'package:ydart/lib0/byte_input_stream.dart';

import 'abstract_stream_decoder.dart';

class RleDecoder extends AbstractStreamDecoder<int> {
  int _state = 0;
  int _count = 0;

  RleDecoder(super.input, {super.leaveOpen = false});

  @override
  int read() {
    checkDisposed();

    if (_count == 0) {
      _state = stream.read();
      if (hasContent) {
        _count = stream.readVarUint() + 1;
        assert(_count > 0);
      } else {
        _count = -1;
      }
    }

    _count--;
    return _state;
  }
}
