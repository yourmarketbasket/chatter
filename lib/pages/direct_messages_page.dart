import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/conversation_page.dart';
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
    // Call placeholder fetch method if conversations are empty
    if (_dataController.conversations.isEmpty) {
      _dataController.fetchConversations().catchError((e) {
        Get.snackbar('Error', 'Could not load conversations: ${e.toString()}',
            backgroundColor: Colors.red, colorText: Colors.white);
      });
    }
  }

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
            final String avatarUrl = conversation['userAvatar'] ?? 'https://via.placeholder.com/150/teal/white?text=U';
            final String username = conversation['username'] ?? 'Unknown User';
            final String lastMessage = conversation['lastMessage'] ?? 'No messages yet...';
            final String timestamp = conversation['timestamp'] ?? ''; // Should be formatted date/time

            return ListTile(
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey[800],
                backgroundImage: CachedNetworkImageProvider(avatarUrl),
              ),
              title: Text(
                username,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.white, fontSize: 16),
              ),
              subtitle: Text(
                lastMessage,
                style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                timestamp, // e.g., "10:30 AM" or "Yesterday"
                style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12),
              ),
              onTap: () {
                Get.to(() => ConversationPage(
                  conversationId: conversation['id'] ?? 'unknown_id',
                  username: username,
                  userAvatar: avatarUrl,
                ));
              },
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement start new conversation functionality
          Get.snackbar('Coming Soon', 'Start new conversation will be implemented.',
              backgroundColor: Colors.blueAccent, colorText: Colors.white);
        },
        backgroundColor: Colors.tealAccent,
        child: const Icon(FeatherIcons.edit, color: Colors.black),
      ),
    );
  }
}
