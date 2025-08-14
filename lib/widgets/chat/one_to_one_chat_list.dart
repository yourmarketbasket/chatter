import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/conversation_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OneToOneChatList extends StatelessWidget {
  const OneToOneChatList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DataController dataController = Get.find<DataController>();
    final String currentUserId = dataController.user.value['user']['_id'];

    return Obx(() {
      if (dataController.isLoadingConversations.value) {
        return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
      }

      final oneToOneChats = dataController.conversations.where((c) => (c['isGroupChat'] ?? false) == false).toList();

      if (oneToOneChats.isEmpty) {
        return Center(
          child: Text(
            'No one-on-one chats yet.',
            style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 16),
          ),
        );
      }

      return ListView.separated(
        itemCount: oneToOneChats.length,
        separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1, indent: 80),
        itemBuilder: (context, index) {
          final conversation = oneToOneChats[index];
          final participants = conversation['participants'] as List? ?? [];
          final otherParticipant = participants.firstWhere(
            (p) => p is Map && p['_id'] != currentUserId,
            orElse: () => null,
          );

          if (otherParticipant == null) {
            return const SizedBox.shrink(); // Don't show chats where the other participant isn't found
          }

          final name = otherParticipant['name'] ?? 'Unknown User';
          final avatarUrl = otherParticipant['avatar'] ?? '';
          final receiverId = otherParticipant['_id'] ?? '';
          final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
          final lastMessage = conversation['lastMessage'];
          final lastMessageContent = lastMessage?['content'] ?? 'No messages yet...';
          final timestamp = lastMessage != null ? TimeOfDay.fromDateTime(DateTime.parse(lastMessage['createdAt'])).format(context) : '';

          return ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.tealAccent.withOpacity(0.3),
              backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
              child: avatarUrl.isEmpty ? Text(initials, style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.bold)) : null,
            ),
            title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.white, fontSize: 16)),
            subtitle: Text(
              lastMessageContent,
              style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(timestamp, style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12)),
            onTap: () {
              Get.to(() => ConversationPage(
                    conversationId: conversation['_id'],
                    username: name,
                    userAvatar: avatarUrl,
                    receiverId: receiverId,
                    isGroupChat: false,
                  ));
            },
          );
        },
      );
    });
  }
}
