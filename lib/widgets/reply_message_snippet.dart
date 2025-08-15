import 'package:chatter/models/chat_models.dart';
import 'package:chatter/models/feed_models.dart' hide Attachment;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:chatter/widgets/video_player_widget.dart';
import 'package:chatter/widgets/audio_waveform_widget.dart';

class ReplyMessageSnippet extends StatelessWidget {
  final ChatMessage originalMessage;
  final Chat chat;
  final String currentUserId;

  const ReplyMessageSnippet({
    super.key,
    required this.originalMessage,
    required this.chat,
    required this.currentUserId,
  });

  Widget _buildPreview(Attachment attachment) {
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
        preview = const Icon(Icons.videocam, size: 24, color: Colors.white);
        break;
      case 'audio':
        preview = const Icon(Icons.audiotrack, size: 24, color: Colors.white);
        break;
      default:
        preview = const Icon(Icons.insert_drive_file, size: 24, color: Colors.white);
    }
    return SizedBox(width: 40, height: 40, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: preview));
  }

  @override
  Widget build(BuildContext context) {
    final bool isReplyingToSelf = originalMessage.senderId == currentUserId;
    final sender = chat.participants.firstWhere(
      (p) => p.id == originalMessage.senderId,
      orElse: () => User(id: originalMessage.senderId, name: 'Unknown User'),
    );
    final senderName = isReplyingToSelf ? 'You' : sender.name;

    Widget contentPreview;
    if (originalMessage.attachments != null && originalMessage.attachments!.isNotEmpty) {
      final firstAttachment = originalMessage.attachments!.first;
      contentPreview = Row(
        children: [
          _buildPreview(firstAttachment),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              firstAttachment.type == 'image' ? 'Image' : firstAttachment.filename,
              style: TextStyle(color: Colors.grey[300]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (originalMessage.voiceNote != null) {
      contentPreview = Row(
        children: [
          const Icon(Icons.audiotrack, size: 24, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            'Voice note',
            style: TextStyle(color: Colors.grey[300]),
          ),
        ],
      );
    } else {
      contentPreview = Text(
        originalMessage.text ?? '',
        style: TextStyle(color: Colors.grey[300]),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Colors.tealAccent, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: const TextStyle(
              color: Colors.tealAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          contentPreview,
        ],
      ),
    );
  }
}
