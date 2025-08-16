import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/models/message_models.dart';
import 'package:chatter/pages/chat_screen_page.dart';
import 'package:chatter/pages/contacts_page.dart';
import 'package:flutter/material.dart';
import 'package:chatter/helpers/time_helper.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

            final otherUserRaw = (chat['participants'] as List<dynamic>).firstWhere(
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

            String preview = '...';
            ChatMessage? lastMessage;
            if (lastMessageData != null && lastMessageData is Map<String, dynamic>) {
              try {
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
              } catch (e, s) {
                print('Error parsing last message in chats_page: $e');
                print(s);
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
                radius: 24,
                backgroundColor: Colors.tealAccent.withOpacity(0.2),
                backgroundImage: otherUser['avatar'] != null && otherUser['avatar'].isNotEmpty
                    ? CachedNetworkImageProvider(otherUser['avatar'])
                    : null,
                child: otherUser['avatar'] == null || otherUser['avatar'].isEmpty
                    ? Text(otherUser['name']?[0] ?? '?',
                        style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold))
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
                  if (lastMessageData != null && lastMessageData is Map<String, dynamic>)
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