import 'abstract_stream_encoder.dart';

class RleEncoder extends AbstractStreamEncoder<int> {
    int? _state;
    int _count = 0;

    RleEncoder() {
        // Do nothing.
    }

    @override
    void write(int value) {
        if (_state == value) {
            _count++;
        } else {
            if (_count > 0) {
                stream.writeVarUint(_count - 1);
            }
            stream.write(value);
            _count = 1;
            _state = value;
        }
    }
}