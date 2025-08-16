import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/models/message_models.dart';
import 'package:chatter/pages/chat_screen_page.dart';
import 'package:flutter/material.dart';
import 'package:chatter/helpers/time_helper.dart';
import 'package:get/get.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final DataController _dataController = Get.find<DataController>();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
        return ListView.builder(
          itemCount: oneOnOneChats.length,
          itemBuilder: (context, index) {
            final chat = oneOnOneChats[index];
            final lastMessageData = chat['lastMessage'];
            final currentUserId = _dataController.user.value['user']['_id'];

            final otherUser = (chat['participants'] as List).firstWhere(
                (p) => p['_id'] != currentUserId,
                orElse: () => chat['participants'].first);

            String preview = '...';
            ChatMessage? lastMessage;
            if (lastMessageData != null) {
              lastMessage = ChatMessage.fromJson(lastMessageData);
              if (lastMessage.attachments != null &&
                  lastMessage.attachments!.isNotEmpty) {
                preview = 'Attachment';
              } else if (lastMessage.voiceNote != null) {
                preview = 'Voice note';
              } else {
                preview = lastMessage.text ?? '';
              }
              if (lastMessage.senderId == currentUserId) {
                preview = 'You: $preview';
              }
            }

            IconData statusIcon;
            Color statusColor;
            switch (lastMessage?.status) {
              case MessageStatus.sent:
                statusIcon = Icons.check;
                statusColor = Colors.grey[400]!;
                break;
              case MessageStatus.delivered:
                statusIcon = Icons.done_all;
                statusColor = Colors.grey[400]!;
                break;
              case MessageStatus.read:
                statusIcon = Icons.done_all;
                statusColor = Colors.tealAccent;
                break;
              default:
                statusIcon = Icons.access_time;
                statusColor = Colors.grey[400]!;
            }

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: CircleAvatar(
                backgroundColor: Colors.tealAccent,
                backgroundImage: otherUser['avatar'] != null && otherUser['avatar'].isNotEmpty
                    ? NetworkImage(otherUser['avatar'])
                    : null,
                child: otherUser['avatar'] == null || otherUser['avatar'].isEmpty
                    ? Text(otherUser['name']?[0] ?? '?',
                        style: const TextStyle(color: Colors.black))
                    : null,
              ),
              title: Text(otherUser['name'] ?? 'User',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500)),
              subtitle: Text(
                preview,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text(
                    otherUser['online'] == true
                        ? 'online'
                        : (otherUser['lastSeen'] != null
                            ? formatLastSeen(DateTime.parse(otherUser['lastSeen']))
                            : 'offline'),
                    style: TextStyle(
                      color: otherUser['online'] == true
                          ? Colors.tealAccent
                          : Colors.grey[400],
                      fontSize: 12,
                      fontWeight: otherUser['online'] == true
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (lastMessageData != null)
                    Text(
                      formatTime(DateTime.parse(lastMessageData['createdAt'])),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  if (lastMessage?.senderId == currentUserId)
                    Icon(
                      statusIcon,
                      size: 16,
                      color: statusColor,
                    ),
                ],
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
    );
  }
}