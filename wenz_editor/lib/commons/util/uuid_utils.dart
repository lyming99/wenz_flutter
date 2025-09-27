import 'package:uuid/uuid.dart';

class UuidUtils {
  UuidUtils._();

  static String v1() {
    var uuid = const Uuid();
    return uuid.v1();
  }
}
