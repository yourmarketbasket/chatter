import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chatter/widgets/voice_note_preview_dialog.dart';
import 'package:chatter/widgets/attachment_preview_dialog.dart';

class MessageInputArea extends StatefulWidget {
  final Function(String text, List<PlatformFile> files) onSend;

  const MessageInputArea({
    super.key,
    required this.onSend,
  });

  @override
  State<MessageInputArea> createState() => _MessageInputAreaState();
}

class _MessageInputAreaState extends State<MessageInputArea> {
  final TextEditingController _messageController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isTyping = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      if (mounted) {
        setState(() {
          _isTyping = _messageController.text.trim().isNotEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (_isTyping) {
      widget.onSend(_messageController.text.trim(), []);
      _messageController.clear();
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      try {
        final appDocumentsDir = await getApplicationDocumentsDirectory();
        final path = '${appDocumentsDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        print('Error starting recording: $e');
      }
    } else {
      // Handle permission denied
      print('Microphone permission denied');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        _showPreviewDialog(path);
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  void _showPreviewDialog(String path) {
    showDialog(
      context: context,
      builder: (context) {
        return VoiceNotePreviewDialog(
          audioPath: path,
          onSend: (duration) {
            final file = PlatformFile(
              name: path.split('/').last,
              path: path,
              size: 0, // Placeholder, as we don't have the size here
            );
            widget.onSend('', [file]);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> _pickAttachments() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AttachmentPreviewDialog(
              files: result.files,
              onSend: widget.onSend,
            ),
            fullscreenDialog: true,
          ),
        );
      }
    } catch (e) {
      // Handle exceptions
      print('Error picking files: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.tealAccent),
            onPressed: _pickAttachments,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(_isTyping ? Icons.send : (_isRecording ? Icons.stop : Icons.mic), color: Colors.tealAccent),
            onPressed: _isTyping
                ? _handleSend
                : (_isRecording ? _stopRecording : _startRecording),
          ),
        ],
      ),
    );
  }
}
