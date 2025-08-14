import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/conversation_page.dart';
import 'package:chatter/pages/create_group_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GroupChatList extends StatelessWidget {
  const GroupChatList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DataController dataController = Get.find<DataController>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (dataController.isLoadingConversations.value) {
          return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
        }

        final groupChats = dataController.conversations.where((c) => c['isGroupChat'] ?? false).toList();

        if (groupChats.isEmpty) {
          return Center(
            child: Text(
              'No group chats yet.',
              style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 16),
            ),
          );
        }

        return ListView.separated(
          itemCount: groupChats.length,
          separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1, indent: 80),
          itemBuilder: (context, index) {
            final conversation = groupChats[index];
            final groupName = conversation['groupName'] ?? 'Unnamed Group';
            final avatarUrl = conversation['groupAvatar'] ?? '';
            final initials = groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G';
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
              title: Text(groupName, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.white, fontSize: 16)),
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
                      username: groupName,
                      userAvatar: avatarUrl,
                      receiverId: '', // Not needed for group chat
                      isGroupChat: true,
                    ));
              },
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() => const CreateGroupPage());
        },
        backgroundColor: Colors.tealAccent,
        child: const Icon(FeatherIcons.plus, color: Colors.black),
      ),
    );
  }
}
