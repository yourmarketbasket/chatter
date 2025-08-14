import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/conversation_page.dart';
import 'package:chatter/pages/create_group_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GroupsListPage extends StatefulWidget {
  const GroupsListPage({Key? key}) : super(key: key);

  @override
  _GroupsListPageState createState() => _GroupsListPageState();
}

class _GroupsListPageState extends State<GroupsListPage> {
  final DataController _dataController = Get.find<DataController>();

  @override
  void initState() {
    super.initState();
    _dataController.getAllChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text('Groups', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Obx(() {
        if (_dataController.isLoadingConversations.value) {
          return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
        }

        final groupChats = _dataController.groupConversations;

        if (groupChats.isEmpty) {
          return Center(
            child: Text(
              'You are not in any groups.',
              style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 16),
            ),
          );
        }
        return ListView.separated(
          itemCount: groupChats.length,
          separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1, indent: 80),
          itemBuilder: (context, index) {
            final conversation = groupChats[index];
            final String avatarUrl = conversation['groupAvatar'] ?? 'https://via.placeholder.com/150/green/white?text=G';
            final String groupName = conversation['groupName'] ?? 'Unnamed Group';
            final String lastMessageContent = conversation['lastMessage']?['content'] ?? 'No messages yet...';
            final String timestamp = conversation['lastMessage'] != null
                ? TimeOfDay.fromDateTime(DateTime.parse(conversation['lastMessage']['createdAt'])).format(context)
                : '';

            return ListTile(
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.tealAccent.withOpacity(0.3),
                backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                child: avatarUrl.isEmpty ? Text(groupName[0], style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.bold)) : null,
              ),
              title: Text(
                groupName,
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
                      username: groupName,
                      userAvatar: avatarUrl,
                      receiverId: '', // Not needed for group chat messages
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
