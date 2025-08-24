import 'package:wenz_editor/editor/block/block.dart';
import 'package:wenz_editor/editor/block/text/text.dart';

class BlockLink{
  WenzBlock block;
  WenTextElement textElement;
  int textOffset;

  BlockLink({
    required this.block,
    required this.textElement,
    required this.textOffset,
  });
}