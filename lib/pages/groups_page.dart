import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/chat_screen_page.dart';
import 'package:chatter/pages/contacts_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final DataController _dataController = Get.find<DataController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (_dataController.isLoadingChats.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final groupChats = _dataController.chats.values
            .where((chat) => chat['isGroup'] == true)
            .toList();

        if (groupChats.isEmpty) {
          return const Center(
              child: Text('No groups yet.',
                  style: TextStyle(color: Colors.white)));
        }
        return ListView.builder(
          itemCount: groupChats.length,
          itemBuilder: (context, index) {
            final chat = groupChats[index];
            final lastMessage = chat['lastMessage'];
            final currentUserId = _dataController.user.value['user']['_id'];

            String preview = '...';
            if (lastMessage != null) {
              if (lastMessage['attachments'] != null &&
                  lastMessage['attachments'].isNotEmpty) {
                preview = 'Attachment';
              } else if (lastMessage['voiceNote'] != null) {
                preview = 'Voice note';
              } else {
                preview = lastMessage['text'] ?? '';
              }
              if (lastMessage['senderId'] == currentUserId) {
                preview = 'You: $preview';
              }
            }

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: CircleAvatar(
                backgroundColor: Colors.tealAccent,
                child: Text(
                  chat['groupName']?[0] ?? 'G',
                  style: const TextStyle(color: Colors.black),
                ),
              ),
              title: Text(
                chat['groupName'] ?? 'Group Chat',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                preview,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(chat: chat),
                  ),
                );
              },
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ContactsPage(isCreatingGroup: true)),
          );
        },
        backgroundColor: Colors.tealAccent,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}