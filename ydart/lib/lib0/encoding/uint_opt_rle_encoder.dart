// ------------------------------------------------------------------------------
//  <copyright company="Microsoft Corporation">
//      Copyright (c) Microsoft Corporation.  All rights reserved.
//  </copyright>
// ------------------------------------------------------------------------------

import 'abstract_stream_encoder.dart';

/// Optimized RLE encoder that does not suffer from the mentioned problem of the basic RLE encoder.
/// Internally uses VarInt encoder to write unsigned integers.
/// If the input occurs multiple times, we write it as a negative number. The UintOptRleDecoder
/// then understands that it needs to read a count.
class UintOptRleEncoder extends AbstractStreamEncoder<int> {
  int _state = 0;
  int _count = 0;

  UintOptRleEncoder() {
    // Do nothing.
  }

  @override
  void write(int value) {
    if (_state == value) {
      _count++;
    } else {
      writeEncodedValue();
      _count = 1;
      _state = value;
    }
  }

  @override
  void flush() {
    writeEncodedValue();
    super.flush();
  }

  void writeEncodedValue() {
    if (_count > 0) {
      // Flush counter, unless this is the first value (count = 0).
      // Case 1: Just a single value. Set sign to positive.
      // Case 2: Write several values. Set sign to negative to indicate that there is a length coming.
      if (_count == 1) {
        stream.writeVarInt(_state);
      } else {
        // Specify 'treatZeroAsNegative' in case we pass the '-0'.
        stream.writeVarInt(-_state, treatZeroAsNegative: _state == 0);

        // Since count is always >1, we can decrement by one. Non-standard encoding.
        stream.writeVarUint(_count - 2);
      }
    }
  }
}
