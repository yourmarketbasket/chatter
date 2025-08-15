import 'package:chatter/models/chat_models.dart';
import 'package:chatter/models/feed_models.dart' hide Attachment;
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final bool isReplyingToSelf = originalMessage.senderId == currentUserId;
    final sender = chat.participants.firstWhere(
      (p) => p.id == originalMessage.senderId,
      orElse: () => User(id: originalMessage.senderId, name: 'Unknown User'),
    );
    final senderName = isReplyingToSelf ? 'You' : sender.name;

    String contentPreview;
    if (originalMessage.attachments != null && originalMessage.attachments!.isNotEmpty) {
      contentPreview = 'Attachment: ${originalMessage.attachments!.first.filename}';
    } else if (originalMessage.voiceNote != null) {
      contentPreview = 'Voice note';
    } else {
      contentPreview = originalMessage.text ?? '';
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
          Text(
            contentPreview,
            style: TextStyle(color: Colors.grey[300]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
