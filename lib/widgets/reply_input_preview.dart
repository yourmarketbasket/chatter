import 'package:chatter/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReplyInputPreview extends StatelessWidget {
  final ChatMessage repliedToMessage;
  final VoidCallback onCancel;

  const ReplyInputPreview({
    Key? key,
    required this.repliedToMessage,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            color: Colors.tealAccent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Replying to ${repliedToMessage.senderId}", // In a real app, you'd resolve this to a name
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.tealAccent,
                  ),
                ),
                Text(
                  repliedToMessage.text ?? 'Attachment',
                  style: GoogleFonts.roboto(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
