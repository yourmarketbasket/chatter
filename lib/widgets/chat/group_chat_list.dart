import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/conversation_page.dart';
import 'package:chatter/pages/create_group_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class GroupChatList extends StatelessWidget {
  const GroupChatList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DataController dataController = Get.find<DataController>();

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Obx(() {
        if (dataController.isLoadingConversations.value) {
          return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
        }

        final groupChats = dataController.conversations.where((c) => c['isGroupChat'] ?? false).toList();

        if (groupChats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No group chats yet.',
                  style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Get.to(() => const CreateGroupPage());
                  },
                  icon: const Icon(FeatherIcons.plus, color: Colors.black),
                  label: Text(
                    'Create Group',
                    style: GoogleFonts.poppins(color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: groupChats.length,
          separatorBuilder: (context, index) => Divider(
            color: Colors.grey[850],
            height: 1,
            indent: 80,
            endIndent: 16,
          ),
          itemBuilder: (context, index) {
            final conversation = groupChats[index];
            final groupName = conversation['groupName'] ?? 'Unnamed Group';
            final avatarUrl = conversation['groupAvatar'] ?? '';
            final initials = groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G';
            final lastMessage = conversation['lastMessage'];
            String lastMessageContent = 'No messages yet...';
            String senderName = '';

            if (lastMessage != null) {
              if (lastMessage['content'] != null && lastMessage['content'].isNotEmpty) {
                lastMessageContent = lastMessage['content'];
                senderName = lastMessage['sender']?['name'] ?? '';
              } else if ((lastMessage['attachments'] as List?)?.isNotEmpty ?? false) {
                final attachment = (lastMessage['attachments'] as List).first;
                final type = attachment['type'];
                senderName = lastMessage['sender']?['name'] ?? '';
                switch (type) {
                  case 'image':
                    lastMessageContent = '$senderName sent an image';
                    break;
                  case 'video':
                    lastMessageContent = '$senderName sent a video';
                    break;
                  case 'audio':
                    lastMessageContent = '$senderName sent a voice message';
                    break;
                  case 'document':
                    lastMessageContent = '$senderName sent a document';
                    break;
                  default:
                    lastMessageContent = '$senderName sent an attachment';
                }
              }
            }

            final String timestamp;
            if (lastMessage != null && lastMessage['createdAt'] != null) {
              final dateTime = DateTime.parse(lastMessage['createdAt']).toLocal();
              final now = DateTime.now();
              if (dateTime.day == now.day &&
                  dateTime.month == now.month &&
                  dateTime.year == now.year) {
                timestamp = DateFormat('h:mm a').format(dateTime);
              } else {
                timestamp = timeago.format(dateTime, locale: 'en_short');
              }
            } else {
              timestamp = '';
            }

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.tealAccent.withOpacity(0.3),
                backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        initials,
                        style: GoogleFonts.poppins(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              title: Text(
                groupName,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              subtitle: Row(
                children: [
                  if (senderName.isNotEmpty)
                    Text(
                      '$senderName: ',
                      style: GoogleFonts.roboto(
                        color: Colors.grey[400],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      lastMessageContent,
                      style: GoogleFonts.roboto(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    timestamp,
                    style: GoogleFonts.roboto(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                  if (conversation['unreadCount'] != null && conversation['unreadCount'] > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.tealAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        conversation['unreadCount'].toString(),
                        style: GoogleFonts.roboto(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
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
        heroTag: 'groupChatListFAB',
        onPressed: () {
          Get.to(() => const CreateGroupPage());
        },
        backgroundColor: Colors.tealAccent,
        child: const Icon(FeatherIcons.plus, color: Colors.black),
      ),
    );
  }
}