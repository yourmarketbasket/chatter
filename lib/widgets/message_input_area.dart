import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chatter/widgets/voice_note_preview_dialog.dart';
import 'package:chatter/widgets/attachment_preview_dialog.dart';
import 'package:chatter/services/socket-service.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/helpers/file_helper.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_video_info/flutter_video_info.dart';

class MessageInputArea extends StatefulWidget {
  final Function(String text, List<Map<String, dynamic>> files) onSend;

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
  final SocketService _socketService = Get.find<SocketService>();
  final DataController _dataController = Get.find<DataController>();
  final FlutterVideoInfo _videoInfo = FlutterVideoInfo();

  bool _isTyping = false;
  bool _isRecording = false;
  Timer? _typingTimer;
  bool _isTypingEventSent = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _audioRecorder.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {
        _isTyping = _messageController.text.trim().isNotEmpty;
      });
    }

    final chatId = _dataController.currentChat.value['_id'];
    if (chatId == null) return;

    if (!_isTypingEventSent && _isTyping) {
      _socketService.sendTypingStart(chatId);
      setState(() {
        _isTypingEventSent = true;
      });
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTypingEventSent) {
        _socketService.sendTypingStop(chatId);
        setState(() {
          _isTypingEventSent = false;
        });
      }
    });
  }

  void _handleSend() {
    if (_isTyping) {
      final chatId = _dataController.currentChat.value['_id'];
      if (chatId != null) {
        _typingTimer?.cancel();
        if (_isTypingEventSent) {
          _socketService.sendTypingStop(chatId);
          _isTypingEventSent = false;
        }
      }
      widget.onSend(_messageController.text.trim(), []);
      _messageController.clear();
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      try {
        final appDocumentsDir = await getApplicationDocumentsDirectory();
        final path =
            '${appDocumentsDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
            widget.onSend('', [
              {'file': file}
            ]);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> _pickAttachments() async {
    const int maxFileSize = 20971520; // 20 MB

    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) return;

      List<Map<String, dynamic>> filesWithMetadata = [];
      List<String> oversizedFiles = [];

      for (var file in result.files) {
        if (file.size > maxFileSize) {
          oversizedFiles.add(file.name);
          continue;
        }

        final safePath = await FileHelper.getSafePath(file);
        if (safePath == null) {
          // Handle case where path could not be determined
          print('Could not determine path for file: ${file.name}');
          continue;
        }

        Map<String, dynamic> metadata = {
          'file': file,
          'safePath': safePath,
          'width': null,
          'height': null,
          'duration': null,
          'orientation': null,
          'aspectRatio': null,
        };

        final extension = file.extension?.toLowerCase();
        if (extension == 'jpg' ||
            extension == 'jpeg' ||
            extension == 'png' ||
            extension == 'gif' ||
            extension == 'bmp' ||
            extension == 'webp') {
          final imageFile = File(safePath);
          final image = img.decodeImage(await imageFile.readAsBytes());
          if (image != null) {
            metadata['width'] = image.width;
            metadata['height'] = image.height;
            metadata['aspectRatio'] =
                (image.width / image.height).toStringAsFixed(2);
          }
        } else if (extension == 'mp4' ||
            extension == 'mov' ||
            extension == 'avi' ||
            extension == 'mkv' ||
            extension == 'webm') {
          try {
            final info = await _videoInfo.getVideoInfo(safePath);
            if (info != null) {
              metadata['width'] = info.width;
              metadata['height'] = info.height;
              metadata['duration'] = info.duration;
                metadata['orientation'] = info.orientation?.toString();
              if (info.width != null &&
                  info.height != null &&
                  info.height! > 0) {
                metadata['aspectRatio'] =
                    (info.width! / info.height!).toStringAsFixed(2);
              }
            }
          } catch (e) {
            print("Error getting video info: $e");
          }
        }
        filesWithMetadata.add(metadata);
      }

      if (oversizedFiles.isNotEmpty && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Files too large'),
            content: Text(
                'The following files exceed the 20MB size limit and were not added:\n\n${oversizedFiles.join('\n')}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      if (filesWithMetadata.isEmpty) return;

      final dialogResult = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AttachmentPreviewDialog(
          files: filesWithMetadata,
        ),
      );

      if (dialogResult != null) {
        final List<Map<String, dynamic>> files = dialogResult['files'];
        final String caption = dialogResult['caption'];
        if (files.isNotEmpty || caption.isNotEmpty) {
          widget.onSend(caption, files);
          _messageController.clear();
        }
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
            icon: const Icon(Icons.attach_file, color: Colors.tealAccent),
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
