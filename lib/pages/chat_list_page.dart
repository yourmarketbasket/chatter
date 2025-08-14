import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/models/chat_model.dart';
import 'package:chatter/pages/conversation_page.dart';
import 'package:chatter/pages/users_list_page.dart';
import 'package:chatter/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatListPage extends StatefulWidget {
  const ChatListPage({Key? key}) : super(key: key);

  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final DataController _dataController = Get.find<DataController>();

  @override
  void initState() {
    super.initState();
    _dataController.fetchChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(),
      body: Obx(() {
        if (_dataController.isLoadingChats.value) {
          return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
        }
        if (_dataController.chats.isEmpty) {
          return Center(
            child: Text(
              'No conversations yet.',
              style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 16),
            ),
          );
        }
        return ListView.separated(
          itemCount: _dataController.chats.length,
          separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1, indent: 80),
          itemBuilder: (context, index) {
            final ChatModel chat = _dataController.chats[index];
            final currentUserId = _dataController.user.value['user']['_id'];
            final otherParticipant = chat.participants.firstWhere((p) => p.id != currentUserId);

            return ListTile(
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey[800],
                backgroundImage: CachedNetworkImageProvider(otherParticipant.avatar),
              ),
              title: Text(
                otherParticipant.name,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.white, fontSize: 16),
              ),
              subtitle: Text(
                chat.lastMessage?.content ?? 'No messages yet...',
                style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                chat.lastMessage != null ? timeago.format(chat.lastMessage!.createdAt) : '',
                style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12),
              ),
              onTap: () {
                Get.to(() => ConversationPage(
                      chatId: chat.id,
                      receiver: otherParticipant,
                    ));
              },
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() => const UsersListPage());
        },
        backgroundColor: Colors.tealAccent,
        child: const Icon(FeatherIcons.edit, color: Colors.black),
      ),
    );
  }
}
