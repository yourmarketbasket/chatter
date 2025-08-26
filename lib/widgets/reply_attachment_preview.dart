import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  // force

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
        preview = Padding(
          padding: const EdgeInsets.all(10.0),
          child: CircularProgressIndicator(strokeWidth: 1.0, color: Colors.teal, valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 110, 110, 110))),
        );
      } else if (_thumbnailData != null) {
        preview = Image.memory(
          _thumbnailData!,
          fit: BoxFit.cover,
          width: 60, // Set width to maintain 4:3 ratio with height 60
          height: 60,
        );
      } else {
        preview = const Icon(Icons.videocam, size: 24, color: Colors.white);
      }
    } else {
      switch (extension) {
        case 'image/jpeg':
        case 'image/png':
        case 'image':
          preview = isLocalFile
              ? Image.file(
                  File(widget.attachment['url']),
                  fit: BoxFit.cover,
                  width: 50,
                  height: 60,
                )
              : CachedNetworkImage(
                  imageUrl: widget.attachment['url'],
                  fit: BoxFit.cover,
                  width: 50,
                  height: 60,
                  placeholder: (context, url) => const SizedBox(
                    height: 10,
                    width: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.0, color: Colors.teal, valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 110, 110, 110))),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.broken_image,
                    size: 24,
                    color: Colors.white,
                  ),
                );
          break;
        case 'audio/mp3':
        case 'voice':
          preview = const Icon(Icons.audiotrack, size: 24, color: Colors.white);
          break;
        case 'application/pdf':
          preview = const Icon(Icons.picture_as_pdf, size: 24, color: Colors.white);
          break;
        default:
          preview = const Icon(Icons.insert_drive_file, size: 24, color: Colors.white);
      }
    }

    return Container(
      width: 60,
      height: 60, // 4:3 aspect ratio (80:60)
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: preview,
    );
  }
}