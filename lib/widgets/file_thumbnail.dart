import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class FileThumbnail extends StatelessWidget {
  final PlatformFile file;

  const FileThumbnail({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    if (file.path == null) {
      return const Icon(Icons.error, color: Colors.red);
    }

    final extension = file.extension?.toLowerCase() ?? '';

    if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
      return Image.file(File(file.path!), fit: BoxFit.cover);
    } else if (['mp4', 'mov', 'avi'].contains(extension)) {
      return const Icon(Icons.videocam, size: 40, color: Colors.white);
    } else if (['mp3', 'wav', 'm4a'].contains(extension)) {
      return const Icon(Icons.audiotrack, size: 40, color: Colors.white);
    } else if (extension == 'pdf') {
      return const Icon(Icons.picture_as_pdf, size: 40, color: Colors.white);
    } else {
      return const Icon(Icons.insert_drive_file, size: 40, color: Colors.white);
    }
  }
}
