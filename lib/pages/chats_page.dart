import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/models/chat_models.dart';
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
  void initState() {
    super.initState();
    _dataController.fetchConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (_dataController.isLoadingConversations.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_dataController.conversations.isEmpty) {
          return const Center(
              child: Text('No conversations yet.',
                  style: TextStyle(color: Colors.white)));
        }
        return ListView.builder(
          itemCount: _dataController.conversations.length,
          itemBuilder: (context, index) {
            final chat = _dataController.conversations[index];
            final lastMessage = chat.lastMessage;

            Widget title;
            Widget avatar;
            Widget statusWidget;

            final currentUserId = _dataController.user.value['user']?['_id'];

            if (chat.isGroup) {
              title = Text(chat.groupName ?? 'Group Chat',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500));
              avatar = CircleAvatar(
                backgroundColor: Colors.tealAccent,
                child: Text(chat.groupName?[0] ?? 'G',
                    style: const TextStyle(color: Colors.black)),
              );
              final onlineCount =
                  chat.participants.where((p) => p.online ?? false).length;
              statusWidget = onlineCount > 0
                  ? Text('$onlineCount online',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12))
                  : const SizedBox.shrink();
            } else {
              final otherUser = chat.participants.firstWhere(
                  (p) => p.id != currentUserId,
                  orElse: () => chat.participants.first);
              title = Text(otherUser.name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500));
              avatar = CircleAvatar(
                backgroundColor: Colors.tealAccent,
                child: Text(otherUser.name[0],
                    style: const TextStyle(color: Colors.black)),
              );
              statusWidget = Text(
                otherUser.online == true
                    ? 'online'
                    : (otherUser.lastSeen != null
                        ? formatLastSeen(otherUser.lastSeen!)
                        : 'offline'),
                style: TextStyle(
                  color: otherUser.online == true
                      ? Colors.tealAccent
                      : Colors.grey[400],
                  fontSize: 12,
                  fontWeight: otherUser.online == true
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              );
            }

            String preview = '...';
            if (lastMessage != null) {
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
              leading: avatar,
              title: title,
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
                  statusWidget,
                  const SizedBox(height: 4),
                  if (lastMessage != null)
                    Text(
                      '${lastMessage.createdAt.hour}:${lastMessage.createdAt.minute}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 4),
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