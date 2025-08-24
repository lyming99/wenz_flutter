import '../lib0/byte_input_stream.dart';
import '../lib0/byte_output_stream.dart';

class ID {
  int client;
  int clock;

  ID({
    required this.client,
    required this.clock,
  });

  factory ID.create(int client, int clock) {
    return ID(client: client, clock: clock);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ID &&
          runtimeType == other.runtimeType &&
          client == other.client &&
          clock == other.clock;

  @override
  int get hashCode => client.hashCode ^ clock.hashCode;

  void write(ByteArrayOutputStream encoder) {
    encoder.writeVarInt(client);
    encoder.writeVarInt(clock);
  }

  @override
  String toString() {
    return "{client:$client,clock:$clock}";
  }

  static ID read(ByteArrayInputStream decoder) {
    var client = decoder.readVarInt();
    var clock = decoder.readVarInt();
    return ID(client: client, clock: clock);
  }
}
