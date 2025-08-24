import '../constans.dart';
import 'abstract_stream_encoder.dart';

class IntDiffOptRleEncoder extends AbstractStreamEncoder<int> {
  int _state = 0;
  int _diff = 0;
  int _count = 0;

  IntDiffOptRleEncoder() {
    // Do nothing.
  }

  @override
  void write(int value) {
    assert(value <= Bits.bits30);
    if (_diff == value - _state) {
      _state = value;
      _count++;
    } else {
      writeEncodedValue();

      _count = 1;
      _diff = value - _state;
      _state = value;
    }
  }

  void flush() {
    writeEncodedValue();
  }

  void writeEncodedValue() {
    if (_count > 0) {
      int encodedDiff;
      if (_diff < 0) {
        encodedDiff = -(((_diff.abs() << 1) | (_count == 1 ? 0 : 1)));
      } else {
        encodedDiff = ((_diff << 1) | (_count == 1 ? 0 : 1));
      }
      stream.writeVarInt(encodedDiff);

      if (_count > 1) {
        stream.writeVarUint(_count - 2);
      }
    }
  }
}
