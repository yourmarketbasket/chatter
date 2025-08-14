import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/conversation_page.dart';
import 'package:chatter/pages/create_group_page.dart';
import 'package:chatter/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DirectMessagesPage extends StatefulWidget {
  const DirectMessagesPage({Key? key}) : super(key: key);

  @override
  _DirectMessagesPageState createState() => _DirectMessagesPageState();
}

class _DirectMessagesPageState extends State<DirectMessagesPage> {
  final DataController _dataController = Get.find<DataController>();

  @override
  void initState() {
    super.initState();
    // Call the new method to fetch real chat data
    _dataController.getAllChats().catchError((e) {
      Get.snackbar('Error', 'Could not load conversations: ${e.toString()}',
          backgroundColor: Colors.red, colorText: Colors.white);
    });
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = _dataController.user.value['user']['_id'];

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          'Direct Messages',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(),
      body: Obx(() {
        if (_dataController.isLoadingConversations.value) {
          return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
        }
        if (_dataController.conversations.isEmpty) {
          return Center(
            child: Text(
              'No conversations yet.',
              style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 16),
            ),
          );
        }
        return ListView.separated(
          itemCount: _dataController.conversations.length,
          separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1, indent: 80),
          itemBuilder: (context, index) {
            final conversation = _dataController.conversations[index];
            final bool isGroupChat = conversation['isGroupChat'] ?? false;

            String name = 'Unknown';
            String avatarUrl = '';
            String receiverId = '';
            String initials = '?';

            if (isGroupChat) {
              name = conversation['groupName'] ?? 'Unnamed Group';
              avatarUrl = conversation['groupAvatar'] ?? '';
              initials = name.isNotEmpty ? name[0].toUpperCase() : 'G';
            } else {
              final List<dynamic> participants = conversation['participants'] as List? ?? [];
              final otherParticipant = participants.firstWhere(
                (p) => p is Map && p['_id'] != currentUserId,
                orElse: () => null,
              );

              if (otherParticipant != null) {
                name = otherParticipant['name'] ?? 'Unknown User';
                avatarUrl = otherParticipant['avatar'] ?? '';
                receiverId = otherParticipant['_id'] ?? '';
                initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
              } else {
                // Handle case where other participant isn't found (e.g., chat with self)
                name = 'Chat with Self';
                avatarUrl = _dataController.user.value['user']?['avatar'] ?? '';
                receiverId = currentUserId;
                initials = name.isNotEmpty ? name[0].toUpperCase() : 'S';
              }
            }

            final String lastMessageContent = conversation['lastMessage']?['content'] ?? 'No messages yet...';
            final String timestamp = conversation['lastMessage'] != null
                ? TimeOfDay.fromDateTime(DateTime.parse(conversation['lastMessage']['createdAt'])).format(context)
                : '';

            return ListTile(
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.tealAccent.withOpacity(0.3),
                backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                child: avatarUrl.isEmpty ? Text(initials, style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.bold)) : null,
              ),
              title: Text(
                name,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.white, fontSize: 16),
              ),
              subtitle: Text(
                lastMessageContent,
                style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                timestamp,
                style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12),
              ),
              onTap: () {
                Get.to(() => ConversationPage(
                      conversationId: conversation['_id'],
                      username: name,
                      userAvatar: avatarUrl,
                      receiverId: receiverId,
                      isGroupChat: isGroupChat,
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
