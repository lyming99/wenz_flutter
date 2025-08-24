// ------------------------------------------------------------------------------
//  <copyright company="Microsoft Corporation">
//      Copyright (c) Microsoft Corporation.  All rights reserved.
//  </copyright>
// ------------------------------------------------------------------------------

import 'abstract_stream_encoder.dart';

/// Basic diff encoder using variable length encoding.
/// Encodes the values [3, 1100, 1101, 1050, 0] to [3, 1097, 1, -51, -1050].
/// See [IntDiffDecoder].
class IntDiffEncoder extends AbstractStreamEncoder<int> {
    late int _state;

    IntDiffEncoder(int start) {
        _state = start;
    }

    @override
    void write(int value) {
        stream.writeVarInt(value - _state);
        _state = value;
    }
}