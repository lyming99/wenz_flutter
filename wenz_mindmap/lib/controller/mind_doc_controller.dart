import 'package:wenz_ui/utils/mvc.dart';

abstract class MindDocController extends MvcController {
  String? get docId;

  bool isChildNoteExist(String childId);

  String? getChildNoteTitle(String childId);

  Future getImageFile(String imageId, String? noteId);

  String getRootDir();

  Future uploadFile(
    String fileId,
    String filePath,
    String? docId,
    String? noteId,
  );

  Future downloadFile(
    String fileId,
    String filePath,
    String? docId,
    String? noteId,
  );

  void openChildNote(String uuid);
}
