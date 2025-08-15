import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AttachmentPreviewDialog extends StatefulWidget {
  final List<PlatformFile> files;

  const AttachmentPreviewDialog({super.key, required this.files});

  @override
  State<AttachmentPreviewDialog> createState() => _AttachmentPreviewDialogState();
}

class _AttachmentPreviewDialogState extends State<AttachmentPreviewDialog> {
  late List<PlatformFile> _files;
  final TextEditingController _captionController = TextEditingController();

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

  Widget _buildPreview(PlatformFile file) {
    final extension = file.extension?.toLowerCase() ?? '';
    Widget preview;

    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        preview = Image.file(
          File(file.path!),
          fit: BoxFit.cover,
          width: 100,
          height: 100,
        );
        break;
      case 'mp4':
      case 'mov':
      case 'avi':
        preview = const Icon(Icons.videocam, size: 50, color: Colors.white);
        break;
      case 'mp3':
      case 'wav':
      case 'm4a':
        preview = const Icon(Icons.audiotrack, size: 50, color: Colors.white);
        break;
      case 'pdf':
        preview = const Icon(Icons.picture_as_pdf, size: 50, color: Colors.white);
        break;
      default:
        preview = const Icon(Icons.insert_drive_file, size: 50, color: Colors.white);
    }

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: preview,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Attachments'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_files.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No files selected.'),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    return ListTile(
                      leading: _buildPreview(file),
                      title: Text(file.name, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${(file.size / 1024).toStringAsFixed(2)} KB'),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removeFile(index),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                hintText: 'Add a caption...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // Return the result
            Navigator.pop(context, {
              'files': _files,
              'caption': _captionController.text,
            });
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}
