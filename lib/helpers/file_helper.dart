import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

class FileHelper {
  static Future<String?> getSafePath(PlatformFile file) async {
    if (file.path != null) {
      return file.path;
    }

    if (file.bytes != null) {
      try {
        final tempDir = await getTemporaryDirectory();
        final extension = file.extension ?? 'tmp';
        final fileName = '${const Uuid().v4()}.$extension';
        final tempFile = File(path.join(tempDir.path, fileName));
        await tempFile.writeAsBytes(file.bytes!);
        return tempFile.path;
      } catch (e) {
        print('Error creating temporary file: $e');
        return null;
      }
    }

    return null;
  }
}
