import 'package:chatter/models/chat_models.dart';
import 'package:chatter/models/feed_models.dart';
import 'package:chatter/pages/chat_screen_page.dart';
import 'package:flutter/material.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final List<Chat> _dummyChats = [
    Chat(
      id: 'chat_1',
      isGroup: false,
      participants: [
        User(id: 'user_1', name: 'Alice', online: true),
        User(id: 'you', name: 'You'),
      ],
      lastMessage: ChatMessage(
        id: 'msg_1',
        chatId: 'chat_1',
        senderId: 'user_1',
        text: 'Hey, how are you?',
        status: MessageStatus.read,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ),
    Chat(
      id: 'chat_2',
      isGroup: false,
      participants: [
        User(id: 'user_2', name: 'Bob', online: false),
        User(id: 'you', name: 'You'),
      ],
      lastMessage: ChatMessage(
        id: 'msg_2',
        chatId: 'chat_2',
        senderId: 'you',
        text: 'Check this out!',
        status: MessageStatus.delivered,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        attachments: [Attachment(filename: 'image.jpg', url: 'https://example.com/image.jpg', size: 1234)],
      ),
    ),
    Chat(
      id: 'chat_3',
      isGroup: false,
      participants: [
        User(id: 'user_3', name: 'Charlie', online: true),
        User(id: 'you', name: 'You'),
      ],
      lastMessage: ChatMessage(
        id: 'msg_3',
        chatId: 'chat_3',
        senderId: 'user_3',
        text: 'This message was deleted',
        status: MessageStatus.sent,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListView.builder(
        itemCount: _dummyChats.length,
        itemBuilder: (context, index) {
          final chat = _dummyChats[index];
          final otherUser = chat.participants.firstWhere((p) => p.id != 'you');
          final lastMessage = chat.lastMessage;

          String preview = '...';
          if (lastMessage != null) {
            if (lastMessage.attachments != null && lastMessage.attachments!.isNotEmpty) {
              preview = 'Attachment';
            } else {
              preview = lastMessage.text ?? '';
            }
            if (lastMessage.senderId == 'you') {
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.tealAccent,
                  child: Text(
                    otherUser.name[0],
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
                if (otherUser.online ?? false)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              otherUser.name,
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
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (lastMessage != null)
                  Text(
                    '${lastMessage.createdAt.hour}:${lastMessage.createdAt.minute}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
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
      ),
    );
  }
}