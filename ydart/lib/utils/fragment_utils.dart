import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ydart/lib0/byte_input_stream.dart';
import 'package:ydart/lib0/byte_output_stream.dart';
import 'package:ydart/utils/y_doc.dart';

import 'transaction.dart';

const kEndFlag = 0xFFFFFE0F;
const kMinFragmentFlag = 0xFFFFFF00;
const kMaxFragmentFlag = 0xFFFFFFFF;
const kMaxFragmentLength = 10000;
const kMinFragmentCount = 200;

class FragmentData {
  int index = 0;
  int offset;
  int endOffset;
  int time;
  Uint8List vector;
  Uint8List content;
  bool isMaxFragment;

  FragmentData({
    required this.offset,
    required this.endOffset,
    required this.vector,
    required this.content,
    required this.isMaxFragment,
    required this.time,
  });

  int get length => endOffset - offset;

  Uint8List toByteArray(bool isEndFlag) {
    var output = ByteArrayOutputStream(1024);
    output.writeUint64(time);
    output.writeUint32(vector.length);
    output.writeBytes(vector);
    output.writeUint32(content.length);
    output.writeBytes(content);
    output.writeUint32(isEndFlag
        ? kEndFlag
        : (isMaxFragment ? kMaxFragmentFlag : kMinFragmentFlag));
    endOffset = offset + output.size();
    return output.toByteArray();
  }
}

class FragmentDocFile {
  String path;
  YDoc? doc;
  var fragments = <FragmentData>[];

  FragmentDocFile({
    required this.path,
  });

  void loadDoc(Uint8List docBytes) {
    this.doc?.updateV2.remove("WriteHandler");
    var doc = YDoc();
    doc.applyUpdateV2(docBytes);
    this.doc = doc;
    var vector = doc.encodeStateVectorV2();
    var fragment = FragmentData(
      offset: 0,
      endOffset: docBytes.length,
      vector: vector,
      content: docBytes,
      isMaxFragment: true,
      time: DateTime.now().millisecondsSinceEpoch,
    );
    fragments.add(fragment);
    doc.updateV2["WriteFragment"] = _writeFragment;
  }

  Future<YDoc> readFragmentDoc() async {
    doc?.updateV2.remove("WriteHandler");
    await _readFile();
    doc!.updateV2["WriteFragment"] = _writeFragment;
    return doc!;
  }

  /// 获取当前大片段数据
  FragmentData? getCurrentMaxFragment() {
    if (fragments.isEmpty) {
      return null;
    }
    if (fragments.length == 1) {
      return fragments.first..isMaxFragment = true;
    }
    for (var i = fragments.length - 1; i >= 0; i--) {
      var current = fragments[i];
      if (current.isMaxFragment) {
        current.index = i;
        return current;
      }
    }
    return null;
  }

  /// 大片段、大片段、小片段、小片段。。。
  void _writeFragment(Uint8List data, Object? origin, Transaction transaction) {
    var doc = transaction.doc;
    var vector = doc.encodeStateVectorV2();
    var currentMaxFragment = _findOrCreateMaxFragment(doc, vector);
    var maxFragmentBytes = currentMaxFragment.toByteArray(false);
    var currentFragment = FragmentData(
      offset: currentMaxFragment.endOffset,
      endOffset: 0,
      vector: vector,
      content: data,
      isMaxFragment: false,
      time: DateTime.now().millisecondsSinceEpoch,
    );
    fragments.add(currentFragment);
    var writer = File(path).openSync(mode: FileMode.append);
    writer.setPositionSync(max(0, currentMaxFragment.offset - 4));
    if (currentMaxFragment.offset > 0) {
      writer.writeFromSync(_createFragmentFlagBytes(currentMaxFragment));
    }
    writer.writeFromSync(maxFragmentBytes);
    var currentOffset = currentMaxFragment.endOffset;
    // 只保留200个小片段，用于回滚数据操作
    var startIndex =
        max(currentMaxFragment.index + 1, fragments.length - kMinFragmentCount);
    if (startIndex > currentMaxFragment.index + 1) {
      fragments.removeRange(currentMaxFragment.index + 1, startIndex);
    }
    for (var i = startIndex; i < fragments.length; i++) {
      var current = fragments[i];
      current.offset = currentOffset;
      writer.writeFromSync(current.toByteArray(i != fragments.length - 1));
      currentOffset = current.endOffset;
    }
    writer.closeSync();
  }

  /// 查找大片段，或者创建大片断
  FragmentData _findOrCreateMaxFragment(YDoc doc, Uint8List vector) {
    var currentMaxFragment = getCurrentMaxFragment();
    if (currentMaxFragment == null) {
      var content = doc.encodeStateAsUpdateV2();
      currentMaxFragment = FragmentData(
        offset: 0,
        endOffset: 0,
        vector: vector,
        content: content,
        isMaxFragment: true,
        time: DateTime.now().millisecondsSinceEpoch,
      );
      fragments.insert(0, currentMaxFragment);
    } else {
      if (currentMaxFragment.length > kMaxFragmentLength) {
        // 构建一个新的 currentMaxFragment
        var content = doc.encodeStateAsUpdateV2(currentMaxFragment.vector);
        var maxFragment = FragmentData(
          offset: currentMaxFragment.endOffset,
          endOffset: 0,
          vector: vector,
          content: content,
          isMaxFragment: true,
          time: DateTime.now().millisecondsSinceEpoch,
        )..index = currentMaxFragment.index + 1;
        fragments.insert(maxFragment.index, maxFragment);
        currentMaxFragment = maxFragment;
      } else {
        if (currentMaxFragment.offset == 0) {
          var content = doc.encodeStateAsUpdateV2();
          currentMaxFragment.vector = vector;
          currentMaxFragment.content = content;
        } else {
          var content = doc.encodeStateAsUpdateV2(
              fragments[currentMaxFragment.index - 1].vector);
          currentMaxFragment.vector = vector;
          currentMaxFragment.content = content;
        }
      }
    }
    return currentMaxFragment;
  }

  /// 将 flag 转换为 bytes 数据
  Uint8List _createFragmentFlagBytes(FragmentData fragmentData) {
    var output = ByteArrayOutputStream(5);
    output.writeUint32(
        fragmentData.isMaxFragment ? kMaxFragmentFlag : kMinFragmentFlag);
    return output.toByteArray();
  }

  /// 读取文件
  Future<void> _readFile() async {
    doc = YDoc();
    fragments = <FragmentData>[];
    if (!File(path).existsSync()) {
      return;
    }
    var bytes = await File(path).readAsBytes();
    var input = ByteArrayInputStream(bytes);
    while (input.available() > 0) {
      try {
        var offset = input.pos;
        var time = input.readUint64();
        var vector = _readVector(input);
        var content = _readContent(input);
        var flag = input.readUint32();
        if (flag != kMinFragmentFlag &&
            flag != kMaxFragmentFlag &&
            flag != kEndFlag) {
          break;
        }
        fragments.add(FragmentData(
          offset: offset,
          vector: vector,
          content: content,
          endOffset: input.pos,
          isMaxFragment: flag == kMaxFragmentFlag,
          time: time,
        ));
        doc!.applyUpdateV2(content);
        if (flag == kEndFlag) {
          break;
        }
      } catch (e, stack) {
        print(stack);
        break;
      }
    }
  }

  Uint8List _readVector(ByteArrayInputStream input) {
    var len = input.readUint32();
    return input.readNBytes(len);
  }

  Uint8List _readContent(ByteArrayInputStream input) {
    var len = input.readUint32();
    return input.readNBytes(len);
  }
}
