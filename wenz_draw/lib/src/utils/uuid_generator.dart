import 'package:uuid/uuid.dart';

class UuidGenerator {
  const UuidGenerator._();

  static const _uuid = Uuid();

  static String create() {
    return _uuid.v4();
  }
}
