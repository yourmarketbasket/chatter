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
import 'package:google_fonts/google_fonts.dart';
import 'package:chatter/widgets/pulsing_icon.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

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
  final SocketService _socketService = Get.find<SocketService>();
  final DataController _dataController = Get.find<DataController>();

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
    // Ensure we send a 'typing:stop' event if the user was typing
    if (_isTypingEventSent) {
      final chatId = _dataController.currentChat.value['_id'];
      if (chatId != null) {
        _socketService.sendTypingStop(chatId);
      }
    }
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

  void _showOversizedFileDialog(List<PlatformFile> oversizedFiles) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text('Files Too Large', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The following files exceed the 20MB size limit and were not attached:',
              style: GoogleFonts.poppins(color: Colors.grey.shade300, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...oversizedFiles
                .map((file) => Text(
                      '- ${file.name}',
                      style: GoogleFonts.poppins(color: Colors.white, fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                    ))
                .toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.poppins(color: Colors.tealAccent.shade400)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFiles(List<PlatformFile> files) async {
    if (files.isEmpty) return;

    const int maxSizeInBytes = 20 * 1024 * 1024; // 20 MB
    final List<PlatformFile> validFiles = [];
    final List<PlatformFile> oversizedFiles = [];

    for (final file in files) {
      if (file.size > maxSizeInBytes) {
        oversizedFiles.add(file);
      } else {
        validFiles.add(file);
      }
    }

    if (oversizedFiles.isNotEmpty) {
      _showOversizedFileDialog(oversizedFiles);
    }

    if (validFiles.isEmpty) return;

    final dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AttachmentPreviewDialog(
        files: validFiles,
      ),
    );

    if (dialogResult != null) {
      final List<PlatformFile> resultingFiles = dialogResult['files'];
      final String caption = dialogResult['caption'];
      if (resultingFiles.isNotEmpty || caption.isNotEmpty) {
        widget.onSend(caption, resultingFiles);
        _messageController.clear();
      }
    }
  }

  Future<void> _pickFromCamera() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Select Media Type', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.white),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _takePhotoAndCrop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white),
              title: const Text('Record Video', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _recordVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhotoAndCrop() async {
    try {
      final imageFile = await ImagePicker().pickImage(source: ImageSource.camera);
      if (imageFile == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
          ),
        ],
      );

      if (croppedFile == null) return;

      final platformFile = PlatformFile(
        name: croppedFile.path.split('/').last,
        path: croppedFile.path,
        size: await File(croppedFile.path).length(),
      );

      _handleFiles([platformFile]);
    } catch (e) {
      print('Error taking photo: $e');
    }
  }

  Future<void> _recordVideo() async {
    try {
      final videoFile = await ImagePicker().pickVideo(source: ImageSource.camera);
      if (videoFile == null) return;

      final platformFile = PlatformFile(
        name: videoFile.path.split('/').last,
        path: videoFile.path,
        size: await File(videoFile.path).length(),
      );

      _handleFiles([platformFile]);
    } catch (e) {
      print('Error recording video: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.media,
      );
      if (result == null || result.files.isEmpty) return;
      _handleFiles(result.files);
    } catch (e) {
      print('Error picking from gallery: $e');
    }
  }

  Future<void> _pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.audio,
      );
      if (result == null || result.files.isEmpty) return;
      _handleFiles(result.files);
    } catch (e) {
      print('Error picking audio: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty) return;
      _handleFiles(result.files);
    } catch (e) {
      print('Error picking document: $e');
    }
  }

  Future<void> _pickAttachments() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _buildAttachmentOption(Icons.photo_camera, 'Camera', _pickFromCamera),
                _buildAttachmentOption(Icons.photo_library, 'Gallery', _pickFromGallery),
                _buildAttachmentOption(Icons.headset, 'Audio', _pickAudio),
                _buildAttachmentOption(Icons.insert_drive_file, 'Document', _pickDocument),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey[800],
              child: Icon(icon, size: 28, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentChat = _dataController.currentChat.value;
      bool isMuted = false;
      if (currentChat['type'] == 'group') {
        final myId = _dataController.user.value['user']['_id'];
        final participants = currentChat['participants'] as List<dynamic>?;
        if (participants != null) {
          for (var p in participants) {
            if (p is Map && p['_id'] == myId) {
              isMuted = p['isMuted'] ?? false;
              break;
            }
          }
        }
      }

      return Container(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, color: Colors.tealAccent),
              onPressed: isMuted ? null : _pickAttachments,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.multiline,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: isMuted ? 'You are muted' : 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                enabled: !isMuted,
                contentInsertionConfiguration: ContentInsertionConfiguration(
                  onContentInserted: (KeyboardInsertedContent content) async {
                    if (content.mimeType == 'image/gif' && content.data != null) {
                      try {
                        final tempDir = await getTemporaryDirectory();
                        final tempFile = await File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.gif').create();
                        await tempFile.writeAsBytes(content.data!);

                        final gifFile = PlatformFile(
                          name: tempFile.path.split('/').last,
                          path: tempFile.path,
                          size: await tempFile.length(),
                        );

                        widget.onSend('', [gifFile]);
                      } catch (e) {
                        print('Error handling inserted GIF: $e');
                      }
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _isRecording
                  ? const PulsingIcon(icon: Icons.stop, color: Colors.red)
                  : Icon(
                      _isTyping ? Icons.send : Icons.mic,
                      color: Colors.tealAccent,
                    ),
              onPressed: isMuted
                  ? null
                  : (_isTyping
                      ? _handleSend
                      : (_isRecording ? _stopRecording : _startRecording)),
            ),
          ],
        ),
      );
    });
  }
}
