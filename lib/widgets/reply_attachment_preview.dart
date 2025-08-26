import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ReplyAttachmentPreview extends StatefulWidget {
  final Map<String, dynamic> attachment;

  const ReplyAttachmentPreview({Key? key, required this.attachment}) : super(key: key);

  @override
  _ReplyAttachmentPreviewState createState() => _ReplyAttachmentPreviewState();
}

class _ReplyAttachmentPreviewState extends State<ReplyAttachmentPreview> {
  Uint8List? _thumbnailData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.attachment['type']?.toLowerCase().startsWith('video')) {
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final thumbnail = await VideoThumbnail.thumbnailData(
        video: widget.attachment['url'],
        imageFormat: ImageFormat.JPEG,
        maxWidth: 128,
        quality: 25,
      );
      if (mounted) {
        setState(() {
          _thumbnailData = thumbnail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final extension = widget.attachment['type']?.toLowerCase() ?? '';
    final isLocalFile = !(widget.attachment['url'] as String).startsWith('http');
    Widget preview;

    if (extension.startsWith('video')) {
      if (_isLoading) {
        preview = const CircularProgressIndicator(strokeWidth: 2);
      } else if (_thumbnailData != null) {
        preview = Image.memory(_thumbnailData!, fit: BoxFit.cover);
      } else {
        preview = const Icon(Icons.videocam, size: 24, color: Colors.white);
      }
    } else {
      switch (extension) {
        case 'image/jpeg':
        case 'image/png':
        case 'image':
          preview = Image(
            image: isLocalFile
                ? FileImage(File(widget.attachment['url']))
                : NetworkImage(widget.attachment['url']) as ImageProvider,
            fit: BoxFit.cover,
          );
          break;
        case 'audio/mp3':
        case 'voice':
          preview = const Icon(Icons.audiotrack, size: 24, color: Colors.white);
          break;
        case 'application/pdf':
          preview =
              const Icon(Icons.picture_as_pdf, size: 24, color: Colors.white);
          break;
        default:
          preview =
              const Icon(Icons.insert_drive_file, size: 24, color: Colors.white);
      }
    }

    return SizedBox(
        width: 80,
        height: 60,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Center(child: preview)));
  }
}
