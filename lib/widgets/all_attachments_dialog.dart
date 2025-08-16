import 'package:chatter/models/message_models.dart';
import 'package:chatter/models/feed_models.dart' hide Attachment;
import 'package:flutter/material.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/widgets/video_player_widget.dart';
import 'package:chatter/widgets/audio_waveform_widget.dart';
import 'dart:io';

class AllAttachmentsDialog extends StatelessWidget {
  final ChatMessage message;
  final Map<String, dynamic> chat;

  const AllAttachmentsDialog({super.key, required this.message, required this.chat});

  Widget _buildPreview(BuildContext context, Attachment attachment) {
    final extension = attachment.type?.toLowerCase() ?? '';
    final isLocalFile = !attachment.url.startsWith('http');
    Widget preview;

    switch (extension) {
      case 'image':
        preview = Image(
          image: isLocalFile ? FileImage(File(attachment.url)) : NetworkImage(attachment.url) as ImageProvider,
          fit: BoxFit.cover,
        );
        break;
      case 'video':
        preview = VideoPlayerWidget(
          url: isLocalFile ? null : attachment.url,
          file: isLocalFile ? File(attachment.url) : null,
        );
        break;
      case 'audio':
        preview = AudioWaveformWidget(
          audioPath: attachment.url,
          isLocal: isLocalFile,
        );
        break;
      case 'pdf':
        preview = const Icon(Icons.picture_as_pdf, size: 50, color: Colors.white);
        break;
      default:
        preview = const Icon(Icons.insert_drive_file, size: 50, color: Colors.white);
    }

    return Center(child: preview);
  }

  void _openMediaView(BuildContext context, int initialIndex) {
    final attachmentsForViewer = message.attachments!
        .map((att) => {
              'url': att.url,
              'type': att.type,
              'filename': att.filename,
            })
        .toList();

    final sender = (chat['participants'] as List).firstWhere(
      (p) => p['_id'] == message.senderId,
      orElse: () => {'_id': message.senderId, 'name': 'Unknown User'},
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaViewPage(
          attachments: attachmentsForViewer,
          initialIndex: initialIndex,
          message: message.text ?? '',
          userName: sender['name'],
          userAvatarUrl: sender['avatar'],
          timestamp: message.createdAt,
          viewsCount: 0, // Placeholder
          likesCount: 0, // Placeholder
          repostsCount: 0, // Placeholder
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('All Attachments', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: message.attachments!.length,
          itemBuilder: (context, index) {
            final attachment = message.attachments![index];
            return GestureDetector(
              onTap: () => _openMediaView(context, index),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: _buildPreview(context, attachment),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: Colors.tealAccent)),
        ),
      ],
    );
  }
}
