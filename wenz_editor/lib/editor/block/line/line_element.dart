import 'package:wenz_editor/editor/block/element/element.dart';

class LineElement extends WenElement {
  LineElement({super.type = "line"});

  @override
  String getMarkDown({FilePathBuilder? filePathBuilder}) {
    return "---";
  }
}
