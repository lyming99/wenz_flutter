import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';

class ImageSize {
  int width;
  int height;

  ImageSize({required this.width, required this.height});
}

int readImageWidth(ImageInput input) {
  return ImageSizeGetter.getSize(input).width;
}

int readImageHeight(ImageInput input) {
  return ImageSizeGetter.getSize(input).height;
}

ImageSize readImageSize(ImageInput input) {
  var size = ImageSizeGetter.getSize(input);
  return ImageSize(width: size.width, height: size.height);
}

final _decoders = [
  const GifDecoder(),
  const JpegDecoder(),
  const WebpDecoder(),
  const PngDecoder(),
  const BmpDecoder(),
];

bool isValidImage(ImageInput input) {
  for (var value in _decoders) {
    if (value.isValid(input)) {
      return true;
    }
  }
  return false;
}

Future<ImageSize> readImageFileSize(File file) async{
  try {
    var size = ImageSizeGetter.getSize(FileInput(file));
    return ImageSize(width: size.width, height: size.height);
  } catch (e) {
    var image = await decodeImageFromList(file.readAsBytesSync());
    return ImageSize(width: image.width, height: image.height);
  }
}
Future<ImageSize> readImageBytesSize(Uint8List file) async{
  try {
    var size = ImageSizeGetter.getSize(MemoryInput(file));
    return ImageSize(width: size.width, height: size.height);
  } catch (e) {
    var image = await decodeImageFromList(file);
    return ImageSize(width: image.width, height: image.height);
  }
}
