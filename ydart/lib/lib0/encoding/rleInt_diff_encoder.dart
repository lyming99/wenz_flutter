import 'abstract_stream_encoder.dart';

class RleIntDiffEncoder extends AbstractStreamEncoder<int> {
  int _state = 0;
  int _count = 0;

  RleIntDiffEncoder(int start) {
    _state = start;
  }

  @override
  void write(int value) {
    if (_state == value && _count > 0) {
      _count++;
    } else {
      if (_count > 0) {
        stream.writeVarUint(_count - 1);
      }
      stream.writeVarInt(value - _state);
      _count = 1;
      _state = value;
    }
  }
}
