import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/chat_screen_page.dart';
import 'package:chatter/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatter/helpers/time_helper.dart';
import 'package:chatter/pages/contacts_page.dart';

class DirectMessagesPage extends StatefulWidget {
  const DirectMessagesPage({Key? key}) : super(key: key);

  @override
  _DirectMessagesPageState createState() => _DirectMessagesPageState();
}

class _DirectMessagesPageState extends State<DirectMessagesPage> {
  final DataController _dataController = Get.find<DataController>();

  @override
  Widget build(BuildContext context) {
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
        if (_dataController.isLoadingChats.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final oneOnOneChats = _dataController.chats.values
            .where((chat) => chat['isGroup'] == false)
            .toList();

        if (oneOnOneChats.isEmpty) {
          return const Center(
              child: Text('No conversations yet.',
                  style: TextStyle(color: Colors.white)));
        }
        return ListView.separated(
          itemCount: oneOnOneChats.length,
          separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1, indent: 80),
          itemBuilder: (context, index) {
            final chat = oneOnOneChats[index];
            final currentUserId = _dataController.user.value['user']['_id'];
            final otherUserRaw =
                (chat['participants'] as List<dynamic>).firstWhere(
              (p) {
                if (p is Map<String, dynamic>) {
                  return p['_id'] != currentUserId;
                }
                return p != currentUserId;
              },
              orElse: () => (chat['participants'] as List<dynamic>).first,
            );

            final otherUser = otherUserRaw is Map<String, dynamic>
                ? otherUserRaw
                : _dataController.allUsers.firstWhere(
                    (u) => u['_id'] == otherUserRaw,
                    orElse: () => {'name': 'Unknown', 'avatar': ''},
                  );
            final lastMessageData = chat['lastMessage'];
            final String avatarUrl = otherUser['avatar'] ??
                'https://via.placeholder.com/150/teal/white?text=${otherUser['name'][0]}';

            String preview = '...';
            if (lastMessageData != null &&
                lastMessageData is Map<String, dynamic>) {
              if (lastMessageData['attachments'] != null &&
                  (lastMessageData['attachments'] as List).isNotEmpty) {
                preview = 'Attachment';
              } else if (lastMessageData['voiceNote'] != null) {
                preview = 'Voice note';
              } else {
                preview = lastMessageData['text'] ?? '';
              }
              if (lastMessageData['senderId'] == currentUserId) {
                preview = 'You: $preview';
              }
            }

            return ListTile(
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey[800],
                backgroundImage: CachedNetworkImageProvider(avatarUrl),
              ),
              title: Text(
                otherUser['name'],
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontSize: 16),
              ),
              subtitle: Text(
                preview,
                style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                lastMessageData != null ? formatTime(DateTime.parse(lastMessageData['createdAt'])) : '',
                style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12),
              ),
              onTap: () {
                _dataController.currentChat.value = chat;
                Get.to(() => const ChatScreen());
              },
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() => const ContactsPage());
        },
        backgroundColor: Colors.tealAccent,
        child: const Icon(FeatherIcons.edit, color: Colors.black),
      ),
    );
  }
}
