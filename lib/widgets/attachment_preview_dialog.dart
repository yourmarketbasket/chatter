import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:chatter/widgets/file_thumbnail.dart';

class AttachmentPreviewDialog extends StatefulWidget {
  final List<PlatformFile> files;
  final String? initialText;
  final Function(String text, List<PlatformFile> files) onSend;

  const AttachmentPreviewDialog({
    super.key,
    required this.files,
    this.initialText,
    required this.onSend,
  });

  @override
  State<AttachmentPreviewDialog> createState() => _AttachmentPreviewDialogState();
}

class _AttachmentPreviewDialogState extends State<AttachmentPreviewDialog> {
  late final TextEditingController _textController;
  late List<PlatformFile> _files;

  @override
  void initState() {
    super.initState();
    _files = List.from(widget.files);
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _addMoreFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _files.addAll(result.files);
        });
      }
    } catch (e) {
      print('Error picking more files: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                ),
                itemCount: _files.length + 1, // +1 for the "Add more" button
                itemBuilder: (context, index) {
                  if (index == _files.length) {
                    // This is the "Add more" button
                    return InkWell(
                      onTap: _addMoreFiles,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 40),
                      ),
                    );
                  }

                  final file = _files[index];
                  return Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                        color: Colors.grey[850],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: FileThumbnail(file: file),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _files.removeAt(index);
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.grey[900],
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a message...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.tealAccent),
                    onPressed: _files.isEmpty
                        ? null // Disable send if there are no files
                        : () {
                            widget.onSend(_textController.text.trim(), _files);
                            Navigator.of(context).pop();
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
