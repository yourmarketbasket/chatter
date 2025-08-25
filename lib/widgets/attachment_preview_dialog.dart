import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:chatter/widgets/better_player_widget.dart';
import 'package:chatter/widgets/audio_waveform_widget.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_video_info/flutter_video_info.dart';

class AttachmentPreviewDialog extends StatefulWidget {
  final List<Map<String, dynamic>> files;

  const AttachmentPreviewDialog({super.key, required this.files});

  @override
  State<AttachmentPreviewDialog> createState() =>
      _AttachmentPreviewDialogState();
}

class _AttachmentPreviewDialogState extends State<AttachmentPreviewDialog> {
  late List<Map<String, dynamic>> _files;
  final TextEditingController _captionController = TextEditingController();
  final FlutterVideoInfo _videoInfo = FlutterVideoInfo();

  @override
  void initState() {
    super.initState();
    _files = List.from(widget.files);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
    });
  }

  Future<void> _addMoreFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        // This dialog does not handle size limits or metadata, it just adds the files.
        // The parent widget is responsible for pre-filtering.
        final newFilesAsMaps = result.files
            .where((file) => file.path != null)
            .map((file) => {'file': file})
            .toList();
        setState(() {
          _files.addAll(newFilesAsMaps);
        });
      }
    } catch (e) {
      // Handle exceptions
      print('Error picking more files: $e');
    }
  }

  Widget _buildPreview(Map<String, dynamic> fileData) {
    final file = fileData['file'] as PlatformFile;
    final extension = file.extension?.toLowerCase() ?? '';
    Widget preview;

    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        preview = FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: Image.file(File(safePath)),
        );
        break;
      case 'mp4':
      case 'mov':
      case 'avi':
        final aspectRatio =
            double.tryParse(fileData['aspectRatio']?.toString() ?? '1.77');
        preview = BetterPlayerWidget(
          file: File(file.path!),
          displayPath: file.name,
          videoAspectRatioProp: aspectRatio,
          showSimpleControls: true,
        );
        break;
      case 'mp3':
      case 'wav':
      case 'm4a':
        preview = AudioWaveformWidget(
          audioPath: file.path!,
          isLocal: true,
        );
        break;
      case 'pdf':
        preview =
            const Icon(Icons.picture_as_pdf, size: 50, color: Colors.white);
        break;
      default:
        preview =
            const Icon(Icons.insert_drive_file, size: 50, color: Colors.white);
    }

    return Center(child: preview);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Send Attachments', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_files.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48.0),
                child: Text('No files selected.', style: TextStyle(color: Colors.white)),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _files.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _files.length) {
                      return InkWell(
                        onTap: _addMoreFiles,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: const Icon(Icons.add_photo_alternate, color: Colors.white, size: 40),
                        ),
                      );
                    }
                    final fileData = _files[index];
                    final file = fileData['file'] as PlatformFile;
                    return Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: _buildPreview(fileData),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => _removeFile(index),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'files': _files,
                      'caption': _captionController.text,
                    });
                  },
                  child: const Text('Send', style: TextStyle(color: Colors.tealAccent)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
