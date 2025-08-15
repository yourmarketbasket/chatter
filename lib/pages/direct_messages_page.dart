import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/models/chat_models.dart';
import 'package:chatter/models/feed_models.dart';
import 'package:chatter/pages/chat_screen_page.dart';
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

  // Temporary dummy data until DataController is fully implemented
  final List<Chat> _dummyChats = [
    Chat(
      id: 'dm_1',
      isGroup: false,
      participants: [
        User(id: 'user_1', name: 'Alice', online: true, avatar: 'https://i.pravatar.cc/150?u=alice'),
        User(id: 'you', name: 'You'),
      ],
      lastMessage: ChatMessage(
        id: 'msg_1',
        chatId: 'dm_1',
        senderId: 'user_1',
        text: 'See you tomorrow!',
        status: MessageStatus.read,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ),
    Chat(
      id: 'dm_2',
      isGroup: false,
      participants: [
        User(id: 'user_2', name: 'Bob', online: false, avatar: 'https://i.pravatar.cc/150?u=bob'),
        User(id: 'you', name: 'You'),
      ],
      lastMessage: ChatMessage(
        id: 'msg_2',
        chatId: 'dm_2',
        senderId: 'you',
        text: 'Sounds good, thanks!',
        status: MessageStatus.delivered,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ),
  ];

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
      body: ListView.separated(
        itemCount: _dummyChats.length,
        separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1, indent: 80),
        itemBuilder: (context, index) {
          final chat = _dummyChats[index];
          final otherUser = chat.participants.firstWhere((p) => p.id != 'you', orElse: () => chat.participants.first);
          final lastMessage = chat.lastMessage;
          final String avatarUrl = otherUser.avatar ?? 'https://via.placeholder.com/150/teal/white?text=${otherUser.name[0]}';

          return ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[800],
              backgroundImage: CachedNetworkImageProvider(avatarUrl),
            ),
            title: Text(
              otherUser.name,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.white, fontSize: 16),
            ),
            subtitle: Text(
              lastMessage?.text ?? 'No messages yet...',
              style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              lastMessage != null ? '${lastMessage.createdAt.hour}:${lastMessage.createdAt.minute}' : '',
              style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12),
            ),
            onTap: () {
              Get.to(() => ChatScreen(chat: chat));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.snackbar('Coming Soon', 'Start new conversation will be implemented.',
              backgroundColor: Colors.blueAccent, colorText: Colors.white);
        },
        backgroundColor: Colors.tealAccent,
        child: const Icon(FeatherIcons.edit, color: Colors.black),
      ),
    );
  }
}
